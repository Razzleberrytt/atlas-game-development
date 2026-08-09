--!strict

-- BA-051 encounter-beat fixture: pin the three BA-050 encounter slots to a
-- readable escalating combat sequence while keeping BA-050 route geometry and
-- traversal dormant under their existing hold.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-051 outdoor encounter beat assertion failed", 2)
	end
end

local enemyContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau"), {
	debugName = "EnemyContracts",
	injectGlobals = true,
})()

local hordeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau"), {
	debugName = "HordeExperienceConfig",
	injectGlobals = true,
})()

local worldConfig = {
	ById = {
		["route.world.primary"] = { kind = "route", active = false },
		["landmark.ranger_station"] = { kind = "landmark", active = true },
		["landmark.logging_road"] = { kind = "landmark", active = true },
		["landmark.lookout_tower"] = { kind = "landmark", active = true },
		["landmark.campground"] = { kind = "landmark", active = true },
		["landmark.creek_crossing"] = { kind = "landmark", active = true },
		["landmark.rocky_overlook"] = { kind = "landmark", active = true },
		["landmark.military_roadblock"] = { kind = "landmark", active = true },
		["landmark.extraction_clearing"] = { kind = "landmark", active = true },
	},
}
local recoveredPathConfig = {
	SourceContentId = "route.world.primary",
	SourceHold = true,
	RuntimeEnabled = false,
}
local firstDungeonConfig = {
	SequenceId = "first-descent-repeatable",
	RoomSequence = { "descent-entry" },
}

