--!strict

--[[
	P5-0105 integration owner between Blackwater Relay, production enemies, P3
	operative damage, and bounded pressure pacing. It keeps one service update
	connection and introduces no client authority path or additional scheduler.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Enemy.EnemyContracts)
local MissionConfig = require(ReplicatedStorage.Shared.Config.MissionConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local PressurePacingDomain = require(script.Parent.Parent.Domain.PressurePacingDomain)
local EnemyLifecycleService = require(script.Parent.EnemyLifecycleService)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local Service = {}
local started = false
local accumulatedSeconds = 0
local updateConnection: RBXScriptConnection? = nil
local releasedWaves: { [number]: boolean } = {}
local completedWaves: { [number]: boolean } = {}
local releasedWaveCount = 0
local lastWaveReleasedServerTimestamp: number? = nil
local recoveryUntilServerTimestamp: number? = nil
local lastAttackByEnemyId: { [string]: number } = {}
local attackSequenceByEnemyId: { [string]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function countActiveEnemies(): number
	local count = 0
	for _, snapshot in EnemyLifecycleService.readAll() do
		if snapshot.lifecycleStateId == EnemyContracts.LifecycleStateIds.Active then
			count += 1
		end
	end
	return count
end

local function requestWaveMembers(waveIndex: number)
	if completedWaves[waveIndex] then
		return
	end
	local wave = MissionConfig.Escalation.Waves[waveIndex]
	if wave == nil then
		return
	end

	local allMembersPresent = true
	for _, definition in wave do
		if EnemyLifecycleService.read(definition.id) == nil then
			local result = EnemyLifecycleService.requestSpawn({
				entityId = definition.id,
				archetypeId = EnemyContracts.ArchetypeIds.Shambler,
				position = { x = definition.x, y = definition.y, z = definition.z },
				facingDirection = nil,
				correlationId = string.format("%s.wave.%d.%s", MissionConfig.OperationId, waveIndex, definition.id),
			})
			if not result.didSpawn then
				allMembersPresent = false
			end
		end
	end

	if allMembersPresent then
		completedWaves[waveIndex] = true
	end
end

local function tryReleaseWave(waveIndex: number, missionResolved: boolean, serverTimestamp: number)
	if releasedWaves[waveIndex] then
		requestWaveMembers(waveIndex)
		return
	end

	local decision = PressurePacingDomain.evaluate({
		missionResolved = missionResolved,
		requestedWaveIndex = waveIndex,
		completedWaveCount = releasedWaveCount,
		activeEnemyCount = countActiveEnemies(),
		maximumConcurrentEnemies = MissionConfig.Escalation.MaximumConcurrentEnemies,
		serverTimestamp = serverTimestamp,
		lastWaveReleasedServerTimestamp = lastWaveReleasedServerTimestamp,
		minimumSecondsBetweenWaves = MissionConfig.Escalation.MinimumSecondsBetweenWaves,
		recoveryUntilServerTimestamp = recoveryUntilServerTimestamp,
	})
	if not decision.shouldReleaseWave then
		return
	end

	releasedWaves[waveIndex] = true
	releasedWaveCount = waveIndex
	lastWaveReleasedServerTimestamp = serverTimestamp
	recoveryUntilServerTimestamp = serverTimestamp + MissionConfig.Escalation.RecoverySecondsAfterWave
	requestWaveMembers(waveIndex)
end

local function operativeTarget(operativeEntityId: string): (Vector3?, number?)
	local read = OperativeLifeService.readByOperativeEntityId(operativeEntityId)
	if read == nil or read.snapshot.lifeStateId ~= OperativeLifeContracts.OperativeLifeStateIds.Alive then
		return nil, nil
	end
	local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
	local character = if player == nil then nil else player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return (root :: BasePart).Position, read.revision
end

local function enemyPosition(entityId: string): Vector3?
	local folder = Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
	local model = if folder == nil then nil else folder:FindFirstChild(entityId)
	if model == nil or not model:IsA("Model") then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

local function contactBlocked(origin: Vector3, target: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions = {}
	local folder = Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
	if folder ~= nil then
		table.insert(exclusions, folder)
	end
	params.FilterDescendantsInstances = exclusions
	local result = Workspace:Raycast(origin, target - origin, params)
	return result ~= nil and (result.Position - target).Magnitude > 4
end

local function evaluateAttack(enemySnapshot, serverTimestamp: number)
	if enemySnapshot.lifecycleStateId ~= EnemyContracts.LifecycleStateIds.Active then
		lastAttackByEnemyId[enemySnapshot.entityId] = nil
		attackSequenceByEnemyId[enemySnapshot.entityId] = nil
		return
	end
	local operativeEntityId = enemySnapshot.selectedOperativeEntityId
	if operativeEntityId == nil then
		return
	end
	local targetPosition, targetRevision = operativeTarget(operativeEntityId)
	local sourcePosition = enemyPosition(enemySnapshot.entityId)
	if targetPosition == nil or targetRevision == nil or sourcePosition == nil then
		return
	end
	if (targetPosition - sourcePosition).Magnitude > EnemyConfig.AttackRangeStuds then
		return
	end
	local lastAttack = lastAttackByEnemyId[enemySnapshot.entityId]
	if lastAttack ~= nil and serverTimestamp < lastAttack + EnemyConfig.AttackCadenceSeconds then
		return
	end
	if contactBlocked(sourcePosition + Vector3.new(0, 1.5, 0), targetPosition) then
		return
	end
	local sequence = (attackSequenceByEnemyId[enemySnapshot.entityId] or 0) + 1
	local damageEventId = string.format("enemy-contact:%s:%d", enemySnapshot.entityId, sequence)
	local result = OperativeLifeService.applyAuthoritativeDamage(operativeEntityId, targetRevision, {
		damageEventId = damageEventId,
		sourceEntityId = enemySnapshot.entityId,
		targetEntityId = operativeEntityId,
		damageAmount = EnemyConfig.AttackDamage,
		serverTimestamp = serverTimestamp,
	})
	if result.didCommit then
		attackSequenceByEnemyId[enemySnapshot.entityId] = sequence
		lastAttackByEnemyId[enemySnapshot.entityId] = serverTimestamp
	end
end

function Service.evaluateAt(serverTimestamp: number)
	if not started then
		return
	end
	local mission = MissionDirectorService.read()
	local missionResolved = mission.phaseId == "Resolved"
	if not missionResolved then
		local nextWaveIndex = releasedWaveCount + 1
		if nextWaveIndex <= mission.escalationLevel then
			tryReleaseWave(nextWaveIndex, false, serverTimestamp)
		end
		for waveIndex = 1, releasedWaveCount do
			requestWaveMembers(waveIndex)
		end
	end
	for _, enemySnapshot in EnemyLifecycleService.readAll() do
		evaluateAttack(enemySnapshot, serverTimestamp)
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	accumulatedSeconds = 0
	updateConnection = RunService.Heartbeat:Connect(function(deltaSeconds)
		accumulatedSeconds += deltaSeconds
		if accumulatedSeconds < EnemyConfig.SimulationIntervalSeconds then
			return
		end
		accumulatedSeconds %= EnemyConfig.SimulationIntervalSeconds
		Service.evaluateAt(now())
	end)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if updateConnection ~= nil then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	table.clear(releasedWaves)
	table.clear(completedWaves)
	table.clear(lastAttackByEnemyId)
	table.clear(attackSequenceByEnemyId)
	releasedWaveCount = 0
	lastWaveReleasedServerTimestamp = nil
	recoveryUntilServerTimestamp = nil
	accumulatedSeconds = 0
end

return Service
