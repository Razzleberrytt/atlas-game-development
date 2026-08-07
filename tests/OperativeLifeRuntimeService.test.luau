--!strict

-- LK-0308 focused finishing, centralized deadline, solo recovery, disclosure,
-- replay, and teardown integration fixtures using the production runtime owner
-- and production pure incapacitation resolver with narrow server fakes.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local RESOLVER_TOKEN = {}
local LIFE_TOKEN = {}
local SQUAD_TOKEN = {}

local lifeStateIds = table.freeze({ Alive = "Alive", Incapacitated = "Incapacitated", Dead = "Dead" })
local contracts = {
	OperativeLifeStateIds = lifeStateIds,
	OperativeLifeTransitionRejectionReasonIds = table.freeze({
		InvalidSnapshot = "InvalidSnapshot",
		InvalidHealth = "InvalidHealth",
		InvalidDamage = "InvalidDamage",
		InvalidServerTimestamp = "InvalidServerTimestamp",
		IllegalTransition = "IllegalTransition",
		StaleTransition = "StaleTransition",
		TransitionNotReady = "TransitionNotReady",
		AlreadyResolved = "AlreadyResolved",
	}),
}
local config = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	ReviveHealth = 30,
	SoloRecoveryDurationSeconds = 8,
	SoloRecoveriesPerOperation = 1,
}
local replicatedStorage = {
	Shared = { Config = { OperativeLifeConfig = CONFIG_TOKEN }, Health = { OperativeLifeContracts = CONTRACTS_TOKEN } },
}

local resolverLoader =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeIncapacitationResolver.luau"), {
		debugName = "OperativeIncapacitationResolver",
		environment = {
			game = {
				GetService = function()
					return replicatedStorage
				end,
			},
			require = function(token)
				if token == CONFIG_TOKEN then
					return config
				end
				if token == CONTRACTS_TOKEN then
					return contracts
				end
				error("unexpected resolver dependency")
			end,
		},
		injectGlobals = true,
	})
local resolver = resolverLoader()

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

local function snapshot(entityId: string, startedAt: number, soloEligible: boolean, recoveriesUsed: number)
	return {
		operativeEntityId = entityId,
		lifeStateId = "Incapacitated",
		healthState = { currentHealth = 0, maximumHealth = 100 },
		incapacitationState = { startedAtServerTimestamp = startedAt, bleedOutDeadlineServerTimestamp = startedAt + 30 },
		soloRecoveryState = {
			isEligible = soloEligible,
			recoveriesUsed = recoveriesUsed,
			recoveryStartedAtServerTimestamp = if soloEligible then startedAt else nil,
			recoveryCompletionServerTimestamp = if soloEligible then startedAt + 8 else nil,
		},
		processedDamageEventIds = {},
	}
end

local callbacks = {}
local rosterCallbacks = {}
local entries = {}
local playersById = {}
local function player(entityId: string)
	local attributes = {}
	local value = {
		entityId = entityId,
		attributes = attributes,
		SetAttribute = function(_self, name, attributeValue)
			attributes[name] = attributeValue
		end,
	}
	playersById[entityId] = value
	return value
end
local function add(entityId: string, state)
	local owner = player(entityId)
	entries[entityId] = { revision = 0, snapshot = copy(state), player = owner }
	return owner
end

local lifeService = {}
function lifeService.readAll()
	local result = {}
	for entityId, entry in entries do
		table.insert(
			result,
			{ operativeEntityId = entityId, revision = entry.revision, snapshot = copy(entry.snapshot) }
		)
	end
	table.sort(result, function(a, b)
		return a.operativeEntityId < b.operativeEntityId
	end)
	return result
end
function lifeService.readByOperativeEntityId(entityId)
	local entry = entries[entityId]
	return if entry == nil then nil else { revision = entry.revision, snapshot = copy(entry.snapshot) }
end
function lifeService.playerForOperativeEntityId(entityId)
	return playersById[entityId]
end
function lifeService.read(owner)
	return lifeService.readByOperativeEntityId(owner.entityId)
end
function lifeService.commitAcceptedTransition(owner, expectedRevision, resolved)
	local entry = entries[owner.entityId]
	if entry == nil then
		return { didCommit = false, rejectionReason = "OperativeNotRegistered" }
	end
	if entry.revision ~= expectedRevision then
		return { didCommit = false, rejectionReason = "StaleRevision" }
	end
	if type(resolved) ~= "table" or resolved.didTransition ~= true then
		return {
			didCommit = false,
			rejectionReason = if type(resolved) == "table" then resolved.rejectionReasonId else "ResolverRejected",
		}
	end
	entry.snapshot = copy(resolved.snapshotAfter)
	entry.revision += 1
	for _, callback in callbacks do
		callback(owner, copy(entry.snapshot), entry.revision)
	end
	return { didCommit = true, revision = entry.revision, snapshot = copy(entry.snapshot) }
end
function lifeService.subscribe(callback)
	table.insert(callbacks, callback)
	local index = #callbacks
	return {
		Disconnect = function()
			callbacks[index] = nil
		end,
	}
end
function lifeService.subscribeRoster(callback)
	table.insert(rosterCallbacks, callback)
	local index = #rosterCallbacks
	return {
		Disconnect = function()
			rosterCallbacks[index] = nil
		end,
	}
end

local failureCallbacks = {}
local squadService = {}
function squadService.readParticipationFacts()
	return {
		operationStarted = true,
		operationStartedSolo = true,
		hasEverHadMultipleParticipants = false,
		lateJoiningProhibited = true,
		isAuthoritativelyAbandoned = false,
	}
