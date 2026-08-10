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
local OperativeHealingResolver = require(script.Parent.OperativeHealingResolver)
local RelicModifierService = require(script.Parent.RelicModifierService)
local OperativeHealthResolver = require(script.Parent.OperativeHealthResolver)

type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage
type AuthoritativeHealing = OperativeHealingResolver.AuthoritativeHealing
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
	resetForReplay: () -> (),
	registerPlayer: (player: Player) -> AuthoritativeRead?,
	unregisterPlayer: (player: Player) -> boolean,
	read: (player: Player) -> AuthoritativeRead?,
	readByOperativeEntityId: (operativeEntityId: string) -> AuthoritativeRead?,
	playerForOperativeEntityId: (operativeEntityId: string) -> Player?,
	readAll: () -> { AuthoritativeRosterRead },
	reconcileMaximumHealth: (player: Player) -> AuthoritativeRead?,
	configureSoloOperationEligibility: (operativeEntityId: string, isEligible: boolean) -> boolean,
	applyAuthoritativeDamage: (
		operativeEntityId: string,
		expectedRevision: number,
		authoritativeDamage: AuthoritativeOperativeDamage
	) -> CommitResult,
	applyAuthoritativeHealing: (
		operativeEntityId: string,
		expectedRevision: number,
		authoritativeHealing: AuthoritativeHealing
	) -> CommitResult,
	hasRetainedSession: (operativeEntityId: string) -> boolean,
	grantTemporaryArmor: (operativeEntityId: string, armorAmount: number, expiresAtServerTimestamp: number) -> boolean,
	readTemporaryArmor: (operativeEntityId: string, serverTimestamp: number) -> number,
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
local ALIVE_HORIZONTAL_SPEED = 16
local OperativeLifeService: OperativeLifeService = {} :: OperativeLifeService
local entries: { [Player]: OperativeEntry } = {}
local playerByOperativeEntityId: { [string]: Player } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
-- RPG-0109 Guardian Signal armor pools. Armor is an operation-bound temporary
-- combat resource, never part of the replicated life snapshot, and it is released
-- with the operative's registration.
type TemporaryArmor = {
	remaining: number,
	expiresAtServerTimestamp: number,
}
local temporaryArmorByPlayer: { [Player]: TemporaryArmor } = {}
-- P10-0106 session retention. A disconnect keeps the operative's authoritative
-- life snapshot against their entity ID for the rest of this operation, so a
-- reconnect resumes exactly where they left off. Without this, reconnecting would
-- hand back full health and undo an incapacitation or death.
local retainedSnapshotByOperativeEntityId: { [string]: OperativeLifeStateSnapshot } = {}
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

local function effectiveMaximumHealth(player: Player): number
	local multiplier = (RelicModifierService.read(player) :: any).equipmentMaximumHealthMultiplier
	if
		type(multiplier) ~= "number"
		or multiplier ~= multiplier
		or multiplier == math.huge
		or multiplier == -math.huge
		or multiplier < 1
		or multiplier > 2
	then
		multiplier = 1
	end
	return OperativeLifeConfig.MaximumHealth * multiplier
end

