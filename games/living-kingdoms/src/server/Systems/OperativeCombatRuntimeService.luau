--!strict

--[[
	P5-0106 production automatic-combat owner. Composes the existing pure P2
	pipeline — WeaponTargetSelector, AutomaticFireResolver,
	FirearmHitResolver, DamageResolver, ReloadResolver — against
	EnemyDirectorService-owned enemies for every operative, everywhere (not
	only in Studio). It replaces the LK-0207 development harness as the
	bootstrapped combat runtime while keeping the identical narrow network
	surface: ReloadIntent is the only client-to-server combat input, and
	CombatPresentation remains server-to-client disclosure only.

	Gameplay visibility is the darkness-bounded prototype provider: a hostile
	is visible only inside the configured horizontal radius. Line of sight and
	shot obstruction come from a bounded per-evaluation raycast budget over
	the nearest visible candidates; everything else fails closed as not yet
	sighted this pass.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local AmmunitionScarcityContracts = require(ReplicatedStorage.Shared.Combat.AmmunitionScarcityContracts)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local HordeExperienceConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end
local AutomaticFireResolver = require(script.Parent.AutomaticFireResolver)
local AmmunitionSupplyResolver = require(script.Parent.Parent.Domain.AmmunitionSupplyResolver)
local ClassService = require(script.Parent.ClassService)
local DamageResolver = require(script.Parent.DamageResolver)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local FirearmHitResolver = require(script.Parent.FirearmHitResolver)
local MatchResultService = require(script.Parent.MatchResultService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local PrimaryCombatModeService = require(script.Parent.PrimaryCombatModeService)
local RelicModifierService = require(script.Parent.RelicModifierService)
local ReloadResolver = require(script.Parent.ReloadResolver)
local RunMagazineCapacityResolver = require(script.Parent.RunMagazineCapacityResolver)
local WeaponSwapAmmunitionResolver = require(script.Parent.WeaponSwapAmmunitionResolver)
local WeaponTargetSelector = require(script.Parent.WeaponTargetSelector)
local WeaponPatternResolver = require(script.Parent.WeaponPatternResolver)
local weaponLoadoutModule = script.Parent.WeaponLoadoutService
local WeaponLoadoutService = if weaponLoadoutModule == nil
	then table.freeze({
		read = function(_player: Player)
			return nil
		end,
	})
	else require(weaponLoadoutModule)

type CombatEntityId = CombatContracts.CombatEntityId
type FirearmHitResolution = CombatContracts.FirearmHitResolution
type FirearmTargetContext = CombatContracts.FirearmTargetContext
type OperativeReloadState = CombatContracts.OperativeReloadState
type TargetCandidate = CombatContracts.TargetCandidate
type WeaponReadinessState = CombatContracts.WeaponReadinessState

type SightedCandidate = {
	fact: EnemyDirectorService.EnemyCombatFact,
	distanceStuds: number,
	hasLineOfSight: boolean,
}

type PlayerRaycastState = {
	character: Model?,
	primary: RaycastParams,
	pierce: RaycastParams,
}

type PlayerCombatState = {
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	selectedTargetEntityId: CombatEntityId?,
	lastRequestServerTimestamp: number,
	lastFireIntentServerTimestamp: number,
	isFiring: boolean,
	aimDirection: Vector3?,
	generation: number,
	processedShotIds: { [string]: boolean },
	sightedByEntityId: { [string]: SightedCandidate },
	lockedLoadoutApplied: boolean,
}

type OperativeCombatRuntimeService = {
	start: () -> (),
	stop: () -> (),
	readReviveCombatState: (player: Player) -> any?,
	commitReviveCombatState: (
		player: Player,
		expectedGeneration: number,
		combatState: any,
		grantedRounds: number?
	) -> boolean,
	publishAmmunitionState: (player: Player, grantedRounds: number?) -> boolean,
	equipFoundWeapon: (player: Player, weaponId: string) -> boolean,
	grantFoundAmmunition: (player: Player, requestedRounds: number) -> number,
	resetForReplay: () -> (),
	evaluateAt: (serverTimestamp: number) -> (),
	readEngineerResupplyState: (player: Player) -> any,
}

local SERVER_REQUEST_COOLDOWN_SECONDS = 0.25
local FIRE_INTENT_COOLDOWN_SECONDS = 0.025
local AIM_CONE_MINIMUM_DOT = math.cos(math.rad(13))
local PrimaryCombatModeIds = PrimaryCombatModeContracts.ModeIds

local function firearmModeActive(player: Player): boolean
	return PrimaryCombatModeService.readMode(player) == PrimaryCombatModeIds.Firearm
end

local function setPlayerAttribute(player: Player, attributeName: string, value: unknown)
	local candidate = player :: any
	if type(candidate.SetAttribute) == "function" then
		candidate:SetAttribute(attributeName, value)
	end
end

local OperativeCombatRuntimeService: OperativeCombatRuntimeService = {} :: OperativeCombatRuntimeService
local started = false
local accumulatedSeconds = 0
local fireIntentConnection: RBXScriptConnection? = nil
local reloadIntentConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local lifeStateConnection: { Disconnect: (self: any) -> () }? = nil
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local playerStates: { [Player]: PlayerCombatState } = {}
local raycastStates: { [Player]: PlayerRaycastState } = {}
-- P10-0106 session retention. Ammunition is a scarce operation resource (P6), so
-- a reconnect must not hand back a fresh magazine and reserve. The disconnecting
-- operative's weapon and ammunition are retained against their entity ID for the
-- rest of this operation and consumed on the first restore.
type RetainedCombatState = {
	weaponId: string,
	ammunition: CombatContracts.AmmunitionState,
}
local retainedCombatByOperativeEntityId: { [string]: RetainedCombatState } = {}
local engineerProcessedSupplyIds: { [Player]: { [string]: boolean } } = {}
local engineerGrantedRoundsBySupplyId: { [Player]: { [string]: number } } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local fireIntentRemote = combatNetwork:WaitForChild("FireIntent") :: RemoteEvent
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function readProgressionNumber(attributeName: string, fallback: number): number
	local network = ReplicatedStorage:FindFirstChild("ProgressionNetwork")
	if network == nil then
		return fallback
	end
	local value = network:GetAttribute(attributeName)
	return if type(value) == "number" and value == value then value else fallback
end

local function createWeaponState(weaponId: string?, initialReserveRounds: number?): WeaponReadinessState
	local definition = resolveWeaponDefinition(weaponId) or FirearmConfig.BasicFirearm
	weaponId = definition.WeaponId
	local ammunition = RunMagazineCapacityResolver.resolve(
		{
			weaponId = weaponId,
			loadedRounds = definition.PrototypeInitialLoadedRounds,
			reserveRounds = initialReserveRounds or definition.PrototypeInitialReserveRounds,
			magazineCapacity = definition.MagazineCapacity,
		},
		definition.MagazineCapacity,
		definition.MaximumReserveRounds,
		readProgressionNumber("RunMagazineCapacityMultiplier", 1)
	).ammunitionAfter
	return {
		weaponId = weaponId,
		readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
		ammunition = ammunition,
		cadence = {
			weaponId = weaponId,
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local function reconcileMagazineCapacity(player: Player, playerState: PlayerCombatState)
	local ammunition = playerState.weaponState.ammunition
	local definition = resolveWeaponDefinition(ammunition.weaponId)
	if definition == nil then
		return
	end
	local resolution = RunMagazineCapacityResolver.resolve(
		ammunition,
		definition.MagazineCapacity,
		definition.MaximumReserveRounds,
		readProgressionNumber("RunMagazineCapacityMultiplier", 1)
	)
	if not resolution.didApply or resolution.ammunitionAfter.magazineCapacity == ammunition.magazineCapacity then
		return
	end
	playerState.weaponState.ammunition = resolution.ammunitionAfter
	OperativeCombatRuntimeService.publishAmmunitionState(player)
end

local function deriveOperativeEntityId(player: Player): string
	-- Must match the P3 life identity so enemy threat facts and revive
	-- coordination address the same operative.
	return "operative.player:" .. tostring(player.UserId)
end

local function createPlayerState(player: Player): PlayerCombatState
	local operativeEntityId = deriveOperativeEntityId(player)
	local retained = retainedCombatByOperativeEntityId[operativeEntityId]
	retainedCombatByOperativeEntityId[operativeEntityId] = nil
	if retained ~= nil then
		PrimaryCombatModeService.setMode(player, PrimaryCombatModeIds.Firearm)
	end
	local weaponId = if retained ~= nil then retained.weaponId else FirearmConfig.DefaultSelectableWeaponId
	local weaponState = createWeaponState(weaponId)
	if retained ~= nil then
		-- Resume the exact rounds they left with; readiness and cadence restart
		-- clean so a reconnect grants no timing advantage.
		weaponState.ammunition = {
			weaponId = retained.ammunition.weaponId,
			loadedRounds = retained.ammunition.loadedRounds,
			reserveRounds = retained.ammunition.reserveRounds,
			magazineCapacity = retained.ammunition.magazineCapacity,
		}
	end
	return {
		operativeState = {
			entityId = operativeEntityId,
			combatStateId = CombatContracts.OperativeCombatStateIds.Ready,
			equippedWeaponId = weaponId,
		},
		weaponState = weaponState,
		selectedTargetEntityId = nil,
		lastRequestServerTimestamp = -math.huge,
		lastFireIntentServerTimestamp = -math.huge,
		isFiring = false,
		aimDirection = nil,
		generation = 1,
		processedShotIds = {},
		sightedByEntityId = {},
		lockedLoadoutApplied = false,
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = deepCopy(child)
	end
	return result
end

function OperativeCombatRuntimeService.publishAmmunitionState(player: Player, grantedRounds: number?): boolean
	local playerState = playerStates[player]
	if playerState == nil then
		return false
	end
	local ammunition = playerState.weaponState.ammunition
	local definition = resolveWeaponDefinition(ammunition.weaponId)
	if definition == nil then
		return false
	end
	local kindId = if grantedRounds == nil
		then CombatContracts.PresentationMessageKindIds.AmmunitionState
		else CombatContracts.PresentationMessageKindIds.AmmunitionCollected
	local payload = {
		kindId = kindId,
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
		maximumReserveRounds = definition.MaximumReserveRounds,
	}
	if grantedRounds ~= nil then
		payload.grantedRounds = grantedRounds
	end
	presentationRemote:FireClient(player, payload)
	return true
end

function OperativeCombatRuntimeService.readReviveCombatState(player: Player): any?
	local playerState = playerStates[player]
	if playerState == nil then
		return nil
	end
	local weaponState = deepCopy(playerState.weaponState)
	if weaponState.readinessStateId == CombatContracts.WeaponReadinessStateIds.Disabled then
		weaponState.readinessStateId = if weaponState.ammunition.loadedRounds == 0
			then CombatContracts.WeaponReadinessStateIds.Empty
			else CombatContracts.WeaponReadinessStateIds.Ready
	end
	return {
		generation = playerState.generation,
		combatState = {
			weaponState = weaponState,
			processedShotIds = deepCopy(playerState.processedShotIds),
			selectedTargetState = nil,
		},
	}
end

function OperativeCombatRuntimeService.commitReviveCombatState(
	player: Player,
	expectedGeneration: number,
	combatState: any,
	grantedRounds: number?
): boolean
	local playerState = playerStates[player]
	if
		playerState == nil
		or playerState.generation ~= expectedGeneration
		or type(combatState) ~= "table"
		or type(combatState.weaponState) ~= "table"
		or type(combatState.processedShotIds) ~= "table"
		or combatState.selectedTargetState ~= nil
	then
		return false
	end
	playerState.weaponState = deepCopy(combatState.weaponState)
	playerState.processedShotIds = deepCopy(combatState.processedShotIds)
	playerState.selectedTargetEntityId = nil
	OperativeCombatRuntimeService.publishAmmunitionState(player, grantedRounds)
	return true
end

local function inspectEngineerResupply(player: Player): (boolean, boolean)
	local playerState = playerStates[player]
	if playerState == nil then
		return false, false
	end
	local ammunition = playerState.weaponState.ammunition
	local definition = resolveWeaponDefinition(ammunition.weaponId)
	if definition == nil then
		return false, false
	end
	return true, ammunition.reserveRounds < definition.MaximumReserveRounds
end

local function commitEngineerResupply(player: Player, supplyId: string, availableRounds: number): (boolean, number)
	if
		not started
		or type(supplyId) ~= "string"
		or supplyId == ""
		or type(availableRounds) ~= "number"
		or availableRounds ~= availableRounds
		or availableRounds <= 0
		or availableRounds % 1 ~= 0
		or not OperativeLifeService.isCombatAllowed(player)
	then
		return false, 0
	end
	local read = OperativeCombatRuntimeService.readReviveCombatState(player)
	if read == nil then
		return false, 0
	end
	local combatState = read.combatState
	local ammunition = combatState.weaponState.ammunition
	local definition = resolveWeaponDefinition(ammunition.weaponId)
	if definition == nil then
		return false, 0
	end
	local processed = engineerProcessedSupplyIds[player] or {}
	local resolution = AmmunitionSupplyResolver.collect({
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
		maximumReserveRounds = definition.MaximumReserveRounds,
		processedSupplyIds = processed,
	}, {
		supplyId = supplyId,
		sourceId = AmmunitionScarcityContracts.SupplySourceIds.EngineerResupply,
		weaponId = ammunition.weaponId,
		availableRounds = availableRounds,
	})
	if not resolution.didCollect then
		return false, 0
	end
	combatState.weaponState.ammunition.reserveRounds = resolution.stateAfter.reserveRounds
	if
		not OperativeCombatRuntimeService.commitReviveCombatState(
			player,
			read.generation,
			combatState,
			resolution.grantedRounds
		)
	then
		return false, 0
	end
	engineerProcessedSupplyIds[player] = table.clone(resolution.stateAfter.processedSupplyIds)
	local granted = engineerGrantedRoundsBySupplyId[player]
	if granted == nil then
		granted = {}
		engineerGrantedRoundsBySupplyId[player] = granted
	end
	granted[supplyId] = resolution.grantedRounds
	return true, resolution.grantedRounds
end

function OperativeCombatRuntimeService.readEngineerResupplyState(player: Player): any
	return table.freeze({
		processedSupplyIds = table.freeze(table.clone(engineerProcessedSupplyIds[player] or {})),
		grantedRoundsBySupplyId = table.freeze(table.clone(engineerGrantedRoundsBySupplyId[player] or {})),
	})
end

local function getOperativePosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root :: BasePart).Position
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function raycastStateFor(player: Player): PlayerRaycastState
	local character = player.Character
	local state = raycastStates[player]
	if state == nil then
		local primary = RaycastParams.new()
		primary.FilterType = Enum.RaycastFilterType.Exclude
		local pierce = RaycastParams.new()
		pierce.FilterType = Enum.RaycastFilterType.Exclude
		state = {
			character = nil,
			primary = primary,
			pierce = pierce,
		}
		raycastStates[player] = state
	end
	if state.character ~= character then
		state.character = character
		state.primary.FilterDescendantsInstances = if character == nil then {} else { character }
	end
	return state
end

local function hasClearShot(
	player: Player,
	operativePosition: Vector3,
	fact: EnemyDirectorService.EnemyCombatFact
): boolean
	local parameters = raycastStateFor(player).primary
	local direction = fact.worldPosition - operativePosition
	local result = Workspace:Raycast(operativePosition, direction, parameters)
	if result == nil then
		return true
	end
	return result.Instance:IsDescendantOf(fact.model)
end

-- A rear candidate naturally fails the normal sight ray when the selected
-- primary is the first hit. One accepted precision shot may therefore perform
-- one additional validation ray that excludes only the operative and the
-- already-hit primary. Terrain and any other hostile still block the path.
local function hasClearPierceShot(
	player: Player,
	operativePosition: Vector3,
	primaryFact: EnemyDirectorService.EnemyCombatFact,
	secondaryFact: EnemyDirectorService.EnemyCombatFact
): boolean
	local state = raycastStateFor(player)
	local parameters = state.pierce
	local exclusions: { Instance } = { primaryFact.model }
	local character = state.character
	if character ~= nil then
		table.insert(exclusions, character)
	end
	parameters.FilterDescendantsInstances = exclusions
	local direction = secondaryFact.worldPosition - operativePosition
	local result = Workspace:Raycast(operativePosition, direction, parameters)
	if result == nil then
		return true
	end
	return result.Instance:IsDescendantOf(secondaryFact.model)
end

--[[
	Build this operative's disclosed-fact candidates for one evaluation pass.
	A hostile is visible only inside the darkness engagement radius, and the
	line-of-sight raycast budget covers the nearest visible candidates first;
	unbudgeted candidates fail closed as unsighted this pass.
]]
local function buildSightedCandidates(
	player: Player,
	playerState: PlayerCombatState,
	operativePosition: Vector3,
	enemyFacts: { EnemyDirectorService.EnemyCombatFact }
): { TargetCandidate }
	local sighted: { SightedCandidate } = {}
	for _, fact in enemyFacts do
		local distance = horizontalDistance(fact.worldPosition, operativePosition)
		if distance <= EnemyDirectorService.readGameplayVisibilityRadiusStuds() then
			table.insert(sighted, { fact = fact, distanceStuds = distance, hasLineOfSight = false })
		end
	end
	table.sort(sighted, function(a, b)
		if a.distanceStuds ~= b.distanceStuds then
			return a.distanceStuds < b.distanceStuds
		end
		return a.fact.entityId < b.fact.entityId
	end)
	table.clear(playerState.sightedByEntityId)
	local candidates: { TargetCandidate } = {}
	local raycastBudget = EnemyConfig.Combat.MaximumLineOfSightRaycastsPerEvaluation
	for index, entry in sighted do
		if index <= raycastBudget then
			entry.hasLineOfSight = hasClearShot(player, operativePosition, entry.fact)
		end
		playerState.sightedByEntityId[entry.fact.entityId] = entry
		table.insert(candidates, {
			entityId = entry.fact.entityId,
			entityKindId = CombatContracts.CombatEntityKindIds.Hostile,
			teamId = "team.exclusion-zone.hostiles",
			relationshipId = CombatContracts.TeamRelationshipIds.Hostile,
			worldPosition = entry.fact.worldPosition,
			distanceStuds = entry.distanceStuds,
			isAlive = entry.fact.isAlive,
			isTargetable = true,
			isVisible = true,
			hasLineOfSight = entry.hasLineOfSight,
			isActivelyThreatening = entry.fact.targetOperativeEntityId == playerState.operativeState.entityId,
			activelyThreateningOperativeEntityId = entry.fact.targetOperativeEntityId,
		})
	end
	return candidates
end

-- The client supplies only a camera direction. The server still discovers the
-- hostile, validates distance/life/relationship, performs line of sight, owns
-- cadence and ammunition, and resolves damage. A modest cone makes the center
-- crosshair usable without turning this back into automatic nearest-target aim.
local function filterCandidatesToAim(
	candidates: { TargetCandidate },
	operativePosition: Vector3,
	aimDirection: Vector3?
): { TargetCandidate }
	if aimDirection == nil then
		return {}
	end
	local aimed = {}
	for _, candidate in candidates do
		local offset = candidate.worldPosition - operativePosition
		if offset.Magnitude > 0.001 and offset.Unit:Dot(aimDirection) >= AIM_CONE_MINIMUM_DOT then
			table.insert(aimed, candidate)
		end
	end
	table.sort(aimed, function(left, right)
		local leftDot = (left.worldPosition - operativePosition).Unit:Dot(aimDirection)
		local rightDot = (right.worldPosition - operativePosition).Unit:Dot(aimDirection)
		if leftDot ~= rightDot then
			return leftDot > rightDot
		end
		return left.distanceStuds < right.distanceStuds
	end)
	return aimed
end

local function discloseTarget(
	player: Player,
	playerState: PlayerCombatState,
	targetEntityId: CombatEntityId?,
	nowTimestamp: number
)
	if playerState.selectedTargetEntityId == targetEntityId then
		return
	end
	playerState.selectedTargetEntityId = targetEntityId
	if targetEntityId == nil then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.TargetCleared,
			operativeEntityId = playerState.operativeState.entityId,
			serverTimestamp = nowTimestamp,
		})
		return
	end
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.TargetSelected,
		operativeEntityId = playerState.operativeState.entityId,
		targetEntityId = targetEntityId,
		serverTimestamp = nowTimestamp,
	})
end

local function broadcastReloadPresentation(
	playerState: PlayerCombatState,
	kindId: CombatContracts.CombatPresentationMessageKindId,
	completionServerTimestamp: number?
)
	local payload: any = {
		kindId = kindId,
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = playerState.weaponState.weaponId,
	}
	if completionServerTimestamp ~= nil then
		payload.completionServerTimestamp = completionServerTimestamp
	end
	presentationRemote:FireAllClients(payload)
end

local function buildPatternTargetFacts(playerState: PlayerCombatState): { WeaponPatternResolver.PatternTargetFact }
	local facts = {}
	for _, sightedEntry in playerState.sightedByEntityId do
		table.insert(facts, {
			entityId = sightedEntry.fact.entityId,
			worldPosition = sightedEntry.fact.worldPosition,
			isAlive = sightedEntry.fact.isAlive,
			isTargetable = true,
			isVisible = sightedEntry.distanceStuds <= EnemyDirectorService.readGameplayVisibilityRadiusStuds(),
			hasLineOfSight = sightedEntry.hasLineOfSight,
		})
	end
	return facts
end

--[[
	Suppression Engine (RPG-0109) rewards sustained automatic fire. The
	sustained-shot counter lives in the operative's equipped relic slot, and this
	owner gates it on an automatic firearm so a relic offered for one loadout can
	never power another. Reloading, a loadout change, or losing combat rights
	resets the counter.
]]
local function isAutomaticFirearm(weaponId: string): boolean
	return weaponId == CombatContracts.WeaponIds.LightMachineGun or weaponId == CombatContracts.WeaponIds.SubmachineGun
end

local function isSustainedFireActive(player: Player, playerState: PlayerCombatState): boolean
	local threshold = RelicModifierService.read(player).sustainedFireShotThreshold
	if threshold <= 0 or not isAutomaticFirearm(playerState.weaponState.weaponId) then
		return false
	end
	return RelicModifierService.readSustainedShots(player) >= threshold
end

local function runDamageContext(
	player: Player,
	playerState: PlayerCombatState,
	fact: EnemyDirectorService.EnemyCombatFact,
	targetMaximumHealth: number?,
	sustainedFireActive: boolean
): DamageResolver.RunDamageContext?
	local ammunition = playerState.weaponState.ammunition
	local definition = resolveWeaponDefinition(ammunition.weaponId)
	if definition == nil then
		return nil
	end
	local roleId = fact.model:GetAttribute("HordeRoleId")
	local eliteAffixId = fact.model:GetAttribute("EnemyEliteAffixId")
	local roles = HordeExperienceConfig.Roles
	local isSpecialEnemy = eliteAffixId ~= nil
		or roleId == roles.Screamer.Id
		or roleId == roles.Bloater.Id
		or roleId == roles.Brute.Id
	return {
		reserveRounds = ammunition.reserveRounds,
		maximumReserveRounds = definition.MaximumReserveRounds,
		isSpecialEnemy = isSpecialEnemy,
		targetMaximumHealth = targetMaximumHealth,
		isSustainedFireActive = sustainedFireActive,
		relicModifiers = RelicModifierService.read(player),
	}
end

--[[
	Blood Battery restores bounded health every configured number of confirmed
	kills. Kill credit comes only from a committed lethal shot resolved by this
	owner, the counter lives in the operative's equipped relic slot, and the
	healing commits through the existing revisioned P3 healing boundary — this
	owner never writes health directly. A full-health operative still consumes the
	trigger, matching every other authoritative healing source.
]]
local function applyBloodBattery(player: Player, killCount: number, shotId: string, nowTimestamp: number)
	if killCount <= 0 then
		return
	end
	local modifiers = RelicModifierService.read(player)
	if modifiers.bloodBatteryKillThreshold <= 0 or modifiers.bloodBatteryHealAmount <= 0 then
		return
	end
	local triggerCount =
		RelicModifierService.advanceBloodBatteryKills(player, killCount, modifiers.bloodBatteryKillThreshold)
	if triggerCount <= 0 then
		return
	end
	local lifeRead = OperativeLifeService.read(player)
	if lifeRead == nil then
		return
	end
	local snapshot = lifeRead.snapshot
	OperativeLifeService.applyAuthoritativeHealing(snapshot.operativeEntityId, lifeRead.revision, {
		healingEventId = "healing:relic.blood-battery:" .. shotId,
		sourceEntityId = snapshot.operativeEntityId,
		targetEntityId = snapshot.operativeEntityId,
		healingAmount = math.min(snapshot.healthState.maximumHealth, triggerCount * modifiers.bloodBatteryHealAmount),
		serverTimestamp = nowTimestamp,
	})
end

--[[
	Records one committed impact into the P10-0104 contribution ledger. Damage and
	boss-exposure credit follow the shot that the authoritative health boundary
	accepted, never a requested or predicted amount.
]]
local function recordCombatContribution(operativeEntityId: string, targetEntityId: string, damageAmount: number)
	MatchResultService.recordDamageDealt(operativeEntityId, damageAmount)
	local didRead, isBoss = pcall(function()
		return EnemyDirectorService.isBossEntity(targetEntityId)
	end)
	if didRead and isBoss == true then
		-- The boss only accepts damage inside its telegraphed exposure window, so a
		-- committed boss hit is by definition an exposure hit.
		MatchResultService.recordBossExposureHit(operativeEntityId)
	end
end

local function commitPatternImpacts(
	player: Player,
	playerState: PlayerCombatState,
	operativePosition: Vector3,
	primaryTargetEntityId: string,
	primaryShotId: string,
	nowTimestamp: number,
	sustainedFireActive: boolean
): ({ CombatContracts.SecondaryShotImpactPresentation }, number)
	local primaryEntry = playerState.sightedByEntityId[primaryTargetEntityId]
	if primaryEntry == nil then
		return {}, 0
	end
	local selectedImpacts = WeaponPatternResolver.resolve(
		playerState.weaponState.weaponId,
		operativePosition,
		primaryTargetEntityId,
		buildPatternTargetFacts(playerState)
	)
	local disclosedImpacts = {}
	local killCount = 0
	for index, impact in selectedImpacts do
		local sightedEntry = playerState.sightedByEntityId[impact.targetEntityId]
		local healthRead = EnemyDirectorService.readHealthState(impact.targetEntityId)
		if sightedEntry == nil or healthRead == nil or not healthRead.isAlive then
			continue
		end
		local hasPatternLineOfSight = if impact.requiresPierceValidation
			then hasClearPierceShot(player, operativePosition, primaryEntry.fact, sightedEntry.fact)
			else sightedEntry.hasLineOfSight
		if not hasPatternLineOfSight then
			continue
		end
		local derivedShotId = string.format("%s:pattern:%d:%s", primaryShotId, index, impact.targetEntityId)
		local hitResolution: FirearmHitResolution = {
			shotId = derivedShotId,
			sourceEntityId = playerState.operativeState.entityId,
			targetEntityId = impact.targetEntityId,
			weaponId = playerState.weaponState.weaponId,
			didHit = true,
			rejectionReasonId = nil,
		}
		local damageResolution = DamageResolver.resolvePattern(
			hitResolution,
			healthRead.healthState,
			nowTimestamp,
			impact.damageMultiplier,
			runDamageContext(player, playerState, sightedEntry.fact, healthRead.maximumHealth, sustainedFireActive)
		)
		local didCommit, committedDamage = EnemyDirectorService.commitHealthState(
			impact.targetEntityId,
			healthRead.revision,
			damageResolution.targetHealthStateAfter,
			nowTimestamp
		)
		local damageEvent = damageResolution.damageEvent
		if didCommit and damageResolution.didApplyDamage and damageEvent ~= nil then
			if damageResolution.becameDead then
				killCount += 1
			end
			-- P10-0104 contribution: only committed damage counts, and only the
			-- operative whose shot committed it.
			recordCombatContribution(
				playerState.operativeState.entityId,
				impact.targetEntityId,
				committedDamage or damageEvent.damageAmount
			)
			table.insert(disclosedImpacts, {
				targetEntityId = impact.targetEntityId,
				impactWorldPosition = sightedEntry.fact.worldPosition,
				damageAmount = committedDamage or damageEvent.damageAmount,
			})
		end
	end
	return disclosedImpacts, killCount
end

local function resolveAcceptedShot(
	player: Player,
	playerState: PlayerCombatState,
	operativePosition: Vector3,
	fireResult: CombatContracts.AuthoritativeFireResult,
	nowTimestamp: number,
	sustainedFireActive: boolean
)
	local targetEntityId = fireResult.targetEntityId
	local shotId = fireResult.shotId
	if targetEntityId == nil or shotId == nil then
		return
	end
	local sightedEntry = playerState.sightedByEntityId[targetEntityId]
	local healthRead = EnemyDirectorService.readHealthState(targetEntityId)
	if sightedEntry == nil or healthRead == nil then
		return
	end
	local fact = sightedEntry.fact
	local targetContext: FirearmTargetContext = {
		entityId = fact.entityId,
		worldPosition = fact.worldPosition,
		isAlive = healthRead.isAlive,
		isTargetable = true,
		relationshipId = CombatContracts.TeamRelationshipIds.Hostile,
		isVisible = sightedEntry.distanceStuds <= EnemyDirectorService.readGameplayVisibilityRadiusStuds(),
	}
	local hitResolution = FirearmHitResolver.resolve(fireResult, {
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = playerState.weaponState.weaponId,
		selectedTargetEntityId = targetEntityId,
		operativeWorldPosition = operativePosition,
		obstructionResultId = if sightedEntry.hasLineOfSight
			then CombatContracts.ShotObstructionResultIds.TargetHit
			else CombatContracts.ShotObstructionResultIds.Blocked,
	}, targetContext)
	local damageResolution = DamageResolver.resolve(
		hitResolution,
		healthRead.healthState,
		nowTimestamp,
		nil,
		runDamageContext(player, playerState, fact, healthRead.maximumHealth, sustainedFireActive)
	)
	local didCommitPrimary, committedDamage = EnemyDirectorService.commitHealthState(
		targetEntityId,
		healthRead.revision,
		damageResolution.targetHealthStateAfter,
		nowTimestamp
	)
	local didApplyPrimaryDamage = didCommitPrimary and damageResolution.didApplyDamage
	local damageAmount = if didApplyPrimaryDamage and damageResolution.damageEvent ~= nil
		then committedDamage or damageResolution.damageEvent.damageAmount
		else nil
	local secondaryImpacts: { CombatContracts.SecondaryShotImpactPresentation } = {}
	local killCount = if didApplyPrimaryDamage and damageResolution.becameDead then 1 else 0
	if didApplyPrimaryDamage then
		local impacts, secondaryKills = commitPatternImpacts(
			player,
			playerState,
			operativePosition,
			targetEntityId,
			shotId,
			nowTimestamp,
			sustainedFireActive
		)
		secondaryImpacts = impacts
		killCount += secondaryKills
	end
	if didApplyPrimaryDamage and damageAmount ~= nil then
		recordCombatContribution(playerState.operativeState.entityId, targetEntityId, damageAmount)
	end
	if killCount > 0 then
		MatchResultService.recordKills(playerState.operativeState.entityId, killCount)
	end
	applyBloodBattery(player, killCount, shotId, nowTimestamp)
	presentationRemote:FireAllClients({
		kindId = CombatContracts.PresentationMessageKindIds.ShotFired,
		shotId = shotId,
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = playerState.weaponState.weaponId,
		targetEntityId = targetEntityId,
		didApplyDamage = didApplyPrimaryDamage,
		impactWorldPosition = if didApplyPrimaryDamage then fact.worldPosition else nil,
		damageAmount = damageAmount,
		secondaryImpacts = if #secondaryImpacts > 0 then secondaryImpacts else nil,
		serverTimestamp = nowTimestamp,
	})
end

local function applyLockedLoadout(player: Player, playerState: PlayerCombatState)
	if playerState.lockedLoadoutApplied then
		return
	end
	local assignment = WeaponLoadoutService.read(player)
	if
		assignment == nil
		or assignment.selectionStateId ~= "Locked"
		or resolveWeaponDefinition(assignment.weaponId) == nil
	then
		return
	end
	playerState.lockedLoadoutApplied = true
	if assignment.weaponId == playerState.weaponState.weaponId then
		return
	end
	playerState.generation += 1
	playerState.operativeState.combatStateId = CombatContracts.OperativeCombatStateIds.Ready
	playerState.operativeState.equippedWeaponId = assignment.weaponId
	playerState.weaponState = createWeaponState(assignment.weaponId)
	playerState.selectedTargetEntityId = nil
	table.clear(playerState.processedShotIds)
	table.clear(playerState.sightedByEntityId)
	setPlayerAttribute(player, "LK_EquippedWeaponId", assignment.weaponId)
	RelicModifierService.resetSustainedShots(player)
	OperativeCombatRuntimeService.publishAmmunitionState(player)
end

function OperativeCombatRuntimeService.equipFoundWeapon(player: Player, weaponId: string): boolean
	local playerState = playerStates[player]
	local definition = resolveWeaponDefinition(weaponId)
	if playerState == nil or definition == nil or not OperativeLifeService.isCombatAllowed(player) then
		return false
	end
	local discoverable = weaponId == FirearmConfig.DefaultSelectableWeaponId
	for _, candidateId in FirearmConfig.DiscoverableWeaponIds do
		if candidateId == weaponId then
			discoverable = true
			break
		end
	end
	if not discoverable then
		return false
	end
	--[[
		A swap moves ammunition, it never creates it. Handing over a full
		magazine let a player refill loaded rounds for free on every weapon
		change, which bypassed scarcity entirely.
	]]
	local carried = playerState.weaponState.ammunition
	local swap = WeaponSwapAmmunitionResolver.resolve({
		loadedRounds = carried.loadedRounds,
		reserveRounds = carried.reserveRounds,
	}, {
		magazineCapacity = definition.MagazineCapacity,
		maximumReserveRounds = definition.MaximumReserveRounds,
	})

	playerState.generation += 1
	playerState.operativeState.combatStateId = CombatContracts.OperativeCombatStateIds.Ready
	playerState.operativeState.equippedWeaponId = weaponId
	local nextWeaponState = createWeaponState(weaponId, 0)
	if swap.Accepted then
		-- RunMagazineCapacityResolver returns an immutable ammunition snapshot.
		-- Replace that snapshot atomically instead of mutating its readonly fields.
		nextWeaponState.ammunition = {
			weaponId = weaponId,
			loadedRounds = swap.LoadedRounds,
			reserveRounds = swap.ReserveRounds,
			magazineCapacity = definition.MagazineCapacity,
		}
	end
	playerState.weaponState = nextWeaponState
	playerState.weaponState.readinessStateId = if nextWeaponState.ammunition.loadedRounds == 0
		then CombatContracts.WeaponReadinessStateIds.Empty
		else CombatContracts.WeaponReadinessStateIds.Ready
	playerState.selectedTargetEntityId = nil
	table.clear(playerState.processedShotIds)
	table.clear(playerState.sightedByEntityId)
	playerState.lockedLoadoutApplied = true
	setPlayerAttribute(player, "LK_EquippedWeaponId", weaponId)
	PrimaryCombatModeService.setMode(player, PrimaryCombatModeIds.Firearm)
	RelicModifierService.resetSustainedShots(player)
	OperativeCombatRuntimeService.publishAmmunitionState(player)
	return true
end

function OperativeCombatRuntimeService.grantFoundAmmunition(player: Player, requestedRounds: number): number
	local playerState = playerStates[player]
	if
		playerState == nil
		or not OperativeLifeService.isCombatAllowed(player)
		or type(requestedRounds) ~= "number"
		or requestedRounds ~= requestedRounds
		or requestedRounds <= 0
	then
		return 0
	end
	local ammunition = playerState.weaponState.ammunition
	local definition = resolveWeaponDefinition(ammunition.weaponId)
	if definition == nil then
		return 0
	end
	local room = math.max(0, definition.MaximumReserveRounds - ammunition.reserveRounds)
	local granted = math.min(room, math.floor(requestedRounds))
	if granted <= 0 then
		return 0
	end
	ammunition.reserveRounds += granted
	playerState.generation += 1
	OperativeCombatRuntimeService.publishAmmunitionState(player, granted)
	return granted
end

local function evaluatePlayer(
	player: Player,
	playerState: PlayerCombatState,
	nowTimestamp: number,
	enemyFacts: { EnemyDirectorService.EnemyCombatFact }
)
	applyLockedLoadout(player, playerState)
	reconcileMagazineCapacity(player, playerState)
	if not OperativeLifeService.isCombatAllowed(player) then
		discloseTarget(player, playerState, nil, nowTimestamp)
		RelicModifierService.resetSustainedShots(player)
		local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
		if restricted ~= nil then
			playerStates[player] = restricted
		end
		return
	end
	if not firearmModeActive(player) then
		playerState.isFiring = false
		playerState.aimDirection = nil
		discloseTarget(player, playerState, nil, nowTimestamp)
		RelicModifierService.resetSustainedShots(player)
		return
	end
	local operativePosition = getOperativePosition(player)
	if operativePosition == nil then
		discloseTarget(player, playerState, nil, nowTimestamp)
		return
	end
	local candidates = buildSightedCandidates(player, playerState, operativePosition, enemyFacts)
	local targetingState = {
		entityId = playerState.operativeState.entityId,
		worldPosition = operativePosition,
		combatStateId = playerState.operativeState.combatStateId,
		weaponReadiness = playerState.weaponState,
	}
	local aimedCandidates = if playerState.isFiring
		then filterCandidatesToAim(candidates, operativePosition, playerState.aimDirection)
		else {}
	local selectedTarget =
		WeaponTargetSelector.select(targetingState, aimedCandidates, playerState.selectedTargetEntityId)
	local targetEntityId = if selectedTarget == nil then nil else selectedTarget.targetEntityId
	discloseTarget(player, playerState, targetEntityId, nowTimestamp)
	local sustainedFireActive = isSustainedFireActive(player, playerState)
	local fireResolution = AutomaticFireResolver.resolve(
		{
			entityId = playerState.operativeState.entityId,
			combatStateId = playerState.operativeState.combatStateId,
		},
		selectedTarget,
		playerState.weaponState,
		nowTimestamp,
		nil,
		if sustainedFireActive then RelicModifierService.read(player).sustainedFireCadenceMultiplier else nil,
		ClassService.readBraceCadenceMultiplier(player)
	)
	playerState.weaponState = fireResolution.weaponStateAfter
	if fireResolution.decision.shouldFire then
		resolveAcceptedShot(
			player,
			playerState,
			operativePosition,
			fireResolution.fireResult,
			nowTimestamp,
			sustainedFireActive
		)
		if isAutomaticFirearm(playerState.weaponState.weaponId) then
			RelicModifierService.recordSustainedShot(player)
		end
		OperativeCombatRuntimeService.publishAmmunitionState(player)
	end
end

function OperativeCombatRuntimeService.evaluateAt(serverTimestamp: number)
	if not started or type(serverTimestamp) ~= "number" or serverTimestamp ~= serverTimestamp then
		return
	end
	ClassService.evaluateActionsAt(serverTimestamp)
	local enemyFacts = EnemyDirectorService.readEnemyCombatFacts()
	for player, playerState in playerStates do
		evaluatePlayer(player, playerState, serverTimestamp, enemyFacts)
	end
end

local function completeReload(player: Player, expectedCompletionTimestamp: number, expectedGeneration: number)
	local playerState = playerStates[player]
	if playerState == nil or playerState.generation ~= expectedGeneration then
		return
	end
	if not OperativeLifeService.isCombatAllowed(player) then
		local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
		if restricted ~= nil then
			playerStates[player] = restricted
		end
		return
	end
	local reloadState = playerState.weaponState.reloadState
	if reloadState == nil or reloadState.completionServerTimestamp ~= expectedCompletionTimestamp then
		return
	end
	local resolution =
		ReloadResolver.complete(playerState.operativeState, playerState.weaponState, Workspace:GetServerTimeNow())
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if resolution.didComplete or resolution.wasInterrupted then
		OperativeCombatRuntimeService.publishAmmunitionState(player)
	end
	if resolution.didComplete then
		broadcastReloadPresentation(playerState, CombatContracts.PresentationMessageKindIds.ReloadCompleted, nil)
	elseif resolution.wasInterrupted then
		broadcastReloadPresentation(playerState, CombatContracts.PresentationMessageKindIds.ReloadInterrupted, nil)
	end
end

--[[
	Emergency Chamber only shortens reloads accepted while the operative is
	critically wounded. The wounded fact comes from the authoritative P3 life
	snapshot, never from the requesting client.
]]
local function relicReloadContext(player: Player): ReloadResolver.RelicReloadContext?
	local modifiers = RelicModifierService.read(player)
	if modifiers.woundedHealthFraction <= 0 or modifiers.woundedReloadDurationMultiplier >= 1 then
		return nil
	end
	local lifeRead = OperativeLifeService.read(player)
	local healthState = if lifeRead == nil then nil else lifeRead.snapshot.healthState
	if healthState == nil or healthState.maximumHealth <= 0 then
		return nil
	end
	return {
		woundedReloadDurationMultiplier = modifiers.woundedReloadDurationMultiplier,
		isCriticallyWounded = healthState.currentHealth <= healthState.maximumHealth * modifiers.woundedHealthFraction,
	}
end

local function onFireIntent(player: Player, isFiring: unknown, aimDirection: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(isFiring) ~= "boolean" or typeof(aimDirection) ~= "Vector3" then
		return
	end
	local playerState = playerStates[player]
	if playerState == nil then
		return
	end
	if not firearmModeActive(player) then
		if isFiring == false then
			playerState.isFiring = false
			playerState.aimDirection = nil
		end
		return
	end
	local direction = aimDirection :: Vector3
	if
		direction.X ~= direction.X
		or direction.Y ~= direction.Y
		or direction.Z ~= direction.Z
		or direction.Magnitude < 0.9
		or direction.Magnitude > 1.1
	then
		return
	end
	local nowTimestamp = Workspace:GetServerTimeNow()
	if isFiring and nowTimestamp - playerState.lastFireIntentServerTimestamp < FIRE_INTENT_COOLDOWN_SECONDS then
		return
	end
	playerState.lastFireIntentServerTimestamp = nowTimestamp
	playerState.aimDirection = direction.Unit
	playerState.isFiring = isFiring and OperativeLifeService.isCombatAllowed(player)
	if not playerState.isFiring then
		discloseTarget(player, playerState, nil, nowTimestamp)
		RelicModifierService.resetSustainedShots(player)
	end
end

local function onReloadIntent(player: Player, weaponId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(weaponId) ~= "string" then
		return
	end
	local playerState = playerStates[player]
	if
		playerState == nil
		or not firearmModeActive(player)
		or not OperativeLifeService.isCombatAllowed(player)
		or weaponId ~= playerState.operativeState.equippedWeaponId
	then
		return
	end
	local nowTimestamp = Workspace:GetServerTimeNow()
	if nowTimestamp - playerState.lastRequestServerTimestamp < SERVER_REQUEST_COOLDOWN_SECONDS then
		return
	end
	playerState.lastRequestServerTimestamp = nowTimestamp
	playerState.isFiring = false
	RelicModifierService.resetSustainedShots(player)
	local resolution = ReloadResolver.begin(
		playerState.operativeState,
		playerState.weaponState,
		nowTimestamp,
		relicReloadContext(player)
	)
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if not resolution.didBegin then
		return
	end
	ClassService.interruptBraceForReload(player, nowTimestamp)
	local reloadState = resolution.weaponStateAfter.reloadState
	assert(reloadState ~= nil, "accepted reload must include authoritative timing")
	broadcastReloadPresentation(
		playerState,
		CombatContracts.PresentationMessageKindIds.ReloadStarted,
		reloadState.completionServerTimestamp
	)
	local generation = playerState.generation
	if resolveWeaponDefinition(playerState.weaponState.weaponId) == nil then
		return
	end
	-- Wake at the authoritative deadline rather than the unmodified configured
	-- duration, so Combat Loader and Emergency Chamber actually shorten the wait
	-- instead of only shortening the deadline the completion pass checks.
	task.delay(math.max(0, reloadState.completionServerTimestamp - nowTimestamp), function()
		completeReload(player, reloadState.completionServerTimestamp, generation)
	end)
end

local function resetPlayer(player: Player)
	local previousState = playerStates[player]
	if previousState == nil then
		playerStates[player] = createPlayerState(player)
		return
	end
	previousState.generation += 1
	previousState.isFiring = false
	previousState.aimDirection = nil
	local restricted = OperativeLifeService.applyCombatRestrictions(player, previousState)
	if restricted ~= nil then
		playerStates[player] = restricted
	end
end

local function applyLifeStateRestriction(player: Player)
	local playerState = playerStates[player]
	if playerState == nil then
		return
	end
	local wasReloading = playerState.weaponState.reloadState ~= nil
	playerState.isFiring = false
	playerState.aimDirection = nil
	discloseTarget(player, playerState, nil, Workspace:GetServerTimeNow())
	local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
	if restricted == nil then
		return
	end
	playerStates[player] = restricted
	if wasReloading and restricted.weaponState.reloadState == nil then
		broadcastReloadPresentation(restricted, CombatContracts.PresentationMessageKindIds.ReloadInterrupted, nil)
	end
end

function OperativeCombatRuntimeService.resetForReplay()
	table.clear(retainedCombatByOperativeEntityId)
	for player in playerStates do
		playerStates[player] = createPlayerState(player)
		local state = playerStates[player]
		setPlayerAttribute(player, "LK_EquippedWeaponId", state.weaponState.weaponId)
		RelicModifierService.resetSustainedShots(player)
		OperativeCombatRuntimeService.publishAmmunitionState(player)
	end
end

local function addPlayer(player: Player)
	resetPlayer(player)
	local state = playerStates[player]
	if state ~= nil then
		setPlayerAttribute(player, "LK_EquippedWeaponId", state.weaponState.weaponId)
	end
	OperativeCombatRuntimeService.publishAmmunitionState(player)
	characterAddedConnections[player] = player.CharacterAdded:Connect(function()
		resetPlayer(player)
		OperativeCombatRuntimeService.publishAmmunitionState(player)
	end)
end

local function removePlayer(player: Player)
	local connection = characterAddedConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		characterAddedConnections[player] = nil
	end
	-- P10-0106: retain the exact rounds this operative left with, so a reconnect
	-- resumes them instead of being reissued a full loadout.
	local removedState = playerStates[player]
	if removedState ~= nil then
		local ammunition = removedState.weaponState.ammunition
		retainedCombatByOperativeEntityId[removedState.operativeState.entityId] = {
			weaponId = removedState.weaponState.weaponId,
			ammunition = {
				weaponId = ammunition.weaponId,
				loadedRounds = ammunition.loadedRounds,
				reserveRounds = ammunition.reserveRounds,
				magazineCapacity = ammunition.magazineCapacity,
			},
		}
	end
	playerStates[player] = nil
	raycastStates[player] = nil
	engineerProcessedSupplyIds[player] = nil
	engineerGrantedRoundsBySupplyId[player] = nil
	RelicModifierService.forget(player)
	setPlayerAttribute(player, "LK_EquippedWeaponId", nil)
end

function OperativeCombatRuntimeService.start()
	if started then
		return
	end
	started = true
	local configureBoundary = (ClassService :: any).configureEngineerResupplyBoundary
	if type(configureBoundary) == "function" then
		configureBoundary(inspectEngineerResupply, commitEngineerResupply)
	end
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	lifeStateConnection = OperativeLifeService.subscribe(function(player)
		applyLifeStateRestriction(player)
	end)
	fireIntentConnection = fireIntentRemote.OnServerEvent:Connect(onFireIntent)
	reloadIntentConnection = reloadIntentRemote.OnServerEvent:Connect(onReloadIntent)
	accumulatedSeconds = 0
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < EnemyConfig.Combat.EvaluationIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		OperativeCombatRuntimeService.evaluateAt(Workspace:GetServerTimeNow())
	end)
end

function OperativeCombatRuntimeService.stop()
	if not started then
		return
	end
	started = false
	local configureBoundary = (ClassService :: any).configureEngineerResupplyBoundary
	if type(configureBoundary) == "function" then
		configureBoundary(nil, nil)
	end
	local playersToRemove = {}
	for player, playerState in playerStates do
		discloseTarget(player, playerState, nil, Workspace:GetServerTimeNow())
		table.insert(playersToRemove, player)
	end
	for _, player in playersToRemove do
		removePlayer(player)
	end
	for _, connection in
		{
			fireIntentConnection,
			reloadIntentConnection,
			playerAddedConnection,
			playerRemovingConnection,
			heartbeatConnection,
		}
	do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	fireIntentConnection = nil
	reloadIntentConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	heartbeatConnection = nil
	if lifeStateConnection ~= nil then
		lifeStateConnection:Disconnect()
		lifeStateConnection = nil
	end
	table.clear(characterAddedConnections)
	table.clear(playerStates)
	table.clear(raycastStates)
	table.clear(engineerProcessedSupplyIds)
	table.clear(engineerGrantedRoundsBySupplyId)
	-- Retention is operation-scoped: a replay issues fresh loadouts.
	table.clear(retainedCombatByOperativeEntityId)
	RelicModifierService.clear()
	accumulatedSeconds = 0
end

return OperativeCombatRuntimeService
