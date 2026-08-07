--!strict

-- P9-0106 encounter security, performance, and class-composition validation.
-- Consolidates the special-enemy + boss encounter's authority, bound, and
-- composition guarantees. Runtime adversarial coverage (forged/stale facts,
-- vulnerability gating, the Slam AoE and Brood surge, defeat and stand-down
-- cleanup) lives in the per-resolver and director fixtures; this fixture proves
-- the composed surface stays server-authoritative and bounded, that the boss adds
-- no client authority or new scheduler, and that the encounter fits the population
-- budget for 1/2/4 operatives without inventing a new resource requirement.
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

local function count(source: string, token: string): number
	local occurrences = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return occurrences
		end
		occurrences += 1
		startIndex = found + #token
	end
end

local function present(source: string, token: string, message: string)
	assertThat(string.find(source, token, 1, true) ~= nil, message)
end

local function absent(source: string, token: string, message: string)
	assertThat(string.find(source, token, 1, true) == nil, message)
end

-- Composition bounds: load the encounter configs (their own asserts validate
-- internal invariants) and prove the pieces fit the shared population budget.
local enemyContracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local ENEMY_CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local SPECIAL_CONTRACTS_TOKEN = {}
local BOSS_CONTRACTS_TOKEN = {}
local ENEMY_CONFIG_TOKEN = {}

local function loadContracts(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {
			script = { Parent = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
			require = function(token: unknown)
				assertThat(token == ENEMY_CONTRACTS_TOKEN, "unexpected contracts dependency")
				return enemyContracts
			end,
		},
		injectGlobals = true,
	})()
end

local specialContracts =
	loadContracts("games/living-kingdoms/src/shared/Combat/SpecialEnemyContracts.luau", "SpecialEnemyContracts")
local bossContracts = loadContracts("games/living-kingdoms/src/shared/Combat/BossContracts.luau", "BossContracts")

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

local function loadConfigOverEnemy(path: string, debugName: string, contractsToken: any, contracts: any)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {
			script = {
				Parent = {
					EnemyConfig = ENEMY_CONFIG_TOKEN,
					Parent = { Combat = { SpecialEnemyContracts = contractsToken, BossContracts = contractsToken } },
				},
			},
			require = function(token: unknown)
				if token == ENEMY_CONFIG_TOKEN then
					return enemyConfig
				end
				if token == contractsToken then
					return contracts
				end
				error("unexpected config dependency")
			end,
		},
		injectGlobals = true,
	})()
end

local specialConfig = loadConfigOverEnemy(
	"games/living-kingdoms/src/shared/Config/SpecialEnemyConfig.luau",
	"SpecialEnemyConfig",
	SPECIAL_CONTRACTS_TOKEN,
	specialContracts
)
local bossConfig = loadConfigOverEnemy(
	"games/living-kingdoms/src/shared/Config/BossConfig.luau",
	"BossConfig",
	BOSS_CONTRACTS_TOKEN,
	bossContracts
)

-- One boss, a low concurrent Spitter count, and one Brood surge all draw from the
-- same authoritative population budget the director enforces at runtime.
assertThat(
	specialConfig.Spawn.MaximumConcurrent <= enemyConfig.Population.MaximumConcurrentPerOperative,
	"concurrent Spitters must fit a single operative's budget"
)
assertThat(
	bossConfig.Brood.SurgeCount <= enemyConfig.Population.AbsoluteMaximumConcurrent,
	"the Brood surge must fit the absolute population cap"
)
-- Even the worst-case composed pressure for a four-operative squad — the boss plus
-- the full Spitter allotment plus a Brood surge — stays inside the absolute cap,
-- so the director's cap never has to reject the authored encounter.
local composedWorstCase = 1 + specialConfig.Spawn.MaximumConcurrent + bossConfig.Brood.SurgeCount
assertThat(
	composedWorstCase <= enemyConfig.Population.AbsoluteMaximumConcurrent,
	"boss + Spitters + a Brood surge must fit the absolute population cap"
)
assertThat(bossConfig.Slam.Damage < 100 and bossConfig.Progenitor.MaximumHealth > 0, "boss tuning stays bounded")
assertThat(
	specialConfig.Bloom.MaximumActiveZones > 0 and specialConfig.Bloom.MaximumActiveZones <= 8,
	"lingering pools stay bounded"
)

