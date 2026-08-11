--!strict

-- Patch 0.5 held authoring chunks for the source-managed primary route.
-- BA-013 sets a 64–128 stud route-per-chunk target. This contract derives the
-- largest source-aligned chunk that fits that ceiling, then covers the route
-- with deterministic semantic chunks. It does not create or map render assets.

local MinimumChunkSpanStuds = 64.0
local MaximumChunkSpanStuds = 128.0
local SourceSegmentCount = 189
local SourceIntervalCount = SourceSegmentCount - 1
local StartZ = -2.9629626274108887
local EndZ = -1500.0
local TotalSpanStuds = math.abs(EndZ - StartZ)
local SourceIntervalSpanStuds = TotalSpanStuds / SourceIntervalCount
local IntervalsPerFullChunk = math.floor(MaximumChunkSpanStuds / SourceIntervalSpanStuds)
local ChunkCount = math.ceil(SourceIntervalCount / IntervalsPerFullChunk)

assert(IntervalsPerFullChunk >= 1, "primary route chunk ceiling is smaller than one source interval")

local chunks = {}
local startInterval = 0
for index = 1, ChunkCount do
	local endInterval = math.min(startInterval + IntervalsPerFullChunk, SourceIntervalCount)
	local spanStuds = (endInterval - startInterval) * SourceIntervalSpanStuds
	assert(spanStuds <= MaximumChunkSpanStuds + 1e-8, "primary route chunk exceeds BA-013 ceiling")
	assert(spanStuds >= MinimumChunkSpanStuds - 1e-8, "primary route chunk falls below BA-013 target")

	chunks[index] = table.freeze({
		id = string.format("main_world.primary_route.chunk.%03d", index),
		streamingGroupId = "main_world.primary_route",
		startSourceSegmentIndex = startInterval + 1,
		endSourceSegmentIndex = endInterval + 1,
		startProgress = startInterval / SourceIntervalCount,
		endProgress = endInterval / SourceIntervalCount,
		spanStuds = spanStuds,
		seamPolicy = "shared-control-boundary",
		renderAssetMapped = false,
	})
	startInterval = endInterval
end

local Config = {
	Version = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-CHUNKS-v1",
	RouteVersion = "P0.5-MAIN-WORLD-PRIMARY-ROUTE-v1",
	ContentId = "route.world.primary.render_chunks",
	StreamingGroupId = "main_world.primary_route",
	SourceHold = true,
	RuntimeEnabled = false,
	RenderAssetsMapped = false,
	Policy = table.freeze({
		MinimumChunkSpanStuds = MinimumChunkSpanStuds,
		MaximumChunkSpanStuds = MaximumChunkSpanStuds,
		SplitEarlierAtSemanticBeat = true,
		SeamPolicy = "shared-control-boundary",
		ExactStreamingRadiiMeasuredLater = true,
	}),
	Derived = table.freeze({
		SourceIntervalCount = SourceIntervalCount,
		SourceIntervalSpanStuds = SourceIntervalSpanStuds,
		IntervalsPerFullChunk = IntervalsPerFullChunk,
		ChunkCount = ChunkCount,
	}),
	Chunks = table.freeze(chunks),
	Rules = table.freeze({
		RouteTruthIndependentOfChunkPresence = true,
		ChunkIdsStableAndDeterministic = true,
		NoLegacySlabAuthoringSurface = true,
		NoRuntimeRenderingBeforeAssetsAndStreamingEvidence = true,
		SemanticBeatMaySplitEarlierWithinBudget = true,
	}),
}

function Config.chunkById(id: string): any?
	for _, chunk in Config.Chunks do
		if chunk.id == id then
			return chunk
		end
	end
	return nil
end

return table.freeze(Config)
