--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

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

local function childByName(parent: any, name: string): any?
	for _, child in parent.Children or {} do
		if child.Name == name then
			return child
		end
	end
	return nil
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

local project = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
local routesPath = "assets/recovered-world/models/main-world-studio-2026-08-11/MainWorld-Routes.model.json"
local routesMapping = project.tree.Workspace.LivingKingdomsMainWorld.Routes
check(routesMapping["$path"] == routesPath, "Routes must map the canonical imported Studio snapshot")

local routesModelSource = fs.readFile("games/living-kingdoms/" .. routesPath)
local routesModel = serde.decode("json", routesModelSource)
check(routesModel.ClassName == "Folder", "imported Routes snapshot must preserve its Folder root")
local primaryRoute = childByName(routesModel, "PrimaryRoute")
check(primaryRoute ~= nil and primaryRoute.ClassName == "Model", "imported primary route mapping missing")
check(#primaryRoute.Children == #chunks.Chunks, "imported primary route chunk count drift")
for _, chunk in chunks.Chunks do
	local renderChunk = childByName(primaryRoute, chunk.id)
	check(renderChunk ~= nil, "imported route chunk missing: " .. chunk.id)
	check(renderChunk.ClassName == "Part", "imported route chunk must remain a Part: " .. chunk.id)
	check(renderChunk.Properties.Anchored == true, "imported route chunk must remain anchored: " .. chunk.id)
end
check(string.find(routesModelSource, "WorldPath", 1, true) == nil, "legacy WorldPath must remain absent")
check(string.find(routesModelSource, "PathSegment_", 1, true) == nil, "legacy slabs must remain absent")
