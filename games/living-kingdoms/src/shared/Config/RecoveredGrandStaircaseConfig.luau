--!strict

-- Patch 0.5 property-backed held reconstruction for
-- Workspace/HubTown/GrandStaircase from the 2026-08-10 authored revision.
--
-- Shared properties are factored only where the uploaded RBXL values are
-- identical. Every varying source id, transform, and size remains explicit.
-- This module is presentation evidence only and never creates runtime geometry.

local StoneProperties = table.freeze({
	anchored = true,
	canCollide = true,
	canQuery = true,
	canTouch = true,
	castShadow = true,
	colorBytes = table.freeze({ r = 160, g = 155, b = 145 }),
	materialEnumValue = 784,
	reflectance = 0.0,
	transparency = 0.0,
	shapeEnumValue = 1,
	rotationId = 2,
})

local LanternProperties = table.freeze({
	anchored = true,
	canCollide = true,
	canQuery = true,
	canTouch = true,
	castShadow = true,
	colorBytes = table.freeze({ r = 255, g = 200, b = 100 }),
	materialEnumValue = 288,
	reflectance = 0.0,
	transparency = 0.0,
	shapeEnumValue = 1,
	rotationId = 2,
	size = table.freeze({ x = 0.5, y = 1.5, z = 0.5 }),
})

local LanternLightProperties = table.freeze({
	brightness = 2.0,
	color = table.freeze({ r = 1.0, g = 0.7843137383460999, b = 0.3921568691730499 }),
	enabled = true,
	range = 12.0,
	shadows = false,
})

local Config = {
	Version = "P0.5-GRAND-STAIRCASE-v1",
	SourcePath = "Workspace/HubTown/GrandStaircase",
	CoordinateSpaceId = "authored-overworld",
	SemanticContentId = "main_world.hub_arrival.grand_staircase",
	StreamingGroupId = "main_world.hub_arrival",
	SourceHold = true,
	RuntimeEnabled = false,
	Evidence = table.freeze({
		SourceRbxlSha256 = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b",
		SourceRbxlBytes = 1808699,
		IdentityRows = 35,
		PropertyBackedRows = 34,
		GeneratedContainerRows = 1,
		PendingNodeRows = 0,
		ReviewUnitId = "grand-staircase.review",
	}),
	StepProperties = StoneProperties,
	StepSize = table.freeze({ x = 80.0, y = 2.0, z = 8.0 }),
	Steps = table.freeze({
		table.freeze({ sourceId = 230, name = "Step1", position = table.freeze({ x = 0.0, y = 57.295631408691406, z = -27.75 }) }),
		table.freeze({ sourceId = 231, name = "Step2", position = table.freeze({ x = 0.0, y = 59.295631408691406, z = -19.75 }) }),
		table.freeze({ sourceId = 232, name = "Step3", position = table.freeze({ x = 0.0, y = 61.295631408691406, z = -11.75 }) }),
		table.freeze({ sourceId = 233, name = "Step4", position = table.freeze({ x = 0.0, y = 63.295631408691406, z = -3.75 }) }),
		table.freeze({ sourceId = 234, name = "Step5", position = table.freeze({ x = 0.0, y = 65.2956314086914, z = 4.25 }) }),
		table.freeze({ sourceId = 235, name = "Step6", position = table.freeze({ x = 0.0, y = 67.2956314086914, z = 12.25 }) }),
		table.freeze({ sourceId = 236, name = "Step7", position = table.freeze({ x = 0.0, y = 69.2956314086914, z = 20.25 }) }),
		table.freeze({ sourceId = 237, name = "Step8", position = table.freeze({ x = 0.0, y = 71.29562377929688, z = 28.25 }) }),
		table.freeze({ sourceId = 238, name = "Step9", position = table.freeze({ x = 0.0, y = 73.29562377929688, z = 36.25 }) }),
		table.freeze({ sourceId = 239, name = "Step10", position = table.freeze({ x = 0.0, y = 75.29562377929688, z = 44.25 }) }),
	}),
	RailProperties = StoneProperties,
	Rails = table.freeze({
		table.freeze({ sourceId = 240, name = "Rail-1", position = table.freeze({ x = -42.0, y = 66.2956314086914, z = 4.25 }), size = table.freeze({ x = 5.0, y = 25.0, z = 85.0 }) }),
		table.freeze({ sourceId = 241, name = "RailGlow-1", position = table.freeze({ x = -42.0, y = 78.29562377929688, z = 4.25 }), size = table.freeze({ x = 2.0, y = 3.0, z = 85.0 }) }),
		table.freeze({ sourceId = 242, name = "Rail1", position = table.freeze({ x = 42.0, y = 66.2956314086914, z = 4.25 }), size = table.freeze({ x = 5.0, y = 25.0, z = 85.0 }) }),
		table.freeze({ sourceId = 243, name = "RailGlow1", position = table.freeze({ x = 42.0, y = 78.29562377929688, z = 4.25 }), size = table.freeze({ x = 2.0, y = 3.0, z = 85.0 }) }),
	}),
	LanternProperties = LanternProperties,
	Lanterns = table.freeze({
		table.freeze({ sourceId = 244, lightSourceId = 245, name = "Lantern_L_2", position = table.freeze({ x = -3.0, y = 60.295631408691406, z = -19.75 }) }),
		table.freeze({ sourceId = 246, lightSourceId = 247, name = "Lantern_R_2", position = table.freeze({ x = 3.0, y = 60.295631408691406, z = -19.75 }) }),
		table.freeze({ sourceId = 248, lightSourceId = 249, name = "Lantern_L_4", position = table.freeze({ x = -3.0, y = 64.2956314086914, z = -3.75 }) }),
		table.freeze({ sourceId = 250, lightSourceId = 251, name = "Lantern_R_4", position = table.freeze({ x = 3.0, y = 64.2956314086914, z = -3.75 }) }),
		table.freeze({ sourceId = 252, lightSourceId = 253, name = "Lantern_L_6", position = table.freeze({ x = -3.0, y = 68.2956314086914, z = 12.25 }) }),
		table.freeze({ sourceId = 254, lightSourceId = 255, name = "Lantern_R_6", position = table.freeze({ x = 3.0, y = 68.2956314086914, z = 12.25 }) }),
		table.freeze({ sourceId = 256, lightSourceId = 257, name = "Lantern_L_8", position = table.freeze({ x = -3.0, y = 72.29562377929688, z = 28.25 }) }),
		table.freeze({ sourceId = 258, lightSourceId = 259, name = "Lantern_R_8", position = table.freeze({ x = 3.0, y = 72.29562377929688, z = 28.25 }) }),
		table.freeze({ sourceId = 260, lightSourceId = 261, name = "Lantern_L_10", position = table.freeze({ x = -3.0, y = 76.29562377929688, z = 44.25 }) }),
		table.freeze({ sourceId = 262, lightSourceId = 263, name = "Lantern_R_10", position = table.freeze({ x = 3.0, y = 76.29562377929688, z = 44.25 }) }),
	}),
	LanternLightProperties = LanternLightProperties,
}

return table.freeze(Config)
