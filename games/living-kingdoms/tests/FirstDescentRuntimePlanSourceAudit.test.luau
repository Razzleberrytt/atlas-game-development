--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local lobby = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionServerBootstrap.luau")
local adapter = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorEncounterAdapter.luau")
local content = fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau")

assert(
	contains(lobby, "require(ReplicatedStorage.Shared.Config.FirstDungeonContentConfig)"),
	"the server-owned lobby must source the MVP run seed from First Descent content"
)
assert(
	contains(lobby, "Seed = FirstDungeonContentConfig.CanonicalSeed"),
	"the deliberate MVP launch must pin the canonical First Descent seed"
)
assert(contains(bootstrap, "RoomPlacementPlanner.plan(rawPlan)"), "combat must use the physical-room layout planner")
assert(contains(bootstrap, "placementByRoomId[context.RoomId]"), "dungeon combat must anchor to room identity")
assert(contains(bootstrap, "placementByRoleId[context.PhaseId]"), "elite and boss phases must anchor to planned rooms")
assert(
	contains(bootstrap, "FirstDungeonContentConfig.Encounters[record.RoomId]"),
	"BA-032 authored encounter content must feed variation composition"
)
assert(
	contains(bootstrap, "RunVariationAuthoredEncounterComposer.compose"),
	"the live First Descent bridge must apply the deterministic variation composition"
)
assert(
	contains(bootstrap, "composedEncounterByRoomId[roomId]"),
	"runtime encounter lookup must consume the composed room-local encounter"
)
assert(contains(bootstrap, "unit.ArchetypeId"), "authored archetype identity must reach the runtime definition")
assert(contains(bootstrap, "unit.HordeRoleId"), "authored walker role identity must reach the runtime definition")
assert(contains(bootstrap, "SpecialEnemyConfig.BlightSpitter.DisplayName"), "Spitter identity must remain special")
assert(contains(adapter, "state.Director.spawnEnemy"), "typed authored enemies must use the canonical spawn authority")
assert(contains(adapter, 'spawnSourceId = "AuthoredWave"'), "typed enemies must preserve authored-wave source truth")
assert(contains(adapter, "hordeRoleId = enemy.hordeRoleId"), "walker role mechanics must not collapse to infected")
assert(contains(adapter, "archetypeId = enemy.archetypeId"), "special archetypes must not collapse to walkers")
assert(
	contains(adapter, "state.Director.spawnAuthoredWave(waveIndex, {})"),
	"the existing authored-pressure pacing side effect must remain owned by EnemyDirector"
)
assert(contains(content, "CanonicalSeed = 202"), "the MVP canonical seed must stay explicit")
assert(contains(content, "unit(EnemyArchetypeIds.BlightSpitter, 1, nil)"), "BA-032 Spitter intent must stay preserved")
assert(
	contains(content, "unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Brute.Id)"),
	"BA-032 Brute intent must stay preserved"
)
assert(
	contains(content, "unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Screamer.Id)"),
	"BA-032 Screamer intent must stay preserved"
)
assert(not contains(bootstrap, "BossPosition = { x = 0, y = 4, z = 120 }"), "boss placement must stay room-local")

print("FirstDescentRuntimePlanSourceAudit: authored archetype/role composition bridge active")
