--!strict

--[[
	P5-0104 production owner for ordinary enemies. This service owns identity,
	spawn acceptance, lifecycle, health, model adaptation, and cleanup. Pursuit
	and contact attacks are integrated through the same bounded service update;
	clients receive no enemy-authority remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Enemy.EnemyContracts)
local EnemyDomain = require(script.Parent.EnemyDomain)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local LifecycleIds = EnemyContracts.LifecycleStateIds
local ActivityIds = EnemyContracts.ActivityStateIds
local SpawnReasons = EnemyContracts.SpawnRejectionReasonIds
local DamageReasons = EnemyContracts.DamageRejectionReasonIds

type EnemySpawnDefinition = EnemyContracts.EnemySpawnDefinition
type EnemySnapshot = EnemyContracts.EnemySnapshot

type EnemyRecord = {
	snapshot: EnemySnapshot,
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	processedDamageCorrelations: { [string]: boolean },
	lastMoveServerTimestamp: number?,
}

export type SpawnResult = {
	didSpawn: boolean,
	rejectionReasonId: string?,
	snapshot: EnemySnapshot?,
}

export type DamageResult = {
	didCommit: boolean,
	rejectionReasonId: string?,
	snapshot: EnemySnapshot?,
}

local Service = {}
local records: { [string]: EnemyRecord } = {}
local started = false
local accumulatedSeconds = 0
local updateConnection: RBXScriptConnection? = nil
local ownedFolder: Folder? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function copySnapshot(snapshot: EnemySnapshot): EnemySnapshot
	return table.freeze({
		entityId = snapshot.entityId,
		archetypeId = snapshot.archetypeId,
		lifecycleStateId = snapshot.lifecycleStateId,
		activityStateId = snapshot.activityStateId,
		health = snapshot.health,
		selectedOperativeEntityId = snapshot.selectedOperativeEntityId,
		spawnServerTimestamp = snapshot.spawnServerTimestamp,
		lastAttackServerTimestamp = snapshot.lastAttackServerTimestamp,
		cleanupDeadlineServerTimestamp = snapshot.cleanupDeadlineServerTimestamp,
		revision = snapshot.revision,
	})
end

local function spawnRejected(reasonId: string): SpawnResult
	return table.freeze({ didSpawn = false, rejectionReasonId = reasonId, snapshot = nil })
end

local function damageRejected(reasonId: string): DamageResult
	return table.freeze({ didCommit = false, rejectionReasonId = reasonId, snapshot = nil })
end

local function livingOperativePositions(): { Vector3 }
	local positions = {}
	for _, read in OperativeLifeService.readAll() do
		if read.snapshot.lifeStateId == OperativeLifeContracts.OperativeLifeStateIds.Alive then
			local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
			local character = if player == nil then nil else player.Character
			local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				table.insert(positions, (root :: BasePart).Position)
			end
		end
	end
	return positions
end

local function isVisibleFromLivingOperative(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local folder = ownedFolder
	if folder ~= nil then
		params.FilterDescendantsInstances = { folder }
	end
	for _, origin in livingOperativePositions() do
		local displacement = position - origin
		local result = Workspace:Raycast(origin + Vector3.new(0, 2, 0), displacement, params)
		if result == nil or (result.Position - position).Magnitude <= 4 then
			return true
		end
	end
	return false
end

local function isSpawnVolumeBlocked(position: Vector3): boolean
	local size = EnemyConfig.SpawnOverlapBoxSize
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local folder = ownedFolder
	if folder ~= nil then
		params.FilterDescendantsInstances = { folder }
	end
	local parts = Workspace:GetPartBoundsInBox(
		CFrame.new(position + Vector3.new(0, size.y * 0.5, 0)),
		Vector3.new(size.x, size.y, size.z),
		params
	)
	for _, part in parts do
		if part.CanCollide and part.Transparency < 1 then
			return true
		end
	end
	return false
end

local function createPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Slate
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function createModel(definition: EnemySpawnDefinition): (Model?, Humanoid?, BasePart?)
	local folder = ownedFolder
	if folder == nil then
		return nil, nil, nil
	end
	local position = Vector3.new(definition.position.x, definition.position.y, definition.position.z)
	local model = Instance.new("Model")
	model.Name = definition.entityId

	local rootSize = EnemyConfig.PlaceholderModel.RootSize
	local root = createPart(
		"HumanoidRootPart",
		Vector3.new(rootSize.x, rootSize.y, rootSize.z),
		CFrame.new(position + Vector3.new(0, EnemyConfig.PlaceholderModel.HipHeight, 0)),
		Color3.fromRGB(72, 78, 68),
		model
	)
	root.Transparency = 1

	local bodySize = EnemyConfig.PlaceholderModel.BodySize
	local body = createPart(
		"Body",
		Vector3.new(bodySize.x, bodySize.y, bodySize.z),
		root.CFrame * CFrame.new(0, bodySize.y * 0.45, 0),
		Color3.fromRGB(83, 97, 72),
		model
	)
	local headSize = EnemyConfig.PlaceholderModel.HeadSize
	local head = createPart(
		"Head",
		Vector3.new(headSize.x, headSize.y, headSize.z),
		root.CFrame * CFrame.new(0, bodySize.y + 0.4, 0),
		Color3.fromRGB(133, 139, 112),
		model
	)

	for _, part in { body, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = EnemyConfig.MaximumHealth
	humanoid.Health = EnemyConfig.MaximumHealth
	humanoid.WalkSpeed = EnemyConfig.WalkSpeedStudsPerSecond
	humanoid.HipHeight = EnemyConfig.PlaceholderModel.HipHeight
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("EnemyEntityId", definition.entityId)
	model:SetAttribute("EnemyArchetypeId", definition.archetypeId)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid, root
end

local function disclose(record: EnemyRecord)
	local snapshot = record.snapshot
	local model = record.model
	model:SetAttribute("EnemyLifecycleStateId", snapshot.lifecycleStateId)
	model:SetAttribute("EnemyActivityStateId", snapshot.activityStateId)
	model:SetAttribute("EnemyHealth", snapshot.health)
	model:SetAttribute("EnemyRevision", snapshot.revision)
end

local function activeCount(): number
	local count = 0
	for _, record in records do
		if record.snapshot.lifecycleStateId == LifecycleIds.Active then
			count += 1
		end
	end
	return count
end

function Service.requestSpawn(definition: EnemySpawnDefinition): SpawnResult
	local positions = livingOperativePositions()
	local facts = {
		started = started,
		definitionValid = EnemyContracts.validateSpawnDefinition(definition),
		duplicateEntityId = type(definition) == "table" and records[(definition :: any).entityId] ~= nil,
		activeCount = activeCount(),
		maximumActiveCount = EnemyConfig.MaximumActiveEnemies,
		insidePlayableBounds = false,
		tooCloseToLivingOperative = false,
		visibleToLivingOperative = false,
		blockedSpawnVolume = false,
	}
	if facts.definitionValid then
		local position = Vector3.new(definition.position.x, definition.position.y, definition.position.z)
		facts.insidePlayableBounds = math.abs(position.X) <= EnemyConfig.PlayableHalfExtentStuds
			and math.abs(position.Z) <= EnemyConfig.PlayableHalfExtentStuds
		for _, operativePosition in positions do
			if (operativePosition - position).Magnitude < EnemyConfig.MinimumFairSpawnDistanceStuds then
				facts.tooCloseToLivingOperative = true
				break
			end
		end
		if not facts.tooCloseToLivingOperative then
			facts.visibleToLivingOperative = isVisibleFromLivingOperative(position)
		end
		if not facts.visibleToLivingOperative then
			facts.blockedSpawnVolume = isSpawnVolumeBlocked(position)
		end
	end
	local rejection = EnemyDomain.evaluateSpawn(facts)
	if rejection ~= nil then
		return spawnRejected(rejection)
	end

	local model, humanoid, root = createModel(definition)
	if model == nil or humanoid == nil or root == nil then
		if model ~= nil then
			model:Destroy()
		end
		return spawnRejected(SpawnReasons.CreationFailed)
	end
	local serverTimestamp = now()
	local snapshot: EnemySnapshot = {
		entityId = definition.entityId,
		archetypeId = definition.archetypeId,
		lifecycleStateId = LifecycleIds.Active,
		activityStateId = ActivityIds.Idle,
		health = EnemyConfig.MaximumHealth,
		selectedOperativeEntityId = nil,
		spawnServerTimestamp = serverTimestamp,
		lastAttackServerTimestamp = nil,
		cleanupDeadlineServerTimestamp = nil,
		revision = 1,
	}
	local record: EnemyRecord = {
		snapshot = snapshot,
		model = model,
		humanoid = humanoid,
		rootPart = root,
		processedDamageCorrelations = {},
		lastMoveServerTimestamp = nil,
	}
	records[definition.entityId] = record
	disclose(record)
	return table.freeze({ didSpawn = true, rejectionReasonId = nil, snapshot = copySnapshot(snapshot) })
end

function Service.applyAuthoritativeDamage(
	entityId: string,
	expectedRevision: number?,
	correlationId: string,
	damage: number,
	serverTimestamp: number
): DamageResult
	if not started then
		return damageRejected(DamageReasons.ServiceStopped)
	end
	local record = records[entityId]
	if record == nil then
		return damageRejected(DamageReasons.UnknownEnemy)
	end
	if record.snapshot.lifecycleStateId ~= LifecycleIds.Active then
		return damageRejected(DamageReasons.InvalidLifecycleState)
	end
	if expectedRevision ~= nil and expectedRevision ~= record.snapshot.revision then
		return damageRejected(DamageReasons.StaleRevision)
	end
	if record.processedDamageCorrelations[correlationId] then
		return damageRejected(DamageReasons.DuplicateCorrelation)
	end
	local result = EnemyDomain.applyDamage(
		record.snapshot,
		correlationId,
		damage,
		serverTimestamp,
		record.processedDamageCorrelations
	)
	if not result.didCommit or result.snapshot == nil then
		return damageRejected(result.rejectionReasonId or DamageReasons.InvalidRequest)
	end
	record.processedDamageCorrelations[correlationId] = true
	record.snapshot = result.snapshot
	record.humanoid.Health = math.max(1, result.snapshot.health)
	if result.snapshot.lifecycleStateId == LifecycleIds.Dead then
		record.humanoid.WalkSpeed = 0
		record.humanoid.AutoRotate = false
	end
	disclose(record)
	return table.freeze({ didCommit = true, rejectionReasonId = nil, snapshot = copySnapshot(record.snapshot) })
end

function Service.read(entityId: string): EnemySnapshot?
	local record = records[entityId]
	return if record == nil then nil else copySnapshot(record.snapshot)
end

function Service.readAll(): { EnemySnapshot }
	local snapshots = {}
	for _, record in records do
		table.insert(snapshots, copySnapshot(record.snapshot))
	end
	table.sort(snapshots, function(a, b)
		return a.entityId < b.entityId
	end)
	return snapshots
end

local function removeRecord(entityId: string, record: EnemyRecord)
	record.snapshot = {
		entityId = record.snapshot.entityId,
		archetypeId = record.snapshot.archetypeId,
		lifecycleStateId = LifecycleIds.Removed,
		activityStateId = nil,
		health = record.snapshot.health,
		selectedOperativeEntityId = nil,
		spawnServerTimestamp = record.snapshot.spawnServerTimestamp,
		lastAttackServerTimestamp = record.snapshot.lastAttackServerTimestamp,
		cleanupDeadlineServerTimestamp = record.snapshot.cleanupDeadlineServerTimestamp,
		revision = record.snapshot.revision + 1,
	}
	record.model:Destroy()
	records[entityId] = nil
end

local function evaluateCleanup(serverTimestamp: number)
	for entityId, record in records do
		local snapshot = record.snapshot
		if
			snapshot.lifecycleStateId == LifecycleIds.Dead
			and snapshot.cleanupDeadlineServerTimestamp ~= nil
			and serverTimestamp >= snapshot.cleanupDeadlineServerTimestamp
		then
			removeRecord(entityId, record)
		end
	end
end

local function nearestLivingTarget(position: Vector3, currentTargetId: string?): (string?, Vector3?)
	local candidates = {}
	local positionById: { [string]: Vector3 } = {}
	for _, read in OperativeLifeService.readAll() do
		if read.snapshot.lifeStateId == OperativeLifeContracts.OperativeLifeStateIds.Alive then
			local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
			local character = if player == nil then nil else player.Character
			local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				local targetPosition = (root :: BasePart).Position
				positionById[read.operativeEntityId] = targetPosition
				table.insert(candidates, {
					operativeEntityId = read.operativeEntityId,
					distanceStuds = (targetPosition - position).Magnitude,
					isAlive = true,
				})
			end
		end
	end
	local targetId = EnemyDomain.selectTarget(
		currentTargetId,
		candidates,
		EnemyConfig.AcquisitionRadiusStuds,
		EnemyConfig.TargetLossRadiusStuds
	)
	return targetId, if targetId == nil then nil else positionById[targetId]
end

local function evaluateActive(record: EnemyRecord, serverTimestamp: number)
	if not record.model:IsDescendantOf(Workspace) or record.rootPart.Parent == nil or record.humanoid.Parent == nil then
		removeRecord(record.snapshot.entityId, record)
		return
	end
	local targetId, targetPosition =
		nearestLivingTarget(record.rootPart.Position, record.snapshot.selectedOperativeEntityId)
	local activityId = ActivityIds.Idle
	if targetId ~= nil and targetPosition ~= nil then
		local distance = (targetPosition - record.rootPart.Position).Magnitude
		activityId = if distance <= EnemyConfig.AttackRangeStuds then ActivityIds.Attacking else ActivityIds.Pursuing
		if activityId == ActivityIds.Pursuing then
			local lastMove = record.lastMoveServerTimestamp
			if lastMove == nil or serverTimestamp - lastMove >= EnemyConfig.DirectMoveRefreshIntervalSeconds then
				record.humanoid:MoveTo(targetPosition)
				record.lastMoveServerTimestamp = serverTimestamp
			end
		else
			record.humanoid:MoveTo(record.rootPart.Position)
		end
	end
	if record.snapshot.selectedOperativeEntityId ~= targetId or record.snapshot.activityStateId ~= activityId then
		record.snapshot = {
			entityId = record.snapshot.entityId,
			archetypeId = record.snapshot.archetypeId,
			lifecycleStateId = record.snapshot.lifecycleStateId,
			activityStateId = activityId,
			health = record.snapshot.health,
			selectedOperativeEntityId = targetId,
			spawnServerTimestamp = record.snapshot.spawnServerTimestamp,
			lastAttackServerTimestamp = record.snapshot.lastAttackServerTimestamp,
			cleanupDeadlineServerTimestamp = record.snapshot.cleanupDeadlineServerTimestamp,
			revision = record.snapshot.revision + 1,
		}
		disclose(record)
	end
end

function Service.evaluateAt(serverTimestamp: number)
	if not started then
		return
	end
	for _, record in records do
		if record.snapshot.lifecycleStateId == LifecycleIds.Active then
			evaluateActive(record, serverTimestamp)
		end
	end
	evaluateCleanup(serverTimestamp)
end

function Service.start()
	if started then
		return
	end
	started = true
	local existing = Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = EnemyConfig.ModelFolderName
	folder.Parent = Workspace
	ownedFolder = folder
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
	for entityId, record in records do
		record.model:Destroy()
		records[entityId] = nil
	end
	if ownedFolder ~= nil then
		ownedFolder:Destroy()
		ownedFolder = nil
	end
	accumulatedSeconds = 0
end

return Service
