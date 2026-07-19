--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ENEMY_CONFIG_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}

local enemyConfig = {
	Cleanup = { CorpseCleanupSeconds = 5 },
	Population = { AbsoluteMaximumConcurrent = 96 },
}
local hordeConfig = {
	Roles = {
		Bloater = { DeathBurstRadiusStuds = 20 },
	},
}

local source = fs.readFile("games/living-kingdoms/src/shared/Config/HordeSpecialTelegraphConfig.luau")
local loader = luau.load(source, {
	debugName = "HordeSpecialTelegraphConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				HordeExperienceConfig = HORDE_CONFIG_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			if token == HORDE_CONFIG_TOKEN then
				return hordeConfig
			end
			error("unexpected special telegraph config dependency")
		end,
	},
	injectGlobals = true,
})
local config = loader()

assert(config.Version == "HROI-0138-v1-screamer-interrupt-confirmation")
assert(config.MaximumTrackedEnemyModels == 128)
assert(config.MaximumActiveTelegraphs == 16)
assert(config.PollIntervalSeconds == 0.05)
assert(config.CommitHoldSeconds == 0.28)

local expected = {
	ScreamerReinforcement = {
		windup = 1.25,
		radius = 9,
		warning = "SCREAMER SUMMONING",
		commit = "REINFORCEMENTS",
	},
	BloaterDeathBurst = {
		windup = 0.85,
		radius = 20,
		warning = "BLOATER BURST",
		commit = "BURST",
	},
	BruteSecondPhase = {
		windup = 0.9,
		radius = 12,
		warning = "BRUTE REANIMATING",
		commit = "PHASE II",
	},
}

for kindId, values in expected do
	local definition = config.get(kindId)
	assert(definition ~= nil, "missing telegraph definition: " .. kindId)
	assert(definition.KindId == kindId)
	assert(definition.WindupSeconds == values.windup)
	assert(definition.RadiusStuds == values.radius)
	assert(definition.WarningLabel == values.warning)
	assert(definition.CommitLabel == values.commit)
	assert(definition.PulseCount >= 1 and definition.PulseCount <= 4)
	assert(#definition.Color == 3)
end

assert(config.get("unknown") == nil)
assert(config.get(5) == nil)
assert(config.BloaterDeathBurst.RadiusStuds == hordeConfig.Roles.Bloater.DeathBurstRadiusStuds)
assert(config.BloaterDeathBurst.WindupSeconds < enemyConfig.Cleanup.CorpseCleanupSeconds)
assert(config.BruteSecondPhase.WindupSeconds < enemyConfig.Cleanup.CorpseCleanupSeconds)

local attributeNames = {}
for _, attributeName in config.AttributeNames do
	assert(attributeNames[attributeName] == nil, "attribute names must be unique")
	attributeNames[attributeName] = true
end
assert(attributeNames.HordeSpecialKindId)
assert(attributeNames.HordeSpecialSequence)
assert(attributeNames.HordeSpecialStateId)
assert(attributeNames.HordeSpecialCommitServerTimestamp)
assert(config.StateIds.Interrupted == "Interrupted")

local mutated = pcall(function()
	config.MaximumActiveTelegraphs = 99
end)
assert(not mutated, "config must be frozen")

print("HordeSpecialTelegraphConfig: exact timings, radius disclosure, bounds, and frozen vocabulary passed")
