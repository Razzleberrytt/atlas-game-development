--!strict

-- Focused LK-0306 authoritative ordinary-damage routing fixtures. The service
-- and pure LK-0302 resolver run together; Roblox instances are represented by
-- narrow server-side fakes and no client or RemoteEvent participates.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local COMBAT_TOKEN = {}
local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local HEALTH_RESOLVER_TOKEN = {}
local HEALING_RESOLVER_TOKEN = {}

local lifeStateIds = table.freeze({ Alive = "Alive", Incapacitated = "Incapacitated", Dead = "Dead" })
local reasons = table.freeze({
	InvalidSnapshot = "InvalidSnapshot",
	InvalidHealth = "InvalidHealth",
	InvalidDamage = "InvalidDamage",
	InvalidServerTimestamp = "InvalidServerTimestamp",
	IllegalTransition = "IllegalTransition",
	StaleTransition = "StaleTransition",
	TransitionNotReady = "TransitionNotReady",
	AlreadyResolved = "AlreadyResolved",
})
local contracts = {
	OperativeLifeStateIds = lifeStateIds,
	OperativeLifeTransitionRejectionReasonIds = reasons,
}
local config = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	SoloRecoveriesPerOperation = 1,
}
local combatContracts = {
	OperativeCombatStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Incapacitated = "Incapacitated",
		Dead = "Dead",
	}),
	WeaponReadinessStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Disabled = "Disabled",
	}),
}

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

local function baseRequire(token)
	if token == COMBAT_TOKEN then
		return combatContracts
	end
	if token == CONFIG_TOKEN then
		return config
	end
	if token == CONTRACTS_TOKEN then
		return contracts
	end
	error("unexpected module")
end

local resolverLoader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeHealthResolver.luau"), {
	debugName = "OperativeHealthResolver",
	environment = {
		game = {
			GetService = function()
				return replicatedStorage
			end,
		},
		require = baseRequire,
	},
	injectGlobals = true,
})
local realResolver = resolverLoader()
local resolverImplementation = realResolver.resolveDamage
local resolverProxy = {
	resolveDamage = function(...)
		return resolverImplementation(...)
	end,
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

local serviceLoader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau"), {
	debugName = "OperativeLifeService",
	environment = {
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
			if token == HEALTH_RESOLVER_TOKEN then
				return resolverProxy
			end
			if token == HEALING_RESOLVER_TOKEN then
				return {
					resolve = function()
						error("healing routing is covered by HROI-0106 fixtures")
					end,
				}
			end
			return baseRequire(token)
		end,
		script = {
			Parent = {
				OperativeHealingResolver = HEALING_RESOLVER_TOKEN,
				OperativeHealthResolver = HEALTH_RESOLVER_TOKEN,
			},
		},
		typeof = function(value)
			return if type(value) == "table" and value._className ~= nil then "Instance" else type(value)
		end,
		Vector3 = { zero = { X = 0, Y = 0, Z = 0 } },
		Enum = { HumanoidStateType = { Dead = "Dead" } },
	},
	injectGlobals = true,
})
local service = serviceLoader()

local function damage(read, eventId: string, amount: number, timestamp: number)
	return {
		damageEventId = eventId,
		sourceEntityId = "hostile.fixture",
		targetEntityId = read.snapshot.operativeEntityId,
		damageAmount = amount,
		serverTimestamp = timestamp,
	}
end

local function apply(read, eventId: string, amount: number, timestamp: number)
	return service.applyAuthoritativeDamage(
		read.snapshot.operativeEntityId,
		read.revision,
		damage(read, eventId, amount, timestamp)
	)
end

local nonlethalPlayer = fakePlayer(601)
local nonlethalRead = service.registerPlayer(nonlethalPlayer)
local nonlethal = apply(nonlethalRead, "damage.nonlethal", 10, 10)
assert(nonlethal.didCommit and nonlethal.revision == 1, "nonlethal runtime damage did not commit")
assert(nonlethal.snapshot.healthState.currentHealth == 90, "nonlethal health was not 90")
assert(nonlethal.snapshot.lifeStateId == "Alive", "nonlethal damage changed life state")
assert(service.isCombatAllowed(nonlethalPlayer), "nonlethal damage disabled combat")
assert(nonlethal.snapshot.processedDamageEventIds["damage.nonlethal"], "accepted event was not preserved")

