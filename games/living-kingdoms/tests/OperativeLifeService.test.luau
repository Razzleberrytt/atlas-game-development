--!strict

-- Focused LK-0305 server ownership, revision, eligibility, combat restriction,
-- and fake-character lifecycle fixtures. No Roblox client or RemoteEvent is
-- involved in this harness.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local COMBAT_TOKEN = {}
local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local HEALTH_RESOLVER_TOKEN = {}

local lifeStateIds = table.freeze({ Alive = "Alive", Incapacitated = "Incapacitated", Dead = "Dead" })
local combatContracts = {
	OperativeCombatStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Incapacitated = "Incapacitated",
		Dead = "Dead",
		Disabled = "Disabled",
	}),
	WeaponReadinessStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Empty = "Empty",
		Disabled = "Disabled",
	}),
}
local config = { MaximumHealth = 100, SoloRecoveriesPerOperation = 1 }
local contracts = { OperativeLifeStateIds = lifeStateIds }

local function signal()
	local callbacks = {}
	local nextId = 0
	return {
		Connect = function(_self, callback)
			nextId += 1
			local id = nextId
			callbacks[id] = callback
			return {
				Disconnect = function()
					callbacks[id] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end

local players = {
	CharacterAutoLoads = true,
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	_members = {},
	GetPlayers = function(self)
		local result = {}
		for player in self._members do
			table.insert(result, player)
		end
		return result
	end,
}
local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = COMBAT_TOKEN },
		Config = { OperativeLifeConfig = CONFIG_TOKEN },
		Health = { OperativeLifeContracts = CONTRACTS_TOKEN },
	},
}

local function fakePlayer(userId: number)
	local player = {
		_className = "Player",
		UserId = userId,
		Parent = players,
		Character = nil,
		CharacterAdded = signal(),
		IsA = function(_self, className)
			return className == "Player"
		end,
	}
	players._members[player] = true
	return player
end

local environment = {
	game = {
		GetService = function(_self, serviceName: string)
			if serviceName == "Players" then
				return players
			end
			if serviceName == "ReplicatedStorage" then
				return replicatedStorage
			end
			error("unexpected service " .. serviceName)
		end,
	},
	require = function(token)
		if token == COMBAT_TOKEN then
			return combatContracts
		end
		if token == CONFIG_TOKEN then
			return config
		end
		if token == CONTRACTS_TOKEN then
			return contracts
		end
		if token == HEALTH_RESOLVER_TOKEN then
			return {
				resolveDamage = function()
					error("damage routing is covered by LK-0306 fixtures")
				end,
			}
		end
		error("unexpected module")
	end,
	script = { Parent = { OperativeHealthResolver = HEALTH_RESOLVER_TOKEN } },
	typeof = function(value)
		return if type(value) == "table" and value._className ~= nil then "Instance" else type(value)
	end,
	Vector3 = { zero = { X = 0, Y = 0, Z = 0 } },
	Enum = { HumanoidStateType = { Dead = "Dead" } },
}

local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau"), {
	debugName = "OperativeLifeService",
	environment = environment,
	injectGlobals = true,
})
local service = loader()

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function incapacitated(snapshot, timestamp: number)
	local after = deepCopy(snapshot)
	after.lifeStateId = "Incapacitated"
	after.healthState.currentHealth = 0
	after.incapacitationState = {
		startedAtServerTimestamp = timestamp,
		bleedOutDeadlineServerTimestamp = timestamp + 30,
	}
	return after
end

local function alive(snapshot, health: number)
	local after = deepCopy(snapshot)
	after.lifeStateId = "Alive"
	after.healthState.currentHealth = health
	after.incapacitationState = nil
	after.soloRecoveryState.recoveryStartedAtServerTimestamp = nil
	after.soloRecoveryState.recoveryCompletionServerTimestamp = nil
	return after
end

local function dead(snapshot)
	local after = deepCopy(snapshot)
	after.lifeStateId = "Dead"
	after.healthState.currentHealth = 0
	after.incapacitationState = nil
	return after
end