-- Authoritative owners and their trust boundaries.
local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local telegraph = fs.readFile("games/living-kingdoms/src/client/Controllers/SpecialEncounterTelegraphController.luau")

-- 1. Boss and Spitter decisions come from the pure resolvers; damage commits only
--    through the P3 boundary; operative fire commits through the revisioned health
--    boundary; the boss is armored outside its exposure window.
present(director, "BossPhaseResolver.resolveBossPhase", "boss phases must come from the pure resolver")
present(director, "SpecialEnemyBehaviorResolver.resolveBehavior", "Spitter behavior must come from the pure resolver")
present(director, "applyAuthoritativeDamage", "boss/Spitter damage must commit through the P3 life boundary")
present(director, "commitBloomImpacts", "boss/Spitter AoE damage must route through the shared authoritative commit")
present(
	director,
	"function EnemyDirectorService.commitHealthState",
	"operative fire commits through the revisioned boundary"
)
present(
	director,
	"entry.archetypeId == PROGENITOR_ARCHETYPE_ID and not entry.bossIsVulnerable",
	"the boss must reject damage outside a telegraphed exposure window"
)
present(director, "function EnemyDirectorService.spawnBoss", "the boss is placed by the server owner, not a client")

-- 2. Cleanup and terminal state are handled deterministically.
present(director, "bossDefeated = true", "boss defeat must be recorded for cleanup and the outcome read")
present(director, "activeBossEntityId = nil", "boss teardown/defeat must free the single-instance slot")

-- 3. No new client authority: the encounter adds no remote surface.
for _, forbidden in
	{ "OnServerEvent", "RemoteEvent", "RemoteFunction", "FireClient", "FireAllClients", "OnClientEvent" }
do
	absent(director, forbidden, "the enemy director must add no remote surface: " .. forbidden)
end

-- 4. Bounded and deterministic: one heartbeat drives the boss too; no per-boss
--    scheduler, no raycasts, no randomness.
assertThat(
	count(director, "RunService.Heartbeat:Connect") == 1,
	"one heartbeat must drive every enemy including the boss"
)
for _, forbidden in { "task.delay", "task.spawn", "task.defer", "Raycast", "math.random", "Random.new" } do
	absent(director, forbidden, "the director must stay bounded and deterministic: " .. forbidden)
end
assertThat(
	string.find(director, "for index = 1, 4", 1, true) == nil,
	"the director must not hard-code four player slots"
)

-- 5. The spore shroud is server-owned: combat reads the authoritative radius, so a
--    client cannot expand its own targeting visibility during Brood/Collapse.
present(
	combat,
	"EnemyDirectorService.readGameplayVisibilityRadiusStuds()",
	"the combat runtime must read the server-owned shroud radius"
)
present(combat, "ReloadIntent", "the reload intent remains the only client-to-server combat input")

-- 6. The mission places the boss at the authored arena; it exposes no client phase
--    or boss control.
present(
	mission,
	"EnemyDirectorService.spawnBoss(MissionConfig.Extraction.Position",
	"the boss must anchor the authored extraction arena"
)

-- 7. The client telegraph is purely cosmetic: no authority, no health, no hit
--    prediction, no early disclosure surface.
for _, forbidden in
	{
		"applyAuthoritativeDamage",
		"commitHealthState",
		"spawnBoss",
		"spawnEnemy",
		"FireServer",
		"RemoteEvent",
		".Health",
	}
do
	absent(telegraph, forbidden, "the telegraph presentation must stay cosmetic: " .. forbidden)
end

print(
	"P9-0106 encounter validation: authority, no-remote surface, bounded/deterministic runtime, server-owned shroud, arena spawn, cosmetic telegraph, and 1/2/4 composition bounds passed"
)
