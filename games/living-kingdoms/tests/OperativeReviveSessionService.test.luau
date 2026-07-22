--!strict

-- LK-0308 focused runtime revive ownership, strict remote, interruption,
-- completion-companion, rate-limit, identity, and teardown fixtures.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local COMBAT_TOKEN = {}
local LIFE_TOKEN = {}
local RESOLVER_TOKEN = {}
local SQUAD_TOKEN = {}
local CLASS_TOKEN = {}
-- Guardian Signal is not equipped in these fixtures, so the revive flow must
-- behave exactly as it did before RPG-0109.
local RELIC_MODIFIER_TOKEN = {}
local relicModifierService = {
	read = function()
		return { temporaryArmorFractionOfMaximumHealth = 0, temporaryArmorDurationSeconds = 0 }
	end,
}
local classService = {
	readMedicReviveBenefits = function()
		return 4, 30, false
	end,
	recordMedicReviveStarted = function() end,
	recordMedicReviveEnded = function() end,
}

local contracts = {
	ReviveSessionStatusIds = table.freeze({ Active = "Active", Cancelled = "Cancelled", Completed = "Completed" }),
}

local function signal()
	local callbacks = {}
	return {
		Connect = function(_self, callback)
			table.insert(callbacks, callback)
			local index = #callbacks
			return {
				Disconnect = function()
					callbacks[index] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
		Count = function()
			local count = 0
			for _ in callbacks do
				count += 1
			end
			return count
		end,
	}
end

local vectorMetatable = {}
function vectorMetatable.__sub(left, right)
	local x, y, z = left.X - right.X, left.Y - right.Y, left.Z - right.Z
	return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }, vectorMetatable)
end
local function vector(x: number, y: number?, z: number?)
	return setmetatable(
		{ X = x, Y = y or 0, Z = z or 0, Magnitude = math.sqrt(x * x + (y or 0) ^ 2 + (z or 0) ^ 2) },
		vectorMetatable
	)
end

local playerRemoving = signal()
local players = {
	PlayerRemoving = playerRemoving,
	GetPlayers = function()
		return {}
	end,
}
local heartbeat = signal()
local runService = {
	Heartbeat = heartbeat,
	IsStudio = function()
		return false
	end,
}
local now = 0
local workspace = {
	blocked = false,
	GetServerTimeNow = function()
		return now
	end,
	Raycast = function(self)
		return if self.blocked then {} else nil
	end,
}
local remoteEvent = {
	OnServerEvent = signal(),
	IsA = function(_self, name)
		return name == "RemoteEvent"
	end,
}
local lifeNetwork = {
	FindFirstChild = function(_self, name)
		return if name == "ReviveIntent" then remoteEvent else nil
	end,
	WaitForChild = function(_self, name)
		assert(name == "ReviveIntent")
		return remoteEvent
	end,
}
local replicatedStorage = {
	Shared = { Health = { OperativeLifeContracts = CONTRACTS_TOKEN } },
	FindFirstChild = function(_self, name)
		return if name == "OperativeLifeNetwork" then lifeNetwork else nil
	end,
	WaitForChild = function(_self, name)
		assert(name == "OperativeLifeNetwork")
		return lifeNetwork
	end,
}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end
local function lifeSnapshot(id: string, state: string)
	return {
		operativeEntityId = id,
		lifeStateId = state,
		healthState = { currentHealth = if state == "Alive" then 100 else 0, maximumHealth = 100 },
		incapacitationState = if state == "Incapacitated"
			then { startedAtServerTimestamp = 0, bleedOutDeadlineServerTimestamp = 30 }
			else nil,
		soloRecoveryState = {
			isEligible = false,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = nil,
			recoveryCompletionServerTimestamp = nil,
		},
		processedDamageEventIds = {},
	}