local function transition(before: string, after, timestamp: number)
	return {
		didTransition = true,
		lifeStateIdBefore = before,
		lifeStateIdAfter = after.lifeStateId,
		transitionServerTimestamp = timestamp,
		snapshotAfter = after,
	}
end

local function rejectedResult(snapshot)
	return {
		didTransition = false,
		transitionServerTimestamp = nil,
		snapshotAfter = deepCopy(snapshot),
	}
end

-- Registration and copied ownership.
local player = fakePlayer(101)
local registered = service.registerPlayer(player)
assert(registered ~= nil, "registration failed")
assert(registered.revision == 0, "initial revision must be zero")
assert(registered.snapshot.lifeStateId == "Alive", "registration must be Alive")
assert(registered.snapshot.healthState.currentHealth == 100, "initial health must be 100")
assert(registered.snapshot.healthState.maximumHealth == 100, "maximum health must be 100")
assert(next(registered.snapshot.processedDamageEventIds) == nil, "processed damage set must start empty")
assert(not registered.snapshot.soloRecoveryState.isEligible, "registration invented solo participation history")
local readCopy = service.read(player)
assert(readCopy ~= nil and readCopy.snapshot ~= registered.snapshot, "reads must be copied")
readCopy.snapshot.healthState.currentHealth = 1
readCopy.snapshot.processedDamageEventIds.injected = true
local unchanged = service.read(player)
assert(unchanged.snapshot.healthState.currentHealth == 100, "caller mutation changed health")
assert(unchanged.snapshot.processedDamageEventIds.injected == nil, "caller mutation changed processed IDs")
local duplicate = service.registerPlayer(player)
assert(
	duplicate.revision == 0 and duplicate.snapshot.healthState.currentHealth == 100,
	"duplicate registration reset state"
)
local clientShaped = { UserId = 101, Parent = players }
assert(service.registerPlayer(clientShaped) == nil, "client-shaped registration was accepted")
local identityCollision = fakePlayer(101)
assert(service.registerPlayer(identityCollision) == nil, "mismatched player replaced an operative identity")
players._members[identityCollision] = nil

local unregistered = fakePlayer(999)
players._members[unregistered] = nil
unregistered.Parent = nil
assert(service.read(unregistered) == nil, "unregistered read succeeded")
assert(
	not service.commitAcceptedTransition(unregistered, 0, transition("Alive", registered.snapshot, 1)).didCommit,
	"unregistered commit succeeded"
)

-- Atomic commits, revision/replay, validation, timestamp, and preservation.
local initial = service.read(player)
local downSnapshot = incapacitated(initial.snapshot, 10)
downSnapshot.processedDamageEventIds["damage.down"] = true
local down = service.commitAcceptedTransition(player, initial.revision, transition("Alive", downSnapshot, 10))
assert(down.didCommit and down.revision == 1, "Alive to Incapacitated did not commit")
assert(down.snapshot.lifeStateId == "Incapacitated", "incapacitated state missing")
assert(down.snapshot.processedDamageEventIds["damage.down"], "processed event did not survive commit")
down.snapshot.healthState.currentHealth = 99
assert(service.read(player).snapshot.healthState.currentHealth == 0, "commit returned authoritative table identity")
assert(
	not service.commitAcceptedTransition(player, initial.revision, transition("Alive", downSnapshot, 10)).didCommit,
	"replayed accepted result committed twice"
)
local rejectedRead = service.read(player)
assert(
	not service.commitAcceptedTransition(player, rejectedRead.revision, rejectedResult(rejectedRead.snapshot)).didCommit,
	"rejected resolver result committed"
)
assert(service.read(player).revision == rejectedRead.revision, "rejection advanced revision")
local mismatch = alive(rejectedRead.snapshot, 30)
mismatch.operativeEntityId = "operative.player:elsewhere"
assert(
	not service.commitAcceptedTransition(player, rejectedRead.revision, transition("Incapacitated", mismatch, 20)).didCommit,
	"mismatched operative identity committed"
)
local malformed = alive(rejectedRead.snapshot, 30)
malformed.healthState.maximumHealth = 999
assert(
	not service.commitAcceptedTransition(player, rejectedRead.revision, transition("Incapacitated", malformed, 20)).didCommit,
	"malformed snapshot committed"
)
local revivedSnapshot = alive(rejectedRead.snapshot, 30)
revivedSnapshot.soloRecoveryState.isEligible = false
revivedSnapshot.soloRecoveryState.recoveriesUsed = 1
local revived = service.commitAcceptedTransition(player, rejectedRead.revision, {
	didTransition = true,
	sessionStateAfter = { statusId = "Completed", completionServerTimestamp = 20 },
	targetSnapshotAfter = revivedSnapshot,
})
assert(revived.didCommit and revived.snapshot.lifeStateId == "Alive", "Incapacitated to Alive did not commit")
assert(revived.snapshot.soloRecoveryState.recoveriesUsed == 1, "solo recovery usage did not survive commit")

