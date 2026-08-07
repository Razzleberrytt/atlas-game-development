--!strict

-- VS-0103 authoritative expedition runtime fixture: validates bounded creation,
-- stale-request rejection, minimum-duration enforcement, monotonic phase order,
-- one-time terminal outcomes, secret idempotency, and destroyed-state behavior.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "VS-0103 expedition runtime fixture assertion failed", 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionContracts.luau"), {
	debugName = "ExpeditionContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/ExpeditionConfig.luau"), {
	debugName = "ExpeditionConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { ExpeditionContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected ExpeditionConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local RUNTIME_CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Expeditions = { ExpeditionContracts = RUNTIME_CONTRACTS_TOKEN },
		Config = { ExpeditionConfig = CONFIG_TOKEN },
	},
}

local runtimeModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRuntime.luau"), {
	debugName = "ExpeditionRuntime",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == RUNTIME_CONTRACTS_TOKEN then
				return contracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected ExpeditionRuntime dependency")
		end,
	},
	injectGlobals = true,
})()

local definition = config.Definitions.FirstExpedition
local phaseIds = contracts.PhaseIds
local outcomeIds = contracts.OutcomeIds

local runtime = runtimeModule.new(definition, {
	RunId = "run-test-0001",
	Seed = 421337,
	PartySize = 2,
	StartedAtUnix = 1_000,
})

local initial = runtime:getSnapshot()
assert(initial ~= nil, "new runtime must expose a snapshot")
assert(initial.PhaseId == phaseIds.Preparation, "runtime must start in preparation")
assert(initial.PhaseIndex == 1, "runtime must start at phase index one")
assert(initial.OutcomeId == outcomeIds.InProgress, "new runtime must be in progress")
assert(initial.Seed == 421337 and initial.PartySize == 2, "snapshot must preserve run identity facts")

assert(runtime:markSecretDiscovered() == true, "first secret discovery must be accepted")
assert(runtime:markSecretDiscovered() == false, "secret discovery must be idempotent")
assert(runtime:getSnapshot().SecretDiscovered == true, "secret discovery must appear in snapshots")

local stale = runtime:advancePhase(phaseIds.Approach, 1_000)
assert(stale.Accepted == false and stale.ReasonId == "StalePhase", "stale phase requests must be rejected")

local preparationAdvance = runtime:advancePhase(phaseIds.Preparation, 1_000)
assert(preparationAdvance.Accepted == true, "preparation should advance at its zero-second minimum")
assert(preparationAdvance.Snapshot.PhaseId == phaseIds.Approach, "preparation must advance to approach")

local tooEarly = runtime:advancePhase(phaseIds.Approach, 1_009)
assert(
	tooEarly.Accepted == false and tooEarly.ReasonId == "PhaseMinimumDuration",
	"phase advancement before the configured minimum must be rejected"
)

local approachAdvance = runtime:advancePhase(phaseIds.Approach, 1_010)
assert(approachAdvance.Accepted == true, "approach should advance at its configured minimum")
assert(approachAdvance.Snapshot.PhaseId == phaseIds.Dungeon, "approach must advance to dungeon")

local earlyCompletion = runtime:finish(outcomeIds.Completed, phaseIds.Dungeon, 1_040)
assert(
	earlyCompletion.Accepted == false and earlyCompletion.ReasonId == "CompletionBeforeFinalPhase",
	"completion must be impossible before the final phase"
)

local failed = runtime:finish(outcomeIds.Failed, phaseIds.Dungeon, 1_040)
assert(failed.Accepted == true and failed.Snapshot.OutcomeId == outcomeIds.Failed, "failure must be terminal")

local duplicateFinish = runtime:finish(outcomeIds.Abandoned, phaseIds.Dungeon, 1_041)
assert(
	duplicateFinish.Accepted == false and duplicateFinish.ReasonId == "RunTerminal",
	"a terminal run must reject every later outcome"
)
assert(runtime:markSecretDiscovered() == false, "terminal runs must reject later secret mutation")

runtime:destroy()
assert(runtime:getSnapshot() == nil, "destroyed runtime must not disclose live state")
assert(runtime:advancePhase(phaseIds.Dungeon, 1_050).ReasonId == "RunDestroyed", "destroyed runs must reject advancement")
runtime:destroy()

local completionRuntime = runtimeModule.new(definition, {
	RunId = "run-test-0002",
	Seed = 99,
	PartySize = 1,
	StartedAtUnix = 2_000,
})

local now = 2_000
for index = 1, #definition.Phases - 1 do
	local phase = definition.Phases[index]
	now += phase.MinimumDurationSeconds
	local result = completionRuntime:advancePhase(phase.Id, now)
	assert(result.Accepted == true, string.format("phase %s should advance", phase.Id))
end

local finalSnapshot = completionRuntime:getSnapshot()
assert(finalSnapshot.PhaseId == phaseIds.Results, "completion fixture must reach results")
local completed = completionRuntime:finish(outcomeIds.Completed, phaseIds.Results, now)
assert(completed.Accepted == true, "results phase must allow one completed outcome")
assert(completed.Snapshot.OutcomeId == outcomeIds.Completed, "completion outcome must be visible")

local invalidPartyOk = pcall(function()
	runtimeModule.new(definition, {
		RunId = "run-test-0003",
		Seed = 1,
		PartySize = 5,
		StartedAtUnix = 0,
	})
end)
assert(invalidPartyOk == false, "out-of-bounds party sizes must fail creation")

print("ExpeditionRuntime fixture passed")
