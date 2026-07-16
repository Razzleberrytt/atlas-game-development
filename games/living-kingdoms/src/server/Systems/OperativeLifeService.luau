--!strict

--[[
	OperativeLifeService is the same-server authoritative owner for one P3 life
	snapshot per connected operative. Player identity comes only from the
	Players service; clients cannot submit an identity, snapshot, revision, or
	transition through this module or through a RemoteEvent.

	Humanoid health is deliberately not synchronized to P3 health. The Humanoid
	is kept as a positive-health locomotion shell with its Dead state disabled so
	ordinary Roblox death/respawn cannot bypass Incapacitated or Dead. P3 state
	and the service-owned revision remain authoritative.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local OperativeHealthResolver = require(script.Parent.OperativeHealthResolver)

type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage
type OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot

export type AuthoritativeRead = {
	revision: number,
	snapshot: OperativeLifeStateSnapshot,
}

export type AuthoritativeRosterRead = AuthoritativeRead & {
	operativeEntityId: string,
}

export type CommitResult = {
	didCommit: boolean,
	rejectionReason: string?,
	revision: number?,
	snapshot: OperativeLifeStateSnapshot?,
}

type CharacterBinding = {
	character: Model,
	humanoid: Humanoid?,
	rootPart: BasePart?,
	walkSpeed: number?,
	jumpPower: number?,
	jumpHeight: number?,
	autoRotate: boolean?,
	healthConnection: RBXScriptConnection?,
}

type OperativeEntry = {
	operativeEntityId: string,
	snapshot: OperativeLifeStateSnapshot,
	revision: number,
	lastTransitionServerTimestamp: number?,
	characterBinding: CharacterBinding?,
	soloOperationEligible: boolean,
}

type LifeStateListener = (player: Player, snapshot: OperativeLifeStateSnapshot, revision: number) -> ()
type RosterListener = (eventName: "Registered" | "Unregistered", operativeEntityId: string) -> ()

type ListenerConnection = {
	Disconnect: (self: ListenerConnection) -> (),
}

type OperativeLifeService = {
	start: () -> (),
	stop: () -> (),
	registerPlayer: (player: Player) -> AuthoritativeRead?,
	unregisterPlayer: (player: Player) -> boolean,
	read: (player: Player) -> AuthoritativeRead?,
	readAll: () -> { AuthoritativeRosterRead },
	configureSoloOperationEligibility: (operativeEntityId: string, isEligible: boolean) -> boolean,
	applyAuthoritativeDamage: (
		operativeEntityId: string,
		expectedRevision: number,
		authoritativeDamage: AuthoritativeOperativeDamage
	) -> CommitResult,
	commitAcceptedTransition: (player: Player, expectedRevision: number, resolverResult: unknown) -> CommitResult,
	isAlive: (player: Player) -> boolean,
	isCharacterMovementAllowed: (player: Player, character: Model) -> boolean,
	isCombatAllowed: (player: Player) -> boolean,
	applyCombatRestrictions: (player: Player, combatState: any) -> any?,
	bindCharacter: (player: Player, character: Model) -> boolean,
	subscribe: (listener: LifeStateListener) -> ListenerConnection,
	subscribeRoster: (listener: RosterListener) -> ListenerConnection,
}

local lifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local OperativeLifeService: OperativeLifeService = {} :: OperativeLifeService
local entries: { [Player]: OperativeEntry } = {}
local playerByOperativeEntityId: { [string]: Player } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local listeners: { [number]: LifeStateListener } = {}
local rosterListeners: { [number]: RosterListener } = {}
local nextListenerId = 0
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local started = false
local previousCharacterAutoLoads: boolean? = nil

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function isServerPlayer(value: unknown): boolean
	if typeof(value) ~= "Instance" or not (value :: Instance):IsA("Player") then
		return false
	end
	local player = value :: Player
	return player.Parent == Players or table.find(Players:GetPlayers(), player) ~= nil
end

local function deriveOperativeEntityId(player: Player): string
	return "operative.player:" .. tostring(player.UserId)
end

local function copyStringSet(source: { [string]: boolean }): { [string]: boolean }
	return table.clone(source)
end

local function copySnapshot(snapshot: OperativeLifeStateSnapshot): OperativeLifeStateSnapshot
	local incapacitationState = snapshot.incapacitationState
	return {
		operativeEntityId = snapshot.operativeEntityId,
		lifeStateId = snapshot.lifeStateId,
		healthState = {
			currentHealth = snapshot.healthState.currentHealth,
			maximumHealth = snapshot.healthState.maximumHealth,
		},
		incapacitationState = if incapacitationState == nil
			then nil
			else {
				startedAtServerTimestamp = incapacitationState.startedAtServerTimestamp,
				bleedOutDeadlineServerTimestamp = incapacitationState.bleedOutDeadlineServerTimestamp,
			},
		soloRecoveryState = {
			isEligible = snapshot.soloRecoveryState.isEligible,
			recoveriesUsed = snapshot.soloRecoveryState.recoveriesUsed,
			recoveryStartedAtServerTimestamp = snapshot.soloRecoveryState.recoveryStartedAtServerTimestamp,
			recoveryCompletionServerTimestamp = snapshot.soloRecoveryState.recoveryCompletionServerTimestamp,
		},
		processedDamageEventIds = copyStringSet(snapshot.processedDamageEventIds),
	}
end

local function initialSnapshot(operativeEntityId: string): OperativeLifeStateSnapshot
	return {
		operativeEntityId = operativeEntityId,
		lifeStateId = lifeStateIds.Alive,
		healthState = {
			currentHealth = OperativeLifeConfig.MaximumHealth,
			maximumHealth = OperativeLifeConfig.MaximumHealth,
		},
		incapacitationState = nil,
		-- Operation participation is not owned by LK-0305. The conservative
		-- canonical initial state invents no solo-operation history.
		soloRecoveryState = {
			isEligible = false,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = nil,
			recoveryCompletionServerTimestamp = nil,
		},
		processedDamageEventIds = {},
	}
end

local function isValidStringSet(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, present in value :: any do
		if type(key) ~= "string" or key == "" or present ~= true then
			return false
		end
	end
	return true
end

local function isValidSnapshot(value: unknown, operativeEntityId: string): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: any
	if snapshot.operativeEntityId ~= operativeEntityId or type(snapshot.healthState) ~= "table" then
		return false
	end
	local currentHealth = snapshot.healthState.currentHealth
	local maximumHealth = snapshot.healthState.maximumHealth
	if
		not isFiniteNonnegative(currentHealth)
		or maximumHealth ~= OperativeLifeConfig.MaximumHealth
		or currentHealth > maximumHealth
	then
		return false
	end
	if type(snapshot.soloRecoveryState) ~= "table" then
		return false
	end
	local solo = snapshot.soloRecoveryState
	if
		type(solo.isEligible) ~= "boolean"
		or not isFiniteNonnegative(solo.recoveriesUsed)
		or solo.recoveriesUsed % 1 ~= 0
		or solo.recoveriesUsed > OperativeLifeConfig.SoloRecoveriesPerOperation
	then
		return false
	end
	local recoveryStart = solo.recoveryStartedAtServerTimestamp
	local recoveryCompletion = solo.recoveryCompletionServerTimestamp
	if
		(recoveryStart ~= nil and not isFiniteNonnegative(recoveryStart))
		or (recoveryCompletion ~= nil and not isFiniteNonnegative(recoveryCompletion))
		or (recoveryStart == nil) ~= (recoveryCompletion == nil)
		or (recoveryStart ~= nil and recoveryCompletion < recoveryStart)
	then
		return false
	end
	if not isValidStringSet(snapshot.processedDamageEventIds) then
		return false
	end
	if snapshot.lifeStateId == lifeStateIds.Alive then
		return currentHealth > 0 and snapshot.incapacitationState == nil and recoveryStart == nil
	end
	if snapshot.lifeStateId == lifeStateIds.Incapacitated then
		local incapacitation = snapshot.incapacitationState
		return currentHealth == 0
			and type(incapacitation) == "table"
			and isFiniteNonnegative(incapacitation.startedAtServerTimestamp)
			and isFiniteNonnegative(incapacitation.bleedOutDeadlineServerTimestamp)
			and incapacitation.bleedOutDeadlineServerTimestamp >= incapacitation.startedAtServerTimestamp
	end
	return snapshot.lifeStateId == lifeStateIds.Dead
		and currentHealth == 0
		and snapshot.incapacitationState == nil
		and recoveryStart == nil
end

local function isAllowedTransition(before: string, after: string): boolean
	if before == lifeStateIds.Alive then
		return after == lifeStateIds.Alive or after == lifeStateIds.Incapacitated
	end
	if before == lifeStateIds.Incapacitated then
		return after == lifeStateIds.Alive or after == lifeStateIds.Dead
	end
	return false
end

local function transitionTimestamp(result: any): number?
	if result.transitionServerTimestamp ~= nil then
		return result.transitionServerTimestamp
	end
	local session = result.sessionStateAfter
	if type(session) == "table" and session.statusId == "Completed" then
		return session.completionServerTimestamp
	end
	return nil
end

local function resultSnapshot(result: any): unknown
	if result.snapshotAfter ~= nil then
		return result.snapshotAfter
	end
	return result.targetSnapshotAfter
end

local function setRootStationary(rootPart: BasePart?)
	if rootPart == nil or rootPart.Parent == nil then
		return
	end
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function applyCharacterRestrictions(entry: OperativeEntry)
	local binding = entry.characterBinding
	if binding == nil or binding.character.Parent == nil then
		return
	end
	local humanoid = binding.humanoid
	if humanoid == nil or humanoid.Parent == nil then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	if humanoid.Health <= 0 then
		humanoid.Health = 1
	end
	if entry.snapshot.lifeStateId == lifeStateIds.Alive then
		humanoid.WalkSpeed = binding.walkSpeed or humanoid.WalkSpeed
		humanoid.JumpPower = binding.jumpPower or humanoid.JumpPower
		humanoid.JumpHeight = binding.jumpHeight or humanoid.JumpHeight
		humanoid.AutoRotate = if binding.autoRotate == nil then true else binding.autoRotate
		return
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid:Move(Vector3.zero, false)
	setRootStationary(binding.rootPart)
end

local function unbindCharacter(entry: OperativeEntry)
	local binding = entry.characterBinding
	if binding == nil then
		return
	end
	local connection = binding.healthConnection
	if connection ~= nil then
		connection:Disconnect()
	end
	local humanoid = binding.humanoid
	if humanoid ~= nil and humanoid.Parent ~= nil then
		-- A replaced character is never restored as an active controller.
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		humanoid:Move(Vector3.zero, false)
	end
	setRootStationary(binding.rootPart)
	entry.characterBinding = nil
end

local function notifyListeners(player: Player, entry: OperativeEntry)
	for _, listener in listeners do
		listener(player, copySnapshot(entry.snapshot), entry.revision)
	end
end

local function notifyRosterListeners(eventName: "Registered" | "Unregistered", operativeEntityId: string)
	for _, listener in rosterListeners do
		listener(eventName, operativeEntityId)
	end
end

local function rejected(reason: string): CommitResult
	return {
		didCommit = false,
		rejectionReason = reason,
		revision = nil,
		snapshot = nil,
	}
end

function OperativeLifeService.registerPlayer(player: Player): AuthoritativeRead?
	if not isServerPlayer(player) then
		return nil
	end
	local existing = entries[player]
	if existing ~= nil then
		return { revision = existing.revision, snapshot = copySnapshot(existing.snapshot) }
	end
	local operativeEntityId = deriveOperativeEntityId(player)
	if playerByOperativeEntityId[operativeEntityId] ~= nil then
		return nil
	end
	local entry: OperativeEntry = {
		operativeEntityId = operativeEntityId,
		snapshot = initialSnapshot(operativeEntityId),
		revision = 0,
		lastTransitionServerTimestamp = nil,
		characterBinding = nil,
		soloOperationEligible = false,
	}
	entries[player] = entry
	playerByOperativeEntityId[operativeEntityId] = player
	notifyRosterListeners("Registered", operativeEntityId)
	return { revision = entry.revision, snapshot = copySnapshot(entry.snapshot) }
end

function OperativeLifeService.unregisterPlayer(player: Player): boolean
	local entry = entries[player]
	if entry == nil then
		return false
	end
	unbindCharacter(entry)
	entries[player] = nil
	playerByOperativeEntityId[entry.operativeEntityId] = nil
	notifyRosterListeners("Unregistered", entry.operativeEntityId)
	return true
end

function OperativeLifeService.read(player: Player): AuthoritativeRead?
	local entry = entries[player]
	if entry == nil then
		return nil
	end
	return { revision = entry.revision, snapshot = copySnapshot(entry.snapshot) }
end

function OperativeLifeService.readAll(): { AuthoritativeRosterRead }
	local result = {}
	for _, entry in entries do
		table.insert(result, {
			operativeEntityId = entry.operativeEntityId,
			revision = entry.revision,
			snapshot = copySnapshot(entry.snapshot),
		})
	end
	table.sort(result, function(left, right)
		return left.operativeEntityId < right.operativeEntityId
	end)
	return result
end

function OperativeLifeService.configureSoloOperationEligibility(operativeEntityId: string, isEligible: boolean): boolean
	if type(operativeEntityId) ~= "string" or type(isEligible) ~= "boolean" then
		return false
	end
	local player = playerByOperativeEntityId[operativeEntityId]
	local entry = if player == nil then nil else entries[player]
	if entry == nil then
		return false
	end
	entry.soloOperationEligible = isEligible
	return true
end

function OperativeLifeService.applyAuthoritativeDamage(
	operativeEntityId: string,
	expectedRevision: number,
	authoritativeDamage: AuthoritativeOperativeDamage
): CommitResult
	if type(operativeEntityId) ~= "string" or operativeEntityId == "" then
		return rejected("UnknownOperative")
	end
	local player = playerByOperativeEntityId[operativeEntityId]
	if player == nil then
		return rejected("OperativeNotRegistered")
	end
	local entry = entries[player]
	if entry == nil or entry.operativeEntityId ~= operativeEntityId then
		return rejected("OperativeNotRegistered")
	end
	if
		type(expectedRevision) ~= "number"
		or expectedRevision ~= expectedRevision
		or expectedRevision == math.huge
		or expectedRevision == -math.huge
		or expectedRevision % 1 ~= 0
		or expectedRevision < 0
		or expectedRevision ~= entry.revision
	then
		return rejected("StaleRevision")
	end

	local snapshot = copySnapshot(entry.snapshot)
	local damage = authoritativeDamage :: any
	local serverTimestamp = if type(damage) == "table" then damage.serverTimestamp else nil
	local resolverResult = OperativeHealthResolver.resolveDamage(snapshot, authoritativeDamage, serverTimestamp :: any)
	if type(resolverResult) ~= "table" or resolverResult.didTransition ~= true then
		local reason = if type(resolverResult) == "table"
				and type(resolverResult.rejectionReasonId) == "string"
			then resolverResult.rejectionReasonId
			else "ResolverRejected"
		return rejected(reason)
	end
	local result = resolverResult :: any
	local snapshotAfter = result.snapshotAfter
	if
		type(damage) ~= "table"
		or type(damage.damageEventId) ~= "string"
		or damage.damageEventId == ""
		or result.damageEventId ~= damage.damageEventId
		or type(snapshotAfter) ~= "table"
		or type(snapshotAfter.processedDamageEventIds) ~= "table"
		or snapshotAfter.processedDamageEventIds[damage.damageEventId] ~= true
	then
		return rejected("InvalidResolverResult")
	end
	if snapshotAfter.lifeStateId == lifeStateIds.Incapacitated and entry.soloOperationEligible then
		local recovery = snapshotAfter.soloRecoveryState
		if recovery.recoveriesUsed < OperativeLifeConfig.SoloRecoveriesPerOperation then
			recovery.isEligible = true
			recovery.recoveryStartedAtServerTimestamp = serverTimestamp
			recovery.recoveryCompletionServerTimestamp = serverTimestamp
				+ OperativeLifeConfig.SoloRecoveryDurationSeconds
		end
	end

	return OperativeLifeService.commitAcceptedTransition(player, expectedRevision, resolverResult)
end

function OperativeLifeService.commitAcceptedTransition(
	player: Player,
	expectedRevision: number,
	resolverResult: unknown
): CommitResult
	local entry = entries[player]
	if entry == nil then
		return rejected("OperativeNotRegistered")
	end
	if type(expectedRevision) ~= "number" or expectedRevision ~= entry.revision then
		return rejected("StaleRevision")
	end
	if type(resolverResult) ~= "table" or (resolverResult :: any).didTransition ~= true then
		return rejected("ResolverRejected")
	end
	local result = resolverResult :: any
	local snapshotAfter = resultSnapshot(result)
	if not isValidSnapshot(snapshotAfter, entry.operativeEntityId) then
		return rejected("InvalidSnapshot")
	end
	local validatedSnapshot = snapshotAfter :: OperativeLifeStateSnapshot
	if
		(result.lifeStateIdBefore ~= nil and result.lifeStateIdBefore ~= entry.snapshot.lifeStateId)
		or (result.lifeStateIdAfter ~= nil and result.lifeStateIdAfter ~= validatedSnapshot.lifeStateId)
		or not isAllowedTransition(entry.snapshot.lifeStateId, validatedSnapshot.lifeStateId)
	then
		return rejected("IllegalTransition")
	end
	local timestamp = transitionTimestamp(result)
	if not isFiniteNonnegative(timestamp) then
		return rejected("InvalidTransitionTimestamp")
	end
	local incapacitation = validatedSnapshot.incapacitationState
	if
		validatedSnapshot.lifeStateId == lifeStateIds.Incapacitated
		and (incapacitation == nil or incapacitation.startedAtServerTimestamp ~= timestamp)
	then
		return rejected("InvalidTransitionTimestamp")
	end
	local recoveryStart = validatedSnapshot.soloRecoveryState.recoveryStartedAtServerTimestamp
	if recoveryStart ~= nil and (incapacitation == nil or recoveryStart ~= incapacitation.startedAtServerTimestamp) then
		return rejected("InvalidTransitionTimestamp")
	end
	local previousTimestamp = entry.lastTransitionServerTimestamp
	if previousTimestamp ~= nil and timestamp < previousTimestamp then
		return rejected("TimestampRegressed")
	end
	if validatedSnapshot.soloRecoveryState.recoveriesUsed < entry.snapshot.soloRecoveryState.recoveriesUsed then
		return rejected("InvalidSnapshot")
	end
	for damageEventId in entry.snapshot.processedDamageEventIds do
		if validatedSnapshot.processedDamageEventIds[damageEventId] ~= true then
			return rejected("InvalidSnapshot")
		end
	end
	if
		entry.snapshot.lifeStateId == lifeStateIds.Alive
		and validatedSnapshot.lifeStateId == lifeStateIds.Alive
		and validatedSnapshot.healthState.currentHealth > entry.snapshot.healthState.currentHealth
	then
		return rejected("InvalidHealth")
	end
	entry.snapshot = copySnapshot(validatedSnapshot)
	entry.revision += 1
	entry.lastTransitionServerTimestamp = timestamp
	applyCharacterRestrictions(entry)
	notifyListeners(player, entry)
	return {
		didCommit = true,
		rejectionReason = nil,
		revision = entry.revision,
		snapshot = copySnapshot(entry.snapshot),
	}
end

function OperativeLifeService.isAlive(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.snapshot.lifeStateId == lifeStateIds.Alive
end

function OperativeLifeService.isCharacterMovementAllowed(player: Player, character: Model): boolean
	local entry = entries[player]
	local binding = if entry == nil then nil else entry.characterBinding
	return entry ~= nil
		and entry.snapshot.lifeStateId == lifeStateIds.Alive
		and binding ~= nil
		and binding.character == character
		and player.Character == character
end

function OperativeLifeService.isCombatAllowed(player: Player): boolean
	return OperativeLifeService.isAlive(player)
end

local function copyTable(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, nested in value do
		result[key] = copyTable(nested)
	end
	return result
end

function OperativeLifeService.applyCombatRestrictions(player: Player, combatState: any): any?
	local entry = entries[player]
	if entry == nil or type(combatState) ~= "table" then
		return nil
	end
	local after = copyTable(combatState)
	local operativeState = after.operativeState
	local weaponState = after.weaponState
	if type(operativeState) ~= "table" or type(weaponState) ~= "table" then
		return nil
	end
	if entry.snapshot.lifeStateId == lifeStateIds.Alive then
		if
			operativeState.combatStateId == CombatContracts.OperativeCombatStateIds.Incapacitated
			or operativeState.combatStateId == CombatContracts.OperativeCombatStateIds.Dead
		then
			operativeState.combatStateId = CombatContracts.OperativeCombatStateIds.Ready
		end
		if weaponState.readinessStateId == CombatContracts.WeaponReadinessStateIds.Disabled then
			-- P2's reload resolver begins from Ready, including the harness's
			-- canonical zero-loaded initial state. This restores eligibility only;
			-- ammunition and cadence remain untouched.
			weaponState.readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready
		end
		return after
	end
	operativeState.combatStateId = if entry.snapshot.lifeStateId == lifeStateIds.Incapacitated
		then CombatContracts.OperativeCombatStateIds.Incapacitated
		else CombatContracts.OperativeCombatStateIds.Dead
	weaponState.readinessStateId = CombatContracts.WeaponReadinessStateIds.Disabled
	weaponState.reloadState = nil
	after.selectedTargetEntityId = nil
	after.selectedTargetState = nil
	return after
end

function OperativeLifeService.bindCharacter(player: Player, character: Model): boolean
	local entry = entries[player]
	if entry == nil or player.Character ~= character or character.Parent == nil then
		return false
	end
	unbindCharacter(entry)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local rootPart = if root ~= nil and root:IsA("BasePart") then root else nil
	local binding: CharacterBinding = {
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		walkSpeed = if humanoid == nil then nil else humanoid.WalkSpeed,
		jumpPower = if humanoid == nil then nil else humanoid.JumpPower,
		jumpHeight = if humanoid == nil then nil else humanoid.JumpHeight,
		autoRotate = if humanoid == nil then nil else humanoid.AutoRotate,
		healthConnection = nil,
	}
	entry.characterBinding = binding
	if humanoid ~= nil then
		binding.healthConnection = humanoid.HealthChanged:Connect(function(health)
			if entry.characterBinding ~= binding then
				return
			end
			if health <= 0 then
				humanoid.Health = 1
			end
		end)
	end
	applyCharacterRestrictions(entry)
	return true
end

function OperativeLifeService.subscribe(listener: LifeStateListener): ListenerConnection
	nextListenerId += 1
	local listenerId = nextListenerId
	listeners[listenerId] = listener
	local connected = true
	local connection = {} :: ListenerConnection
	function connection:Disconnect()
		if not connected then
			return
		end
		connected = false
		listeners[listenerId] = nil
	end
	return connection
end

function OperativeLifeService.subscribeRoster(listener: RosterListener): ListenerConnection
	nextListenerId += 1
	local listenerId = nextListenerId
	rosterListeners[listenerId] = listener
	local connected = true
	local connection = {} :: ListenerConnection
	function connection:Disconnect()
		if not connected then
			return
		end
		connected = false
		rosterListeners[listenerId] = nil
	end
	return connection
end

local function addPlayer(player: Player)
	local registered = OperativeLifeService.registerPlayer(player)
	if registered == nil then
		return
	end
	characterAddedConnections[player] = player.CharacterAdded:Connect(function(character)
		OperativeLifeService.bindCharacter(player, character)
	end)
	local character = player.Character
	if character ~= nil then
		OperativeLifeService.bindCharacter(player, character)
	else
		task.spawn(function()
			if entries[player] ~= nil and player.Parent == Players and player.Character == nil then
				player:LoadCharacter()
			end
		end)
	end
end

local function removePlayer(player: Player)
	local connection = characterAddedConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		characterAddedConnections[player] = nil
	end
	OperativeLifeService.unregisterPlayer(player)
end

local function reconcilePlayers()
	if not started then
		return
	end
	for _, player in Players:GetPlayers() do
		if entries[player] == nil then
			addPlayer(player)
		end
	end
end

function OperativeLifeService.start()
	if started then
		return
	end
	started = true
	previousCharacterAutoLoads = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	reconcilePlayers()
	-- Studio server/client startup can publish the initial Player children
	-- before this bootstrap observes PlayerAdded. Reconcile again after the
	-- bootstrap yields; this is bounded registration, not a gameplay loop.
	task.defer(reconcilePlayers)
	task.delay(1, reconcilePlayers)
end

function OperativeLifeService.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	local playersToRemove = {}
	for player in entries do
		table.insert(playersToRemove, player)
	end
	for _, player in playersToRemove do
		removePlayer(player)
	end
	if previousCharacterAutoLoads ~= nil then
		Players.CharacterAutoLoads = previousCharacterAutoLoads
		previousCharacterAutoLoads = nil
	end
	table.clear(listeners)
	table.clear(rosterListeners)
end

return OperativeLifeService