local timestampPlayer = fakePlayer(202)
local timestampInitial = service.registerPlayer(timestampPlayer)
assert(
	not service.commitAcceptedTransition(
		timestampPlayer,
		timestampInitial.revision,
		transition("Alive", incapacitated(timestampInitial.snapshot, 40), 50)
	).didCommit,
	"mismatched embedded transition timestamp committed"
)
local timestampDown = service.commitAcceptedTransition(
	timestampPlayer,
	timestampInitial.revision,
	transition("Alive", incapacitated(timestampInitial.snapshot, 50), 50)
)
assert(timestampDown.didCommit, "timestamp fixture setup failed")
local regressedAlive = alive(timestampDown.snapshot, 30)
assert(
	not service.commitAcceptedTransition(
		timestampPlayer,
		timestampDown.revision,
		transition("Incapacitated", regressedAlive, 49)
	).didCommit,
	"timestamp regression committed"
)

local secondDownRead = service.read(player)
local secondDown = service.commitAcceptedTransition(
	player,
	secondDownRead.revision,
	transition("Alive", incapacitated(secondDownRead.snapshot, 30), 30)
)
assert(secondDown.didCommit, "second incapacitation setup failed")
local deathSnapshot = dead(secondDown.snapshot)
deathSnapshot.processedDamageEventIds["damage.finish"] = true
local died =
	service.commitAcceptedTransition(player, secondDown.revision, transition("Incapacitated", deathSnapshot, 31))
assert(died.didCommit and died.snapshot.lifeStateId == "Dead", "Incapacitated to Dead did not commit")
assert(died.snapshot.processedDamageEventIds["damage.finish"], "finishing event identity was lost")
local illegalAlive = alive(died.snapshot, 30)
assert(
	not service.commitAcceptedTransition(player, died.revision, transition("Dead", illegalAlive, 40)).didCommit,
	"Dead returned to Alive"
)

