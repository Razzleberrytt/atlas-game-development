--!strict

-- P9-0105 special-encounter telegraph contract: the disc-kind attribute mappings
-- for the Spitter bloom and the Progenitor Slam, the boss status vocabulary,
-- redundant (non-color-only) labels, and bounded pool/poll invariants.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P9-0105 telegraph config fixture assertion failed", 2)
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
local presentationContracts =
	loadSimple("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau", "EnemyPresentationContracts")

local ENEMY_CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local enemyConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
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
local PRESENTATION_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/SpecialEncounterTelegraphConfig.luau"), {
	debugName = "SpecialEncounterTelegraphConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				Parent = {
					Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN },
					Visual = { EnemyPresentationContracts = PRESENTATION_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			if token == PRESENTATION_TOKEN then
				return presentationContracts
			end
			error("unexpected SpecialEncounterTelegraphConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local attr = presentationContracts.AttributeNames

-- Disc kinds map to the correct archetypes and the authoritative disclosure
-- attributes the server actually publishes.
assert(config.Bloom.ArchetypeId == enemyContracts.EnemyArchetypeIds.BlightSpitter)
assert(config.Slam.ArchetypeId == enemyContracts.EnemyArchetypeIds.Progenitor)
assert(config.Bloom.CommitAttribute == attr.SpitterBloomCommitServerTimestamp)
assert(
	config.Bloom.CenterXAttribute == attr.SpitterBloomCenterX
		and config.Bloom.CenterZAttribute == attr.SpitterBloomCenterZ
)
assert(config.Bloom.RadiusAttribute == attr.SpitterBloomRadiusStuds)
assert(config.Slam.CommitAttribute == attr.BossSlamCommitServerTimestamp)
assert(config.Slam.CenterXAttribute == attr.BossSlamCenterX and config.Slam.CenterZAttribute == attr.BossSlamCenterZ)
assert(config.Slam.RadiusAttribute == attr.BossSlamRadiusStuds)
assert(config.Bloom.HasLinger == true, "the bloom leaves lingering ground")
assert(config.Slam.HasLinger == false, "the Slam is a one-shot")

-- Archetype lookup drives which model gets which telegraph.
assert(config.discKindForArchetypeId(enemyContracts.EnemyArchetypeIds.BlightSpitter) == config.Bloom)
assert(config.discKindForArchetypeId(enemyContracts.EnemyArchetypeIds.Progenitor) == config.Slam)
assert(
	config.discKindForArchetypeId(enemyContracts.EnemyArchetypeIds.ExclusionWalker) == nil,
	"walkers have no telegraph"
)
assert(config.discKindForArchetypeId(42) == nil)

-- Redundant cues: every telegraph and boss state carries text, not color alone.
for _, kind in config.DiscKinds do
	assert(kind.WarningLabel ~= "" and kind.CommitLabel ~= "")
	assert(#kind.Color == 3 and kind.PulseCount >= 1)
end
assert(config.BossStatus.VulnerableLabel ~= "" and config.BossStatus.ArmoredLabel ~= "")
assert(
	config.BossStatus.PhaseAttribute == attr.BossPhaseId
		and config.BossStatus.VulnerableAttribute == attr.BossIsVulnerable
)
for _, phase in { "Carapace", "Brood", "Collapse", "Defeated" } do
	assert(config.BossStatus.PhaseLabels[phase] ~= nil, "missing boss phase label: " .. phase)
end

-- Bounded pool and polling.
assert(config.MaximumTrackedEnemyModels >= enemyConfig.Population.AbsoluteMaximumConcurrent)
assert(config.MaximumActiveTelegraphs > 0 and config.MaximumActiveTelegraphs <= 24)
assert(config.PollIntervalSeconds > 0 and config.PollIntervalSeconds <= 0.1)
assert(config.CommitHoldSeconds > 0 and config.CommitHoldSeconds <= 0.5)
assert(table.isfrozen(config) and table.isfrozen(config.Bloom) and table.isfrozen(config.BossStatus))

print("SpecialEncounterTelegraphConfig: P9-0105 disc-kind mappings, boss status vocabulary, and bounds passed")
