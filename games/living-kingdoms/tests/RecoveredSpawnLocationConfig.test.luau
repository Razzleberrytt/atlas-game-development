--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredSpawnLocationConfig assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredSpawnLocationConfig.luau"), {
	debugName = "RecoveredSpawnLocationConfig",
	injectGlobals = true,
})()

check(config.Version == "BA-005-SPAWN-LOCATION-v1")
check(config.SourceContentId == "spawn.main_world.arrival")
check(config.SourcePath == "Workspace/SpawnLocation")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)

check(config.Evidence.SourceRbxlSha256 == "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16")
check(config.Evidence.SourceId == 117)
check(config.Evidence.IdentityRows == 1)
check(config.Evidence.PropertyBackedRows == 1)
check(config.Evidence.PendingNodeRows == 0)

local spawn = config.Spawn
check(spawn.name == "SpawnLocation")
check(spawn.sourceId == 117)
check(spawn.position.x == 0.0 and spawn.position.y == 7.0 and spawn.position.z == 30.0)
check(spawn.rotationId == 2)
check(spawn.size.x == 6.0 and spawn.size.y == 1.0 and spawn.size.z == 6.0)
check(spawn.colorBytes.r == 255 and spawn.colorBytes.g == 220 and spawn.colorBytes.b == 150)
check(spawn.materialEnumValue == 288)
check(spawn.reflectance == 0.0)
check(spawn.transparency == 0.0)
check(spawn.shapeEnumValue == 1)
check(spawn.anchored == true)
check(spawn.canCollide == true)
check(spawn.canQuery == true)
check(spawn.canTouch == true)
check(spawn.castShadow == true)
check(spawn.enabled == true)
check(spawn.neutral == true)
check(spawn.teamColorEnumValue == 194)

check(config.Ownership.DedicatedOverworldLifecycleRequired == true)
check(config.Ownership.CurrentOperationInsertionUnaffected == true)
check(config.Ownership.PlayerMovementAuthority == false)
check(config.Ownership.TeleportAuthority == false)
check(config.Ownership.RuntimeEnabled == false)

local worldContentSource = fs.readFile("games/living-kingdoms/src/shared/Config/WorldContentConfig.luau")
local heldArrivalDescriptor = table.concat({
	'id = "spawn.main_world.arrival",',
	'\t\tkind = "spawn",',
	'\t\tdisplayName = "Main World Arrival",',
	'\t\tlegacyAliases = table.freeze({ "SpawnLocation" }),',
	"\t\tactive = false,",
}, "\n")
check(string.find(worldContentSource, heldArrivalDescriptor, 1, true) ~= nil)

local placementSource = fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredWorldPlacementConfig.luau")
check(string.find(placementSource, '"Workspace/SpawnLocation"', 1, true) ~= nil)
check(string.find(placementSource, 'CoordinateSpaceId = "authored-overworld"', 1, true) ~= nil)
check(string.find(placementSource, "PreserveAbsoluteCoordinates = true", 1, true) ~= nil)