-- Movement/combat eligibility and restriction preservation.
local combatPlayer = fakePlayer(303)
local combatRead = service.registerPlayer(combatPlayer)
local combatState = {
	operativeState = { combatStateId = "Reloading", entityId = combatRead.snapshot.operativeEntityId },
	weaponState = {
		readinessStateId = "Reloading",
		ammunition = { loadedRounds = 5, reserveRounds = 7, magazineCapacity = 12 },
		cadence = { lastFireServerTimestamp = 8, nextAllowedFireServerTimestamp = 9 },
		reloadState = { startedAtServerTimestamp = 8, completionServerTimestamp = 10 },
	},
	selectedTargetEntityId = "hostile.alpha",
	selectedTargetState = { targetEntityId = "hostile.alpha" },
	processedShotIds = { ["shot.prior"] = true },
}
assert(service.isCombatAllowed(combatPlayer), "Alive fire eligibility denied")
local aliveCombat = service.applyCombatRestrictions(combatPlayer, combatState)
assert(aliveCombat.weaponState.reloadState ~= nil, "Alive reload was interrupted")
local combatDown = service.commitAcceptedTransition(
	combatPlayer,
	combatRead.revision,
	transition("Alive", incapacitated(combatRead.snapshot, 10), 10)
)
assert(combatDown.didCommit and not service.isCombatAllowed(combatPlayer), "Incapacitated fire remained eligible")
local restricted = service.applyCombatRestrictions(combatPlayer, combatState)
assert(restricted.operativeState.combatStateId == "Incapacitated", "incapacitated combat state missing")
assert(restricted.weaponState.readinessStateId == "Disabled", "incapacitated weapon remained enabled")
assert(restricted.weaponState.reloadState == nil, "incapacitation did not clear reload")
assert(restricted.selectedTargetEntityId == nil and restricted.selectedTargetState == nil, "target was retained")
assert(restricted.weaponState.ammunition.loadedRounds == 5, "ammunition changed under restriction")
assert(restricted.weaponState.ammunition.reserveRounds == 7, "reserve ammunition changed")
assert(restricted.weaponState.cadence.nextAllowedFireServerTimestamp == 9, "cadence changed")
assert(restricted.processedShotIds["shot.prior"], "processed ShotIds changed")
assert(combatState.weaponState.reloadState ~= nil, "combat input was mutated")
local combatRevived = service.commitAcceptedTransition(
	combatPlayer,
	combatDown.revision,
	transition("Incapacitated", alive(combatDown.snapshot, 30), 20)
)
assert(combatRevived.didCommit and service.isCombatAllowed(combatPlayer), "return to Alive did not restore eligibility")
local restored = service.applyCombatRestrictions(combatPlayer, restricted)
assert(restored.operativeState.combatStateId == "Ready", "Alive combat state did not restore")
assert(restored.weaponState.ammunition.loadedRounds == 5, "revive refilled ammunition")
assert(restored.weaponState.cadence.nextAllowedFireServerTimestamp == 9, "revive reset cadence")
local emptyRestricted = deepCopy(restricted)
emptyRestricted.weaponState.ammunition.loadedRounds = 0
local emptyRestored = service.applyCombatRestrictions(combatPlayer, emptyRestricted)
assert(emptyRestored.weaponState.readinessStateId == "Ready", "revived empty weapon cannot begin reload")
assert(emptyRestored.weaponState.ammunition.loadedRounds == 0, "revive refilled empty weapon")
local combatDownAgain = service.commitAcceptedTransition(
	combatPlayer,
	combatRevived.revision,
	transition("Alive", incapacitated(combatRevived.snapshot, 30), 30)
)
local combatDead = service.commitAcceptedTransition(
	combatPlayer,
	combatDownAgain.revision,
	transition("Incapacitated", dead(combatDownAgain.snapshot), 31)
)
assert(combatDead.didCommit and not service.isCombatAllowed(combatPlayer), "Dead fire remained eligible")
local deadRestricted = service.applyCombatRestrictions(combatPlayer, combatState)
assert(deadRestricted.operativeState.combatStateId == "Dead", "dead combat state missing")
assert(deadRestricted.weaponState.reloadState == nil, "death did not clear reload")
assert(deadRestricted.selectedTargetEntityId == nil, "death retained selected target")

-- Fake character bind/replacement verifies restriction mapping and stale binding.
local function fakeCharacter(name: string)
	local character = { _className = "Model", Name = name, Parent = {} }
	local humanoid = {
		_className = "Humanoid",
		Parent = character,
		Health = 100,
		WalkSpeed = 16,
		JumpPower = 50,
		JumpHeight = 7.2,
		AutoRotate = true,
		BreakJointsOnDeath = true,
		HealthChanged = signal(),
		SetStateEnabled = function(self, state, enabled)
			self.deadState = state
			self.deadEnabled = enabled
		end,
		Move = function(self, direction)
			self.lastMove = direction
		end,
	}
	local root = {
		_className = "Part",
		Parent = character,
		AssemblyLinearVelocity = { X = 1 },
		AssemblyAngularVelocity = { X = 1 },
		IsA = function(_self, className)
			return className == "BasePart"
		end,
	}
	character.FindFirstChildOfClass = function(_self, className)
		return if className == "Humanoid" then humanoid else nil
	end
	character.FindFirstChild = function(_self, childName)
		return if childName == "HumanoidRootPart" then root else nil
	end
	return character, humanoid, root
end