-- Successful results are authoritative copies, and a later event preserves the
-- existing processed-event set owned by the snapshot.
nonlethal.snapshot.healthState.currentHealth = 1
nonlethal.snapshot.processedDamageEventIds.injected = true
local afterCopyMutation = service.read(nonlethalPlayer)
assert(afterCopyMutation.snapshot.healthState.currentHealth == 90, "returned snapshot aliases service state")
assert(afterCopyMutation.snapshot.processedDamageEventIds.injected == nil, "returned event set aliases service state")
local second = apply(afterCopyMutation, "damage.second", 10, 11)
assert(second.didCommit and second.snapshot.healthState.currentHealth == 80, "second damage did not commit")
assert(second.snapshot.processedDamageEventIds["damage.nonlethal"], "prior processed event was discarded")
assert(second.snapshot.processedDamageEventIds["damage.second"], "new processed event was not committed")

local lethalPlayer = fakePlayer(602)
local lethalRead = service.registerPlayer(lethalPlayer)
local lethal = apply(lethalRead, "damage.lethal", 100, 20)
assert(lethal.didCommit and lethal.snapshot.lifeStateId == "Incapacitated", "lethal damage did not incapacitate")
assert(lethal.snapshot.healthState.currentHealth == 0, "lethal damage did not clamp to zero")
assert(not service.isCombatAllowed(lethalPlayer), "lethal damage left combat enabled")

local overkillPlayer = fakePlayer(603)
local overkillRead = service.registerPlayer(overkillPlayer)
local overkill = apply(overkillRead, "damage.overkill", 999, 30)
assert(overkill.didCommit and overkill.snapshot.lifeStateId == "Incapacitated", "overkill did not incapacitate")
assert(overkill.snapshot.healthState.currentHealth == 0, "overkill health was not exactly zero")
assert(overkill.snapshot.lifeStateId ~= "Dead", "ordinary overkill produced Dead")

local duplicateBefore = service.read(nonlethalPlayer)
local duplicate = service.applyAuthoritativeDamage(
	duplicateBefore.snapshot.operativeEntityId,
	duplicateBefore.revision,
	damage(duplicateBefore, "damage.second", 10, 12)
)
assert(not duplicate.didCommit and duplicate.rejectionReason == "AlreadyResolved", "duplicate event was not rejected")
assert(service.read(nonlethalPlayer).revision == duplicateBefore.revision, "duplicate event mutated revision")
assert(service.read(nonlethalPlayer).snapshot.healthState.currentHealth == 80, "duplicate event applied twice")

local malformedBefore = service.read(nonlethalPlayer)
local malformed = service.applyAuthoritativeDamage(
	malformedBefore.snapshot.operativeEntityId,
	malformedBefore.revision,
	{ damageEventId = "", targetEntityId = malformedBefore.snapshot.operativeEntityId, damageAmount = 10 } :: any
)
assert(not malformed.didCommit and malformed.rejectionReason == "InvalidDamage", "malformed damage was not rejected")
assert(service.read(nonlethalPlayer).revision == malformedBefore.revision, "malformed damage mutated state")

local unknown = service.applyAuthoritativeDamage("", 0, {} :: any)
assert(not unknown.didCommit and unknown.rejectionReason == "UnknownOperative", "unknown operative was not rejected")
local notRegistered = service.applyAuthoritativeDamage("operative.player:999999", 0, {} :: any)
assert(
	not notRegistered.didCommit and notRegistered.rejectionReason == "OperativeNotRegistered",
	"unregistered operative was not rejected"
)

local staleBefore = service.read(nonlethalPlayer)
local stale = service.applyAuthoritativeDamage(
	staleBefore.snapshot.operativeEntityId,
	staleBefore.revision - 1,
	damage(staleBefore, "damage.stale", 10, 13)
)
assert(not stale.didCommit and stale.rejectionReason == "StaleRevision", "revision mismatch was not rejected")
assert(service.read(nonlethalPlayer).revision == staleBefore.revision, "stale revision mutated state")

