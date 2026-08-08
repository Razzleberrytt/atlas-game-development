--!strict

-- BA-005: canonicalized reconstruction contract for the Studio-authored
-- Workspace/WorldPath evidence. The original place used 189 identical Parts in
-- a straight line. We preserve the recovered geometry mathematically instead of
-- making 189 legacy instances authoritative.
--
-- This module is deliberately inert. Nothing in the runtime requires it yet.

local SegmentCount = 189
local FirstCenterZ = -2.9629626274108887
local LastCenterZ = -1500.0
local StepZ = (LastCenterZ - FirstCenterZ) / (SegmentCount - 1)

local Config = {
	Version = "BA-005-WORLDPATH-v1",
	SourceContentId = "route.world.primary",
	SourcePath = "Workspace/WorldPath",
	SourceHold = true,
	RuntimeEnabled = false,
	Evidence = table.freeze({
		SourceRbxlSha256 = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16",
		SegmentCount = SegmentCount,
		FirstLegacyName = "PathSegment_1",
		LastLegacyName = "PathSegment_189",
		MaximumCanonicalizationDriftStuds = 0.00011,
	}),
	Route = table.freeze({
		StartCenter = table.freeze({ x = 0.0, y = 0.10000000149011612, z = FirstCenterZ }),
		EndCenter = table.freeze({ x = 0.0, y = 0.10000000149011612, z = LastCenterZ }),
		StepZ = StepZ,
		SegmentSize = table.freeze({ x = 6.0, y = 0.20000000298023224, z = 6.0 }),
		RotationId = 2,
		ColorBytes = table.freeze({ r = 100, g = 95, b = 90 }),
		MaterialEnumValue = 880,
		Transparency = 0.0,
		Reflectance = 0.0,
		ShapeEnumValue = 1,
		Anchored = true,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = true,
	}),
}

function Config.segmentCenter(index: number): { x: number, y: number, z: number }
	assert(index % 1 == 0 and index >= 1 and index <= SegmentCount, "WorldPath segment index out of range")
	return {
		x = Config.Route.StartCenter.x,
		y = Config.Route.StartCenter.y,
		z = FirstCenterZ + StepZ * (index - 1),
	}
end

return table.freeze(Config)