end
local function fakePlayer(id: string, position)
	local attributes = {}
	local root = {
		Position = position,
		IsA = function(_self, name)
			return name == "BasePart"
		end,
	}
	local character = {
		Parent = {},
		FindFirstChild = function(_self, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
	}
	local value = {
		id = id,
		Parent = players,
		Character = character,
		root = root,
		attributes = attributes,
		SetAttribute = function(_self, name, attributeValue)
			attributes[name] = attributeValue
		end,
	}
	return value
end

local p1 = fakePlayer("operative.1", vector(0))
local p2 = fakePlayer("operative.2", vector(4))
local p3 = fakePlayer("operative.3", vector(1))
local playerById = { [p1.id] = p1, [p2.id] = p2, [p3.id] = p3 }
local entries = {
	[p1] = { revision = 0, snapshot = lifeSnapshot(p1.id, "Alive") },
	[p2] = { revision = 0, snapshot = lifeSnapshot(p2.id, "Incapacitated") },
	[p3] = { revision = 0, snapshot = lifeSnapshot(p3.id, "Alive") },
}
local lifeChanged = signal()
local lifeService = {}
function lifeService.read(player)
	local entry = entries[player]
	return if entry == nil then nil else { revision = entry.revision, snapshot = copy(entry.snapshot) }
end
function lifeService.readByOperativeEntityId(id)
	return lifeService.read(playerById[id])
end
function lifeService.playerForOperativeEntityId(id)
	return playerById[id]
end
function lifeService.subscribe(callback)
	return lifeChanged:Connect(callback)
end
function lifeService.commitAcceptedTransition(player, expectedRevision, resolved)
	local entry = entries[player]
	if entry.revision ~= expectedRevision then
		return { didCommit = false }
	end
	entry.revision += 1
	entry.snapshot = copy(resolved.targetSnapshotAfter)
	lifeChanged:Fire(player, copy(entry.snapshot), entry.revision)
	return { didCommit = true, revision = entry.revision, snapshot = copy(entry.snapshot) }
end

local admitted = { [p1.id] = true, [p2.id] = true, [p3.id] = true }
local squadService = {
	isOperativeAdmitted = function(id)
		return admitted[id] == true
	end,
}
local combatStates = {
	[p2] = {
		generation = 7,
		combatState = {
			weaponState = {
				readinessStateId = "Reloading",
				ammunition = { loadedRounds = 2, reserveRounds = 9 },
				cadence = { nextAllowedFireServerTimestamp = 12 },
				reloadState = { completionServerTimestamp = 20 },
			},
			processedShotIds = { ["shot.kept"] = true },
			selectedTargetState = { targetEntityId = "hostile.old" },
		},
	},
}
local combat = {}
function combat.readReviveCombatState(player)
	return copy(combatStates[player])
end
function combat.commitReviveCombatState(player, generation, state)
	local current = combatStates[player]
	if current == nil or current.generation ~= generation then
		return false
	end
	current.combatState = copy(state)
	return true
end

local resolver = {}
function resolver.beginRevive(reviver, target, facts)
	if reviver.lifeStateId ~= "Alive" then
		return { didTransition = false, rejectionReasonId = "ReviverNotAlive" }
	end
	if target.lifeStateId ~= "Incapacitated" then
		return { didTransition = false, rejectionReasonId = "TargetNotIncapacitated" }
	end
	if facts.distanceStuds > 8 then
		return { didTransition = false, rejectionReasonId = "OutOfRange" }
	end
	if not facts.hasLineOfSight then
		return { didTransition = false, rejectionReasonId = "NoLineOfSight" }
	end
	return {
		didTransition = true,
		normalizedProgress = 0,
		sessionStateAfter = {
			sessionId = facts.sessionId,
			reviverOperativeEntityId = facts.reviverOperativeEntityId,
			targetOperativeEntityId = facts.targetOperativeEntityId,
			statusId = "Active",
			startedAtServerTimestamp = facts.serverTimestamp,
			completionServerTimestamp = facts.serverTimestamp + 4,
		},
	}
end
function resolver.continueRevive(reviver, target, session, facts, combatState)
	local interrupted = reviver.lifeStateId ~= "Alive"
		or target.lifeStateId ~= "Incapacitated"
		or not facts.reviverRemainsConnectedAndParticipating
		or not facts.reviverMovementRemainedValid
		or not facts.reviverReceivedNoInterruptingDamage
		or not facts.holdRemainsActive
		or facts.distanceStuds > 8
		or not facts.hasLineOfSight
	if interrupted then
		local cancelled = copy(session)
		cancelled.statusId = "Cancelled"
		return { didTransition = true, normalizedProgress = 0, sessionStateAfter = cancelled }
	end
	if facts.serverTimestamp < session.completionServerTimestamp then
		return {
			didTransition = false,
			normalizedProgress = math.clamp((facts.serverTimestamp - session.startedAtServerTimestamp) / 4, 0, 1),
			sessionStateAfter = copy(session),
		}
	end
	local completed = copy(session)
	completed.statusId = "Completed"
	completed.completionServerTimestamp = facts.serverTimestamp
	local targetAfter = copy(target)
	targetAfter.lifeStateId = "Alive"
	targetAfter.healthState.currentHealth = 30
	targetAfter.incapacitationState = nil
	local combatAfter = copy(combatState)
	combatAfter.weaponState.reloadState = nil
	combatAfter.weaponState.readinessStateId = "Ready"
	combatAfter.selectedTargetState = nil
	return {
		didTransition = true,
		normalizedProgress = 1,
		sessionStateAfter = completed,
		targetSnapshotAfter = targetAfter,
		combatStateAfter = combatAfter,
	}
end

local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau"), {
	debugName = "OperativeReviveSessionService",
	environment = {
		game = {
			GetService = function(_self, name)
				if name == "Players" then
					return players
				end
				if name == "ReplicatedStorage" then
					return replicatedStorage
				end
				if name == "RunService" then
					return runService
				end
				return workspace
			end,
		},
		require = function(token)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			if token == COMBAT_TOKEN then
				return combat
			end
			if token == LIFE_TOKEN then
				return lifeService
			end
			if token == RESOLVER_TOKEN then
				return resolver
			end
			if token == SQUAD_TOKEN then
				return squadService
			end
			if token == RELIC_MODIFIER_TOKEN then
				return relicModifierService
			end
			if token == CLASS_TOKEN then
				return classService
			end
			error("unexpected dependency")
		end,
		script = {
			Parent = {
				ClassService = CLASS_TOKEN,
				OperativeCombatRuntimeService = COMBAT_TOKEN,
				OperativeLifeService = LIFE_TOKEN,
				OperativeReviveResolver = RESOLVER_TOKEN,
				RelicModifierService = RELIC_MODIFIER_TOKEN,
				SquadFailureService = SQUAD_TOKEN,
			},
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = { RaycastFilterType = { Exclude = "Exclude" } },
	},
	injectGlobals = true,
})
local service = loader()
service.start()

