--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionBossRewardTransitionResolver.luau"),
	{
		debugName = "ExpeditionBossRewardTransitionResolver",
		injectGlobals = true,
	}
)()

local decision = {
	DecisionId = "first-descent.boss-relic-choice",
	RunRewardSourceId = "run.reward-source.boss-milestone",
	RuntimeConsumptionEnabled = true,
}

local function snapshot(runId: string, phaseId: string)
	return {
		RunId = runId,
		PhaseId = phaseId,
	}
end

local event = Resolver.resolve(snapshot("run:alpha", "Boss"), snapshot("run:alpha", "Rewards"), decision)
assert(event ~= nil, "same-run Boss -> Rewards must resolve the authored boss reward")
assert(
	event.EventId == "first-descent.boss-relic-choice:run:alpha",
	"boss reward event identity must be deterministic from the authored decision and run"
)
assert(event.SourceId == decision.RunRewardSourceId, "the resolver must preserve the canonical reward source")

assert(
	Resolver.resolve(snapshot("run:alpha", "Boss"), snapshot("run:alpha", "Boss"), decision) == nil,
	"remaining in Boss must not pay"
)
assert(
	Resolver.resolve(snapshot("run:alpha", "Rewards"), snapshot("run:alpha", "Results"), decision) == nil,
	"leaving Rewards must not pay again"
)
assert(
	Resolver.resolve(snapshot("run:alpha", "Boss"), snapshot("run:beta", "Rewards"), decision) == nil,
	"cross-run snapshots must fail closed"
)
assert(
	Resolver.resolve(snapshot("run:alpha", "Boss"), snapshot("run:alpha", "Rewards"), {
		DecisionId = decision.DecisionId,
		RunRewardSourceId = decision.RunRewardSourceId,
		RuntimeConsumptionEnabled = false,
	}) == nil,
	"a dormant authored decision must never resolve a live reward"
)
assert(Resolver.resolve(nil, snapshot("run:alpha", "Rewards"), decision) == nil, "missing snapshots must fail closed")

print("ExpeditionBossRewardTransitionResolver: deterministic one-transition boss reward passed")
