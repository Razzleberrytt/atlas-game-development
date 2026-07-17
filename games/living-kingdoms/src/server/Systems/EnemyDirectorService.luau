--!strict

--[[
	P5-0105 production enemy lifecycle owner. One server-only director owns
	enemy identity, fair spawning, graybox bodies, behavior, movement intent,
	melee attacks, death, and cleanup. Decisions come from the pure
	EnemyBehaviorResolver; attacks commit through the existing authoritative
	P3 life boundary; operative fire commits through the revisioned enemy
	health boundary exposed here. No client remote exists: enemies replicate
	only as ordinary server-owned Workspace instances.

	Bounded by construction: one heartbeat connection, one evaluation pass at
	a configured interval, configured population caps, a bounded deferred
	fair-spawn queue, zero per-enemy connections, zero timers, and zero
	raycasts. Corpse cleanup and spawn retries ride the same pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnemyBehaviorResolver = require(script.Parent.EnemyBehaviorResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

type AuthoritativeEnemyAttack = EnemyContracts.AuthoritativeEnemyAttack
type EnemyOperativeFact = EnemyContracts.EnemyOperativeFact
type EnemySpawnRequest = EnemyContracts.EnemySpawnRequest
type EnemyWorldPosition = EnemyContracts.EnemyWorldPosition

local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds
local SpawnSourceIds = EnemyContracts.EnemySpawnSourceIds
local SpawnRejectionReasonIds = EnemyContracts.EnemySpawnRejectionReasonIds

export type SpawnResult = {
	didSpawn: boolean,
	wasDeferred: boolean,
	rejectionReasonId: string?,
}

export type EnemyCombatFact = {
	entityId: string,
	worldPosition: Vector3,
	isAlive: boolean,
	targetOperativeEntityId: string?,
	model: Model,
}

export type EnemyHealthRead = {
	revision: number,
	isAlive: boolean,
	healthState: {
		entityId: string,
		currentHealth: number,
		processedShotIds: { [string]: boolean },
	},
}

export type EvaluationSummary = {
	spawnedCount: number,
	attackCommittedCount: number,
	cleanedCount: number,
}

export type PressureRead = {
	isPressureActive: boolean,
	isStoodDown: boolean,
	escalationLevel: number,
	nextRoamingSpawnServerTimestamp: number?,
	recoveryWindowEndServerTimestamp: number?,
	pendingSpawnCount: number,
	activeEnemyCount: number,
}

type EnemyEntry = {
	entityId: string,
	spawnSourceId: string,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	healthLabel: TextLabel,
	behaviorStateId: string,
	targetOperativeEntityId: string?,
	lastAttackServerTimestamp: number?,
	healthRevision: number,
	healthState: {
		entityId: string,
		currentHealth: number,
		processedShotIds: { [string]: boolean },
	},
	isAlive: boolean,
	roamAnchor: EnemyWorldPosition,
	nextRoamRetargetServerTimestamp: number,
	cleanupAtServerTimestamp: number?,
}

type PendingSpawn = {
	request: EnemySpawnRequest,
	nextRetryServerTimestamp: number,
}

local ENEMY_FOLDER_NAME = "EnemyEntities"

local EnemyDirectorService = {}

local started = false
local enemyFolder: Folder? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local accumulatedSeconds = 0
local entries: { [string]: EnemyEntry } = {}
local activeEnemyCount = 0
local pendingSpawns: { PendingSpawn } = {}
local isPressureActive = false
local isStoodDown = false
local escalationLevel = 0
local nextRoamingSpawnServerTimestamp: number? = nil
local recoveryWindowEndServerTimestamp: number? = nil
-- Deterministic counter behind roam identity, wander headings, and spawn-ring
-- placement; no randomness enters enemy behavior.
local sequenceCounter = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function nextSequence(): number
	sequenceCounter += 1
	return sequenceCounter
end

local function copyStringSet(source: { [string]: boolean }): { [string]: boolean }
	return table.clone(source)
end

local function setHealthPresentation(entry: EnemyEntry)
	entry.healthLabel.Text =
		string.format("%s\nHealth: %d", entry.model.Name, math.max(0, entry.healthState.currentHealth))
	entry.root.Color = if entry.isAlive then Color3.fromRGB(126, 46, 46) else Color3.fromRGB(74, 74, 74)
end

local function readOperativeFacts(): { EnemyOperativeFact }
	local facts = {}
	for _, rosterRead in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(rosterRead.operativeEntityId)
		local character = if player == nil then nil else player.Character
		local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			local position = (root :: BasePart).Position
			table.insert(facts, {
				operativeEntityId = rosterRead.operativeEntityId,
				isAlive = rosterRead.snapshot.lifeStateId == "Alive",
				position = { x = position.X, y = position.Y, z = position.Z },
			})
		end
	end
	return facts
end

local function alivePositions(operativeFacts: { EnemyOperativeFact }): { EnemyWorldPosition }
	local positions = {}
	for _, fact in operativeFacts do
		if fact.isAlive then
			table.insert(positions, fact.position)
		end
	end
	return positions
end

local function populationCap(): number
	local operativeCount = #OperativeLifeService.readAll()
	return math.min(
		EnemyConfig.Population.AbsoluteMaximumConcurrent,
		EnemyConfig.Population.MaximumConcurrentPerOperative * math.max(1, operativeCount)
	)
end

local function spawnFacts(operativeFacts: { EnemyOperativeFact }): EnemyContracts.EnemySpawnFacts
	local existing = {}
	for entityId in entries do
		existing[entityId] = true
	end
	return {
		existingEnemyEntityIds = existing,
		activeEnemyCount = activeEnemyCount,
		populationCap = populationCap(),
		playableHalfExtentStuds = WorldFoundationConfig.PlayableHalfExtentStuds,
		alivePositions = alivePositions(operativeFacts),
	}
end

local function createEnemyBody(request: EnemySpawnRequest): (Model, BasePart, Humanoid, TextLabel)
	local model = Instance.new("Model")
	model.Name = request.displayName
	model:SetAttribute("CombatEntityId", request.entityId)
	model:SetAttribute("EnemyArchetypeId", request.archetypeId)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 5.6, 3)
	root.Position = Vector3.new(request.position.x, request.position.y + 3, request.position.z)
	root.Anchored = false
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = EnemyConfig.Walker.RoamSpeedStudsPerSecond
	humanoid.JumpPower = 0
	humanoid.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.MaxDistance = 220
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "Health"
	label.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Parent = billboard

	return model, root, humanoid, label
end

local function commitSpawn(request: EnemySpawnRequest, serverTimestamp: number)
	local folder = enemyFolder
	assert(folder ~= nil, "enemy spawns require the started director folder")
	local model, root, humanoid, label = createEnemyBody(request)
	local entry: EnemyEntry = {
		entityId = request.entityId,
		spawnSourceId = request.spawnSourceId,
		model = model,
		root = root,
		humanoid = humanoid,
		healthLabel = label,
		behaviorStateId = if isStoodDown then BehaviorStateIds.StandDown else BehaviorStateIds.Roaming,
		targetOperativeEntityId = nil,
		lastAttackServerTimestamp = nil,
		healthRevision = 1,
		healthState = {
			entityId = request.entityId,
			currentHealth = EnemyConfig.Walker.MaximumHealth,
			processedShotIds = {},
		},
		isAlive = true,
		roamAnchor = { x = request.position.x, y = request.position.y, z = request.position.z },
		nextRoamRetargetServerTimestamp = serverTimestamp,
		cleanupAtServerTimestamp = nil,
	}
	entries[request.entityId] = entry
	activeEnemyCount += 1
	setHealthPresentation(entry)
	model.Parent = folder
	-- Keep physical simulation server-owned so replicated movement cannot be
	-- steered by a client.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

--[[
	Validate and spawn one enemy now. An authored-wave placement that is only
	unfair (an operative stands too close) or over the cap defers into the
	bounded retry queue instead of appearing beside a player; roaming spawns
	never defer because the next interval simply proposes a fresh position.
]]
function EnemyDirectorService.spawnEnemy(request: EnemySpawnRequest): SpawnResult
	if not started then
		return { didSpawn = false, wasDeferred = false, rejectionReasonId = "ServiceStopped" }
	end
	local operativeFacts = readOperativeFacts()
	local resolution = EnemyBehaviorResolver.resolveSpawn(request, spawnFacts(operativeFacts))
	if resolution.isLegal then
		commitSpawn(request, now())
		return { didSpawn = true, wasDeferred = false, rejectionReasonId = nil }
	end
	local shouldDefer = request.spawnSourceId == SpawnSourceIds.AuthoredWave
		and (
			resolution.rejectionReasonId == SpawnRejectionReasonIds.TooCloseToOperative
			or resolution.rejectionReasonId == SpawnRejectionReasonIds.PopulationCapReached
		)
	if shouldDefer and #pendingSpawns < EnemyConfig.FairSpawn.MaximumDeferredSpawns then
		table.insert(pendingSpawns, {
			request = request,
			nextRetryServerTimestamp = now() + EnemyConfig.FairSpawn.DeferredRetryIntervalSeconds,
		})
		return { didSpawn = false, wasDeferred = true, rejectionReasonId = resolution.rejectionReasonId }
	end
	return { didSpawn = false, wasDeferred = false, rejectionReasonId = resolution.rejectionReasonId }
end

--[[
	Spawn one authored escalation wave. Raises the escalation level
	monotonically and opens the configured recovery window so roaming pressure
	pauses around the authored spike.
]]
function EnemyDirectorService.spawnAuthoredWave(
	waveIndex: number,
	definitions: { { id: string, name: string, x: number, y: number, z: number } }
): number
	if not started or type(waveIndex) ~= "number" or type(definitions) ~= "table" then
		return 0
	end
	escalationLevel = math.clamp(math.max(escalationLevel, waveIndex), 0, EnemyConfig.Pressure.MaximumEscalationLevel)
	recoveryWindowEndServerTimestamp = now() + EnemyConfig.Pressure.RecoveryWindowSeconds
	local accepted = 0
	for _, definition in definitions do
		local result = EnemyDirectorService.spawnEnemy({
			entityId = definition.id,
			archetypeId = EnemyConfig.Walker.ArchetypeId,
			spawnSourceId = SpawnSourceIds.AuthoredWave,
			displayName = definition.name,
			position = { x = definition.x, y = definition.y, z = definition.z },
		})
		if result.didSpawn or result.wasDeferred then
			accepted += 1
		end
	end
	return accepted
end

function EnemyDirectorService.beginOperationPressure()
	if not started then
		return
	end
	isPressureActive = true
	isStoodDown = false
	escalationLevel = 0
	local cadence = EnemyConfig.Pressure.RoamingByEscalationLevel[escalationLevel]
	nextRoamingSpawnServerTimestamp = now() + cadence.IntervalSeconds
	for _, entry in entries do
		if entry.isAlive and entry.behaviorStateId == BehaviorStateIds.StandDown then
			entry.behaviorStateId = BehaviorStateIds.Roaming
		end
	end
end

--[[
	Terminal stand-down at mission resolution: spawning stops, pending spawns
	clear, and every living enemy becomes inert so a resolved squad is not
	chased through the result screen.
]]
function EnemyDirectorService.endOperationPressure()
	if not started then
		return
	end
	isPressureActive = false
	isStoodDown = true
	nextRoamingSpawnServerTimestamp = nil
	recoveryWindowEndServerTimestamp = nil
	table.clear(pendingSpawns)
	for _, entry in entries do
		if entry.isAlive then
			entry.behaviorStateId = BehaviorStateIds.StandDown
			entry.targetOperativeEntityId = nil
			entry.humanoid.WalkSpeed = 0
		end
	end
end

function EnemyDirectorService.readEnemyCombatFacts(): { EnemyCombatFact }
	local facts = {}
	for _, entry in entries do
		if entry.isAlive then
			table.insert(facts, {
				entityId = entry.entityId,
				worldPosition = entry.root.Position,
				isAlive = true,
				targetOperativeEntityId = entry.targetOperativeEntityId,
				model = entry.model,
			})
		end
	end
	return facts
end

function EnemyDirectorService.readHealthState(entityId: string): EnemyHealthRead?
	local entry = entries[entityId]
	if entry == nil then
		return nil
	end
	return {
		revision = entry.healthRevision,
		isAlive = entry.isAlive,
		healthState = {
			entityId = entry.healthState.entityId,
			currentHealth = entry.healthState.currentHealth,
			processedShotIds = copyStringSet(entry.healthState.processedShotIds),
		},
	}
end

local function applyDeath(entry: EnemyEntry, serverTimestamp: number)
	entry.isAlive = false
	entry.behaviorStateId = BehaviorStateIds.Dead
	entry.targetOperativeEntityId = nil
	entry.humanoid.WalkSpeed = 0
	entry.root.Anchored = true
	entry.cleanupAtServerTimestamp = serverTimestamp + EnemyConfig.Cleanup.CorpseCleanupSeconds
	activeEnemyCount = math.max(0, activeEnemyCount - 1)
	setHealthPresentation(entry)
end

--[[
	Revisioned commit boundary for operative fire. The caller supplies the
	P2 DamageResolver output state; the commit is rejected unless identity
	matches, the expected revision is current, health never increases, and
	every previously processed ShotId is preserved.
]]
function EnemyDirectorService.commitHealthState(
	entityId: string,
	expectedRevision: number,
	healthStateAfter: {
		entityId: string,
		currentHealth: number,
		processedShotIds: { [string]: boolean },
	},
	serverTimestamp: number
): boolean
	local entry = entries[entityId]
	if
		entry == nil
		or not entry.isAlive
		or type(expectedRevision) ~= "number"
		or expectedRevision ~= entry.healthRevision
		or type(healthStateAfter) ~= "table"
		or healthStateAfter.entityId ~= entityId
		or type(healthStateAfter.currentHealth) ~= "number"
		or healthStateAfter.currentHealth ~= healthStateAfter.currentHealth
		or healthStateAfter.currentHealth > entry.healthState.currentHealth
		or type(healthStateAfter.processedShotIds) ~= "table"
		or type(serverTimestamp) ~= "number"
		or serverTimestamp ~= serverTimestamp
	then
		return false
	end
	for shotId in entry.healthState.processedShotIds do
		if healthStateAfter.processedShotIds[shotId] ~= true then
			return false
		end
	end
	entry.healthState = {
		entityId = entityId,
		currentHealth = healthStateAfter.currentHealth,
		processedShotIds = copyStringSet(healthStateAfter.processedShotIds),
	}
	entry.healthRevision += 1
	if entry.healthState.currentHealth <= 0 then
		applyDeath(entry, serverTimestamp)
	else
		setHealthPresentation(entry)
	end
	return true
end

function EnemyDirectorService.readActiveEnemyCount(): number
	return activeEnemyCount
end

function EnemyDirectorService.readPressureState(): PressureRead
	return table.freeze({
		isPressureActive = isPressureActive,
		isStoodDown = isStoodDown,
		escalationLevel = escalationLevel,
		nextRoamingSpawnServerTimestamp = nextRoamingSpawnServerTimestamp,
		recoveryWindowEndServerTimestamp = recoveryWindowEndServerTimestamp,
		pendingSpawnCount = #pendingSpawns,
		activeEnemyCount = activeEnemyCount,
	}) :: PressureRead
end

local function retryPendingSpawns(operativeFacts: { EnemyOperativeFact }, serverTimestamp: number): number
	local spawned = 0
	local index = 1
	while index <= #pendingSpawns do
		local pending = pendingSpawns[index]
		if serverTimestamp < pending.nextRetryServerTimestamp then
			index += 1
			continue
		end
		local resolution = EnemyBehaviorResolver.resolveSpawn(pending.request, spawnFacts(operativeFacts))
		if resolution.isLegal then
			commitSpawn(pending.request, serverTimestamp)
			table.remove(pendingSpawns, index)
			spawned += 1
		elseif
			resolution.rejectionReasonId == SpawnRejectionReasonIds.TooCloseToOperative
			or resolution.rejectionReasonId == SpawnRejectionReasonIds.PopulationCapReached
		then
			pending.nextRetryServerTimestamp = serverTimestamp + EnemyConfig.FairSpawn.DeferredRetryIntervalSeconds
			index += 1
		else
			-- Duplicate or invalid placements can never become legal.
			table.remove(pendingSpawns, index)
		end
	end
	return spawned
end

local function proposeRoamingPosition(anchor: EnemyWorldPosition): EnemyWorldPosition
	local sequence = nextSequence()
	-- Golden-angle sequence: deterministic, well-spread headings without
	-- randomness.
	local angle = sequence * 2.399963
	local ringMinimum = EnemyConfig.Pressure.RoamingSpawnMinimumDistanceStuds
	local ringMaximum = EnemyConfig.Pressure.RoamingSpawnMaximumDistanceStuds
	local fraction = (sequence % 7) / 7
	local distance = ringMinimum + fraction * (ringMaximum - ringMinimum)
	local halfExtent = WorldFoundationConfig.PlayableHalfExtentStuds
	return {
		x = math.clamp(anchor.x + math.cos(angle) * distance, -halfExtent, halfExtent),
		y = anchor.y,
		z = math.clamp(anchor.z + math.sin(angle) * distance, -halfExtent, halfExtent),
	}
end

local function attemptRoamingSpawns(operativeFacts: { EnemyOperativeFact }, serverTimestamp: number): number
	if not isPressureActive or isStoodDown then
		return 0
	end
	local nextSpawnAt = nextRoamingSpawnServerTimestamp
	if nextSpawnAt == nil or serverTimestamp < nextSpawnAt then
		return 0
	end
	local recoveryEnd = recoveryWindowEndServerTimestamp
	local cadence = EnemyConfig.Pressure.RoamingByEscalationLevel[escalationLevel]
	nextRoamingSpawnServerTimestamp = serverTimestamp + cadence.IntervalSeconds
	if recoveryEnd ~= nil and serverTimestamp < recoveryEnd then
		return 0
	end
	local anchors = alivePositions(operativeFacts)
	if #anchors == 0 then
		return 0
	end
	local spawned = 0
	for _ = 1, cadence.SpawnCount do
		local anchor = anchors[(nextSequence() % #anchors) + 1]
		local request: EnemySpawnRequest = {
			entityId = "enemy.roam:" .. tostring(nextSequence()) .. ":" .. tostring(serverTimestamp),
			archetypeId = EnemyConfig.Walker.ArchetypeId,
			spawnSourceId = SpawnSourceIds.RoamingPressure,
			displayName = EnemyConfig.Walker.DisplayName,
			position = proposeRoamingPosition(anchor),
		}
		local resolution = EnemyBehaviorResolver.resolveSpawn(request, spawnFacts(operativeFacts))
		if resolution.isLegal then
			commitSpawn(request, serverTimestamp)
			spawned += 1
		end
	end
	return spawned
end

local function applyBehavior(entry: EnemyEntry, operativeFacts: { EnemyOperativeFact }, serverTimestamp: number): number
	local decision = EnemyBehaviorResolver.resolveBehavior({
		entityId = entry.entityId,
		behaviorStateId = entry.behaviorStateId,
		position = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z },
		targetOperativeEntityId = entry.targetOperativeEntityId,
		lastAttackServerTimestamp = entry.lastAttackServerTimestamp,
	}, operativeFacts, serverTimestamp)
	if decision.rejectionReasonId ~= nil then
		return 0
	end
	entry.behaviorStateId = decision.behaviorStateIdAfter
	entry.targetOperativeEntityId = decision.targetOperativeEntityId

	if decision.behaviorStateIdAfter == BehaviorStateIds.Pursuing then
		local targetId = decision.targetOperativeEntityId
		entry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond
		for _, fact in operativeFacts do
			if fact.operativeEntityId == targetId then
				entry.humanoid:MoveTo(Vector3.new(fact.position.x, fact.position.y, fact.position.z))
				break
			end
		end
		return 0
	end
	if decision.behaviorStateIdAfter == BehaviorStateIds.Roaming then
		entry.humanoid.WalkSpeed = EnemyConfig.Walker.RoamSpeedStudsPerSecond
		if serverTimestamp >= entry.nextRoamRetargetServerTimestamp then
			entry.nextRoamRetargetServerTimestamp = serverTimestamp + EnemyConfig.Walker.RoamRetargetIntervalSeconds
			local angle = nextSequence() * 2.399963
			local anchor = entry.roamAnchor
			local radius = EnemyConfig.Walker.RoamWanderRadiusStuds
			entry.humanoid:MoveTo(
				Vector3.new(anchor.x + math.cos(angle) * radius, anchor.y, anchor.z + math.sin(angle) * radius)
			)
		end
		return 0
	end
	if decision.behaviorStateIdAfter ~= BehaviorStateIds.Attacking then
		return 0
	end

	entry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond
	local attack = decision.attack
	if not decision.shouldAttack or attack == nil then
		return 0
	end
	local targetRead = OperativeLifeService.readByOperativeEntityId(attack.targetEntityId)
	if targetRead == nil or targetRead.snapshot.lifeStateId ~= "Alive" then
		return 0
	end
	local commit = OperativeLifeService.applyAuthoritativeDamage(attack.targetEntityId, targetRead.revision, {
		damageEventId = attack.damageEventId,
		sourceEntityId = attack.sourceEntityId,
		targetEntityId = attack.targetEntityId,
		damageAmount = attack.damageAmount,
		serverTimestamp = attack.serverTimestamp,
	})
	if commit.didCommit then
		entry.lastAttackServerTimestamp = attack.serverTimestamp
		return 1
	end
	return 0
end

--[[
	One bounded evaluation pass driving every enemy: deferred fair-spawn
	retries, roaming pressure with recovery windows, behavior decisions with
	movement intent and attacks, and corpse cleanup. The heartbeat calls this
	at the configured interval; fixtures call it directly with deterministic
	timestamps.
]]
function EnemyDirectorService.evaluateAt(serverTimestamp: number): EvaluationSummary
	local summary = { spawnedCount = 0, attackCommittedCount = 0, cleanedCount = 0 }
	if not started or type(serverTimestamp) ~= "number" or serverTimestamp ~= serverTimestamp then
		return summary
	end
	local operativeFacts = readOperativeFacts()
	summary.spawnedCount += retryPendingSpawns(operativeFacts, serverTimestamp)
	summary.spawnedCount += attemptRoamingSpawns(operativeFacts, serverTimestamp)
	local toClean: { string } = {}
	for entityId, entry in entries do
		local cleanupAt = entry.cleanupAtServerTimestamp
		if cleanupAt ~= nil then
			if serverTimestamp >= cleanupAt then
				table.insert(toClean, entityId)
			end
		elseif entry.isAlive then
			summary.attackCommittedCount += applyBehavior(entry, operativeFacts, serverTimestamp)
		end
	end
	for _, entityId in toClean do
		local entry = entries[entityId]
		entries[entityId] = nil
		entry.model:Destroy()
		summary.cleanedCount += 1
	end
	return summary
end

function EnemyDirectorService.start()
	if started then
		return
	end
	started = true
	local existing = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = ENEMY_FOLDER_NAME
	folder.Parent = Workspace
	enemyFolder = folder
	accumulatedSeconds = 0
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < EnemyConfig.EvaluationIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		EnemyDirectorService.evaluateAt(now())
	end)
end

function EnemyDirectorService.stop()
	if not started then
		return
	end
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	table.clear(entries)
	table.clear(pendingSpawns)
	activeEnemyCount = 0
	isPressureActive = false
	isStoodDown = false
	escalationLevel = 0
	nextRoamingSpawnServerTimestamp = nil
	recoveryWindowEndServerTimestamp = nil
	accumulatedSeconds = 0
	sequenceCounter = 0
	local folder = enemyFolder
	if folder ~= nil then
		folder:Destroy()
		enemyFolder = nil
	end
end

return EnemyDirectorService