local resolverRejectedBefore = service.read(nonlethalPlayer)
resolverImplementation = function(snapshot)
	return {
		didTransition = false,
		rejectionReasonId = "InvalidSnapshot",
		snapshotAfter = snapshot,
	}
end
local resolverRejected = service.applyAuthoritativeDamage(
	resolverRejectedBefore.snapshot.operativeEntityId,
	resolverRejectedBefore.revision,
	damage(resolverRejectedBefore, "damage.resolver-rejected", 10, 14)
)
assert(not resolverRejected.didCommit, "rejected resolver result committed")
assert(service.read(nonlethalPlayer).revision == resolverRejectedBefore.revision, "resolver rejection mutated state")

-- An accepted but invalid resolver output reaches the existing commit validator
-- and proves commit rejection is also atomic.
resolverImplementation = function(snapshot, authoritativeDamage)
	local invalid = table.clone(snapshot)
	invalid.healthState = { currentHealth = 200, maximumHealth = 100 }
	invalid.processedDamageEventIds = table.clone(snapshot.processedDamageEventIds)
	invalid.processedDamageEventIds[authoritativeDamage.damageEventId] = true
	return {
		didTransition = true,
		lifeStateIdBefore = "Alive",
		lifeStateIdAfter = "Alive",
		transitionServerTimestamp = authoritativeDamage.serverTimestamp,
		damageEventId = authoritativeDamage.damageEventId,
		snapshotAfter = invalid,
	}
end
local commitRejected = service.applyAuthoritativeDamage(
	resolverRejectedBefore.snapshot.operativeEntityId,
	resolverRejectedBefore.revision,
	damage(resolverRejectedBefore, "damage.commit-rejected", 10, 15)
)
assert(
	not commitRejected.didCommit and commitRejected.rejectionReason == "InvalidSnapshot",
	"invalid commit was accepted"
)
assert(service.read(nonlethalPlayer).revision == resolverRejectedBefore.revision, "commit rejection mutated state")
resolverImplementation = realResolver.resolveDamage

local function fakeCharacter()
	local character = { _className = "Model", Parent = {} }
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
		SetStateEnabled = function() end,
		Move = function() end,
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
	character.FindFirstChildOfClass = function()
		return humanoid
	end
	character.FindFirstChild = function()
		return root
	end
	return character, humanoid
end

local restrictedPlayer = fakePlayer(604)
local restrictedRead = service.registerPlayer(restrictedPlayer)
local character, humanoid = fakeCharacter()
restrictedPlayer.Character = character
assert(service.bindCharacter(restrictedPlayer, character), "character setup failed")
local restrictedDamage = apply(restrictedRead, "damage.restrict", 100, 40)
assert(restrictedDamage.didCommit and humanoid.WalkSpeed == 0, "movement restriction did not update")
assert(humanoid.JumpPower == 0 and humanoid.JumpHeight == 0, "jump restriction did not update")
assert(not service.isCharacterMovementAllowed(restrictedPlayer, character), "incapacitated movement remained allowed")
local combat = service.applyCombatRestrictions(restrictedPlayer, {
	operativeState = { combatStateId = "Reloading" },
	weaponState = { readinessStateId = "Reloading", reloadState = { completionServerTimestamp = 50 } },
	selectedTargetEntityId = "hostile.fixture",
	selectedTargetState = { targetEntityId = "hostile.fixture" },
})
assert(combat.operativeState.combatStateId == "Incapacitated", "combat restriction did not update")
assert(combat.weaponState.readinessStateId == "Disabled", "weapon restriction did not update")
assert(combat.weaponState.reloadState == nil, "reload was not disabled")
assert(combat.selectedTargetEntityId == nil and combat.selectedTargetState == nil, "target was not cleared")

local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
assert(string.find(serviceSource, "OperativeHealthResolver.resolveDamage", 1, true), "runtime does not call LK-0302")
local project = fs.readFile("games/living-kingdoms/default.project.json")
assert(not string.find(project, "DamageIntent", 1, true), "client damage remote was added")

print("OperativeLifeDamageRouting: authoritative commits, replay, copies, revisions, and restrictions passed")
