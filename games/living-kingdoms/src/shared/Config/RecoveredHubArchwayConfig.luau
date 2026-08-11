--!strict

-- Patch 0.5 property-backed held reconstruction for the Studio-authored
-- Workspace/HubTown/HubArchway group from the checksum-pinned 2026-08-10 revision.
-- Presentation evidence only; no runtime geometry or gameplay authority.

local CommonPartFlags = table.freeze({
	anchored = true,
	canQuery = true,
	canTouch = true,
	castShadow = true,
	reflectance = 0.0,
	transparency = 0.0,
	rotationId = 2,
})

local Config = {
	Version = "P0.5-HUB-ARCHWAY-v1",
	SourcePath = "Workspace/HubTown/HubArchway",
	CoordinateSpaceId = "authored-overworld",
	SemanticContentId = "main_world.hub_core.archway",
	StreamingGroupId = "main_world.hub_core",
	SourceHold = true,
	RuntimeEnabled = false,
	HubTownSourceId = 118,
	RootModelSourceId = 382,
	Evidence = table.freeze({
		SourceRbxlSha256 = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b",
		SourceRbxlBytes = 1808699,
		IdentityRows = 6,
		PropertyBackedRows = 5,
		GeneratedContainerRows = 1,
		PendingNodeRows = 0,
		EvidenceArtifactName = "hub-civic-geometry-summary.json",
	}),
	Parts = table.freeze({
		table.freeze({
			sourceId = 383,
			parentSourceId = 382,
			name = "LeftPillar",
			position = table.freeze({ x = -8.0, y = 7.5, z = -20.0 }),
			size = table.freeze({ x = 2.0, y = 8.0, z = 2.0 }),
			colorBytes = table.freeze({ r = 180, g = 170, b = 160 }),
			materialEnumValue = 784,
			shapeEnumValue = 1,
			canCollide = true,
			flags = CommonPartFlags,
		}),
		table.freeze({
			sourceId = 384,
			parentSourceId = 382,
			name = "RightPillar",
			position = table.freeze({ x = 8.0, y = 7.5, z = -20.0 }),
			size = table.freeze({ x = 2.0, y = 8.0, z = 2.0 }),
			colorBytes = table.freeze({ r = 180, g = 170, b = 160 }),
			materialEnumValue = 784,
			shapeEnumValue = 1,
			canCollide = true,
			flags = CommonPartFlags,
		}),
		table.freeze({
			sourceId = 385,
			parentSourceId = 382,
			name = "TopBeam",
			position = table.freeze({ x = 0.0, y = 12.5, z = -20.0 }),
			size = table.freeze({ x = 20.0, y = 2.0, z = 2.0 }),
			colorBytes = table.freeze({ r = 170, g = 160, b = 150 }),
			materialEnumValue = 784,
			shapeEnumValue = 1,
			canCollide = true,
			flags = CommonPartFlags,
		}),
		table.freeze({
			sourceId = 386,
			parentSourceId = 382,
			name = "ArchCrystal",
			position = table.freeze({ x = 0.0, y = 14.5, z = -20.0 }),
			size = table.freeze({ x = 1.5, y = 1.5, z = 1.5 }),
			colorBytes = table.freeze({ r = 100, g = 200, b = 255 }),
			materialEnumValue = 288,
			shapeEnumValue = 0,
			canCollide = false,
			flags = CommonPartFlags,
		}),
	}),
	PointLight = table.freeze({
		sourceId = 387,
		parentSourceId = 386,
		parent = "ArchCrystal",
		name = "PointLight",
		brightness = 2.0,
		color = table.freeze({ r = 0.3921568691730499, g = 0.7843137383460999, b = 1.0 }),
		enabled = true,
		range = 15.0,
		shadows = false,
	}),
}

return table.freeze(Config)
