--!strict

--[[
	Cross-system regression for the first-upgrade / first-wipe balance pass.
	RunProgressionConfig and HordeExperienceConfig have separate authority, but
	their production values must describe one coherent opening curve.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local hordeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau"), {
	debugName = "HordeExperienceConfig",
	injectGlobals = true,
})()
local progressionConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()
local enemyConfigSource = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function pulseCountThrough(firstPulseSeconds: number, intervalSeconds: number, durationSeconds: number): number
	local count = 0
	local timestamp = firstPulseSeconds
	while timestamp <= durationSeconds do
		count += 1
		timestamp += intervalSeconds
	end
	return count
end

-- Canonical director level zero remains the first-contact owner: four spawn
-- attempts every nine seconds. The horde layer must reinforce, not duplicate,
-- that initial contact burst.
assertThat(
	contains(enemyConfigSource, "[0] = table.freeze({ IntervalSeconds = 9, SpawnCount = 4 })"),
	"opening-curve evidence must be updated when the canonical director baseline changes"
)
local directorOpeningSpawnAttempts = math.floor(30 / 9) * 4
local hordeOpeningPulses = pulseCountThrough(
	hordeConfig.Pressure.WarmupSeconds,
	hordeConfig.Pressure.BaseSpawnIntervalSeconds,
	30
)
local hordeOpeningSpawnAttempts = hordeOpeningPulses * hordeConfig.Pressure.BaseSpawnCount
local combinedOpeningSpawnAttempts = directorOpeningSpawnAttempts + hordeOpeningSpawnAttempts

assertThat(hordeConfig.Pressure.WarmupSeconds >= 9, "horde pressure must not beat canonical first contact")
assertThat(hordeOpeningPulses == 2, "the first 30 seconds should contain exactly two baseline horde reinforcements")
assertThat(hordeOpeningSpawnAttempts == 6, "baseline horde pressure should contribute six opening spawn attempts")
assertThat(
	combinedOpeningSpawnAttempts == 18 and combinedOpeningSpawnAttempts < 24,
	"combined opening spawn attempts must remain below the solo living-enemy ceiling before kills and cleanup"
)

local firstUpgradeKills = math.ceil(
	progressionConfig.BaseXpToLevel / progressionConfig.FieldXpPerConfirmedEnemyDeath
)
assertThat(firstUpgradeKills == 4, "the first run upgrade must arrive after four ordinary confirmed deaths")
assertThat(
	firstUpgradeKills * progressionConfig.FieldXpPerConfirmedEnemyDeath == progressionConfig.BaseXpToLevel,
	"ordinary kills must reach the opening threshold without fractional spillover"
)
local secondLevelRequirement =
	math.floor(progressionConfig.BaseXpToLevel * progressionConfig.XpGrowthPerLevel + 0.5)
assertThat(secondLevelRequirement == 108, "the second upgrade threshold must slow after the opening reward")

-- The pass softens only the opening ramp. At maximum threat the horde layer must
-- still retain a severe pulse and its configured minimum cadence.
local maximumThreatSpawnCount = math.clamp(
	hordeConfig.Pressure.BaseSpawnCount + math.floor(hordeConfig.Pressure.ThreatMaximum / 12),
	hordeConfig.Pressure.BaseSpawnCount,
	hordeConfig.Pressure.MaximumSpawnCount
)
assertThat(maximumThreatSpawnCount == 10, "maximum threat must retain a ten-contact horde pulse")
assertThat(hordeConfig.Pressure.MinimumSpawnIntervalSeconds == 4, "late horde cadence must remain severe")

print(
	"OpeningBalanceCurve: 18 combined opening attempts, four-kill first upgrade, and ten-contact maximum horde passed"
)
