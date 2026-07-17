--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "landmark accent source audit failed", 2)
	end
end

local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/LandmarkAccentPresentationResolver.luau")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/LandmarkAccentPresentationFactory.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/LandmarkAccentPresentationController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

for _, style in { "RangerStation", "MilitaryRoadblock", "Campground", "CreekCrossing", "RockyOverlook" } do
	check(string.find(resolver, style .. ' = "' .. style .. '"', 1, true) ~= nil, "missing safe landmark style")
end
check(string.find(resolver, "LookoutTower", 1, true) == nil, "resolver must not select the objective-area lookout")
check(
	string.find(resolver, "ExtractionClearing", 1, true) == nil,
	"resolver must not select the future extraction landmark"
)

check(string.find(factory, 'PresentationModelName = "LandmarkSilhouettePresentation"', 1, true) ~= nil)
check(string.find(factory, "MaximumPresentationParts = 22", 1, true) ~= nil)
check(string.find(factory, "WorldMaterialLanguageConfig", 1, true) ~= nil, "factory must use the shared material language")
for _, anchorName in
	{
		"Roof",
		"RadioMast",
		"CheckpointCabin",
		"RoadblockEmergencyLight",
		"AbandonedTent1",
		"AbandonedTent2",
		"DeadFire",
		"WashedOutWarning",
		"FallenCreekTree",
		"BrokenGuardRail",
		"ReadableCliffEdge",
	}
do
	check(string.find(factory, 'basePart(model, "' .. anchorName .. '")', 1, true) ~= nil, "missing landmark anchor")
	check(string.find(controller, anchorName .. " = true", 1, true) ~= nil, "controller must track every anchor")
end

local _, makeAccentCount = string.gsub(factory, "makeAccent%(", "")
check(makeAccentCount == 23, "factory must define one helper and exactly twenty-two bounded accent parts")
check(string.find(factory, "part.Massless = true", 1, true) ~= nil)
check(string.find(factory, "part.CanCollide = false", 1, true) ~= nil)
check(string.find(factory, "part.CanTouch = false", 1, true) ~= nil)
check(string.find(factory, "part.CanQuery = false", 1, true) ~= nil)
check(string.find(factory, 'Instance.new("WeldConstraint")', 1, true) ~= nil)
check(string.find(factory, 'Instance.new("PointLight")', 1, true) == nil, "accents must add no lights")
check(string.find(factory, 'Instance.new("SpotLight")', 1, true) == nil, "accents must add no lights")
check(string.find(factory, 'Instance.new("SurfaceGui")', 1, true) == nil, "accents must add no text UI")
check(string.find(factory, 'Instance.new("BillboardGui")', 1, true) == nil, "accents must add no destination UI")

check(string.find(controller, "Workspace.DescendantAdded:Connect", 1, true) ~= nil)
check(string.find(controller, "Workspace.DescendantRemoving:Connect", 1, true) ~= nil)
local _, connectionCount = string.gsub(controller, ":Connect%(", "")
check(connectionCount == 2, "landmark accents must use exactly two global connections")
check(string.find(controller, "OnClientEvent", 1, true) == nil)
check(string.find(controller, "FireServer", 1, true) == nil)
check(string.find(controller, "RemoteEvent", 1, true) == nil)
check(string.find(controller, "Heartbeat", 1, true) == nil)
check(string.find(controller, "RenderStepped", 1, true) == nil)
check(string.find(controller, "task.", 1, true) == nil)
check(string.find(controller, "while true", 1, true) == nil, "controller must not contain an unbounded loop")
check(string.find(controller, "Humanoid", 1, true) == nil)
check(string.find(controller, "CanCollide", 1, true) == nil)
check(string.find(controller, "CFrame =", 1, true) == nil)
check(string.find(controller, "Size =", 1, true) == nil)
check(string.find(controller, "RespawnLocation", 1, true) == nil)
check(string.find(controller, "MissionNetwork", 1, true) == nil)

check(string.find(bootstrap, "LandmarkAccentPresentationController", 1, true) ~= nil)
check(string.find(bootstrap, "LandmarkAccentPresentationController.start()", 1, true) ~= nil)

print("landmark accent source audit passed")
