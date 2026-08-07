--!strict

-- Focused LK-0307 runtime ownership, operation participation, and disconnect fixtures.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local LIFE_TOKEN = {}
local EVALUATOR_TOKEN = {}
local CONTRACTS_TOKEN = {}
local now = 100
local delayed = {}

local lifeListeners = {}
local rosterListeners = {}
local roster = {}
local eligibility = {}
local nextConnection = 0

local function connect(collection, callback)
	nextConnection += 1
	local id = nextConnection
	collection[id] = callback
	return {
		Disconnect = function()
			collection[id] = nil
		end,
	}
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function snapshot(identity: string, lifeStateId: string)
	return {
		operativeEntityId = identity,
		lifeStateId = lifeStateId,
		healthState = { currentHealth = if lifeStateId == "Alive" then 100 else 0, maximumHealth = 100 },
		incapacitationState = if lifeStateId == "Incapacitated"
			then { startedAtServerTimestamp = now, bleedOutDeadlineServerTimestamp = now + 30 }
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

local function register(identity: string)
	roster[identity] = { operativeEntityId = identity, revision = 0, snapshot = snapshot(identity, "Alive") }
	for _, callback in rosterListeners do
		callback("Registered", identity)
	end
end

local function unregister(identity: string)
	roster[identity] = nil
	for _, callback in rosterListeners do
		callback("Unregistered", identity)
	end
end

local function commitLife(identity: string, lifeStateId: string)
	local read = roster[identity]
	if read == nil then
		return
	end
	read.revision += 1
	read.snapshot = snapshot(identity, lifeStateId)
	if lifeStateId == "Incapacitated" and eligibility[identity] then
		read.snapshot.soloRecoveryState.isEligible = true
		read.snapshot.soloRecoveryState.recoveryStartedAtServerTimestamp = now
		read.snapshot.soloRecoveryState.recoveryCompletionServerTimestamp = now + 8
	end
	for _, callback in lifeListeners do
		callback(nil, deepCopy(read.snapshot), read.revision)
	end
end

local lifeService = {
	readAll = function()
		local result = {}
		for _, read in roster do
			table.insert(result, deepCopy(read))
		end
		table.sort(result, function(left, right)
			return left.operativeEntityId < right.operativeEntityId
		end)
		return result
	end,
	configureSoloOperationEligibility = function(identity, isEligible)
		if roster[identity] == nil then
			return false
		end
		eligibility[identity] = isEligible
		return true
	end,
	subscribe = function(callback)
		return connect(lifeListeners, callback)
	end,
	subscribeRoster = function(callback)
		return connect(rosterListeners, callback)
	end,
}

local statusIds = table.freeze({ Viable = "Viable", Pending = "Pending", Failed = "Failed" })
local evaluator = {}
local function copyState(state)
	return deepCopy(state)
end
function evaluator.resolve(state, facts, timestamp)
	local hasAlive = false
	local hasSolo = false
	for _, operative in facts.operativeSnapshots do
		hasAlive = hasAlive or operative.lifeStateId == "Alive"
		local recovery = operative.soloRecoveryState
		hasSolo = hasSolo
			or (
				#facts.operativeSnapshots == 1
				and operative.lifeStateId == "Incapacitated"
				and facts.operationStartedSolo
				and not facts.hasEverHadMultipleParticipants
				and recovery.isEligible
				and recovery.recoveriesUsed < 1
				and recovery.recoveryCompletionServerTimestamp ~= nil
				and timestamp <= recovery.recoveryCompletionServerTimestamp
			)
	end
	local viable = not facts.isAuthoritativelyAbandoned and (hasAlive or hasSolo)
	local after = copyState(state)
	if state.statusId == "Failed" then
	elseif viable then
		after = {
			statusId = "Viable",
			pendingStartedAtServerTimestamp = nil,
			pendingDeadlineServerTimestamp = nil,
			failedAtServerTimestamp = nil,
		}
	elseif state.statusId == "Viable" then
		after = {
			statusId = "Pending",
			pendingStartedAtServerTimestamp = timestamp,
			pendingDeadlineServerTimestamp = timestamp + 3,
			failedAtServerTimestamp = nil,
		}
	elseif timestamp >= state.pendingDeadlineServerTimestamp then
		after = {
			statusId = "Failed",
			pendingStartedAtServerTimestamp = nil,
			pendingDeadlineServerTimestamp = nil,
			failedAtServerTimestamp = timestamp,
		}
	end
	return { didResolve = true, stateAfter = after }
end

local replicatedStorage = { Shared = { Health = { OperativeLifeContracts = CONTRACTS_TOKEN } } }
local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/SquadFailureService.luau"), {
	debugName = "SquadFailureService",
	environment = {
		game = {
			GetService = function(_self, name)
				if name == "ReplicatedStorage" then
					return replicatedStorage
				end
				if name == "Workspace" then
					return {
						GetServerTimeNow = function()
							return now
						end,
					}
				end
				error("unexpected service")
			end,
		},
		require = function(token)
			if token == LIFE_TOKEN then
				return lifeService
			end
			if token == EVALUATOR_TOKEN then
				return evaluator
			end
			if token == CONTRACTS_TOKEN then
				return { SquadFailureStatusIds = statusIds }
			end
			error("unexpected module")
		end,
		script = { Parent = { OperativeLifeService = LIFE_TOKEN, SquadFailureEvaluator = EVALUATOR_TOKEN } },
		task = {
			delay = function(seconds, callback)
				table.insert(delayed, { at = now + seconds, callback = callback })
			end,
		},
	},
	injectGlobals = true,
})
local service = loader()

