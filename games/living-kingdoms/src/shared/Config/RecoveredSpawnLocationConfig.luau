--!strict

-- BA-005 property-backed reconstruction contract for the Studio-authored
-- Workspace/SpawnLocation instance.
--
-- This module preserves the original Main World arrival marker as dormant
-- authored-overworld evidence. It does not spawn, move, or teleport players and
-- does not replace the current operation insertion flow.

local Config = {
	Version = "BA-005-SPAWN-LOCATION-v1",
	SourceContentId = "spawn.main_world.arrival",
	SourcePath = "Workspace/SpawnLocation",
	CoordinateSpaceId = "authored-overworld",
	SourceHold = true,
	RuntimeEnabled = false,
	Evidence = table.freeze({
		SourceRbxlSha256 = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16",
		SourceId = 117,
		IdentityRows = 1,
		PropertyBackedRows = 1,
		PendingNodeRows = 0,
	}),
	Spawn = table.freeze({
		name = "SpawnLocation",
		sourceId = 117,
		position = table.freeze({ x = 0.0, y = 7.0, z = 30.0 }),
		rotationId = 2,
		size = table.freeze({ x = 6.0, y = 1.0, z = 6.0 }),
		colorBytes = table.freeze({ r = 255, g = 220, b = 150 }),
		materialEnumValue = 288,
		reflectance = 0.0,
		transparency = 0.0,
		shapeEnumValue = 1,
		anchored = true,
		canCollide = true,
		canQuery = true,
		canTouch = true,
		castShadow = true,
		enabled = true,
		neutral = true,
		teamColorEnumValue = 194,
	}),
	Ownership = table.freeze({
		DedicatedOverworldLifecycleRequired = true,
		CurrentOperationInsertionUnaffected = true,
		PlayerMovementAuthority = false,
		TeleportAuthority = false,
		RuntimeEnabled = false,
	}),
}

return table.freeze(Config)