end
function squadService.read()
	return { revision = 0, state = { statusId = "Viable" } }
end
function squadService.subscribe(callback)
	table.insert(failureCallbacks, callback)
	local index = #failureCallbacks
	return {
		Disconnect = function()
			failureCallbacks[index] = nil
		end,
	}
end

local now = 0
local scheduled = {}
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
local runtimeLoader =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeRuntimeService.luau"), {
		debugName = "OperativeLifeRuntimeService",
		environment = {
			game = {
				GetService = function(_self, name)
					return if name == "ReplicatedStorage" then replicatedStorage else workspace
				end,
			},
			require = function(token)
				if token == CONTRACTS_TOKEN then
					return contracts
				end
				if token == RESOLVER_TOKEN then
					return resolver
				end
				if token == LIFE_TOKEN then
					return lifeService
				end
				if token == SQUAD_TOKEN then
					return squadService
				end
				error("unexpected runtime dependency")
			end,
			script = {
				Parent = {
					OperativeIncapacitationResolver = RESOLVER_TOKEN,
					OperativeLifeService = LIFE_TOKEN,
					SquadFailureService = SQUAD_TOKEN,
				},
			},
			task = {
				delay = function(delay, callback)
					table.insert(scheduled, { delay = delay, callback = callback })
				end,
			},
		},
		injectGlobals = true,
	})
local runtime = runtimeLoader()

local bleedPlayer = add("operative.bleed", snapshot("operative.bleed", 0, false, 0))
runtime.start()
assert(bleedPlayer.attributes.LK_P3_LifeState == "Incapacitated", "life disclosure was not server-copied")
bleedPlayer.attributes.LK_P3_LifeState = "Alive"
assert(
	entries["operative.bleed"].snapshot.lifeStateId == "Incapacitated",
	"client disclosure mutation changed authority"
)
assert(#scheduled > 0 and scheduled[#scheduled].delay == 30, "central scheduler did not select stored deadline")
assert(#runtime.evaluateDeadlinesAt(29.999) == 0, "bleed-out committed before deadline")
local exactBleed = runtime.evaluateDeadlinesAt(30)
assert(#exactBleed == 1 and exactBleed[1].didCommit, "exact bleed-out deadline did not commit")
assert(entries["operative.bleed"].snapshot.lifeStateId == "Dead", "bleed-out did not produce Dead")
assert(#runtime.evaluateDeadlinesAt(30) == 0, "stale deadline committed twice")

local finishPlayer = add("operative.finish", snapshot("operative.finish", 40, false, 0))
local finishRead = lifeService.read(finishPlayer)
local finishingDamage = {
	damageEventId = "finish.1",
	sourceEntityId = "server.fixture",
	targetEntityId = "operative.finish",
	damageAmount = 1,
	serverTimestamp = 41,
}
local finish = runtime.applyAuthoritativeFinishingDamage("operative.finish", finishRead.revision, finishingDamage)
assert(finish.didCommit and finish.snapshot.lifeStateId == "Dead", "finishing route did not commit Dead")
local duplicate = runtime.applyAuthoritativeFinishingDamage("operative.finish", finish.revision, finishingDamage)
assert(not duplicate.didCommit, "duplicate finishing event was accepted")
assert(entries["operative.finish"].revision == 1, "duplicate finishing event changed revision")
local ordinarySource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local runtimeSource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeRuntimeService.luau")
assert(string.find(ordinarySource, "OperativeHealthResolver.resolveDamage", 1, true), "ordinary route missing")
assert(string.find(runtimeSource, "resolveFinishingDamage", 1, true), "finishing route missing")

local soloPlayer = add("operative.solo", snapshot("operative.solo", 100, true, 0))
assert(#runtime.evaluateDeadlinesAt(107.999) == 0, "solo recovery committed early")
local exactRecovery = runtime.evaluateDeadlinesAt(108)
assert(#exactRecovery == 1 and exactRecovery[1].didCommit, "exact eight-second recovery did not commit")
local soloAfter = entries["operative.solo"].snapshot
assert(
	soloAfter.lifeStateId == "Alive" and soloAfter.healthState.currentHealth == 30,
	"solo recovery restored wrong state"
)
assert(soloAfter.soloRecoveryState.recoveriesUsed == 1, "solo recovery use was not consumed")
entries["operative.solo"].snapshot = snapshot("operative.solo", 200, false, 1)
entries["operative.solo"].revision += 1
assert(#runtime.evaluateDeadlinesAt(208) == 0, "consumed second solo recovery was invented")
local secondBleed = runtime.evaluateDeadlinesAt(230)
assert(#secondBleed == 1 and secondBleed[1].didCommit, "consumed recovery did not fall through to bleed-out")

runtime.stop()
assert(#callbacks == 0 and #rosterCallbacks == 0 and #failureCallbacks == 0, "runtime connections leaked after stop")
assert(bleedPlayer.attributes.LK_P3_LifeState == nil, "disclosure was not cleared during teardown")
assert(not string.find(runtimeSource, "OnServerEvent", 1, true), "deadline/finishing owner gained a client route")
assert(
	string.find(runtimeSource, "SquadFailureService", 1, true),
	"life commits are not integrated with failure ownership"
)

print("OperativeLifeRuntimeService: finishing, replay, deadlines, recovery, disclosure, and teardown passed")