local function runDue()
	local pending = delayed
	delayed = {}
	for _, timer in pending do
		if timer.at <= now then
			timer.callback()
		else
			table.insert(delayed, timer)
		end
	end
end

-- Registration is observed, operation start freezes two-player participation,
-- and copied reads cannot mutate authority.
service.start()
register("operative.a")
register("operative.b")
local began = service.beginOperation()
assert(began.state.statusId == "Viable", "two Alive did not begin Viable")
local participation = service.readParticipationFacts()
assert(participation.operationStarted and participation.hasEverHadMultipleParticipants, "multiplayer facts missing")
assert(participation.lateJoiningProhibited, "late joining was not prohibited")
local readCopy = service.read()
readCopy.state.statusId = "Failed"
assert(service.read().state.statusId == "Viable", "caller mutated authoritative state")

-- Life commits drive evaluation: one Alive preserves viability; all down starts
-- Pending, cancellation clears time, and a fresh loss gets a full grace.
now = 110
commitLife("operative.a", "Incapacitated")
assert(service.read().state.statusId == "Viable", "one Alive did not preserve viability")
local notifications = 0
local subscription = service.subscribe(function()
	notifications += 1
end)
commitLife("operative.b", "Incapacitated")
local pending = service.read()
assert(
	pending.state.statusId == "Pending" and pending.state.pendingDeadlineServerTimestamp == 113,
	"all down did not start grace"
)
assert(notifications == 1, "Pending status notification was not singular")
local duplicate = service.evaluate(pending.revision)
assert(not duplicate.didCommit and notifications == 1, "duplicate evaluation committed or notified")
assert(service.evaluate(pending.revision - 1).rejectionReason == "StaleRevision", "stale runtime revision was accepted")

now = 112.999
commitLife("operative.a", "Alive")
local cancelled = service.read()
assert(
	cancelled.state.statusId == "Viable" and cancelled.state.pendingDeadlineServerTimestamp == nil,
	"Alive did not cancel and clear grace"
)
now = 120
commitLife("operative.a", "Incapacitated")
local fresh = service.read()
assert(
	fresh.state.pendingStartedAtServerTimestamp == 120 and fresh.state.pendingDeadlineServerTimestamp == 123,
	"fresh grace reused prior progress"
)
now = 123
runDue()
assert(service.read().state.statusId == "Failed", "deadline timer did not commit Failed")
local failedRevision = service.read().revision
commitLife("operative.a", "Alive")
assert(
	service.read().state.statusId == "Failed" and service.read().revision == failedRevision,
	"Alive undid or recommitted Failed"
)

-- A late registration is ignored for viability and cannot undo committed failure.
register("operative.late")
assert(service.read().state.statusId == "Failed", "late join undid Failed")
assert(not eligibility["operative.late"], "late join was admitted to solo participation")

subscription:Disconnect()
service.stop()
assert(next(lifeListeners) == nil and next(rosterListeners) == nil, "teardown left runtime connections")
assert(service.read().state.statusId == "Viable" and service.read().revision == 0, "teardown retained failure lifetime")

-- Removing one participant while another remains Alive stays viable; removing
-- the final viable participant begins abandonment grace.
table.clear(roster)
table.clear(eligibility)
delayed = {}
now = 180
service.start()
register("operative.disconnect-a")
register("operative.disconnect-b")
service.beginOperation()
unregister("operative.disconnect-a")
assert(service.read().state.statusId == "Viable", "one remaining Alive did not preserve viability")
unregister("operative.disconnect-b")
assert(service.read().state.statusId == "Pending", "final viable disconnect did not start Pending")
service.stop()

-- A solo operation receives the one pending recovery path. Disconnect removes
-- the snapshot, marks abandonment, and duplicate removal is deterministic.
table.clear(roster)
table.clear(eligibility)
delayed = {}
now = 200
service.start()
register("operative.solo")
service.beginOperation()
assert(eligibility["operative.solo"], "solo eligibility was not configured authoritatively")
commitLife("operative.solo", "Incapacitated")
assert(service.read().state.statusId == "Viable", "valid solo recovery did not preserve viability")
unregister("operative.solo")
assert(service.read().state.statusId == "Pending", "final disconnect did not start Pending")
unregister("operative.solo")
local afterDuplicate = service.read()
assert(afterDuplicate.state.statusId == "Pending", "duplicate disconnect changed status")
now = afterDuplicate.state.pendingDeadlineServerTimestamp
runDue()
assert(service.read().state.statusId == "Failed", "zero-connected abandonment did not fail")
assert(service.readParticipationFacts().isAuthoritativelyAbandoned, "zero-connected abandonment fact missing")
service.stop()

local project = fs.readFile("games/living-kingdoms/default.project.json")
assert(not string.find(project, "SquadFailure", 1, true), "client-accessible squad failure remote was added")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
assert(string.find(bootstrap, "SquadFailureService.start()", 1, true), "runtime owner is not bootstrapped")

print("SquadFailureService: authoritative snapshots, events, grace, disconnect, late join, copies, and teardown passed")
