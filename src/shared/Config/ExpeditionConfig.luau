--!strict

--[[
	VS-0102 bounded configuration for the first five-to-ten-minute expedition.
	The configuration describes phase order and safety limits only. Runtime state,
	encounter completion, rewards, and persistence remain server-owned concerns.
]]

local ExpeditionContracts = require(script.Parent.Parent.Expeditions.ExpeditionContracts)

local PhaseIds = ExpeditionContracts.PhaseIds

local ExpeditionConfig = {
	Version = "VS-0102-v1",
	Definitions = table.freeze({
		FirstExpedition = table.freeze({
			Id = "first-expedition",
			Version = "1.0.0",
			DisplayName = "The First Descent",
			MinimumPlayers = 1,
			MaximumPlayers = 4,
			TargetDurationSeconds = 480,
			Phases = table.freeze({
				table.freeze({
					Id = PhaseIds.Preparation,
					Order = 1,
					DisplayName = "Prepare",
					MinimumDurationSeconds = 0,
					MaximumDurationSeconds = 120,
					AllowsLateJoin = true,
				}),
				table.freeze({
					Id = PhaseIds.Approach,
					Order = 2,
					DisplayName = "Reach the Ruins",
					MinimumDurationSeconds = 10,
					MaximumDurationSeconds = 180,
					AllowsLateJoin = true,
				}),
				table.freeze({
					Id = PhaseIds.Dungeon,
					Order = 3,
					DisplayName = "Explore the Descent",
					MinimumDurationSeconds = 30,
					MaximumDurationSeconds = 360,
					AllowsLateJoin = true,
				}),
				table.freeze({
					Id = PhaseIds.Elite,
					Order = 4,
					DisplayName = "Break the Warden",
					MinimumDurationSeconds = 10,
					MaximumDurationSeconds = 180,
					AllowsLateJoin = false,
				}),
				table.freeze({
					Id = PhaseIds.Boss,
					Order = 5,
					DisplayName = "Defeat the Keeper",
					MinimumDurationSeconds = 15,
					MaximumDurationSeconds = 240,
					AllowsLateJoin = false,
				}),
				table.freeze({
					Id = PhaseIds.Rewards,
					Order = 6,
					DisplayName = "Claim Rewards",
					MinimumDurationSeconds = 0,
					MaximumDurationSeconds = 90,
					AllowsLateJoin = false,
				}),
				table.freeze({
					Id = PhaseIds.Results,
					Order = 7,
					DisplayName = "Expedition Results",
					MinimumDurationSeconds = 0,
					MaximumDurationSeconds = 120,
					AllowsLateJoin = false,
				}),
			}),
		}),
	}),
	RuntimeLimits = table.freeze({
		MaximumConcurrentRunsPerServer = 1,
		MinimumSeed = 1,
		MaximumSeed = 2_147_483_647,
		MaximumRunLifetimeSeconds = 1_200,
		MaximumPhaseAdvanceRequestsPerPlayerPerMinute = 12,
	}),
}

local definition = ExpeditionConfig.Definitions.FirstExpedition

assert(definition.MinimumPlayers == 1, "the first expedition must remain solo-capable")
assert(definition.MaximumPlayers == 4, "the first expedition is scoped to one-to-four players")
assert(
	definition.TargetDurationSeconds >= 300 and definition.TargetDurationSeconds <= 600,
	"the vertical slice must target a five-to-ten-minute run"
)
assert(#definition.Phases == 7, "the first expedition requires the canonical seven-phase sequence")

for index, phase in definition.Phases do
	assert(phase.Order == index, "expedition phases must use contiguous deterministic order")
	assert(phase.MaximumDurationSeconds >= phase.MinimumDurationSeconds, "phase duration bounds are invalid")
	assert(phase.MaximumDurationSeconds <= 360, "individual expedition phases must remain bounded")
end

assert(
	ExpeditionConfig.RuntimeLimits.MaximumRunLifetimeSeconds >= definition.TargetDurationSeconds,
	"the maximum run lifetime must cover the target expedition duration"
)
assert(
	ExpeditionConfig.RuntimeLimits.MinimumSeed >= 1
		and ExpeditionConfig.RuntimeLimits.MaximumSeed > ExpeditionConfig.RuntimeLimits.MinimumSeed,
	"expedition seed bounds must define a useful positive integer range"
)

return table.freeze(ExpeditionConfig)
