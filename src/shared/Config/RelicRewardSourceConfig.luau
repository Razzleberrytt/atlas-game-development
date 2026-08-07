--!strict

--[[
	RPG-0110 production relic-reward pacing.

	These values decide how often the live operation opens a relic choice, and for
	which server-confirmed events. They grant nothing on their own: each source is
	applied by the owner that already observes the event (RunProgressionService for
	confirmed enemy deaths, ScreamerInterruptRewardService for confirmed special
	interrupts), and every offer still passes the RPG-0107 queue ceiling, replay
	history, and slot rules.

	Sources whose authoritative owner does not exist yet — authored objectives
	(P8), authored containers, and boss milestones (P9) — stay unimplemented and
	are deliberately absent here.
]]

local RelicRewardSourceConfig = {
	Version = "RPG-0110-v1-live-reward-sources",
	-- Every confirmed elite death opens one choice for each participating
	-- operative. Elites are already rare and capped at three simultaneously.
	EliteKillsPerReward = 1,
	-- Confirmed special interrupts are far more common than elites, so they pay
	-- out on a longer interval.
	SpecialInterruptsPerReward = 4,
	-- A squad-kill milestone guarantees a floor on reward frequency even in a run
	-- with unlucky elite spawns.
	HordeKillsPerReward = 90,
}

local function isPositiveInteger(value: number): boolean
	return value == value and value > 0 and value % 1 == 0 and value ~= math.huge
end

assert(
	isPositiveInteger(RelicRewardSourceConfig.EliteKillsPerReward) and RelicRewardSourceConfig.EliteKillsPerReward <= 3,
	"elite relic rewards must stay frequent enough for elites to feel worth hunting"
)
assert(
	isPositiveInteger(RelicRewardSourceConfig.SpecialInterruptsPerReward)
		and RelicRewardSourceConfig.SpecialInterruptsPerReward >= 2
		and RelicRewardSourceConfig.SpecialInterruptsPerReward <= 10,
	"special-interrupt rewards must remain an interval, not a per-interrupt payout"
)
assert(
	isPositiveInteger(RelicRewardSourceConfig.HordeKillsPerReward)
		and RelicRewardSourceConfig.HordeKillsPerReward >= 40
		and RelicRewardSourceConfig.HordeKillsPerReward <= 250,
	"the horde milestone must be a reachable floor without overwhelming the slot economy"
)

return table.freeze(RelicRewardSourceConfig)
