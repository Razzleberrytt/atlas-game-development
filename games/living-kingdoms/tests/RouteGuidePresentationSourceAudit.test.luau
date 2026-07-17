--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/RouteEdgePresentationResolver.luau")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/RouteGuidePresentationFactory.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/RouteGuidePresentationController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")
local readme = fs.readFile("games/living-kingdoms/assets/visual/world/route-guides/README.md")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/world/route-guides/asset-manifest.json")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")
local inventory = fs.readFile("docs/specifications/visual-placeholder-inventory.md")

for _, required in {
	'export type RouteStyleId = "Hidden" | "Road" | "Trail"',
	'startsWith(facts.segmentName, "LoggingRoad")',
	'startsWith(facts.segmentName, "SwitchbackTrail")',
	'local offset = widthStuds / 2 + 1.1',
	'local offset = widthStuds / 2 + 0.8',
	'return HIDDEN',
} do
	assertThat(string.find(resolver, required, 1, true) ~= nil, "route resolver missing: " .. required)
end
assertThat(not string.find(resolver, "ExtractionClearing", 1, true), "resolver must not create extraction-clearing behavior")
assertThat(not string.find(resolver, "LandmarkId", 1, true), "resolver must not consume landmark identity")

for _, required in {
	'model.Name = "RouteGuidePresentation"',
	'VisualAssetContracts.AssetKeys.WorldLoggingRoad',
	'model:SetAttribute("TruthSource", "ExistingAuthoredRouteSegment")',
	'"LeftGuidePost"',
	'"RightGuidePost"',
	'post.CanCollide = false',
	'post.CanTouch = false',
	'post.CanQuery = false',
	'Instance.new("WeldConstraint")',
} do
	assertThat(string.find(factory, required, 1, true) ~= nil, "route factory missing: " .. required)
end
local makePostCount = select(2, string.gsub(factory, "makePost%(", ""))
assertThat(makePostCount == 3, "factory must contain one helper plus exactly two guide-post declarations")
for _, forbidden in { "TextLabel", "SurfaceGui", "BillboardGui", "PointLight", "SpotLight", "ExtractionClearing" } do
	assertThat(not string.find(factory, forbidden, 1, true), "route factory contains hidden-information or label token: " .. forbidden)
end

for _, required in {
	'Workspace:GetDescendants()',
	'Workspace.DescendantAdded:Connect(inspect)',
	'Workspace.DescendantRemoving:Connect(onRemoving)',
	'RouteEdgePresentationResolver.resolve',
	'RouteGuidePresentationFactory.create',
	'rig.model.Parent = instance',
	'removeSegment(segment)',
} do
	assertThat(string.find(controller, required, 1, true) ~= nil, "route controller missing: " .. required)
end
local connectionCount = select(2, string.gsub(controller, ":Connect%(", ""))
assertThat(connectionCount == 2, "route controller must use exactly two global connections")
for _, forbidden in {
	"ReplicatedStorage",
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"InvokeServer",
	"RunService",
	"Heartbeat",
	"RenderStepped",
	"Stepped",
	"task.",
	"LocalTransparencyModifier",
	"CanCollide =",
	"CFrame =",
	"Size =",
	"Position =",
	"SetNetworkOwner",
	"PrimaryNavigationRoute =",
	"LandmarkId",
	"DisplayName",
	"ExtractionClearing",
} do
	assertThat(not string.find(controller, forbidden, 1, true), "route controller contains authority token: " .. forbidden)
end

assertThat(string.find(bootstrap, "RouteGuidePresentationController.start()", 1, true) ~= nil, "route controller must start")
assertThat(string.find(manifest, '"partsPerSegment": 2', 1, true) ~= nil, "per-segment part bound missing")
assertThat(string.find(manifest, '"maximumBoundSegments": 11', 1, true) ~= nil, "segment bound missing")
assertThat(string.find(manifest, '"maximumPresentationParts": 22', 1, true) ~= nil, "total part bound missing")
assertThat(string.find(manifest, '"globalConnections": 2', 1, true) ~= nil, "connection bound missing")
assertThat(string.find(manifest, '"perSegmentConnections": 0', 1, true) ~= nil, "per-segment connection bound missing")
assertThat(string.find(manifest, '"newRemoteCount": 0', 1, true) ~= nil, "remote bound missing")
assertThat(string.find(manifest, '"createsDestinationLabels": false', 1, true) ~= nil, "destination-label exclusion missing")
assertThat(string.find(manifest, '"createsExtractionCue": false', 1, true) ~= nil, "extraction-cue exclusion missing")
assertThat(string.find(manifest, '"studioApproved": false', 1, true) ~= nil, "Studio gate must remain pending")
assertThat(string.find(readme, "Roblox Studio", 1, true) ~= nil, "README must preserve Studio gate")
assertThat(string.find(readme, "No text labels", 1, true) ~= nil, "README must preserve hidden-information rule")
assertThat(string.find(registry, '"RouteGuidePresentation"', 1, true) ~= nil, "registry route root missing")
assertThat(string.find(registry, '"src/client/Controllers/RouteGuidePresentationController.luau"', 1, true) ~= nil, "registry owner missing")
assertThat(string.find(roadmap, "capped at 22 parts", 1, true) ~= nil, "VIS-0105 route status missing")
assertThat(string.find(inventory, "RouteGuidePresentationController", 1, true) ~= nil, "placeholder inventory owner missing")

print("RouteGuidePresentationSourceAudit: static geography, bounded posts, hidden information, cleanup, authority, and Studio gates passed")
