--!strict

--[[
	P5-0104 integration owner between the authored Blackwater Relay mission,
	production enemy lifecycle, and P3 operative damage. It uses one bounded
	service update connection, creates no client authority path, and never owns
	enemy or operative health directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Enemy.EnemyContracts)
local MissionConfig = require(ReplicatedStorage.Shared.Config.MissionConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local AutomaticCombatDevelopmentHarness = require(script.Parent.AutomaticCombatDevelopmentHarness)
local EnemyLifecycleService = require(script.Parent.EnemyLifecycleService)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local Service = {}
local started = false
local accumulatedSeconds = 0
local updateConnection: RBXScriptConnection? = nil
local requestedWaves: { [number]: boolean } = {}
local lastAttackByEnemyId: { [string]: number } = {}
local attackSequenceByEnemyId: { [string]: number } = {}
local legacySpawnMissionHostile = AutomaticCombatDevelopmentHarness.spawnMissionHostile

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function requestWave(waveIndex: number)
	if requestedWaves[waveIndex] then
		return
	end
	local wave = MissionConfig.Escalation.Waves[waveIndex]
	if wave == nil then
		return
	end
	requestedWaves[waveIndex] = true
	for _, definition in wave do
		EnemyLifecycleService.requestSpawn({
			entityId = definition.id,
			archetypeId = EnemyContracts.ArchetypeIds.Shambler,
			position = { x = definition.x, y = definition.y, z = definition.z },
			facingDirection = nil,
			correlationId = string.format("%s.wave.%d", MissionConfig.OperationId, waveIndex),
		})
	end
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
	if mission.phaseId ~= "Resolved" then
		for waveIndex = 1, mission.escalationLevel do
			requestWave(waveIndex)
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
	-- MissionDirectorService still contains the P5-0103 Studio fixture call.
	-- Disable only that legacy adapter while this production integration owns
	-- authored waves; the harness keeps its two isolated P2 fixtures.
	AutomaticCombatDevelopmentHarness.spawnMissionHostile = function(): boolean
		return false
	end
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
	AutomaticCombatDevelopmentHarness.spawnMissionHostile = legacySpawnMissionHostile
	if updateConnection ~= nil then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	table.clear(requestedWaves)
	table.clear(lastAttackByEnemyId)
	table.clear(attackSequenceByEnemyId)
	accumulatedSeconds = 0
end

return Service