local WORLD_CONFIG_TOKEN = {}
local RECOVERED_PATH_TOKEN = {}
local FIRST_DUNGEON_TOKEN = {}
local routeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorRouteConfig.luau"), {
	debugName = "FirstOutdoorRouteConfig",
	environment = {
		script = {
			Parent = {
				WorldContentConfig = WORLD_CONFIG_TOKEN,
				RecoveredWorldPathConfig = RECOVERED_PATH_TOKEN,
				FirstDungeonContentConfig = FIRST_DUNGEON_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == WORLD_CONFIG_TOKEN then
				return worldConfig
			end
			if token == RECOVERED_PATH_TOKEN then
				return recoveredPathConfig
			end
			if token == FIRST_DUNGEON_TOKEN then
				return firstDungeonConfig
			end
			error("unexpected FirstOutdoorRouteConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local ENEMY_CONTRACTS_TOKEN = {}
local ROUTE_CONFIG_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}
local beats = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorEncounterBeatConfig.luau"), {
	debugName = "FirstOutdoorEncounterBeatConfig",
	environment = {
		script = {
			Parent = {
				Parent = { Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
				FirstOutdoorRouteConfig = ROUTE_CONFIG_TOKEN,
				HordeExperienceConfig = HORDE_CONFIG_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == ROUTE_CONFIG_TOKEN then
				return routeConfig
			end
			if token == HORDE_CONFIG_TOKEN then
				return hordeConfig
			end
			error("unexpected FirstOutdoorEncounterBeatConfig dependency")
		end,
	},
	injectGlobals = true,
})()

assert(beats.Version == "BA-051-v2-approach-live", "encounter-beat fixture version changed unexpectedly")
assert(beats.RouteId == routeConfig.RouteId, "encounter beats must remain pinned to the BA-050 route")
assert(beats.RouteVersion == routeConfig.RouteVersion, "encounter beats must remain pinned to the BA-050 route version")
assert(beats.RuntimeConsumptionActive == true, "BA-051 approach combat sequence should be live")
assert(beats.RuntimeConsumptionScopeId == "ApproachCombatSequenceOnly", "BA-051 live scope must stay combat-only")
assert(routeConfig.RuntimeConsumptionActive == false, "BA-051 cannot activate its route-geometry dependency")
assert(#beats.Beats == 3, "the first outdoor approach must keep exactly three encounter beats")

local loggingRoad = beats.Beats[1]
assert(loggingRoad.EncounterSlotId == routeConfig.EncounterSlotIds.LoggingRoad)
assert(loggingRoad.ElitePlacementIntentId == beats.ElitePlacementIntentIds.Ordinary)
assert(#loggingRoad.Waves == 1 and #loggingRoad.Waves[1].Units == 1, "opening contact must remain simple")
assert(loggingRoad.Waves[1].Units[1].ArchetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker)
assert(loggingRoad.Waves[1].Units[1].HordeRoleId == hordeConfig.Roles.Basic.Id)
assert(loggingRoad.Waves[1].Units[1].Count == 2, "opening contact must remain two basic walkers")

local campground = beats.Beats[2]
assert(campground.EncounterSlotId == routeConfig.EncounterSlotIds.Campground)
assert(campground.ElitePlacementIntentId == beats.ElitePlacementIntentIds.Ordinary)
assert(#campground.Waves == 1, "campground pressure should remain one readable mixed wave")
local campgroundRoles = {}
for _, authoredUnit in campground.Waves[1].Units do
	campgroundRoles[authoredUnit.HordeRoleId] = true
end
assert(campgroundRoles[hordeConfig.Roles.Basic.Id] == true, "campground must retain baseline pressure")
assert(campgroundRoles[hordeConfig.Roles.Runner.Id] == true, "campground must introduce runner pressure")
assert(campgroundRoles[hordeConfig.Roles.Crawler.Id] == true, "campground must introduce low-profile pressure")

local roadblock = beats.Beats[3]
assert(roadblock.EncounterSlotId == routeConfig.EncounterSlotIds.MilitaryRoadblock)
assert(
	roadblock.ElitePlacementIntentId == beats.ElitePlacementIntentIds.LateRouteResolverCandidate,
	"roadblock must remain the sole late-route elite candidate"
)
assert(#roadblock.Waves == 2, "roadblock must preserve its two-wave escalation")
assert(roadblock.Waves[2].DelayAfterPreviousSeconds == 5, "roadblock follow-up pacing changed unexpectedly")
local roadblockHasSpitter = false
for _, authoredWave in roadblock.Waves do
	for _, authoredUnit in authoredWave.Units do
		if authoredUnit.ArchetypeId == enemyContracts.EnemyArchetypeIds.BlightSpitter then
			roadblockHasSpitter = true
		end
		assert(
			authoredUnit.ArchetypeId ~= enemyContracts.EnemyArchetypeIds.Progenitor,
			"outdoor route cannot contain boss content"
		)
	end
end
assert(roadblockHasSpitter, "roadblock must introduce the canonical ranged special before the dungeon")
assert(roadblock.RecoveryIntentId == beats.RecoveryIntentIds.ResetBeforeDungeon)
assert(
	roadblock.PostClearRecoverySeconds > campground.PostClearRecoverySeconds,
	"the pre-dungeon roadblock must retain the longest recovery target"
)
assert(
	loggingRoad.TargetDurationMaximumSeconds < campground.TargetDurationMaximumSeconds
		and campground.TargetDurationMaximumSeconds < roadblock.TargetDurationMaximumSeconds,
	"outdoor encounter duration targets must escalate toward First Descent"
)

for _, authoredBeat in beats.Beats do
	assert(authoredBeat.SpawnSourceId == enemyContracts.EnemySpawnSourceIds.AuthoredWave)
	for _, authoredWave in authoredBeat.Waves do
		local population = 0
		for _, authoredUnit in authoredWave.Units do
			population += authoredUnit.Count
		end
		assert(population <= 3, "outdoor onboarding wave population must remain capped at three")
	end
end

local source = fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorEncounterBeatConfig.luau")
assert(string.find(source, "EliteAffixResolver", 1, true) ~= nil, "source must document canonical elite ownership")
assert(string.find(source, "Workspace/", 1, true) == nil, "BA-051 cannot author raw Workspace paths")
assert(
	string.find(source, "RewardSource", 1, true) == nil,
	"BA-051 must not smuggle reward authority into route pacing"
)

print("BA-051 FirstOutdoorEncounterBeatConfig live approach-combat fixture passed")
