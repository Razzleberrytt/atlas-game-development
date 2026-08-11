--!strict

-- Patch 0.5 source-managed replacement for the 189 recovered WorldPath slabs.
-- The legacy slab sequence is evidence, not route authority. This contract keeps
-- only the exact recovered line/corridor truth needed for bounded rendering.

local Config = {
	Version = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-v1",
	ContentId = "route.world.primary",
	SourceContractVersion = "BA-005-WORLDPATH-v1",
	SourcePath = "Workspace/WorldPath",
	CoordinateSpaceId = "authored-overworld",
	StreamingGroupId = "main_world.primary_route",
	SourceHold = true,
	RuntimeEnabled = false,
	LegacySegmentInstancesAuthoritative = false,
	RenderChunksDefined = true,
	RenderChunkPolicyVersion = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-CHUNKS-v1",
	RenderAssetsMapped = false,
	ControlPoints = table.freeze({
		table.freeze({
			id = "route.world.primary.start",
			position = table.freeze({ x = 0.0, y = 0.10000000149011612, z = -2.9629626274108887 }),
		}),
		table.freeze({
			id = "route.world.primary.end",
			position = table.freeze({ x = 0.0, y = 0.10000000149011612, z = -1500.0 }),
		}),
	}),
	Corridor = table.freeze({
		widthStuds = 6.0,
		sourceSurfaceThicknessStuds = 0.20000000298023224,
		direction = table.freeze({ x = 0.0, y = 0.0, z = -1.0 }),
	}),
	SourceEvidence = table.freeze({
		SegmentCount = 189,
		MaximumCanonicalizationDriftStuds = 0.00011,
	}),
	Rules = table.freeze({
		ControlTruthMustNotDependOnLegacySlabInstances = true,
		PreserveRecoveredEndpointsOneToOne = true,
		PreserveRecoveredCorridorWidth = true,
		RenderChunkPolicyMustBeDefinedBeforeRuntimeRendering = true,
		LocallyAbsentRenderChunksMustNotChangeRouteTruth = true,
		DoNotInferDestinationOrGameplayMeaningFromLegacyGeometry = true,
	}),
}

function Config.pointAt(progress: number): { x: number, y: number, z: number }
	assert(progress >= 0 and progress <= 1, "Main World primary route progress out of range")
	local startPosition = Config.ControlPoints[1].position
	local endPosition = Config.ControlPoints[2].position
	return {
		x = startPosition.x + (endPosition.x - startPosition.x) * progress,
		y = startPosition.y + (endPosition.y - startPosition.y) * progress,
		z = startPosition.z + (endPosition.z - startPosition.z) * progress,
	}
end

return table.freeze(Config)
