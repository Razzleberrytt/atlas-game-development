--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local lobby = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionServerBootstrap.luau")
local content = fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau")

assert(
	contains(lobby, "require(ReplicatedStorage.Shared.Config.FirstDungeonContentConfig)"),
	"the server-owned lobby must source the MVP run seed from First Descent content"
)
assert(
	contains(lobby, "Seed = FirstDungeonContentConfig.CanonicalSeed"),
	"the deliberate MVP launch must pin the canonical First Descent seed"
)
assert(
	contains(bootstrap, "RoomPlacementPlanner.plan(rawPlan)"),
	"the active encounter resolver must use the same deterministic layout planner as physical room placement"
)
assert(
	contains(bootstrap, "placementByRoomId[context.RoomId]"),
	"dungeon combat must anchor to the active room identity"
)
assert(
	contains(bootstrap, "placementByRoleId[context.PhaseId]"),
	"elite and boss phases must anchor to their planned rooms"
)
assert(
	contains(bootstrap, "math.clamp(((value % 17) - 8) * 6, -18, 18)"),
	"authored-wave X offsets must stay bounded inside the room footprint"
)
assert(
	contains(bootstrap, "math.clamp(((math.floor(value / 17) % 11) - 5) * 6, -24, 24)"),
	"authored-wave Z offsets must stay bounded inside the room footprint"
)
assert(
	not contains(bootstrap, "BossPosition = { x = 0, y = 4, z = 120 }"),
	"boss placement must not regress to the old fixed-Z band"
)
assert(
	not contains(bootstrap, 'z = z + if context.PhaseId == "Approach" then 24 else 64'),
	"dungeon waves must not regress to the old fixed-Z band"
)

-- This slice deliberately activates only the canonical run seed/layout and
-- room-local placement. The richer BA-032 composition remains a separate
-- authority-safe handoff because the existing enemy/horde owners must preserve
-- archetype and role mechanics rather than receiving cosmetic labels only.
assert(contains(content, "CanonicalSeed = 202"), "the MVP canonical seed must stay explicit")
assert(contains(content, "unit(EnemyArchetypeIds.BlightSpitter, 1, nil)"), "BA-032 Spitter intent must stay preserved")
assert(
	contains(content, "unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Brute.Id)"),
	"BA-032 Brute intent must stay preserved"
)
assert(
	not contains(bootstrap, "FirstDungeonContentConfig.Encounters"),
	"this partial handoff must not pretend authored enemy compositions are active"
)

print("FirstDescentRuntimePlanSourceAudit: canonical seed and room-local placement active; composition bridge held")
