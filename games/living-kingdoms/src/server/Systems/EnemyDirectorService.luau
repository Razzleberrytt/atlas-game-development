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
	fair-spawn queue, zero per-enemy connections, zero timers, and bounded
	pathfinding work. Corpse cleanup and spawn retries ride the same pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local SpecialEnemyConfig = require(ReplicatedStorage.Shared.Config.SpecialEnemyConfig)
local BossConfig = require(ReplicatedStorage.Shared.Config.BossConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local SpecialEnemyContracts = require(ReplicatedStorage.Shared.Combat.SpecialEnemyContracts)
local BossContracts = require(ReplicatedStorage.Shared.Combat.BossContracts)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnemyBehaviorResolver = require(script.Parent.EnemyBehaviorResolver)
local SpecialEnemyBehaviorResolver = require(script.Parent.SpecialEnemyBehaviorResolver)
local BossPhaseResolver = require(script.Parent.BossPhaseResolver)
local EliteAffixResolver = require(script.Parent.EliteAffixResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local EnemyNavigationScheduler = require(script.Parent.Parent.Domain.EnemyNavigationScheduler)

type AuthoritativeEnemyAttack = EnemyContracts.AuthoritativeEnemyAttack
type EnemyOperativeFact = EnemyContracts.EnemyOperativeFact
type EnemySpawnRequest = EnemyContracts.EnemySpawnRequest
type EnemyWorldPosition = EnemyContracts.EnemyWorldPosition
type LingeringBloomZone = SpecialEnemyContracts.LingeringBloomZone

local SpecialBehaviorStateIds = SpecialEnemyContracts.SpecialEnemyBehaviorStateIds
local SpecialAbilityActionIds = SpecialEnemyContracts.SpecialAbilityActionIds
local BLIGHT_SPITTER_ARCHETYPE_ID = SpecialEnemyContracts.SpecialEnemyArchetypeIds.BlightSpitter
local BossPhaseIds = BossContracts.BossPhaseIds
local BossActionIds = BossContracts.BossActionIds
local PROGENITOR_ARCHETYPE_ID = BossContracts.BossArchetypeIds.Progenitor

local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds
local AttackWindupActionIds = EnemyContracts.EnemyAttackWindupActionIds
local PresentationAttributeNames = EnemyPresentationContracts.AttributeNames
local PresentationLifeStateIds = EnemyPresentationContracts.LifeStateIds
local SpawnSourceIds = EnemyContracts.EnemySpawnSourceIds
local SpawnRejectionReasonIds = EnemyContracts.EnemySpawnRejectionReasonIds

local function readIncomingDamageMultiplier(): number
	local storageAsAny = ReplicatedStorage :: any
	if type(storageAsAny.FindFirstChild) ~= "function" then
		return 1
	end
	local network = storageAsAny:FindFirstChild("ProgressionNetwork")
	if network == nil or type(network.GetAttribute) ~= "function" then
		return 1
	end
	local value = network:GetAttribute("RunIncomingDamageMultiplier")
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(value, 0, 1)
end

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
	maximumHealth: number,
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

export type BossStateRead = {
	exists: boolean,
	isAlive: boolean,
	isDefeated: boolean,
	phaseId: string?,
	isVulnerable: boolean,
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
	archetypeId: string,
	spawnSourceId: string,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	healthLabel: TextLabel,
	behaviorStateId: string,
	targetOperativeEntityId: string?,
	lastAttackServerTimestamp: number?,
	attackAttemptSequence: number,
	attackWindupTargetOperativeEntityId: string?,
	attackWindupStartedServerTimestamp: number?,
	attackWindupPresentationSequence: number?,
	attackPresentationSequence: number,
	hitPresentationSequence: number,
	healthRevision: number,
	healthState: {
		entityId: string,
		currentHealth: number,
		processedShotIds: { [string]: boolean },
	},
	isAlive: boolean,
	roamAnchor: EnemyWorldPosition,
	nextRoamRetargetServerTimestamp: number,
	nextPursuitRepathServerTimestamp: number,
	pursuitFlankSign: number,
	navigationProgressAnchor: EnemyWorldPosition,
	navigationProgressAnchorServerTimestamp: number,
	nextStuckRecoveryServerTimestamp: number,
	cleanupAtServerTimestamp: number?,
	eliteAffixId: string?,
	movementSpeedMultiplier: number,
	attackCadenceMultiplier: number,
	bonusFieldXp: number,
	maximumHealth: number,
	armorRemaining: number,
	nextRegenerationServerTimestamp: number?,
	volatileDetonateServerTimestamp: number?,
	volatileDidDetonate: boolean,
	commanderAuraActive: boolean,
	effectiveMovementSpeedMultiplier: number,
	effectiveAttackCadenceMultiplier: number,
	bloomChargeTargetPosition: EnemyWorldPosition?,
	bloomChargeStartedServerTimestamp: number?,
	lastBloomCommitServerTimestamp: number?,
	bossPhaseId: string?,
	bossIsVulnerable: boolean,
	bossFloodlightsRestored: boolean,
	bossBroodSummonedForPhase: boolean,
	bossVisibilityOverrideRadiusStuds: number?,
	bossSlamTargetPosition: EnemyWorldPosition?,
	bossSlamWindupStartedServerTimestamp: number?,
	bossLastSlamCommitServerTimestamp: number?,
}

type BloomZone = {
	zoneId: string,
	sourceEntityId: string,
	centerPosition: EnemyWorldPosition,
	radiusStuds: number,
	tickDamage: number,
	tickIntervalSeconds: number,
	lifetimeSeconds: number,
	committedServerTimestamp: number,
	lastTickServerTimestamp: number?,
}

type PendingSpawn = {
	request: EnemySpawnRequest,
	nextRetryServerTimestamp: number,
}

type EvaluationBudget = {
	pathComputationGrants: { [string]: boolean },
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
local sequenceCounter = 0
local navigationFairnessCursorEntityId: string? = nil
local operationPressureStartedServerTimestamp: number? = nil
local activeEliteCount = 0
local activeSpitterCount = 0
local activeBloomZones: { BloomZone } = {}
local activeBossEntityId: string? = nil
local bossDefeated = false

local EliteAffixIds = RunRpgContracts.EliteAffixIds

local NO_AFFIX_ASSIGNMENT = table.freeze({
	affixId = nil :: string?,
	maximumHealthMultiplier = 1,
	movementSpeedMultiplier = 1,
	attackCadenceMultiplier = 1,
	bonusFieldXp = 0,
})

local ELITE_DISPLAY_NAMES = table.freeze({
	[EliteAffixIds.Armored] = "ARMORED",
	[EliteAffixIds.Frenzied] = "FRENZIED",
	[EliteAffixIds.Regenerator] = "REGENERATOR",
	[EliteAffixIds.Volatile] = "VOLATILE",
	[EliteAffixIds.Commander] = "COMMANDER",
})

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

local function horizontalDistanceSquared(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

local function setHealthPresentation(entry: EnemyEntry)
	local billboard = entry.healthLabel.Parent
	if billboard ~= nil and billboard:IsA("BillboardGui") then
		billboard.Enabled = entry.isAlive and entry.eliteAffixId ~= nil
	end
	local displayName = if entry.eliteAffixId == nil then nil else ELITE_DISPLAY_NAMES[entry.eliteAffixId]
	if entry.volatileDetonateServerTimestamp ~= nil and not entry.volatileDidDetonate then
		displayName = "VOLATILE — DETONATING"
	end
	local armorLine = if entry.armorRemaining > 0 then string.format(" • Armor: %d", entry.armorRemaining) else ""
	local eliteLine = if displayName == nil then "" else displayName .. armorLine .. " • "
	entry.healthLabel.Text =
		string.format("%s%s  •  %d HP", eliteLine, entry.model.Name, math.max(0, entry.healthState.currentHealth))
	entry.root.Color = if entry.isAlive then Color3.fromRGB(126, 46, 46) else Color3.fromRGB(74, 74, 74)
end

local function setPresentationBehaviorState(entry: EnemyEntry, behaviorStateId: string)
	if entry.behaviorStateId == behaviorStateId then
		return
	end
	entry.behaviorStateId = behaviorStateId
	entry.model:SetAttribute(PresentationAttributeNames.BehaviorStateId, behaviorStateId)
end

local function initializePresentationAttributes(entry: EnemyEntry)
	entry.model:SetAttribute(PresentationAttributeNames.BehaviorStateId, entry.behaviorStateId)
	entry.model:SetAttribute(PresentationAttributeNames.LifeStateId, PresentationLifeStateIds.Alive)
	entry.model:SetAttribute(PresentationAttributeNames.WindupSequence, 0)
	entry.model:SetAttribute(PresentationAttributeNames.WindupStartedServerTimestamp, 0)
	entry.model:SetAttribute(PresentationAttributeNames.WindupCommitServerTimestamp, 0)
	entry.model:SetAttribute(PresentationAttributeNames.AttackSequence, 0)
	entry.model:SetAttribute(PresentationAttributeNames.AttackServerTimestamp, 0)
	entry.model:SetAttribute(PresentationAttributeNames.HitSequence, 0)
	entry.model:SetAttribute(PresentationAttributeNames.HitServerTimestamp, 0)
end

local function clearAttackWindup(entry: EnemyEntry)
	entry.attackWindupTargetOperativeEntityId = nil
	entry.attackWindupStartedServerTimestamp = nil
	entry.attackWindupPresentationSequence = nil
end

local function clearBloomCharge(entry: EnemyEntry)
	entry.bloomChargeTargetPosition = nil
	entry.bloomChargeStartedServerTimestamp = nil
end

local function clearBloomTelegraph(entry: EnemyEntry)
	entry.model:SetAttribute(PresentationAttributeNames.SpitterBloomChargeStartedServerTimestamp, 0)
	entry.model:SetAttribute(PresentationAttributeNames.SpitterBloomCommitServerTimestamp, 0)
end

local function clearBossSlamWindup(entry: EnemyEntry)
	entry.bossSlamTargetPosition = nil
	entry.bossSlamWindupStartedServerTimestamp = nil
end

local function clearBossSlamTelegraph(entry: EnemyEntry)
	entry.model:SetAttribute(PresentationAttributeNames.BossSlamStartedServerTimestamp, 0)
	entry.model:SetAttribute(PresentationAttributeNames.BossSlamCommitServerTimestamp, 0)
end

local function beginAttackWindup(entry: EnemyEntry, targetOperativeEntityId: string, serverTimestamp: number)
	entry.attackAttemptSequence += 1
	entry.attackWindupTargetOperativeEntityId = targetOperativeEntityId
	entry.attackWindupStartedServerTimestamp = serverTimestamp
	entry.attackWindupPresentationSequence = entry.attackAttemptSequence
	entry.model:SetAttribute(PresentationAttributeNames.WindupStartedServerTimestamp, serverTimestamp)
	entry.model:SetAttribute(
		PresentationAttributeNames.WindupCommitServerTimestamp,
		serverTimestamp + EnemyConfig.Walker.AttackWindupSeconds * entry.effectiveAttackCadenceMultiplier
	)
	entry.model:SetAttribute(PresentationAttributeNames.WindupSequence, entry.attackAttemptSequence)
end

local function discloseCommittedAttack(entry: EnemyEntry, serverTimestamp: number, presentationSequence: number)
	entry.attackPresentationSequence = presentationSequence
	entry.model:SetAttribute(PresentationAttributeNames.AttackServerTimestamp, serverTimestamp)
	entry.model:SetAttribute(PresentationAttributeNames.AttackSequence, presentationSequence)
end

local function discloseCommittedHit(entry: EnemyEntry, serverTimestamp: number)
	entry.hitPresentationSequence += 1
	entry.model:SetAttribute(PresentationAttributeNames.HitServerTimestamp, serverTimestamp)
	entry.model:SetAttribute(PresentationAttributeNames.HitSequence, entry.hitPresentationSequence)
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
	billboard.AlwaysOnTop = false
	billboard.Enabled = false
	billboard.Size = UDim2.fromOffset(168, 26)
	billboard.StudsOffset = Vector3.new(0, 3.8, 0)
	billboard.MaxDistance = 70
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "Health"
	label.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	label.BackgroundTransparency = 0.42
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 12
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = billboard

	return model, root, humanoid, label
end

local function commitSpawn(request: EnemySpawnRequest, serverTimestamp: number)
	local folder = enemyFolder
	assert(folder ~= nil, "enemy spawns require the started director folder")
	local model, root, humanoid, label = createEnemyBody(request)
	local isSpitter = request.archetypeId == BLIGHT_SPITTER_ARCHETYPE_ID
	local isBoss = request.archetypeId == PROGENITOR_ARCHETYPE_ID
	local assignment
	local maximumHealth
	if isBoss then
		assignment = NO_AFFIX_ASSIGNMENT
		maximumHealth = BossConfig.Progenitor.MaximumHealth
		humanoid.WalkSpeed = 0
		root.Size = Vector3.new(10, 14, 10)
		root.Position = Vector3.new(request.position.x, request.position.y + 7, request.position.z)
	elseif isSpitter then
		assignment = NO_AFFIX_ASSIGNMENT
		maximumHealth = SpecialEnemyConfig.BlightSpitter.MaximumHealth
		humanoid.WalkSpeed = SpecialEnemyConfig.BlightSpitter.RoamSpeedStudsPerSecond
	else
		local pressureStartedAt = operationPressureStartedServerTimestamp
		assignment = EliteAffixResolver.resolveAssignment({
			entityId = request.entityId,
			spawnSourceId = request.spawnSourceId,
			operationElapsedSeconds = if pressureStartedAt == nil
				then 0
				else math.max(0, serverTimestamp - pressureStartedAt),
			activeEliteCount = activeEliteCount,
			isBoss = false,
			isHordePulse = request.isHordePulse == true,
			hordeRoleId = request.hordeRoleId or "horde.role.infected",
		})
		maximumHealth =
			math.max(1, math.floor(EnemyConfig.Walker.MaximumHealth * assignment.maximumHealthMultiplier + 0.5))
	end
	local entry: EnemyEntry = {
		entityId = request.entityId,
		archetypeId = request.archetypeId,
		spawnSourceId = request.spawnSourceId,
		model = model,
		root = root,
		humanoid = humanoid,
		healthLabel = label,
		behaviorStateId = if isStoodDown then BehaviorStateIds.StandDown else BehaviorStateIds.Roaming,
		targetOperativeEntityId = nil,
		lastAttackServerTimestamp = nil,
		attackAttemptSequence = 0,
		attackWindupTargetOperativeEntityId = nil,
		attackWindupStartedServerTimestamp = nil,
		attackWindupPresentationSequence = nil,
		attackPresentationSequence = 0,
		hitPresentationSequence = 0,
		healthRevision = 1,
		healthState = {
			entityId = request.entityId,
			currentHealth = maximumHealth,
			processedShotIds = {},
		},
		isAlive = true,
		roamAnchor = { x = request.position.x, y = request.position.y, z = request.position.z },
		nextRoamRetargetServerTimestamp = serverTimestamp,
		nextPursuitRepathServerTimestamp = serverTimestamp,
		pursuitFlankSign = if nextSequence() % 2 == 0 then -1 else 1,
		navigationProgressAnchor = { x = root.Position.X, y = root.Position.Y, z = root.Position.Z },
		navigationProgressAnchorServerTimestamp = serverTimestamp,
		nextStuckRecoveryServerTimestamp = serverTimestamp,
		cleanupAtServerTimestamp = nil,
		eliteAffixId = assignment.affixId,
		movementSpeedMultiplier = assignment.movementSpeedMultiplier,
		attackCadenceMultiplier = assignment.attackCadenceMultiplier,
		bonusFieldXp = assignment.bonusFieldXp,
		maximumHealth = maximumHealth,
		armorRemaining = if assignment.affixId == EliteAffixIds.Armored
			then RunRpgConfig.ArmoredRuntime.armorCapacity
			else 0,
		nextRegenerationServerTimestamp = nil,
		volatileDetonateServerTimestamp = nil,
		volatileDidDetonate = false,
		commanderAuraActive = false,
		effectiveMovementSpeedMultiplier = assignment.movementSpeedMultiplier,
		effectiveAttackCadenceMultiplier = assignment.attackCadenceMultiplier,
		bloomChargeTargetPosition = nil,
		bloomChargeStartedServerTimestamp = nil,
		lastBloomCommitServerTimestamp = nil,
		bossPhaseId = if isBoss then BossPhaseIds.Carapace else nil,
		bossIsVulnerable = false,
		bossFloodlightsRestored = false,
		bossBroodSummonedForPhase = false,
		bossVisibilityOverrideRadiusStuds = nil,
		bossSlamTargetPosition = nil,
		bossSlamWindupStartedServerTimestamp = nil,
		bossLastSlamCommitServerTimestamp = nil,
	}
	model:SetAttribute(PresentationAttributeNames.EliteAffixId, assignment.affixId)
	model:SetAttribute(
		PresentationAttributeNames.EliteDisplayName,
		if assignment.affixId == nil then nil else ELITE_DISPLAY_NAMES[assignment.affixId]
	)
	model:SetAttribute(PresentationAttributeNames.EliteMovementSpeedMultiplier, assignment.movementSpeedMultiplier)
	model:SetAttribute(PresentationAttributeNames.EliteAttackCadenceMultiplier, assignment.attackCadenceMultiplier)
	model:SetAttribute(PresentationAttributeNames.EliteBonusFieldXp, assignment.bonusFieldXp)
	model:SetAttribute(PresentationAttributeNames.EliteArmorRemaining, entry.armorRemaining)
	model:SetAttribute(PresentationAttributeNames.EliteRegenerationReadyServerTimestamp, 0)
	model:SetAttribute(PresentationAttributeNames.EliteVolatileDetonateServerTimestamp, 0)
	model:SetAttribute(PresentationAttributeNames.EliteVolatileDetonationSequence, 0)
	model:SetAttribute(PresentationAttributeNames.EliteCommanderAuraActive, false)
	model:SetAttribute(
		PresentationAttributeNames.EffectiveMovementSpeedMultiplier,
		entry.effectiveMovementSpeedMultiplier
	)
	if assignment.affixId ~= nil then
		activeEliteCount += 1
		local telegraph = Instance.new("Highlight")
		local runtime = RunRpgConfig.EliteAffixRuntimeById[assignment.affixId]
		telegraph.Name = "EliteTelegraph"
		telegraph.FillColor = Color3.fromRGB(table.unpack(runtime.highlightFillColor))
		telegraph.OutlineColor = Color3.fromRGB(table.unpack(runtime.highlightOutlineColor))
		telegraph.FillTransparency = runtime.highlightFillTransparency
		telegraph.OutlineTransparency = runtime.highlightOutlineTransparency
		telegraph.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		telegraph.Parent = model
		if assignment.affixId == EliteAffixIds.Commander then
			local aura = Instance.new("Part")
			aura.Name = "EliteCommanderAura"
			aura.Shape = Enum.PartType.Ball
			aura.Size = Vector3.new(1, 1, 1) * RunRpgConfig.CommanderRuntime.auraRadiusStuds * 2
			aura.CFrame = root.CFrame
			aura.Anchored = false
			aura.CanCollide = false
			aura.CanQuery = false
			aura.CanTouch = false
			aura.Massless = true
			aura.Material = Enum.Material.Neon
			aura.Color = Color3.fromRGB(table.unpack(runtime.highlightOutlineColor))
			aura.Transparency = 0.88
			aura.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = aura
			weld.Parent = aura
		end
	end
	if isSpitter then
		activeSpitterCount += 1
	end
	if isBoss then
		activeBossEntityId = request.entityId
		bossDefeated = false
	end
	entries[request.entityId] = entry
	activeEnemyCount += 1
	setHealthPresentation(entry)
	initializePresentationAttributes(entry)
	if isSpitter then
		model:SetAttribute(PresentationAttributeNames.SpitterBloomChargeSequence, 0)
		model:SetAttribute(PresentationAttributeNames.SpitterBloomChargeStartedServerTimestamp, 0)
		model:SetAttribute(PresentationAttributeNames.SpitterBloomCommitServerTimestamp, 0)
		model:SetAttribute(PresentationAttributeNames.SpitterBloomCenterX, 0)
		model:SetAttribute(PresentationAttributeNames.SpitterBloomCenterZ, 0)
		model:SetAttribute(PresentationAttributeNames.SpitterBloomRadiusStuds, 0)
	end
	if isBoss then
		model:SetAttribute(PresentationAttributeNames.BossPhaseId, BossPhaseIds.Carapace)
		model:SetAttribute(PresentationAttributeNames.BossIsVulnerable, false)
		model:SetAttribute(PresentationAttributeNames.BossSlamSequence, 0)
		model:SetAttribute(PresentationAttributeNames.BossSlamStartedServerTimestamp, 0)
		model:SetAttribute(PresentationAttributeNames.BossSlamCommitServerTimestamp, 0)
		model:SetAttribute(PresentationAttributeNames.BossSlamCenterX, 0)
		model:SetAttribute(PresentationAttributeNames.BossSlamCenterZ, 0)
		model:SetAttribute(PresentationAttributeNames.BossSlamRadiusStuds, BossConfig.Slam.RadiusStuds)
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

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
			isHordePulse = true,
			hordeRoleId = "horde.role.infected",
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
	operationPressureStartedServerTimestamp = now()
	local cadence = EnemyConfig.Pressure.RoamingByEscalationLevel[escalationLevel]
	nextRoamingSpawnServerTimestamp = now() + cadence.IntervalSeconds
	for _, entry in entries do
		if entry.isAlive and entry.behaviorStateId == BehaviorStateIds.StandDown then
			setPresentationBehaviorState(entry, BehaviorStateIds.Roaming)
		end
	end
end

function EnemyDirectorService.endOperationPressure()
	if not started then
		return
	end
	isPressureActive = false
	isStoodDown = true
	nextRoamingSpawnServerTimestamp = nil
	recoveryWindowEndServerTimestamp = nil
	table.clear(pendingSpawns)
	table.clear(activeBloomZones)
	for _, entry in entries do
		if entry.isAlive then
			clearAttackWindup(entry)
			if entry.archetypeId == BLIGHT_SPITTER_ARCHETYPE_ID then
				clearBloomCharge(entry)
				clearBloomTelegraph(entry)
			end
			if entry.archetypeId == PROGENITOR_ARCHETYPE_ID then
				entry.bossIsVulnerable = false
				entry.bossVisibilityOverrideRadiusStuds = nil
				clearBossSlamWindup(entry)
				clearBossSlamTelegraph(entry)
				entry.model:SetAttribute(PresentationAttributeNames.BossIsVulnerable, false)
			end
			setPresentationBehaviorState(entry, BehaviorStateIds.StandDown)
			entry.targetOperativeEntityId = nil
			entry.humanoid.WalkSpeed = 0
			entry.commanderAuraActive = false
			entry.effectiveMovementSpeedMultiplier = entry.movementSpeedMultiplier
			entry.effectiveAttackCadenceMultiplier = entry.attackCadenceMultiplier
			entry.model:SetAttribute(PresentationAttributeNames.EliteCommanderAuraActive, false)
			entry.model:SetAttribute(
				PresentationAttributeNames.EffectiveMovementSpeedMultiplier,
				entry.effectiveMovementSpeedMultiplier
			)
		elseif entry.volatileDetonateServerTimestamp ~= nil and not entry.volatileDidDetonate then
			entry.volatileDidDetonate = true
			entry.volatileDetonateServerTimestamp = nil
			entry.model:SetAttribute(PresentationAttributeNames.EliteVolatileDetonateServerTimestamp, 0)
			local dangerZone = entry.model:FindFirstChild("EliteVolatileDangerZone")
			if dangerZone ~= nil then
				dangerZone:Destroy()
			end
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
		maximumHealth = entry.maximumHealth,
		healthState = {
			entityId = entry.healthState.entityId,
			currentHealth = entry.healthState.currentHealth,
			processedShotIds = copyStringSet(entry.healthState.processedShotIds),
		},
	}
end

local function applyDeath(entry: EnemyEntry, serverTimestamp: number)
	entry.isAlive = false
	clearAttackWindup(entry)
	clearBloomCharge(entry)
	setPresentationBehaviorState(entry, BehaviorStateIds.Dead)
	entry.model:SetAttribute(PresentationAttributeNames.LifeStateId, PresentationLifeStateIds.Dead)
	entry.targetOperativeEntityId = nil
	entry.humanoid.WalkSpeed = 0
	entry.root.Anchored = true
	entry.cleanupAtServerTimestamp = serverTimestamp + EnemyConfig.Cleanup.CorpseCleanupSeconds
	if entry.eliteAffixId == EliteAffixIds.Volatile then
		entry.volatileDetonateServerTimestamp = serverTimestamp + RunRpgConfig.VolatileRuntime.deathReactionDelaySeconds
		entry.model:SetAttribute(
			PresentationAttributeNames.EliteVolatileDetonateServerTimestamp,
			entry.volatileDetonateServerTimestamp
		)
		local dangerZone = Instance.new("Part")
		dangerZone.Name = "EliteVolatileDangerZone"
		dangerZone.Shape = Enum.PartType.Ball
		local diameter = RunRpgConfig.VolatileRuntime.deathReactionRadiusStuds * 2
		dangerZone.Size = Vector3.new(diameter, diameter, diameter)
		dangerZone.CFrame = entry.root.CFrame
		dangerZone.Anchored = true
		dangerZone.CanCollide = false
		dangerZone.CanQuery = false
		dangerZone.CanTouch = false
		dangerZone.Material = Enum.Material.Neon
		dangerZone.Color = Color3.fromRGB(table.unpack(RunRpgConfig.VolatileRuntime.highlightOutlineColor))
		dangerZone.Transparency = 0.72
		dangerZone.Parent = entry.model
	end
	activeEnemyCount = math.max(0, activeEnemyCount - 1)
	if entry.eliteAffixId ~= nil then
		activeEliteCount = math.max(0, activeEliteCount - 1)
	end
	if entry.archetypeId == BLIGHT_SPITTER_ARCHETYPE_ID then
		activeSpitterCount = math.max(0, activeSpitterCount - 1)
	end
	if entry.archetypeId == PROGENITOR_ARCHETYPE_ID then
		bossDefeated = true
		activeBossEntityId = nil
		entry.bossIsVulnerable = false
		entry.bossPhaseId = BossPhaseIds.Defeated
		clearBossSlamWindup(entry)
		clearBossSlamTelegraph(entry)
		entry.model:SetAttribute(PresentationAttributeNames.BossPhaseId, BossPhaseIds.Defeated)
		entry.model:SetAttribute(PresentationAttributeNames.BossIsVulnerable, false)
	end
	setHealthPresentation(entry)
end

function EnemyDirectorService.commitHealthState(
	entityId: string,
	expectedRevision: number,
	healthStateAfter: {
		entityId: string,
		currentHealth: number,
		processedShotIds: { [string]: boolean },
	},
	serverTimestamp: number
): (boolean, number?)
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
		return false, nil
	end
	if entry.archetypeId == PROGENITOR_ARCHETYPE_ID and not entry.bossIsVulnerable then
		return false, nil
	end
	for shotId in entry.healthState.processedShotIds do
		if healthStateAfter.processedShotIds[shotId] ~= true then
			return false, nil
		end
	end
	local previousHealth = entry.healthState.currentHealth
	local requestedDamage = previousHealth - healthStateAfter.currentHealth
	local committedDamage = requestedDamage
	if requestedDamage > 0 and entry.armorRemaining > 0 then
		local runtime = RunRpgConfig.ArmoredRuntime
		local reducedDamage = math.max(1, math.floor(requestedDamage * runtime.damageTakenMultiplierWhileArmored + 0.5))
		local absorbedDamage = math.min(entry.armorRemaining, math.max(0, requestedDamage - reducedDamage))
		entry.armorRemaining -= absorbedDamage
		committedDamage = requestedDamage - absorbedDamage
		entry.model:SetAttribute(PresentationAttributeNames.EliteArmorRemaining, entry.armorRemaining)
	end
	entry.healthState = {
		entityId = entityId,
		currentHealth = math.max(0, previousHealth - committedDamage),
		processedShotIds = copyStringSet(healthStateAfter.processedShotIds),
	}
	entry.healthRevision += 1
	if entry.healthState.currentHealth < previousHealth then
		if entry.eliteAffixId == EliteAffixIds.Regenerator then
			entry.nextRegenerationServerTimestamp = serverTimestamp
				+ RunRpgConfig.RegeneratorRuntime.damageRecoveryDelaySeconds
			entry.model:SetAttribute(
				PresentationAttributeNames.EliteRegenerationReadyServerTimestamp,
				entry.nextRegenerationServerTimestamp
			)
		end
		discloseCommittedHit(entry, serverTimestamp)
	end
	if entry.healthState.currentHealth <= 0 then
		applyDeath(entry, serverTimestamp)
	else
		setHealthPresentation(entry)
	end
	return true, committedDamage
end

function EnemyDirectorService.readActiveEnemyCount(): number
	return activeEnemyCount
end

function EnemyDirectorService.spawnBoss(position: EnemyWorldPosition, floodlightsRestored: boolean): boolean
	if not started or activeBossEntityId ~= nil or type(position) ~= "table" then
		return false
	end
	local request: EnemySpawnRequest = {
		entityId = "boss.progenitor:" .. tostring(nextSequence()),
		archetypeId = PROGENITOR_ARCHETYPE_ID,
		spawnSourceId = SpawnSourceIds.AuthoredWave,
		displayName = BossConfig.Progenitor.DisplayName,
		position = { x = position.x, y = position.y, z = position.z },
	}
	commitSpawn(request, now())
	local entry = entries[request.entityId]
	if entry ~= nil then
		entry.bossFloodlightsRestored = floodlightsRestored == true
	end
	return true
end

function EnemyDirectorService.isBossEntity(entityId: string): boolean
	return type(entityId) == "string" and entityId ~= "" and activeBossEntityId == entityId
end

function EnemyDirectorService.readBossState(): BossStateRead
	local bossId = activeBossEntityId
	local entry = if bossId ~= nil then entries[bossId] else nil
	if entry == nil then
		return table.freeze({
			exists = false,
			isAlive = false,
			isDefeated = bossDefeated,
			phaseId = nil,
			isVulnerable = false,
		}) :: BossStateRead
	end
	return table.freeze({
		exists = true,
		isAlive = entry.isAlive,
		isDefeated = bossDefeated,
		phaseId = entry.bossPhaseId,
		isVulnerable = entry.bossIsVulnerable,
	}) :: BossStateRead
end

function EnemyDirectorService.readGameplayVisibilityRadiusStuds(): number
	local normal = EnemyConfig.Combat.GameplayVisibilityRadiusStuds
	local bossId = activeBossEntityId
	local entry = if bossId ~= nil then entries[bossId] else nil
	if entry ~= nil and entry.isAlive then
		local override = entry.bossVisibilityOverrideRadiusStuds
		if override ~= nil then
			return math.min(normal, override)
		end
	end
	return normal
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
			table.remove(pendingSpawns, index)
		end
	end
	return spawned
end

local function proposeRoamingPosition(anchor: EnemyWorldPosition): EnemyWorldPosition
	local sequence = nextSequence()
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
	local shouldSpawnSpitter = escalationLevel >= SpecialEnemyConfig.Spawn.IntroductionEscalationLevel
		and activeSpitterCount < SpecialEnemyConfig.Spawn.MaximumConcurrent
	local stalkerSpawnCount = cadence.SpawnCount - (if shouldSpawnSpitter then 1 else 0)
	for _ = 1, stalkerSpawnCount do
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
	if shouldSpawnSpitter then
		local anchor = anchors[(nextSequence() % #anchors) + 1]
		local spitterRequest: EnemySpawnRequest = {
			entityId = "enemy.spitter:" .. tostring(nextSequence()) .. ":" .. tostring(serverTimestamp),
			archetypeId = SpecialEnemyConfig.BlightSpitter.ArchetypeId,
			spawnSourceId = SpawnSourceIds.RoamingPressure,
			displayName = SpecialEnemyConfig.BlightSpitter.DisplayName,
			position = proposeRoamingPosition(anchor),
		}
		local spitterResolution = EnemyBehaviorResolver.resolveSpawn(spitterRequest, spawnFacts(operativeFacts))
		if spitterResolution.isLegal then
			commitSpawn(spitterRequest, serverTimestamp)
			spawned += 1
		end
	end
	return spawned
end

local function commitBloomImpacts(impacts: { AuthoritativeEnemyAttack }, serverTimestamp: number): number
	local committed = 0
	local mitigation = readIncomingDamageMultiplier()
	for _, impact in impacts do
		local targetRead = OperativeLifeService.readByOperativeEntityId(impact.targetEntityId)
		if targetRead == nil or targetRead.snapshot.lifeStateId ~= "Alive" then
			continue
		end
		local reducedDamage = math.max(1, math.floor(impact.damageAmount * mitigation + 0.5))
		local commit = OperativeLifeService.applyAuthoritativeDamage(impact.targetEntityId, targetRead.revision, {
			damageEventId = impact.damageEventId,
			sourceEntityId = impact.sourceEntityId,
			targetEntityId = impact.targetEntityId,
			damageAmount = reducedDamage,
			serverTimestamp = serverTimestamp,
		})
		if commit.didCommit then
			committed += 1
		end
	end
	return committed
end

local function registerBloomZone(zone: LingeringBloomZone)
	if #activeBloomZones >= SpecialEnemyConfig.Bloom.MaximumActiveZones then
		table.remove(activeBloomZones, 1)
	end
	table.insert(activeBloomZones, {
		zoneId = zone.zoneId,
		sourceEntityId = zone.sourceEntityId,
		centerPosition = zone.centerPosition,
		radiusStuds = zone.radiusStuds,
		tickDamage = zone.tickDamage,
		tickIntervalSeconds = zone.tickIntervalSeconds,
		lifetimeSeconds = zone.lifetimeSeconds,
		committedServerTimestamp = zone.committedServerTimestamp,
		lastTickServerTimestamp = zone.lastTickServerTimestamp,
	})
end

local function tickBloomZones(operativeFacts: { EnemyOperativeFact }, serverTimestamp: number): number
	local committed = 0
	local index = 1
	while index <= #activeBloomZones do
		local zone = activeBloomZones[index]
		local resolution = SpecialEnemyBehaviorResolver.resolveLingeringDamage(zone, operativeFacts, serverTimestamp)
		if not resolution.isActive then
			table.remove(activeBloomZones, index)
			continue
		end
		if resolution.ticked then
			zone.lastTickServerTimestamp = resolution.tickServerTimestamp
			committed += commitBloomImpacts(resolution.impacts, serverTimestamp)
		end
		index += 1
	end
	return committed
end

local function applySpitterBehavior(
	entry: EnemyEntry,
	operativeFacts: { EnemyOperativeFact },
	serverTimestamp: number
): number
	local decision = SpecialEnemyBehaviorResolver.resolveBehavior({
		entityId = entry.entityId,
		behaviorStateId = entry.behaviorStateId,
		position = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z },
		anchorOperativeEntityId = entry.targetOperativeEntityId,
		lastBloomCommitServerTimestamp = entry.lastBloomCommitServerTimestamp,
		bloomChargeTargetPosition = entry.bloomChargeTargetPosition,
		bloomChargeStartedServerTimestamp = entry.bloomChargeStartedServerTimestamp,
	}, operativeFacts, serverTimestamp)
	if decision.rejectionReasonId ~= nil then
		return 0
	end
	setPresentationBehaviorState(entry, decision.behaviorStateIdAfter)
	entry.targetOperativeEntityId = decision.anchorOperativeEntityId

	local action = decision.bloomActionId
	if action == SpecialAbilityActionIds.Begin then
		local target = decision.bloomTargetPosition
		if target == nil then
			return 0
		end
		entry.bloomChargeStartedServerTimestamp = serverTimestamp
		entry.bloomChargeTargetPosition = { x = target.x, y = target.y, z = target.z }
		entry.humanoid.WalkSpeed = 0
		entry.attackAttemptSequence += 1
		entry.model:SetAttribute(PresentationAttributeNames.SpitterBloomChargeSequence, entry.attackAttemptSequence)
		entry.model:SetAttribute(PresentationAttributeNames.SpitterBloomChargeStartedServerTimestamp, serverTimestamp)
		entry.model:SetAttribute(
			PresentationAttributeNames.SpitterBloomCommitServerTimestamp,
			serverTimestamp + SpecialEnemyConfig.Bloom.ChargeWindupSeconds
		)
		entry.model:SetAttribute(PresentationAttributeNames.SpitterBloomCenterX, target.x)
		entry.model:SetAttribute(PresentationAttributeNames.SpitterBloomCenterZ, target.z)
		entry.model:SetAttribute(
			PresentationAttributeNames.SpitterBloomRadiusStuds,
			SpecialEnemyConfig.Bloom.ImpactRadiusStuds
		)
		return 0
	elseif action == SpecialAbilityActionIds.Continue then
		entry.humanoid.WalkSpeed = 0
		return 0
	elseif action == SpecialAbilityActionIds.Commit then
		entry.humanoid.WalkSpeed = 0
		local committed = commitBloomImpacts(decision.bloomImpacts, serverTimestamp)
		if decision.lingeringZone ~= nil then
			registerBloomZone(decision.lingeringZone)
		end
		clearBloomCharge(entry)
		entry.lastBloomCommitServerTimestamp = serverTimestamp
		clearBloomTelegraph(entry)
		return committed
	elseif action == SpecialAbilityActionIds.Cancel then
		clearBloomCharge(entry)
		clearBloomTelegraph(entry)
	end

	local state = decision.behaviorStateIdAfter
	if state == SpecialBehaviorStateIds.Approaching then
		entry.humanoid.WalkSpeed = SpecialEnemyConfig.BlightSpitter.PursuitSpeedStudsPerSecond
		local anchorId = decision.anchorOperativeEntityId
		for _, fact in operativeFacts do
			if fact.operativeEntityId == anchorId then
				entry.humanoid:MoveTo(Vector3.new(fact.position.x, fact.position.y, fact.position.z))
				break
			end
		end
	elseif state == SpecialBehaviorStateIds.Roaming then
		entry.humanoid.WalkSpeed = SpecialEnemyConfig.BlightSpitter.RoamSpeedStudsPerSecond
		if serverTimestamp >= entry.nextRoamRetargetServerTimestamp then
			entry.nextRoamRetargetServerTimestamp = serverTimestamp + EnemyConfig.Walker.RoamRetargetIntervalSeconds
			local angle = nextSequence() * 2.399963
			local anchor = entry.roamAnchor
			local radius = EnemyConfig.Walker.RoamWanderRadiusStuds
			entry.humanoid:MoveTo(
				Vector3.new(anchor.x + math.cos(angle) * radius, anchor.y, anchor.z + math.sin(angle) * radius)
			)
		end
	elseif state == SpecialBehaviorStateIds.Recovering then
		entry.humanoid.WalkSpeed = 0
	end
	return 0
end

local function summonBroodSurge(
	entry: EnemyEntry,
	count: number,
	operativeFacts: { EnemyOperativeFact },
	serverTimestamp: number
)
	local anchor = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z }
	for _ = 1, count do
		local request: EnemySpawnRequest = {
			entityId = "enemy.brood:" .. tostring(nextSequence()) .. ":" .. tostring(serverTimestamp),
			archetypeId = EnemyConfig.Walker.ArchetypeId,
			spawnSourceId = SpawnSourceIds.AuthoredWave,
			displayName = EnemyConfig.Walker.DisplayName,
			position = proposeRoamingPosition(anchor),
			isHordePulse = true,
			hordeRoleId = "horde.role.infected",
		}
		if EnemyBehaviorResolver.resolveSpawn(request, spawnFacts(operativeFacts)).isLegal then
			commitSpawn(request, serverTimestamp)
		end
	end
end

local function applyBossBehavior(
	entry: EnemyEntry,
	operativeFacts: { EnemyOperativeFact },
	serverTimestamp: number
): number
	if isStoodDown then
		return 0
	end
	local decision = BossPhaseResolver.resolveBossPhase({
		entityId = entry.entityId,
		phaseId = entry.bossPhaseId :: string,
		position = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z },
		currentHealth = entry.healthState.currentHealth,
		maximumHealth = entry.maximumHealth,
		lastSlamCommitServerTimestamp = entry.bossLastSlamCommitServerTimestamp,
		slamWindupStartedServerTimestamp = entry.bossSlamWindupStartedServerTimestamp,
		slamTargetPosition = entry.bossSlamTargetPosition,
		broodSummonedForPhase = entry.bossBroodSummonedForPhase,
		floodlightsRestored = entry.bossFloodlightsRestored,
	}, operativeFacts, serverTimestamp)
	if decision.rejectionReasonId ~= nil then
		return 0
	end

	if entry.bossPhaseId ~= decision.phaseIdAfter then
		entry.bossPhaseId = decision.phaseIdAfter
		entry.model:SetAttribute(PresentationAttributeNames.BossPhaseId, decision.phaseIdAfter)
	end
	if entry.bossIsVulnerable ~= decision.isVulnerable then
		entry.bossIsVulnerable = decision.isVulnerable
		entry.model:SetAttribute(PresentationAttributeNames.BossIsVulnerable, decision.isVulnerable)
	end
	entry.bossVisibilityOverrideRadiusStuds = decision.visibilityOverrideRadiusStuds

	if decision.shouldSummonBrood then
		entry.bossBroodSummonedForPhase = true
		summonBroodSurge(entry, decision.broodSurgeCount, operativeFacts, serverTimestamp)
	end

	local action = decision.slamActionId
	if action == BossActionIds.Begin then
		local target = decision.slamTargetPosition
		if target ~= nil then
			entry.bossSlamWindupStartedServerTimestamp = serverTimestamp
			entry.bossSlamTargetPosition = { x = target.x, y = target.y, z = target.z }
			entry.attackAttemptSequence += 1
			local phaseTuning = BossConfig.Phases[entry.bossPhaseId :: string]
			entry.model:SetAttribute(PresentationAttributeNames.BossSlamSequence, entry.attackAttemptSequence)
			entry.model:SetAttribute(PresentationAttributeNames.BossSlamStartedServerTimestamp, serverTimestamp)
			entry.model:SetAttribute(
				PresentationAttributeNames.BossSlamCommitServerTimestamp,
				serverTimestamp + phaseTuning.SlamWindupSeconds
			)
			entry.model:SetAttribute(PresentationAttributeNames.BossSlamCenterX, target.x)
			entry.model:SetAttribute(PresentationAttributeNames.BossSlamCenterZ, target.z)
			entry.model:SetAttribute(PresentationAttributeNames.BossSlamRadiusStuds, BossConfig.Slam.RadiusStuds)
		end
		return 0
	elseif action == BossActionIds.Commit then
		local committed = commitBloomImpacts(decision.slamImpacts, serverTimestamp)
		clearBossSlamWindup(entry)
		entry.bossLastSlamCommitServerTimestamp = serverTimestamp
		clearBossSlamTelegraph(entry)
		return committed
	elseif action == BossActionIds.Cancel then
		clearBossSlamWindup(entry)
		clearBossSlamTelegraph(entry)
	end
	return 0
end

local function buildEvaluationBudget(serverTimestamp: number): EvaluationBudget
	local candidates: { string } = {}
	for entityId, entry in entries do
		if
			entry.isAlive
			and entry.archetypeId == EnemyConfig.Walker.ArchetypeId
			and entry.behaviorStateId == BehaviorStateIds.Pursuing
			and serverTimestamp >= entry.nextPursuitRepathServerTimestamp
		then
			table.insert(candidates, entityId)
		end
	end
	local resolution = EnemyNavigationScheduler.resolveRoundRobin(
		candidates,
		navigationFairnessCursorEntityId,
		EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation
	)
	navigationFairnessCursorEntityId = resolution.nextCursorEntityId
	return { pathComputationGrants = resolution.grantedEntityIds }
end

local function resetNavigationProgress(entry: EnemyEntry, serverTimestamp: number)
	local position = entry.root.Position
	entry.navigationProgressAnchor = { x = position.X, y = position.Y, z = position.Z }
	entry.navigationProgressAnchorServerTimestamp = serverTimestamp
	entry.nextStuckRecoveryServerTimestamp = serverTimestamp
end

local function moveStalkerToward(
	entry: EnemyEntry,
	targetPosition: Vector3,
	serverTimestamp: number,
	budget: EvaluationBudget
)
	local currentPosition = entry.root.Position
	local progress = EnemyNavigationScheduler.resolveProgress(
		{ x = currentPosition.X, y = currentPosition.Y, z = currentPosition.Z },
		entry.navigationProgressAnchor,
		entry.navigationProgressAnchorServerTimestamp,
		entry.nextStuckRecoveryServerTimestamp,
		serverTimestamp,
		EnemyConfig.Navigation.StuckMinimumProgressStuds,
		EnemyConfig.Navigation.StuckProgressWindowSeconds,
		EnemyConfig.Navigation.StuckRecoveryCooldownSeconds
	)
	entry.navigationProgressAnchor = progress.progressAnchor
	entry.navigationProgressAnchorServerTimestamp = progress.progressAnchorServerTimestamp
	entry.nextStuckRecoveryServerTimestamp = progress.nextRecoveryServerTimestamp
	if progress.didRecover then
		entry.pursuitFlankSign *= -1
		entry.nextPursuitRepathServerTimestamp = serverTimestamp
	end

	if serverTimestamp < entry.nextPursuitRepathServerTimestamp then
		return
	end

	local canComputePath = budget.pathComputationGrants[entry.entityId] == true
	if canComputePath then
		entry.nextPursuitRepathServerTimestamp = serverTimestamp + EnemyConfig.Navigation.PursuitRepathIntervalSeconds
	else
		entry.nextPursuitRepathServerTimestamp = serverTimestamp + EnemyConfig.EvaluationIntervalSeconds
	end

	local destination = targetPosition
	local toTarget = Vector3.new(targetPosition.X - entry.root.Position.X, 0, targetPosition.Z - entry.root.Position.Z)
	if
		toTarget.Magnitude > EnemyConfig.Walker.AttackRangeStuds * 1.5
		and toTarget.Magnitude <= EnemyConfig.Navigation.FlankActivationDistanceStuds
	then
		local perpendicular = Vector3.new(-toTarget.Z, 0, toTarget.X).Unit
		destination += perpendicular * EnemyConfig.Navigation.PackFlankOffsetStuds * entry.pursuitFlankSign
	end

	local pathService = PathfindingService :: any
	if canComputePath and type(pathService.CreatePath) == "function" then
		local ok, path = pcall(function()
			local createdPath = pathService:CreatePath({
				AgentRadius = EnemyConfig.Navigation.AgentRadiusStuds,
				AgentHeight = EnemyConfig.Navigation.AgentHeightStuds,
				AgentCanJump = EnemyConfig.Navigation.AgentCanJump,
				WaypointSpacing = EnemyConfig.Navigation.WaypointSpacingStuds,
			})
			createdPath:ComputeAsync(entry.root.Position, destination)
			return createdPath
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			local waypoint = waypoints[math.min(2, #waypoints)]
			if waypoint ~= nil then
				if EnemyConfig.Navigation.AgentCanJump and waypoint.Action == Enum.PathWaypointAction.Jump then
					entry.humanoid.Jump = true
				end
				entry.humanoid:MoveTo(waypoint.Position)
				return
			end
		end
	end

	entry.humanoid:MoveTo(destination)
end

local function applyBehavior(
	entry: EnemyEntry,
	operativeFacts: { EnemyOperativeFact },
	serverTimestamp: number,
	budget: EvaluationBudget
): number
	if entry.archetypeId == PROGENITOR_ARCHETYPE_ID then
		return applyBossBehavior(entry, operativeFacts, serverTimestamp)
	end
	if entry.archetypeId == BLIGHT_SPITTER_ARCHETYPE_ID then
		return applySpitterBehavior(entry, operativeFacts, serverTimestamp)
	end
	local decision = EnemyBehaviorResolver.resolveBehavior({
		entityId = entry.entityId,
		behaviorStateId = entry.behaviorStateId,
		position = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z },
		targetOperativeEntityId = entry.targetOperativeEntityId,
		lastAttackServerTimestamp = entry.lastAttackServerTimestamp,
		attackWindupTargetOperativeEntityId = entry.attackWindupTargetOperativeEntityId,
		attackWindupStartedServerTimestamp = entry.attackWindupStartedServerTimestamp,
		attackCadenceMultiplier = entry.effectiveAttackCadenceMultiplier,
	}, operativeFacts, serverTimestamp)
	if decision.rejectionReasonId ~= nil then
		return 0
	end
	setPresentationBehaviorState(entry, decision.behaviorStateIdAfter)
	entry.targetOperativeEntityId = decision.targetOperativeEntityId

	local windupActionId = decision.attackWindupActionId
	if windupActionId == AttackWindupActionIds.Begin then
		local targetId = decision.targetOperativeEntityId
		if targetId == nil then
			return 0
		end
		beginAttackWindup(entry, targetId, serverTimestamp)
		entry.humanoid.WalkSpeed = 0
		return 0
	elseif windupActionId == AttackWindupActionIds.Continue then
		entry.humanoid.WalkSpeed = 0
		return 0
	elseif windupActionId == AttackWindupActionIds.Cancel then
		clearAttackWindup(entry)
	end

	if decision.behaviorStateIdAfter == BehaviorStateIds.Pursuing then
		local targetId = decision.targetOperativeEntityId
		entry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond
			* entry.effectiveMovementSpeedMultiplier
		for _, fact in operativeFacts do
			if fact.operativeEntityId == targetId then
				moveStalkerToward(
					entry,
					Vector3.new(fact.position.x, fact.position.y, fact.position.z),
					serverTimestamp,
					budget
				)
				break
			end
		end
		return 0
	end
	if decision.behaviorStateIdAfter == BehaviorStateIds.Roaming then
		entry.humanoid.WalkSpeed = EnemyConfig.Walker.RoamSpeedStudsPerSecond * entry.effectiveMovementSpeedMultiplier
		resetNavigationProgress(entry, serverTimestamp)
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

	if decision.behaviorStateIdAfter == BehaviorStateIds.WindingUp then
		entry.humanoid.WalkSpeed = 0
		local attack = decision.attack
		if windupActionId ~= AttackWindupActionIds.Commit or not decision.shouldAttack or attack == nil then
			return 0
		end
		local targetRead = OperativeLifeService.readByOperativeEntityId(attack.targetEntityId)
		if targetRead == nil or targetRead.snapshot.lifeStateId ~= "Alive" then
			return 0
		end
		local reducedDamage = math.max(1, math.floor(attack.damageAmount * readIncomingDamageMultiplier() + 0.5))
		local commit = OperativeLifeService.applyAuthoritativeDamage(attack.targetEntityId, targetRead.revision, {
			damageEventId = attack.damageEventId,
			sourceEntityId = attack.sourceEntityId,
			targetEntityId = attack.targetEntityId,
			damageAmount = reducedDamage,
			serverTimestamp = attack.serverTimestamp,
		})
		if commit.didCommit then
			local presentationSequence = entry.attackWindupPresentationSequence
			if presentationSequence == nil then
				return 0
			end
			entry.lastAttackServerTimestamp = attack.serverTimestamp
			clearAttackWindup(entry)
			setPresentationBehaviorState(entry, BehaviorStateIds.Attacking)
			discloseCommittedAttack(entry, attack.serverTimestamp, presentationSequence)
			return 1
		end
		return 0
	end

	if decision.behaviorStateIdAfter == BehaviorStateIds.Attacking then
		entry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond
			* entry.effectiveMovementSpeedMultiplier
	end
	return 0
end

local function refreshCommanderAuras()
	local runtime = RunRpgConfig.CommanderRuntime
	local radiusSquared = runtime.auraRadiusStuds * runtime.auraRadiusStuds
	for _, entry in entries do
		if entry.isAlive then
			entry.commanderAuraActive = false
			entry.effectiveMovementSpeedMultiplier = entry.movementSpeedMultiplier
			entry.effectiveAttackCadenceMultiplier = entry.attackCadenceMultiplier
		end
	end
	if not isStoodDown then
		for _, commander in entries do
			if not commander.isAlive or commander.eliteAffixId ~= EliteAffixIds.Commander then
				continue
			end
			for _, target in entries do
				if
					target.isAlive
					and target.eliteAffixId == nil
					and horizontalDistanceSquared(commander.root.Position, target.root.Position) <= radiusSquared
				then
					target.commanderAuraActive = true
					target.effectiveMovementSpeedMultiplier = math.min(
						RunRpgConfig.ModifierCeilings.maximumMovementSpeedMultiplier,
						target.movementSpeedMultiplier * runtime.auraMovementSpeedMultiplier
					)
					target.effectiveAttackCadenceMultiplier = math.max(
						RunRpgConfig.ModifierCeilings.minimumCadenceMultiplier,
						target.attackCadenceMultiplier * runtime.auraAttackCadenceMultiplier
					)
				end
			end
		end
	end
	for _, entry in entries do
		if entry.isAlive then
			entry.model:SetAttribute(PresentationAttributeNames.EliteCommanderAuraActive, entry.commanderAuraActive)
			entry.model:SetAttribute(
				PresentationAttributeNames.EffectiveMovementSpeedMultiplier,
				entry.effectiveMovementSpeedMultiplier
			)
		end
	end
end

local function applyRegeneration(entry: EnemyEntry, serverTimestamp: number)
	if
		not entry.isAlive
		or isStoodDown
		or entry.eliteAffixId ~= EliteAffixIds.Regenerator
		or entry.healthState.currentHealth >= entry.maximumHealth
	then
		return
	end
	local runtime = RunRpgConfig.RegeneratorRuntime
	local nextRegenerationAt = entry.nextRegenerationServerTimestamp
	if nextRegenerationAt == nil then
		nextRegenerationAt = serverTimestamp + runtime.damageRecoveryDelaySeconds
		entry.nextRegenerationServerTimestamp = nextRegenerationAt
		entry.model:SetAttribute(PresentationAttributeNames.EliteRegenerationReadyServerTimestamp, nextRegenerationAt)
	end
	if serverTimestamp < nextRegenerationAt then
		return
	end
	entry.healthState.currentHealth =
		math.min(entry.maximumHealth, entry.healthState.currentHealth + runtime.healingPerInterval)
	entry.healthRevision += 1
	entry.nextRegenerationServerTimestamp = serverTimestamp + runtime.healingIntervalSeconds
	entry.model:SetAttribute(
		PresentationAttributeNames.EliteRegenerationReadyServerTimestamp,
		entry.nextRegenerationServerTimestamp
	)
	setHealthPresentation(entry)
end

local function detonateVolatile(entry: EnemyEntry, serverTimestamp: number)
	local detonateAt = entry.volatileDetonateServerTimestamp
	if
		entry.eliteAffixId ~= EliteAffixIds.Volatile
		or entry.volatileDidDetonate
		or detonateAt == nil
		or serverTimestamp < detonateAt
	then
		return
	end
	entry.volatileDidDetonate = true
	entry.model:SetAttribute(PresentationAttributeNames.EliteVolatileDetonationSequence, serverTimestamp)
	local runtime = RunRpgConfig.VolatileRuntime
	local radiusSquared = runtime.deathReactionRadiusStuds * runtime.deathReactionRadiusStuds
	for _, fact in readOperativeFacts() do
		if not fact.isAlive then
			continue
		end
		local dx = fact.position.x - entry.root.Position.X
		local dz = fact.position.z - entry.root.Position.Z
		if dx * dx + dz * dz > radiusSquared then
			continue
		end
		local read = OperativeLifeService.readByOperativeEntityId(fact.operativeEntityId)
		if read ~= nil and read.snapshot.lifeStateId == "Alive" then
			OperativeLifeService.applyAuthoritativeDamage(fact.operativeEntityId, read.revision, {
				damageEventId = string.format("elitevolatile:%s:%s", entry.entityId, tostring(detonateAt)),
				sourceEntityId = entry.entityId,
				targetEntityId = fact.operativeEntityId,
				damageAmount = runtime.deathReactionDamage,
				serverTimestamp = serverTimestamp,
			})
		end
	end
	setHealthPresentation(entry)
end

function EnemyDirectorService.evaluateAt(serverTimestamp: number): EvaluationSummary
	local summary = { spawnedCount = 0, attackCommittedCount = 0, cleanedCount = 0 }
	if not started or type(serverTimestamp) ~= "number" or serverTimestamp ~= serverTimestamp then
		return summary
	end
	local operativeFacts = readOperativeFacts()
	summary.spawnedCount += retryPendingSpawns(operativeFacts, serverTimestamp)
	summary.spawnedCount += attemptRoamingSpawns(operativeFacts, serverTimestamp)
	local budget = buildEvaluationBudget(serverTimestamp)
	refreshCommanderAuras()
	summary.attackCommittedCount += tickBloomZones(operativeFacts, serverTimestamp)
	local toClean: { string } = {}
	for entityId, entry in entries do
		local cleanupAt = entry.cleanupAtServerTimestamp
		if cleanupAt ~= nil then
			detonateVolatile(entry, serverTimestamp)
			if serverTimestamp >= cleanupAt then
				table.insert(toClean, entityId)
			end
		elseif entry.isAlive then
			applyRegeneration(entry, serverTimestamp)
			summary.attackCommittedCount += applyBehavior(entry, operativeFacts, serverTimestamp, budget)
		end
	end
	for _, entityId in toClean do
		local entry = entries[entityId]
		if entry ~= nil then
			entries[entityId] = nil
			entry.model:Destroy()
			summary.cleanedCount += 1
		end
	end
	return summary
end

local function clearEnemyFolder(folder: Folder)
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
end

function EnemyDirectorService.start()
	if started then
		return
	end
	started = true
	local existing = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	local folder: Folder
	if existing ~= nil and existing:IsA("Folder") then
		folder = existing
		clearEnemyFolder(folder)
	else
		if existing ~= nil then
			existing:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = ENEMY_FOLDER_NAME
		folder.Parent = Workspace
	end
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
	activeEliteCount = 0
	activeSpitterCount = 0
	table.clear(activeBloomZones)
	activeBossEntityId = nil
	bossDefeated = false
	operationPressureStartedServerTimestamp = nil
	table.clear(pendingSpawns)
	activeEnemyCount = 0
	isPressureActive = false
	isStoodDown = false
	escalationLevel = 0
	nextRoamingSpawnServerTimestamp = nil
	recoveryWindowEndServerTimestamp = nil
	accumulatedSeconds = 0
	sequenceCounter = 0
	navigationFairnessCursorEntityId = nil
	local folder = enemyFolder
	if folder ~= nil then
		clearEnemyFolder(folder)
		enemyFolder = nil
	end
end

return EnemyDirectorService
