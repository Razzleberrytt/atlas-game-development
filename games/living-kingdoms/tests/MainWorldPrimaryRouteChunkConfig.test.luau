--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldPrimaryRouteChunkConfig assertion failed", 2)
	end
end

local function near(actual: number, expected: number, label: string)
	check(math.abs(actual - expected) <= 1e-8, label .. " mismatch")
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local route = loadConfig("MainWorldPrimaryRouteConfig")
local chunks = loadConfig("MainWorldPrimaryRouteChunkConfig")

check(chunks.Version == route.RenderChunkPolicyVersion)
check(chunks.RouteVersion == route.Version)
check(chunks.StreamingGroupId == route.StreamingGroupId)
check(chunks.StreamingGroupId == "main_world.primary_route")
check(chunks.SourceHold == true)
check(chunks.RuntimeEnabled == false)
check(chunks.RenderAssetsMapped == true)
check(chunks.Policy.MinimumChunkSpanStuds == 64.0)
check(chunks.Policy.MaximumChunkSpanStuds == 128.0)
check(chunks.Policy.SplitEarlierAtSemanticBeat == true)
check(chunks.Policy.SeamPolicy == "shared-control-boundary")
check(chunks.Policy.ExactStreamingRadiiMeasuredLater == true)
check(chunks.Derived.SourceIntervalCount == route.SourceEvidence.SegmentCount - 1)
check(chunks.Derived.IntervalsPerFullChunk == 16)
check(chunks.Derived.ChunkCount == 12)
check(#chunks.Chunks == chunks.Derived.ChunkCount)

local previousEndProgress = 0.0
local previousEndSegment = 1
for index, chunk in chunks.Chunks do
	check(chunk.id == string.format("main_world.primary_route.chunk.%03d", index))
	check(chunk.streamingGroupId == chunks.StreamingGroupId)
	check(chunk.renderAssetMapped == true)
	check(chunk.seamPolicy == chunks.Policy.SeamPolicy)
	check(chunk.spanStuds >= chunks.Policy.MinimumChunkSpanStuds - 1e-8)
	check(chunk.spanStuds <= chunks.Policy.MaximumChunkSpanStuds + 1e-8)
	near(chunk.startProgress, previousEndProgress, "chunk start continuity")
	check(chunk.startSourceSegmentIndex == previousEndSegment)
	check(chunk.endProgress > chunk.startProgress)
	check(chunk.endSourceSegmentIndex > chunk.startSourceSegmentIndex)
	check(chunks.chunkById(chunk.id) == chunk)

	local startPoint = route.pointAt(chunk.startProgress)
	local endPoint = route.pointAt(chunk.endProgress)
	near(math.abs(endPoint.z - startPoint.z), chunk.spanStuds, "chunk span")

	previousEndProgress = chunk.endProgress
	previousEndSegment = chunk.endSourceSegmentIndex
end

near(chunks.Chunks[1].startProgress, 0.0, "first start")
near(chunks.Chunks[#chunks.Chunks].endProgress, 1.0, "last end")
check(chunks.Chunks[1].startSourceSegmentIndex == 1)
check(chunks.Chunks[#chunks.Chunks].endSourceSegmentIndex == route.SourceEvidence.SegmentCount)
check(chunks.chunkById("main_world.primary_route.chunk.999") == nil)

check(chunks.Rules.RouteTruthIndependentOfChunkPresence == true)
check(chunks.Rules.ChunkIdsStableAndDeterministic == true)
check(chunks.Rules.NoLegacySlabAuthoringSurface == true)
check(chunks.Rules.NoRuntimeRenderingBeforeAssetsAndStreamingEvidence == true)
check(chunks.Rules.SemanticBeatMaySplitEarlierWithinBudget == true)

local projectSource = fs.readFile("games/living-kingdoms/main-world.project.json")
check(string.find(projectSource, '"Routes"', 1, true) ~= nil, "dedicated Main World must expose route hierarchy")
check(string.find(projectSource, '"PrimaryRoute"', 1, true) ~= nil, "primary route mapping missing")
check(
	string.find(projectSource, "assets/visual/world/primary-route/MainWorldPrimaryRoute.model.json", 1, true) ~= nil,
	"primary route source asset mapping missing"
)
check(string.find(projectSource, "WorldPath", 1, true) == nil, "legacy WorldPath must remain unmapped")
check(string.find(projectSource, "PathSegment_", 1, true) == nil, "legacy slabs must remain unmapped")
