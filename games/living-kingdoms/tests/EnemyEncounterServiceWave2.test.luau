--!strict

-- Wave 2 encounter runtime: simultaneous sessions, deferred spawns, completion
-- exactly once, invalid/zero-accepted handling, cancellation, and cleanup.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local CONTRACTS_TOKEN = {}
local COMPOSER_TOKEN = {}
local DIRECTOR_TOKEN = {}
local BRIDGE_TOKEN = {}

local facts = {}
local rejectAll = false
local deferEntityIds = {}
local submittedRequests = {}
local bridgeRegistered = {}
local bridgeUnregistered = {}

local fakeDirector = {
	spawnEnemy = function(request)
		table.insert(submittedRequests, request)
		if rejectAll then
			return { didSpawn = false, wasDeferred = false, rejectionReasonId = "PopulationCapReached" }
		end
		if deferEntityIds[request.entityId] == true then
			return { didSpawn = false, wasDeferred = true, rejectionReasonId = nil }
		end
		return { didSpawn = true, wasDeferred = false, rejectionReasonId = nil }
	end,
	readEnemyCombatFacts = function()
		return facts
	end,
}

local fakeComposer = {
	compose = function(config, _spawnPoints, context)
		if config.Invalid == true then
			return { isValid = false, rejectionReasonId = "InvalidFixture", spawns = {} }
		end
		return {
			isValid = true,
			compositionIdentity = context.CompositionIdentity or (config.Id .. ":composition"),
			spawns = {
				{
					entityId = config.Id .. ":1",
					archetypeId = contracts.EnemyArchetypeIds.ExclusionWalker,
					displayName = "Fixture A",
					position = { x = 70, y = 3, z = 0 },
					eliteChance = 0,
					requestedEliteAffixId = nil,
				},
				{
					entityId = config.Id .. ":2",
					archetypeId = contracts.EnemyArchetypeIds.RazorRunner,
					displayName = "Fixture B",
					position = { x = 80, y = 3, z = 0 },
					eliteChance = 0.1,
					requestedEliteAffixId = nil,
				},
			},
		}
	end,
}

local fakeBridge = {
	registerSpawn = function(request)
		bridgeRegistered[request.entityId] = true
		return true
	end,
	unregisterSpawn = function(entityId)
		bridgeUnregistered[entityId] = true
		bridgeRegistered[entityId] = nil
		return true
	end,
}

