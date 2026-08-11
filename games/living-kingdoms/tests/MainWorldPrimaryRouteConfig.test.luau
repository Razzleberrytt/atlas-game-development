--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldPrimaryRouteConfig assertion failed", 2)
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

local recovered = loadConfig("RecoveredWorldPathConfig")
local route = loadConfig("MainWorldPrimaryRouteConfig")

check(route.ContentId == recovered.SourceContentId)
check(route.SourceContractVersion == recovered.Version)
check(route.SourcePath == recovered.SourcePath)
check(route.CoordinateSpaceId == "authored-overworld")
check(route.StreamingGroupId == "main_world.route.primary")
check(route.SourceHold == true)
check(route.RuntimeEnabled == false)
check(route.LegacySegmentInstancesAuthoritative == false)
check(route.RenderChunksDefined == false)
check(route.SourceEvidence.SegmentCount == recovered.Evidence.SegmentCount)
near(
	route.SourceEvidence.MaximumCanonicalizationDriftStuds,
	recovered.Evidence.MaximumCanonicalizationDriftStuds,
	"canonicalization drift"
)

local startPoint = route.ControlPoints[1]
local endPoint = route.ControlPoints[2]
check(startPoint.id == "route.world.primary.start")
check(endPoint.id == "route.world.primary.end")
near(startPoint.position.x, recovered.Route.StartCenter.x, "start.x")
near(startPoint.position.y, recovered.Route.StartCenter.y, "start.y")
near(startPoint.position.z, recovered.Route.StartCenter.z, "start.z")
near(endPoint.position.x, recovered.Route.EndCenter.x, "end.x")
near(endPoint.position.y, recovered.Route.EndCenter.y, "end.y")
near(endPoint.position.z, recovered.Route.EndCenter.z, "end.z")
near(route.Corridor.widthStuds, recovered.Route.SegmentSize.x, "corridor width")
near(route.Corridor.sourceSurfaceThicknessStuds, recovered.Route.SegmentSize.y, "source surface thickness")
check(route.Corridor.direction.x == 0.0)
check(route.Corridor.direction.y == 0.0)
check(route.Corridor.direction.z == -1.0)

for index = 1, recovered.Evidence.SegmentCount do
	local recoveredCenter = recovered.segmentCenter(index)
	local progress = (index - 1) / (recovered.Evidence.SegmentCount - 1)
	local routePoint = route.pointAt(progress)
	near(routePoint.x, recoveredCenter.x, "segment x")
	near(routePoint.y, recoveredCenter.y, "segment y")
	near(routePoint.z, recoveredCenter.z, "segment z")
end

check(route.Rules.ControlTruthMustNotDependOnLegacySlabInstances == true)
check(route.Rules.PreserveRecoveredEndpointsOneToOne == true)
check(route.Rules.PreserveRecoveredCorridorWidth == true)
check(route.Rules.RenderChunkPolicyMustBeDefinedBeforeRuntimeRendering == true)
check(route.Rules.LocallyAbsentRenderChunksMustNotChangeRouteTruth == true)
check(route.Rules.DoNotInferDestinationOrGameplayMeaningFromLegacyGeometry == true)

local projectSource = fs.readFile("games/living-kingdoms/main-world.project.json")
check(string.find(projectSource, "WorldPath", 1, true) == nil, "legacy WorldPath must not be mapped into Main World")
check(string.find(projectSource, "PathSegment_", 1, true) == nil, "legacy slabs must not be mapped into Main World")
