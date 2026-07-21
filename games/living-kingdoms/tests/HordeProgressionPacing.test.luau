--!strict

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

local pressure = hordeConfig.Pressure
local killsForFirstUpgrade = progressionConfig.BaseXpToLevel / progressionConfig.FieldXpPerConfirmedEnemyDeath

local function threatAt(elapsedSeconds: number, activeEnemies: number, confirmedKills: number): number
	return math.clamp(
		elapsedSeconds / 60 * pressure.ThreatPerMinute
			+ activeEnemies * pressure.ThreatPerLivingEnemy
			+ confirmedKills * pressure.ThreatPerKill,
		0,
		pressure.ThreatMaximum
	)
end

local function spawnCountAt(threat: number): number
	return math.clamp(
		pressure.BaseSpawnCount + math.floor(threat / 12),
		pressure.BaseSpawnCount,
		pressure.MaximumSpawnCount
	)
end

local function spawnIntervalAt(threat: number): number
	local fraction = threat / pressure.ThreatMaximum
	return pressure.BaseSpawnIntervalSeconds
		- fraction * (pressure.BaseSpawnIntervalSeconds - pressure.MinimumSpawnIntervalSeconds)
end

assertThat(killsForFirstUpgrade == 4, "first upgrade must arrive after four ordinary confirmed deaths")
assertThat(
	pressure.WarmupSeconds >= 20 and pressure.WarmupSeconds <= 30,
	"the additive horde layer must leave a bounded opening combat window"
)
assertThat(
	pressure.BaseSpawnCount < killsForFirstUpgrade,
	"the first additive horde burst must remain smaller than the first-upgrade kill target"
)

-- At the first additive injection, baseline EnemyDirector contact is already in
-- progress. The horde layer should add a readable pulse rather than front-load a
-- second full wave into the same opening seconds.
local openingThreat = threatAt(pressure.WarmupSeconds, 8, 2)
assertThat(spawnCountAt(openingThreat) == 3, "opening additive pressure should remain a three-enemy pulse")
assertThat(spawnIntervalAt(openingThreat) >= 9, "opening additive waves must retain a meaningful recovery interval")

-- A representative first-upgrade checkpoint: four confirmed kills by 45 seconds
-- with a busy but sub-cap battlefield. The upgrade should arrive before the
-- threat model enters the RISING band at 25.
local firstUpgradeThreat = threatAt(45, 16, killsForFirstUpgrade)
assertThat(firstUpgradeThreat < 25, "first upgrade should precede the likely-wipe threat band")
assertThat(spawnCountAt(firstUpgradeThreat) <= 4, "pre-upgrade additive waves must remain readable")
assertThat(spawnIntervalAt(firstUpgradeThreat) >= 8.5, "pre-upgrade cadence must leave time to choose an upgrade")

-- The gentler opening must still build into real horde pressure. These later
-- checkpoints prevent the retune from flattening the operation into a soft mode.
local midRunThreat = threatAt(180, 24, 15)
assertThat(midRunThreat >= 40, "three-minute pressure should reach the severe transition")
assertThat(spawnCountAt(midRunThreat) >= 6, "mid-run horde pulses must escalate beyond the opening burst")
assertThat(spawnIntervalAt(midRunThreat) <= 7.5, "mid-run cadence must accelerate")

local lateRunThreat = threatAt(480, 24, 50)
assertThat(lateRunThreat >= 90, "late-run pressure should approach the catastrophic ceiling")
assertThat(spawnCountAt(lateRunThreat) >= 10, "late-run horde pulses must remain brutal")
assertThat(spawnIntervalAt(lateRunThreat) <= 4, "late-run cadence must approach the configured minimum")

print("HordeProgressionPacing: four-kill first upgrade precedes escalating solo wipe pressure")
