--!strict

-- P9-0103 boss vocabulary and configuration invariants: stable phase/action/
-- outcome/rejection IDs, the monotonic phase order, bounded Progenitor balance
-- values, ordered health thresholds, enrage tightening, and frozen tables.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P9-0103 boss contracts fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local enemyContracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local ENEMY_CONTRACTS_TOKEN = {}
local bossContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/BossContracts.luau"), {
	debugName = "BossContracts",
	environment = {
		script = { Parent = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assert(token == ENEMY_CONTRACTS_TOKEN, "unexpected BossContracts dependency")
			return enemyContracts
		end,
	},
	injectGlobals = true,
})()

local WORLD_TOKEN = {}
local ENEMY_CONTRACTS_CONFIG_TOKEN = {}
local enemyConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = ENEMY_CONTRACTS_CONFIG_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_CONFIG_TOKEN then
				return enemyContracts
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local ENEMY_CONFIG_TOKEN = {}
local BOSS_CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/BossConfig.luau"), {
	debugName = "BossConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				Parent = { Combat = { BossContracts = BOSS_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			if token == BOSS_CONTRACTS_TOKEN then
				return bossContracts
			end
			error("unexpected BossConfig dependency")
		end,
	},
	injectGlobals = true,
})()

-- Stable vocabulary.
assert(bossContracts.BossArchetypeIds.Progenitor == "boss.progenitor")
assert(bossContracts.BossArchetypeIds.Progenitor == enemyContracts.EnemyArchetypeIds.Progenitor, "one archetype source")
for _, phase in { "Carapace", "Brood", "Collapse", "Defeated" } do
	assert(bossContracts.BossPhaseIds[phase] == phase, "missing phase: " .. phase)
end
for _, action in { "None", "Begin", "Continue", "Cancel", "Commit" } do
	assert(bossContracts.BossActionIds[action] == action, "missing action: " .. action)
end
assert(bossContracts.BossOutcomeIds.Pending == "Pending" and bossContracts.BossOutcomeIds.Defeated == "Defeated")
for _, reason in { "InvalidFacts", "InvalidTimestamp" } do
	assert(bossContracts.BossDecisionRejectionReasonIds[reason] == reason, "missing rejection: " .. reason)
end
-- The phase order is strictly monotonic and total.
local order = bossContracts.BossPhaseOrder
assert(order.Carapace < order.Brood and order.Brood < order.Collapse and order.Collapse < order.Defeated)
assert(table.isfrozen(bossContracts) and table.isfrozen(bossContracts.BossPhaseIds), "contracts must be frozen")
assert(table.isfrozen(bossContracts.BossActionIds) and table.isfrozen(bossContracts.BossPhaseOrder))

-- Configuration invariants beyond the module's own asserts.
local progenitor = config.Progenitor
local slam = config.Slam
local brood = config.Brood
local visibility = config.Visibility
assert(progenitor.ArchetypeId == bossContracts.BossArchetypeIds.Progenitor)
assert(table.isfrozen(config) and table.isfrozen(progenitor) and table.isfrozen(config.Phases), "config must be frozen")
assert(progenitor.MaximumHealth > enemyConfig.Walker.MaximumHealth, "the boss must read as a climax, not a walker")
assert(
	progenitor.CollapseHealthFraction < progenitor.BroodHealthFraction and progenitor.BroodHealthFraction < 1,
	"phase thresholds must be strictly ordered"
)
assert(slam.Damage < 100, "one Slam must never down a full-health operative outright")
assert(
	brood.SurgeCount > 0 and brood.SurgeCount <= enemyConfig.Population.AbsoluteMaximumConcurrent,
	"the Brood surge must fit the population budget"
)
assert(visibility.ShroudRadiusStuds < enemyConfig.Combat.GameplayVisibilityRadiusStuds, "the shroud reduces visibility")
assert(
	visibility.CollapseDarkRadiusStuds < enemyConfig.Combat.GameplayVisibilityRadiusStuds,
	"Collapse darkness reduces visibility"
)

-- Enrage is monotonic across the three combat phases.
local previousCooldown = math.huge
local previousExposure = math.huge
for _, phaseName in { "Carapace", "Brood", "Collapse" } do
	local phase = config.Phases[phaseName]
	assert(phase.ExposureWindowSeconds < phase.SlamCooldownSeconds, "exposure must close before the next Slam")
	assert(phase.SlamWindupSeconds < phase.SlamCooldownSeconds, "windup must be shorter than cooldown")
	assert(phase.SlamCooldownSeconds <= previousCooldown, "later phases must not relax the Slam cadence")
	assert(phase.ExposureWindowSeconds <= previousExposure, "later phases must not lengthen exposure")
	previousCooldown = phase.SlamCooldownSeconds
	previousExposure = phase.ExposureWindowSeconds
end

print("BossContracts: P9-0103 Progenitor vocabulary, phase order, and enrage invariants passed")