local function intent(player, targetId: string, phase: string)
	now += 0.1
	return service.handleReviveIntent(player, { targetOperativeEntityId = targetId, phase = phase })
end
local function resetTarget()
	entries[p1].snapshot = lifeSnapshot(p1.id, "Alive")
	entries[p2].snapshot = lifeSnapshot(p2.id, "Incapacitated")
	entries[p3].snapshot = lifeSnapshot(p3.id, "Alive")
	p1.Parent, p2.Parent, p3.Parent = players, players, players
	p1.root.Position, p2.root.Position, p3.root.Position = vector(0), vector(4), vector(1)
	workspace.blocked = false
	admitted[p1.id], admitted[p2.id], admitted[p3.id] = true, true, true
end

assert(not service.handleReviveIntent(p1, nil).accepted, "missing payload accepted")
assert(not service.handleReviveIntent(p1, { targetOperativeEntityId = p2.id }).accepted, "missing phase accepted")
assert(
	not service.handleReviveIntent(p1, { targetOperativeEntityId = p2.id, phase = "Begin", progress = 1 }).accepted,
	"extra field accepted"
)
assert(
	not service.handleReviveIntent(p1, { targetOperativeEntityId = 2, phase = "Begin" }).accepted,
	"wrong target type accepted"
)
assert(
	not service.handleReviveIntent(p1, { targetOperativeEntityId = p2.id, phase = "Begin" }, "extra").accepted,
	"extra argument accepted"
)
assert(not intent(p1, p1.id, "Begin").accepted, "self-target accepted")
assert(not intent(p1, "operative.hidden", "Begin").accepted, "hidden target accepted")
admitted[p2.id] = false
assert(not intent(p1, p2.id, "Begin").accepted, "cross-operation target accepted")
admitted[p2.id] = true

