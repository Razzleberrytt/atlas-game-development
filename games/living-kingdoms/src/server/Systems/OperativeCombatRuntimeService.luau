--!strict

--[[
	P5-0106 production automatic-combat owner. Composes the existing pure P2
	pipeline — TargetCandidateSelector, AutomaticFireResolver,
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
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local AutomaticFireResolver = require(script.Parent.AutomaticFireResolver)
local DamageResolver = require(script.Parent.DamageResolver)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local FirearmHitResolver = require(script.Parent.FirearmHitResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local ReloadResolver = require(script.Parent.ReloadResolver)
local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)

type CombatEntityId = CombatContracts.CombatEntityId
type FirearmTargetContext = CombatContracts.FirearmTargetContext
type OperativeReloadState = CombatContracts.OperativeReloadState
type TargetCandidate = CombatContracts.TargetCandidate
type WeaponReadinessState = CombatContracts.WeaponReadinessState

type SightedCandidate = {
	fact: EnemyDirectorService.EnemyCombatFact,
	distanceStuds: number,
	hasLineOfSight: boolean,
}

type PlayerCombatState = {
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	selectedTargetEntityId: CombatEntityId?,
	lastRequestServerTimestamp: number,
	generation: number,
	processedShotIds: { [string]: boolean },
	sightedByEntityId: { [string]: SightedCandidate },
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
	evaluateAt: (serverTimestamp: number) -> (),
}

local SERVER_REQUEST_COOLDOWN_SECONDS = 0.25

local OperativeCombatRuntimeService: OperativeCombatRuntimeService = {} :: OperativeCombatRuntimeService
local started = false
local accumulatedSeconds = 0
local reloadIntentConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local lifeStateConnection: { Disconnect: (self: any) -> () }? = nil
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local playerStates: { [Player]: PlayerCombatState } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function createWeaponState(): WeaponReadinessState
	local weaponId = FirearmConfig.BasicFirearm.WeaponId
	return {
		weaponId = weaponId,
		readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
		ammunition = {
			weaponId = weaponId,
			loadedRounds = FirearmConfig.BasicFirearm.PrototypeInitialLoadedRounds,
			reserveRounds = FirearmConfig.BasicFirearm.PrototypeInitialReserveRounds,
			magazineCapacity = FirearmConfig.BasicFirearm.MagazineCapacity,
		},
		cadence = {
			weaponId = weaponId,
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local function deriveOperativeEntityId(player: Player): string
	-- Must match the P3 life identity so enemy threat facts and revive
	-- coordination address the same operative.
	return "operative.player:" .. tostring(player.UserId)
end

local function createPlayerState(player: Player): PlayerCombatState
	local weaponId = FirearmConfig.BasicFirearm.WeaponId
	return {
		operativeState = {
			entityId = deriveOperativeEntityId(player),
			combatStateId = CombatContracts.OperativeCombatStateIds.Ready,
			equippedWeaponId = weaponId,
		},
		weaponState = createWeaponState(),
		selectedTargetEntityId = nil,
		lastRequestServerTimestamp = -math.huge,
		generation = 1,
		processedShotIds = {},
		sightedByEntityId = {},
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
	local kindId = if grantedRounds == nil
		then CombatContracts.PresentationMessageKindIds.AmmunitionState
		else CombatContracts.PresentationMessageKindIds.AmmunitionCollected
	local payload = {
		kindId = kindId,
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
		maximumReserveRounds = FirearmConfig.BasicFirearm.MaximumReserveRounds,
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

local function hasClearShot(
	player: Player,
	operativePosition: Vector3,
	fact: EnemyDirectorService.EnemyCombatFact
): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions: { Instance } = {}
	local character = player.Character
	if character ~= nil then
		table.insert(exclusions, character)
	end
	parameters.FilterDescendantsInstances = exclusions
	local direction = fact.worldPosition - operativePosition
	local result = Workspace:Raycast(operativePosition, direction, parameters)
	if result == nil then
		return true
	end
	return result.Instance:IsDescendantOf(fact.model)
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
	operativePosition: Vector3
): { TargetCandidate }
	local sighted: { SightedCandidate } = {}
	for _, fact in EnemyDirectorService.readEnemyCombatFacts() do
		local distance = horizontalDistance(fact.worldPosition, operativePosition)
		if distance <= EnemyConfig.Combat.GameplayVisibilityRadiusStuds then
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
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
	}
	if completionServerTimestamp ~= nil then
		payload.completionServerTimestamp = completionServerTimestamp
	end
	presentationRemote:FireAllClients(payload)
end

local function resolveAcceptedShot(
	playerState: PlayerCombatState,
	operativePosition: Vector3,
	fireResult: CombatContracts.AuthoritativeFireResult,
	nowTimestamp: number
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
		isVisible = sightedEntry.distanceStuds <= EnemyConfig.Combat.GameplayVisibilityRadiusStuds,
	}
	local hitResolution = FirearmHitResolver.resolve(fireResult, {
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		selectedTargetEntityId = targetEntityId,
		operativeWorldPosition = operativePosition,
		obstructionResultId = if sightedEntry.hasLineOfSight
			then CombatContracts.ShotObstructionResultIds.TargetHit
			else CombatContracts.ShotObstructionResultIds.Blocked,
	}, targetContext)
	local damageResolution = DamageResolver.resolve(hitResolution, healthRead.healthState, nowTimestamp)
	EnemyDirectorService.commitHealthState(
		targetEntityId,
		healthRead.revision,
		damageResolution.targetHealthStateAfter,
		nowTimestamp
	)
	presentationRemote:FireAllClients({
		kindId = CombatContracts.PresentationMessageKindIds.ShotFired,
		shotId = shotId,
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		targetEntityId = targetEntityId,
		didApplyDamage = damageResolution.didApplyDamage,
		impactWorldPosition = if damageResolution.didApplyDamage then fact.worldPosition else nil,
		serverTimestamp = nowTimestamp,
	})
end

local function evaluatePlayer(player: Player, playerState: PlayerCombatState, nowTimestamp: number)
	if not OperativeLifeService.isCombatAllowed(player) then
		discloseTarget(player, playerState, nil, nowTimestamp)
		local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
		if restricted ~= nil then
			playerStates[player] = restricted
		end
		return
	end
	local operativePosition = getOperativePosition(player)
	if operativePosition == nil then
		discloseTarget(player, playerState, nil, nowTimestamp)
		return
	end
	local candidates = buildSightedCandidates(player, playerState, operativePosition)
	local targetingState = {
		entityId = playerState.operativeState.entityId,
		worldPosition = operativePosition,
		combatStateId = playerState.operativeState.combatStateId,
		weaponReadiness = playerState.weaponState,
	}
	local selectedTarget = TargetCandidateSelector.select(targetingState, candidates)
	local targetEntityId = if selectedTarget == nil then nil else selectedTarget.targetEntityId
	discloseTarget(player, playerState, targetEntityId, nowTimestamp)
	local fireResolution = AutomaticFireResolver.resolve({
		entityId = playerState.operativeState.entityId,
		combatStateId = playerState.operativeState.combatStateId,
	}, selectedTarget, playerState.weaponState, nowTimestamp)
	playerState.weaponState = fireResolution.weaponStateAfter
	if fireResolution.decision.shouldFire then
		resolveAcceptedShot(playerState, operativePosition, fireResolution.fireResult, nowTimestamp)
		OperativeCombatRuntimeService.publishAmmunitionState(player)
	end
end

function OperativeCombatRuntimeService.evaluateAt(serverTimestamp: number)
	if not started or type(serverTimestamp) ~= "number" or serverTimestamp ~= serverTimestamp then
		return
	end
	for player, playerState in playerStates do
		evaluatePlayer(player, playerState, serverTimestamp)
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

local function onReloadIntent(player: Player, weaponId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(weaponId) ~= "string" then
		return
	end
	local playerState = playerStates[player]
	if
		playerState == nil
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
	local resolution = ReloadResolver.begin(playerState.operativeState, playerState.weaponState, nowTimestamp)
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if not resolution.didBegin then
		return
	end
	local reloadState = resolution.weaponStateAfter.reloadState
	assert(reloadState ~= nil, "accepted reload must include authoritative timing")
	broadcastReloadPresentation(
		playerState,
		CombatContracts.PresentationMessageKindIds.ReloadStarted,
		reloadState.completionServerTimestamp
	)
	local generation = playerState.generation
	task.delay(FirearmConfig.BasicFirearm.ReloadDurationSeconds, function()
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

local function addPlayer(player: Player)
	resetPlayer(player)
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
	playerStates[player] = nil
end

function OperativeCombatRuntimeService.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	lifeStateConnection = OperativeLifeService.subscribe(function(player)
		applyLifeStateRestriction(player)
	end)
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
	local playersToRemove = {}
	for player, playerState in playerStates do
		discloseTarget(player, playerState, nil, Workspace:GetServerTimeNow())
		table.insert(playersToRemove, player)
	end
	for _, player in playersToRemove do
		removePlayer(player)
	end
	for _, connection in
		{ reloadIntentConnection, playerAddedConnection, playerRemovingConnection, heartbeatConnection }
	do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
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
	accumulatedSeconds = 0
end

return OperativeCombatRuntimeService