local function initialSnapshot(operativeEntityId: string, maximumHealth: number?): OperativeLifeStateSnapshot
	local resolvedMaximumHealth = maximumHealth or OperativeLifeConfig.MaximumHealth
	return {
		operativeEntityId = operativeEntityId,
		lifeStateId = lifeStateIds.Alive,
		healthState = {
			currentHealth = resolvedMaximumHealth,
			maximumHealth = resolvedMaximumHealth,
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
		or not isFiniteNonnegative(maximumHealth)
		or maximumHealth < OperativeLifeConfig.MaximumHealth
		or maximumHealth > OperativeLifeConfig.MaximumHealth * 2
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
		-- Alive is an explicit movement contract. Never restore a transient zero
		-- captured while a character was spawning or being rebound; doing so leaves
		-- jumping functional while making every horizontal control appear broken.
		humanoid.WalkSpeed = math.max(binding.walkSpeed or 0, ALIVE_HORIZONTAL_SPEED)
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
	-- Resume a retained snapshot rather than issuing a fresh one. The record is
	-- consumed on restore, so a reconnect can never be replayed for a second
	-- restoration.
	local retained = retainedSnapshotByOperativeEntityId[operativeEntityId]
	retainedSnapshotByOperativeEntityId[operativeEntityId] = nil
	local entry: OperativeEntry = {
		operativeEntityId = operativeEntityId,
		snapshot = if retained ~= nil
			then copySnapshot(retained)
			else initialSnapshot(operativeEntityId, effectiveMaximumHealth(player)),
		revision = 0,
		lastTransitionServerTimestamp = nil,
		characterBinding = nil,
		soloOperationEligible = false,
	}
	entries[player] = entry
	temporaryArmorByPlayer[player] = nil
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
	-- Retain the authoritative snapshot for a same-session reconnect. Temporary
	-- armor is a transient combat resource and deliberately does not survive.
	retainedSnapshotByOperativeEntityId[entry.operativeEntityId] = copySnapshot(entry.snapshot)
	entries[player] = nil
	temporaryArmorByPlayer[player] = nil
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

function OperativeLifeService.readByOperativeEntityId(operativeEntityId: string): AuthoritativeRead?
	if type(operativeEntityId) ~= "string" or operativeEntityId == "" then
		return nil
	end
	local player = playerByOperativeEntityId[operativeEntityId]
	if player == nil then
		return nil
	end
	return OperativeLifeService.read(player)
end

function OperativeLifeService.playerForOperativeEntityId(operativeEntityId: string): Player?
	if type(operativeEntityId) ~= "string" or operativeEntityId == "" then
		return nil
	end
	return playerByOperativeEntityId[operativeEntityId]
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

--[[
	Reconciles the authoritative life snapshot against the currently equipped
	Armor modifier. The target maximum always derives from base health plus the
	current server-owned equipment fact, never from the previous maximum, so
	repeated equip changes cannot compound. Current health preserves its fraction
	of maximum health, preventing gear swaps from becoming a free-heal mechanic.
]]
function OperativeLifeService.reconcileMaximumHealth(player: Player): AuthoritativeRead?
	if not isServerPlayer(player) then
		return nil
	end
	local entry = entries[player]
	if entry == nil then
		return nil
	end
	local targetMaximumHealth = effectiveMaximumHealth(player)
	local currentMaximumHealth = entry.snapshot.healthState.maximumHealth
	if targetMaximumHealth == currentMaximumHealth then
		return { revision = entry.revision, snapshot = copySnapshot(entry.snapshot) }
	end
	local healthFraction = math.clamp(entry.snapshot.healthState.currentHealth / currentMaximumHealth, 0, 1)
	local snapshotAfter = copySnapshot(entry.snapshot)
	snapshotAfter.healthState.maximumHealth = targetMaximumHealth
	snapshotAfter.healthState.currentHealth = targetMaximumHealth * healthFraction
	if not isValidSnapshot(snapshotAfter, entry.operativeEntityId) then
		return { revision = entry.revision, snapshot = copySnapshot(entry.snapshot) }
	end
	entry.snapshot = snapshotAfter
	entry.revision += 1
	applyCharacterRestrictions(entry)
	notifyListeners(player, entry)
	return { revision = entry.revision, snapshot = copySnapshot(entry.snapshot) }
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

--[[
	Grants an expiring pool of temporary armor. Guardian Signal is the only source
	today; the pool replaces rather than stacks, so repeated revives refresh the
	protection instead of accumulating it.
]]
function OperativeLifeService.grantTemporaryArmor(
	operativeEntityId: string,
	armorAmount: number,
	expiresAtServerTimestamp: number
): boolean
	local player = if type(operativeEntityId) == "string" then playerByOperativeEntityId[operativeEntityId] else nil
	if
		player == nil
		or entries[player] == nil
		or not isFiniteNonnegative(armorAmount)
		or armorAmount < 1
		or armorAmount % 1 ~= 0
		or not isFiniteNonnegative(expiresAtServerTimestamp)
	then
		return false
	end
	temporaryArmorByPlayer[player] = {
		remaining = armorAmount,
		expiresAtServerTimestamp = expiresAtServerTimestamp,
	}
	return true
end

-- Reads the operative's unexpired armor, discarding an expired pool as it goes.
function OperativeLifeService.readTemporaryArmor(operativeEntityId: string, serverTimestamp: number): number
	local player = if type(operativeEntityId) == "string" then playerByOperativeEntityId[operativeEntityId] else nil
	local armor = if player == nil then nil else temporaryArmorByPlayer[player]
	if armor == nil or not isFiniteNonnegative(serverTimestamp) then
		return 0
	end
	if serverTimestamp >= armor.expiresAtServerTimestamp then
		temporaryArmorByPlayer[player :: Player] = nil
		return 0
	end
	return armor.remaining
end

--[[
	Applies Guardian Signal armor to one incoming damage event. Armor absorbs at
	most all but one point, so every authoritative damage event still commits and
	stays replay-protected through the existing processed-event set.
]]
local function absorbWithTemporaryArmor(player: Player, damageAmount: number, serverTimestamp: number): number
	local armor = temporaryArmorByPlayer[player]
	if armor == nil then
		return damageAmount
	end
	if not isFiniteNonnegative(serverTimestamp) or serverTimestamp >= armor.expiresAtServerTimestamp then
		temporaryArmorByPlayer[player] = nil
		return damageAmount
	end
	local absorbed = math.min(armor.remaining, math.max(0, math.floor(damageAmount) - 1))
	if absorbed <= 0 then
		return damageAmount
	end
	armor.remaining -= absorbed
	if armor.remaining <= 0 then
		temporaryArmorByPlayer[player] = nil
	end
	return damageAmount - absorbed
end

-- Returns a copy of the authoritative damage carrying a reduced amount. Identity,
-- source, target, and timestamp are preserved so replay protection is unchanged.
local function withDamageAmount(authoritativeDamage: any, damageAmount: number): any
	local reduced = table.clone(authoritativeDamage)
	reduced.damageAmount = damageAmount
	return reduced
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
	if
		type(damage) == "table"
		and isFiniteNonnegative(damage.damageAmount)
		and damage.damageAmount > 0
		and entry.snapshot.lifeStateId == lifeStateIds.Alive
	then
		local absorbedAmount = absorbWithTemporaryArmor(player, damage.damageAmount, serverTimestamp :: any)
		if absorbedAmount ~= damage.damageAmount then
			damage = withDamageAmount(damage, absorbedAmount)
			authoritativeDamage = damage
		end
	end
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
	-- Second Wind (RPG-0109): a once-per-operation reprieve. When the resolved
	-- transition would incapacitate a living operative and the relic still holds
	-- its charge, the damage is reduced to leave the operative alive but fragile
	-- and re-resolved through the same pure boundary. The charge is spent first,
	-- so a failed re-resolve cannot retry the reprieve.
	if
		type(snapshotAfter) == "table"
		and entry.snapshot.lifeStateId == lifeStateIds.Alive
		and snapshotAfter.lifeStateId == lifeStateIds.Incapacitated
		and type(damage) == "table"
		and isFiniteNonnegative(damage.damageAmount)
	then
		local survivalHealth = RelicModifierService.read(player).secondWindSurvivalHealth
		local healthBefore = entry.snapshot.healthState.currentHealth
		if survivalHealth > 0 and healthBefore > 1 and RelicModifierService.consumeSecondWindCharge(player) then
			local reducedAmount = math.max(1, math.floor(healthBefore - survivalHealth))
			local reprieve = OperativeHealthResolver.resolveDamage(
				copySnapshot(entry.snapshot),
				withDamageAmount(damage, reducedAmount),
				serverTimestamp :: any
			)
			if
				type(reprieve) == "table"
				and reprieve.didTransition == true
				and type(reprieve.snapshotAfter) == "table"
				and reprieve.snapshotAfter.lifeStateId == lifeStateIds.Alive
			then
				resolverResult = reprieve
				result = reprieve :: any
				snapshotAfter = result.snapshotAfter
				damage = withDamageAmount(damage, reducedAmount)
			end
		end
	end
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

local function commitAcceptedTransitionInternal(
	player: Player,
	expectedRevision: number,
	resolverResult: unknown,
	allowHealthIncrease: boolean
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
	if
		type(snapshotAfter) ~= "table"
		or type((snapshotAfter :: any).healthState) ~= "table"
		or (snapshotAfter :: any).healthState.maximumHealth ~= entry.snapshot.healthState.maximumHealth
	then
		return rejected("InvalidSnapshot")
	end
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
		not allowHealthIncrease
		and entry.snapshot.lifeStateId == lifeStateIds.Alive
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

function OperativeLifeService.commitAcceptedTransition(
	player: Player,
	expectedRevision: number,
	resolverResult: unknown
): CommitResult
	return commitAcceptedTransitionInternal(player, expectedRevision, resolverResult, false)
end

function OperativeLifeService.applyAuthoritativeHealing(
	operativeEntityId: string,
	expectedRevision: number,
	authoritativeHealing: AuthoritativeHealing
): CommitResult
	if type(operativeEntityId) ~= "string" or operativeEntityId == "" then
		return rejected("UnknownOperative")
	end
	local player = playerByOperativeEntityId[operativeEntityId]
	local entry = if player == nil then nil else entries[player]
	if entry == nil or entry.operativeEntityId ~= operativeEntityId then
		return rejected("OperativeNotRegistered")
	end
	if
		type(expectedRevision) ~= "number"
		or expectedRevision ~= expectedRevision
		or expectedRevision % 1 ~= 0
		or expectedRevision < 0
		or expectedRevision ~= entry.revision
	then
		return rejected("StaleRevision")
	end
	local healing = authoritativeHealing :: any
	local serverTimestamp = if type(healing) == "table" then healing.serverTimestamp else nil
	local resolution =
		OperativeHealingResolver.resolve(copySnapshot(entry.snapshot), authoritativeHealing, serverTimestamp :: any)
	if
		type(resolution) ~= "table"
		or resolution.didTransition ~= true
		or type(healing) ~= "table"
		or type(healing.healingEventId) ~= "string"
		or resolution.healingEventId ~= healing.healingEventId
		or type(resolution.healedAmount) ~= "number"
		or resolution.healedAmount <= 0
	then
		local reason = if type(resolution) == "table" and type(resolution.rejectionReasonId) == "string"
			then resolution.rejectionReasonId
			else "ResolverRejected"
		return rejected(reason)
	end
	return commitAcceptedTransitionInternal(player, expectedRevision, resolution, true)
end

-- True while a disconnected operative's snapshot is still resumable this
-- operation. Used by the roster owner to distinguish a reconnect from a new join.
function OperativeLifeService.hasRetainedSession(operativeEntityId: string): boolean
	return type(operativeEntityId) == "string" and retainedSnapshotByOperativeEntityId[operativeEntityId] ~= nil
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

-- Begin a fresh operation without tearing down application-scoped player,
-- character, or subscriber bindings. OperationLifecycleService used to call
-- stop/start here, which silently disconnected every long-lived life and roster
-- consumer after the first run. Revisions remain monotonic for the lifetime of
-- this service; the new operation is identified by MissionDirectorService's
-- operationId rather than by rewinding this owner.
function OperativeLifeService.resetForReplay()
	if not started then
		return
	end
	table.clear(temporaryArmorByPlayer)
	table.clear(retainedSnapshotByOperativeEntityId)
	for player, entry in entries do
		entry.snapshot = initialSnapshot(entry.operativeEntityId, effectiveMaximumHealth(player))
		entry.revision += 1
		entry.lastTransitionServerTimestamp = nil
		entry.soloOperationEligible = false
		applyCharacterRestrictions(entry)
		notifyListeners(player, entry)
	end
	reconcilePlayers()
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
	table.clear(temporaryArmorByPlayer)
	-- Retention is operation-scoped: a replay issues fresh operatives.
	table.clear(retainedSnapshotByOperativeEntityId)
end

return OperativeLifeService