local began = intent(p1, p2.id, "Begin")
assert(began.accepted, "valid begin rejected")
local owned = service.readActiveSessionForTarget(p2.id)
assert(owned ~= nil and owned.reviverOperativeEntityId == p1.id, "sender identity was not derived")
assert(
	not service.handleReviveIntent(p1, { targetOperativeEntityId = p2.id, phase = "Begin" }).accepted,
	"duplicate request bypassed rate limit"
)
local sessionId = owned.sessionId
assert(not intent(p1, p2.id, "Begin").accepted, "duplicate begin accelerated session")
assert(service.readActiveSessionForTarget(p2.id).sessionId == sessionId, "duplicate begin replaced ownership")
assert(not intent(p3, p2.id, "Begin").accepted, "second reviver replaced target owner")
assert(
	intent(p1, p2.id, "End").accepted and service.readActiveSessionForTarget(p2.id) == nil,
	"hold release did not cancel/reset"
)

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "retry did not begin at zero")
assert(p1.attributes.LK_P3_ReviveProgress == 0, "retry retained progress")
p1.root.Position = vector(0.3)
heartbeat:Fire(0.05)
assert(service.readActiveSessionForTarget(p2.id) == nil, "movement interruption did not cancel")

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "damage case did not begin")
entries[p1].snapshot.processedDamageEventIds["damage.accepted"] = true
lifeChanged:Fire(p1, copy(entries[p1].snapshot), entries[p1].revision)
assert(service.readActiveSessionForTarget(p2.id) == nil, "accepted reviver damage did not cancel")

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "line-of-sight case did not begin")
workspace.blocked = true
heartbeat:Fire(0.05)
assert(service.readActiveSessionForTarget(p2.id) == nil, "line-of-sight loss did not cancel")

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "range case did not begin")
p2.root.Position = vector(9)
heartbeat:Fire(0.05)
assert(service.readActiveSessionForTarget(p2.id) == nil, "out-of-range target movement did not cancel")

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "reviver-state case did not begin")
entries[p1].snapshot = lifeSnapshot(p1.id, "Incapacitated")
lifeChanged:Fire(p1, copy(entries[p1].snapshot), entries[p1].revision)
assert(service.readActiveSessionForTarget(p2.id) == nil, "incapacitated reviver did not cancel")

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "target-state case did not begin")
entries[p2].snapshot = lifeSnapshot(p2.id, "Dead")
lifeChanged:Fire(p2, copy(entries[p2].snapshot), entries[p2].revision)
assert(service.readActiveSessionForTarget(p2.id) == nil, "dead target did not cancel")

resetTarget()
assert(intent(p1, p2.id, "Begin").accepted, "disconnect case did not begin")
p1.Parent = nil
playerRemoving:Fire(p1)
assert(service.readActiveSessionForTarget(p2.id) == nil, "reviver disconnect did not cancel")

resetTarget()
local completionStart = now + 0.1
assert(intent(p1, p2.id, "Begin").accepted, "completion case did not begin")
now = completionStart + 3.999
heartbeat:Fire(0.05)
assert(entries[p2].snapshot.lifeStateId == "Incapacitated", "revive completed before four seconds")
now = completionStart + 4
heartbeat:Fire(0.05)
assert(
	entries[p2].snapshot.lifeStateId == "Alive" and entries[p2].snapshot.healthState.currentHealth == 30,
	"exact completion failed"
)
local completedCombat = combatStates[p2].combatState
assert(
	completedCombat.weaponState.ammunition.loadedRounds == 2
		and completedCombat.weaponState.ammunition.reserveRounds == 9,
	"revive refilled ammunition"
)
assert(completedCombat.weaponState.cadence.nextAllowedFireServerTimestamp == 12, "revive changed cadence")
assert(completedCombat.processedShotIds["shot.kept"], "revive discarded processed ShotIds")
assert(
	completedCombat.weaponState.reloadState == nil and completedCombat.selectedTargetState == nil,
	"revive retained reload/target"
)
assert(entries[p2].snapshot.invulnerable == nil, "revive granted invulnerability")

local source = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")
local clientSource = fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeLifeController.luau")
assert(string.find(source, "REQUEST_COOLDOWN_SECONDS", 1, true), "remote is not rate limited")
assert(string.find(source, 'select("#", ...)', 1, true), "extra remote arguments are not rejected")
assert(string.find(source, "player: Player", 1, true), "sender identity is not used")
assert(string.find(source, "distanceAndLineOfSight", 1, true), "server does not derive spatial facts")
assert(
	string.find(clientSource, 'phase = "Begin"', 1, true) and string.find(clientSource, 'phase = "End"', 1, true),
	"client hold lifecycle missing"
)
assert(not string.find(clientSource, "completionServerTimestamp =", 1, true), "client submits completion timing")
assert(not string.find(clientSource, "normalizedProgress", 1, true), "client submits progress")

service.stop()
assert(
	remoteEvent.OnServerEvent:Count() == 0
		and heartbeat:Count() == 0
		and playerRemoving:Count() == 0
		and lifeChanged:Count() == 0,
	"runtime connections leaked"
)
assert(service.readActiveSessionForTarget(p2.id) == nil, "teardown retained target ownership")

print(
	"OperativeReviveSessionService: strict intent, ownership, interruptions, completion, security, and teardown passed"
)
