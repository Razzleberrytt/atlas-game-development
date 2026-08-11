--!strict

-- Patch 0.5 source-managed presentation contract for the primary Main World
-- route. Geometry is derived from the stable route control + bounded chunk
-- contracts; recovered WorldPath style is preserved without resurrecting its
-- 189 legacy Parts. The asset is mapped into the dedicated unpublished place,
-- while runtime activation and BA-014 streaming/performance choices stay held.

local Config = {
	Version = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-RENDER-v1",
	RouteVersion = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-v1",
	ChunkVersion = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-CHUNKS-v1",
	StyleSourceVersion = "BA-005-WORLDPATH-v1",
	ContentId = "route.world.primary.render",
	StreamingGroupId = "main_world.primary_route",
	SourceHold = true,
	RuntimeEnabled = false,
	RenderAssetMapped = true,
	ModelAssetPath = "assets/visual/world/primary-route/MainWorldPrimaryRoute.model.json",
	ProjectContainerPath = "Workspace/LivingKingdomsMainWorld/Routes/PrimaryRoute",
	ExpectedChunkCount = 12,
	ExpectedPartCount = 12,
	Style = table.freeze({
		colorBytes = table.freeze({ r = 100, g = 95, b = 90 }),
		materialEnumValue = 880,
		transparency = 0.0,
		reflectance = 0.0,
		shapeEnumValue = 1,
		anchored = true,
		canCollide = true,
		canQuery = true,
		canTouch = true,
		castShadow = true,
	}),
	Rules = table.freeze({
		GeometryMustDeriveFromRouteControl = true,
		OnePartPerBoundedChunk = true,
		PartNameMustEqualChunkSemanticId = true,
		LegacyWorldPathInstancesForbidden = true,
		PresentationMayBeRemovedWithoutChangingRouteTruth = true,
		LocallyAbsentPresentationMayNotChangeConsequentialTruth = true,
		MappingDoesNotImplyRuntimeActivation = true,
		ExactStreamingRadiiDefined = false,
		ModelStreamingModeDefined = false,
		QualityTierBehaviorDefined = false,
	}),
}

function Config.renderDescriptor(route: any, chunk: any): any
	assert(route.Version == Config.RouteVersion, "primary route render route-version drift")
	assert(chunk.streamingGroupId == Config.StreamingGroupId, "primary route render streaming-group drift")
	assert(chunk.seamPolicy == "shared-control-boundary", "primary route render seam-policy drift")

	local startPoint = route.pointAt(chunk.startProgress)
	local endPoint = route.pointAt(chunk.endProgress)
	local spanStuds = math.abs(endPoint.z - startPoint.z)

	return table.freeze({
		id = chunk.id,
		instanceName = chunk.id,
		streamingGroupId = chunk.streamingGroupId,
		position = table.freeze({
			x = (startPoint.x + endPoint.x) / 2,
			y = (startPoint.y + endPoint.y) / 2,
			z = (startPoint.z + endPoint.z) / 2,
		}),
		size = table.freeze({
			x = route.Corridor.widthStuds,
			y = route.Corridor.sourceSurfaceThicknessStuds,
			z = spanStuds,
		}),
		startProgress = chunk.startProgress,
		endProgress = chunk.endProgress,
		seamPolicy = chunk.seamPolicy,
	})
end

return table.freeze(Config)