local replicatedStorage = { Shared = { Combat = { EnemyContracts = CONTRACTS_TOKEN } } }
local serviceModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyEncounterService.luau"), {
	debugName = "EnemyEncounterService",
	environment = {
		game = {
			GetService = function(_self: unknown, name: string)
				assertThat(name == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		script = {
			Parent = {
				EnemyEncounterComposer = COMPOSER_TOKEN,
				EnemyDirectorService = DIRECTOR_TOKEN,
				EnemyArchetypeRuntimeBridge = BRIDGE_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == COMPOSER_TOKEN then
				return fakeComposer
			elseif token == DIRECTOR_TOKEN then
				return fakeDirector
			elseif token == BRIDGE_TOKEN then
				return fakeBridge
			end
			error("unexpected EnemyEncounterService dependency")
		end,
	},
	injectGlobals = true,
})()

local service = serviceModule.new(fakeDirector, fakeComposer, fakeBridge)
local points = { { x = 70, y = 3, z = 0 }, { x = 80, y = 3, z = 0 } }

local a = service:spawnEncounter({ Id = "encounter:a" }, points, { Seed = 1 })
local b = service:spawnEncounter({ Id = "encounter:b" }, points, { Seed = 2 })
assertThat(a.didStart and a.acceptedCount == 2, "first encounter should start")
assertThat(b.didStart and b.acceptedCount == 2, "second simultaneous encounter should start")
assertThat(#submittedRequests == 4, "each planned spawn must cross the director boundary once")
assertThat(submittedRequests[1].encounterId == "encounter:a", "encounter identity must reach spawn request")
assertThat(
	bridgeRegistered["encounter:a:1"] and bridgeRegistered["encounter:b:2"],
	"runtime metadata must register before spawn"
)

facts = {
	{ entityId = "encounter:a:1", isAlive = true },
	{ entityId = "encounter:a:2", isAlive = true },
	{ entityId = "encounter:b:1", isAlive = true },
}
assertThat(select(1, service:pollCompletion("encounter:a")) == false, "A must remain active while tracked enemies live")
assertThat(select(1, service:pollCompletion("encounter:b")) == false, "B must remain independently active")

facts = { { entityId = "encounter:b:1", isAlive = true } }
local aCompleted, aId = service:pollCompletion("encounter:a")
assertThat(aCompleted and aId == "encounter:a", "A must complete when its exact tracked set clears")
local duplicate, duplicateReason = service:pollCompletion("encounter:a")
assertThat(not duplicate and duplicateReason == "CompletionAlreadyReported", "completion must never fire twice")
assertThat(select(1, service:pollCompletion("encounter:b")) == false, "A completion must not complete B")

facts = {}
assertThat(select(1, service:pollCompletion("encounter:b")) == true, "B must complete independently")
assertThat(service:releaseEncounter("encounter:a"), "completed session should be releasable")
assertThat(service:readEncounter("encounter:a") == nil, "released session must be cleaned up")

local invalid = service:spawnEncounter({ Id = "encounter:invalid", Invalid = true }, points, { Seed = 3 })
assertThat(
	not invalid.didStart and invalid.rejectionReasonId == "InvalidFixture",
	"invalid composition must fail closed"
)
assertThat(
	not service:spawnEncounter({ Id = "" }, points, { Seed = 3 }).didStart,
	"empty encounter IDs must fail closed"
)

rejectAll = true
local rejected = service:spawnEncounter({ Id = "encounter:rejected" }, points, { Seed = 4 })
assertThat(not rejected.didStart and rejected.acceptedCount == 0, "zero accepted spawns must not create a live session")
assertThat(
	bridgeUnregistered["encounter:rejected:1"] and bridgeUnregistered["encounter:rejected:2"],
	"permanent spawn rejection must clean runtime metadata"
)
rejectAll = false

deferEntityIds["encounter:deferred:1"] = true
deferEntityIds["encounter:deferred:2"] = true
local deferred = service:spawnEncounter({ Id = "encounter:deferred" }, points, { Seed = 5 })
assertThat(deferred.didStart and deferred.deferredCount == 2, "deferred legal spawns must remain tracked")
facts = {}
local earlyComplete, earlyReason = service:pollCompletion("encounter:deferred")
assertThat(
	not earlyComplete and earlyReason == "AwaitingTrackedSpawn",
	"pending deferred spawns must not false-complete"
)
facts = { { entityId = "encounter:deferred:1", isAlive = true }, { entityId = "encounter:deferred:2", isAlive = true } }
assertThat(
	select(1, service:pollCompletion("encounter:deferred")) == false,
	"deferred encounter must observe live state"
)
facts = {}
assertThat(
	select(1, service:pollCompletion("encounter:deferred")) == true,
	"deferred encounter completes after observed enemies die"
)

local cancelled = service:spawnEncounter({ Id = "encounter:cancelled" }, points, { Seed = 6 })
assertThat(cancelled.didStart and service:cancelEncounter("encounter:cancelled"), "active encounter must cancel")
local cancelledComplete, cancelledReason = service:pollCompletion("encounter:cancelled")
assertThat(
	not cancelledComplete and cancelledReason == "EncounterCancelled",
	"cancelled encounters must never report completion"
)

service:destroy()
assertThat(
	not service:spawnEncounter({ Id = "encounter:after-destroy" }, points, { Seed = 7 }).didStart,
	"destroyed service must reject new work"
)

print(
	"EnemyEncounterServiceWave2: simultaneous tracking, exact completion, deferral, invalid/zero handling, cancellation, and cleanup passed"
)
