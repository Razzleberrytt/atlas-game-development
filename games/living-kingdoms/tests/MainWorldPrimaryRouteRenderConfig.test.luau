--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldPrimaryRouteRenderConfig assertion failed", 2)
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
local recovered = loadConfig("RecoveredWorldPathConfig")
local render = loadConfig("MainWorldPrimaryRouteRenderConfig")

check(render.RouteVersion == route.Version)
check(render.ChunkVersion == chunks.Version)
check(render.StyleSourceVersion == recovered.Version)
check(render.StreamingGroupId == route.StreamingGroupId)
check(render.SourceHold == true)
check(render.RuntimeEnabled == false)
check(render.RenderAssetMapped == true)
check(render.ExpectedChunkCount == chunks.Derived.ChunkCount)
check(render.ExpectedPartCount == #chunks.Chunks)
check(render.ExpectedPartCount == 12)

local style = render.Style
local recoveredStyle = recovered.Route
check(style.colorBytes.r == recoveredStyle.ColorBytes.r)
check(style.colorBytes.g == recoveredStyle.ColorBytes.g)
check(style.colorBytes.b == recoveredStyle.ColorBytes.b)
check(style.materialEnumValue == recoveredStyle.MaterialEnumValue)
near(style.transparency, recoveredStyle.Transparency, "style transparency")
near(style.reflectance, recoveredStyle.Reflectance, "style reflectance")
check(style.shapeEnumValue == recoveredStyle.ShapeEnumValue)
check(style.anchored == recoveredStyle.Anchored)
check(style.canCollide == recoveredStyle.CanCollide)
check(style.canQuery == recoveredStyle.CanQuery)
check(style.canTouch == recoveredStyle.CanTouch)
check(style.castShadow == recoveredStyle.CastShadow)

local model = serde.decode("json", fs.readFile("games/living-kingdoms/" .. render.ModelAssetPath))
check(model.ClassName == "Model")
check(#model.Children == render.ExpectedPartCount)

local byName = {}
for _, child in model.Children do
	check(child.ClassName == "Part", "primary route render child must be a Part")
	check(byName[child.Name] == nil, "duplicate primary route render instance name")
	byName[child.Name] = child
end

for _, chunk in chunks.Chunks do
	local descriptor = render.renderDescriptor(route, chunk)
	local part = byName[descriptor.instanceName]
	check(part ~= nil, "missing primary route render part: " .. descriptor.instanceName)
	check(descriptor.id == chunk.id)
	check(descriptor.streamingGroupId == chunks.StreamingGroupId)
	check(descriptor.seamPolicy == chunks.Policy.SeamPolicy)
	near(descriptor.startProgress, chunk.startProgress, chunk.id .. ".startProgress")
	near(descriptor.endProgress, chunk.endProgress, chunk.id .. ".endProgress")

	local properties = part.Properties
	near(properties.CFrame[1], descriptor.position.x, chunk.id .. ".x")
	near(properties.CFrame[2], descriptor.position.y, chunk.id .. ".y")
	near(properties.CFrame[3], descriptor.position.z, chunk.id .. ".z")
	check(properties.CFrame[4] == 1 and properties.CFrame[8] == 1 and properties.CFrame[12] == 1)
	near(properties.Size[1], descriptor.size.x, chunk.id .. ".size.x")
	near(properties.Size[2], descriptor.size.y, chunk.id .. ".size.y")
	near(properties.Size[3], descriptor.size.z, chunk.id .. ".size.z")
	near(properties.Size[3], chunk.spanStuds, chunk.id .. ".chunkSpan")
	check(properties.Anchored == style.anchored)
	check(properties.CanCollide == style.canCollide)
	check(properties.CanQuery == style.canQuery)
	check(properties.CanTouch == style.canTouch)
	check(properties.CastShadow == style.castShadow)
	check(properties.Material.Enum == style.materialEnumValue)
	check(properties.Shape.Enum == style.shapeEnumValue)
	near(properties.Reflectance, style.reflectance, chunk.id .. ".Reflectance")
	near(properties.Transparency, style.transparency, chunk.id .. ".Transparency")
	near(properties.Color[1], style.colorBytes.r / 255, chunk.id .. ".Color.r")
	near(properties.Color[2], style.colorBytes.g / 255, chunk.id .. ".Color.g")
	near(properties.Color[3], style.colorBytes.b / 255, chunk.id .. ".Color.b")
end

check(render.Rules.GeometryMustDeriveFromRouteControl == true)
check(render.Rules.OnePartPerBoundedChunk == true)
check(render.Rules.PartNameMustEqualChunkSemanticId == true)
check(render.Rules.LegacyWorldPathInstancesForbidden == true)
check(render.Rules.PresentationMayBeRemovedWithoutChangingRouteTruth == true)
check(render.Rules.LocallyAbsentPresentationMayNotChangeConsequentialTruth == true)
check(render.Rules.MappingDoesNotImplyRuntimeActivation == true)
check(render.Rules.ExactStreamingRadiiDefined == false)
check(render.Rules.ModelStreamingModeDefined == false)
check(render.Rules.QualityTierBehaviorDefined == false)

local projectSource = fs.readFile("games/living-kingdoms/main-world.project.json")
local project = serde.decode("json", projectSource)
local routeMapping = project.tree.Workspace.LivingKingdomsMainWorld.Routes.PrimaryRoute
check(routeMapping["$path"] == render.ModelAssetPath)
check(render.ProjectContainerPath == "Workspace/LivingKingdomsMainWorld/Routes/PrimaryRoute")
check(project.placeId == nil and project.gameId == nil and project.servePlaceIds == nil)
check(string.find(projectSource, "WorldPath", 1, true) == nil, "legacy WorldPath must remain unmapped")
check(string.find(projectSource, "PathSegment_", 1, true) == nil, "legacy route slabs must remain unmapped")