local characterPlayer = fakePlayer(404)
local characterRead = service.registerPlayer(characterPlayer)
local firstCharacter, firstHumanoid = fakeCharacter("First")
characterPlayer.Character = firstCharacter
assert(service.bindCharacter(characterPlayer, firstCharacter), "Alive character bind failed")
assert(firstHumanoid.WalkSpeed == 16 and firstHumanoid.AutoRotate, "Alive restrictions changed movement")
assert(not firstHumanoid.BreakJointsOnDeath and firstHumanoid.deadEnabled == false, "Humanoid death boundary missing")
assert(service.isCharacterMovementAllowed(characterPlayer, firstCharacter), "Alive movement denied")
local characterDown = service.commitAcceptedTransition(
	characterPlayer,
	characterRead.revision,
	transition("Alive", incapacitated(characterRead.snapshot, 10), 10)
)
assert(characterDown.didCommit and firstHumanoid.WalkSpeed == 0, "incapacitated character can move")
assert(not service.isCharacterMovementAllowed(characterPlayer, firstCharacter), "incapacitated movement permitted")
local replacement, replacementHumanoid = fakeCharacter("Replacement")
characterPlayer.Character = replacement
assert(service.bindCharacter(characterPlayer, replacement), "incapacitated replacement bind failed")
assert(replacementHumanoid.WalkSpeed == 0, "replacement bypassed incapacitation")
assert(firstHumanoid.WalkSpeed == 0, "stale character was restored")
assert(not service.isCharacterMovementAllowed(characterPlayer, firstCharacter), "stale character can move operative")
local afterReplacement = service.read(characterPlayer)
assert(afterReplacement.snapshot.lifeStateId == "Incapacitated", "replacement reset life state")
assert(afterReplacement.snapshot.healthState.currentHealth == 0, "replacement reset health")
local characterAlive = service.commitAcceptedTransition(
	characterPlayer,
	afterReplacement.revision,
	transition("Incapacitated", alive(afterReplacement.snapshot, 30), 20)
)
assert(characterAlive.didCommit and replacementHumanoid.WalkSpeed == 16, "valid revive did not restore movement")
assert(service.isCharacterMovementAllowed(characterPlayer, replacement), "Alive movement did not restore")
local finalDown = service.commitAcceptedTransition(
	characterPlayer,
	characterAlive.revision,
	transition("Alive", incapacitated(characterAlive.snapshot, 30), 30)
)
local finalDead = service.commitAcceptedTransition(
	characterPlayer,
	finalDown.revision,
	transition("Incapacitated", dead(finalDown.snapshot), 31)
)
assert(finalDead.didCommit and replacementHumanoid.WalkSpeed == 0, "Dead character can move")
local deadReplacement, deadReplacementHumanoid = fakeCharacter("DeadReplacement")
characterPlayer.Character = deadReplacement
assert(service.bindCharacter(characterPlayer, deadReplacement), "Dead replacement bind failed")
assert(deadReplacementHumanoid.WalkSpeed == 0, "replacement restored Dead movement")
local deadRead = service.read(characterPlayer)
assert(deadRead.snapshot.lifeStateId == "Dead" and deadRead.snapshot.healthState.currentHealth == 0, "spawn reset Dead")

-- Source-level compatibility/authority boundaries that complement fake objects.
local movementSource = fs.readFile("games/living-kingdoms/src/server/Systems/MovementValidationSystem.luau")
assert(string.find(movementSource, "isCharacterMovementAllowed", 1, true), "movement sanity boundary lacks life gate")
local project = fs.readFile("games/living-kingdoms/default.project.json")
assert(not string.find(project, "LifeState", 1, true), "life-state RemoteEvent was added")
local developmentSource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeDevelopmentHarness.luau")
assert(string.find(developmentSource, "RunService:IsStudio()", 1, true), "development hook is not Studio-only")
assert(not string.find(developmentSource, "OnServerEvent", 1, true), "development hook accepts client events")

assert(service.unregisterPlayer(characterPlayer), "authoritative lifetime teardown failed")
assert(service.read(characterPlayer) == nil, "teardown retained snapshot")
assert(not service.unregisterPlayer(characterPlayer), "duplicate teardown was not deterministic")

print("OperativeLifeService: ownership, revisions, movement/combat restrictions, and character lifecycle passed")
