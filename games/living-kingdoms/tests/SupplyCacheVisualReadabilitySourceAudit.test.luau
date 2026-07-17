--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = fs.readFile("games/living-kingdoms/src/client/Presentation/SupplyCachePresentationConfig.luau")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/SupplyCachePresentationFactory.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/AmmunitionCachePresentationController.luau")
local service = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")
local readme = fs.readFile("games/living-kingdoms/assets/visual/supply/ammunition-cache/README.md")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/supply/ammunition-cache/asset-manifest.json")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")
local inventory = fs.readFile("docs/specifications/visual-placeholder-inventory.md")

for _, required in {
	"MaximumPartsPerCache = 13",
	"SupplyCacheBody",
	"SupplyCacheSignalBand",
	"SupplyCacheEmptyTray",
	"ConsumedRotationDegrees = vector(55, 0, 0)",
} do
	assertThat(string.find(config, required, 1, true) ~= nil, "supply cache config missing: " .. required)
end

for _, required in {
	'Instance.new("WeldConstraint")',
	'Instance.new("Motor6D")',
	'motor.Name = "SupplyCacheLidMotor"',
	"part.Massless = true",
	"part.CanCollide = false",
	"part.CanTouch = false",
	"part.CanQuery = false",
	"Factory.applyState",
	'rig.label.Text = if consumed then "EMPTY" else "RIFLE AMMO"',
} do
	assertThat(string.find(factory, required, 1, true) ~= nil, "supply cache factory missing: " .. required)
end

for _, required in {
	"presentationRemote.OnClientEvent:Connect",
	"Workspace.DescendantAdded:Connect",
	"Workspace.DescendantRemoving:Connect",
	"root.LocalTransparencyModifier = 1",
	"root.LocalTransparencyModifier = binding.originalLocalTransparencyModifier",
	"prompt.Enabled = if consumed then false",
	"SupplyCachePresentationFactory.create(root)",
	"SupplyCachePresentationFactory.applyState",
} do
	assertThat(string.find(controller, required, 1, true) ~= nil, "supply cache controller missing: " .. required)
end

local rememberIndex = string.find(controller, "consumedCacheIds[cacheId] = true", 1, true)
local lookupIndex = string.find(controller, "local binding = bindingsByCacheId[cacheId]", rememberIndex or 1, true)
assertThat(rememberIndex ~= nil and lookupIndex ~= nil and rememberIndex < lookupIndex, "consumed state must be remembered before cache lookup")

for _, forbidden in {
	"RunService",
	"RenderStepped",
	"Heartbeat",
	"Stepped",
	"task.delay",
	"task.spawn",
	"task.defer",
	"FireServer",
	"InvokeServer",
	"OnServerEvent",
	"prompt.Triggered",
	"SetNetworkOwner",
	"PivotTo",
	"root.Position =",
	"root.CFrame =",
	"root.CanCollide =",
	"reserveRounds =",
	"loadedRounds =",
	"processedCacheIds =",
} do
	assertThat(not string.find(controller, forbidden, 1, true), "supply cache controller contains authority token: " .. forbidden)
end

assertThat(string.find(service, "part.Size = Vector3.new(3.6, 1.8, 2.6)", 1, true) ~= nil, "authoritative cache root size drifted")
assertThat(string.find(service, "part.Anchored = true", 1, true) ~= nil, "authoritative cache root must remain anchored")
assertThat(string.find(service, "part.CanCollide = true", 1, true) ~= nil, "authoritative cache collision must remain server-owned")
assertThat(string.find(service, "prompt.Triggered:Connect", 1, true) ~= nil, "server prompt must remain the collection path")

assertThat(string.find(registry, '"src/client/Controllers/AmmunitionCachePresentationController.luau"', 1, true) ~= nil, "registry must name the presentation owner")
assertThat(string.find(readme, "per-operative depletion", 1, true) ~= nil, "README must document local depletion")
assertThat(string.find(readme, "Roblox Studio approval remains pending", 1, true) ~= nil, "README must preserve Studio gate")
assertThat(string.find(manifest, '"maximumPartsPerCache": 13', 1, true) ~= nil, "manifest part budget missing")
assertThat(string.find(manifest, '"connectionsPerCache": 0', 1, true) ~= nil, "manifest must record zero per-cache connections")
assertThat(string.find(manifest, '"newRemoteCount": 0', 1, true) ~= nil, "manifest must record zero new remotes")
assertThat(string.find(manifest, '"studioApproved": false', 1, true) ~= nil, "manifest must preserve Studio gate")
assertThat(string.find(roadmap, "procedural supply case", 1, true) ~= nil, "VIS-0105 status missing")
assertThat(string.find(inventory, "SupplyCachePresentationFactory", 1, true) ~= nil, "inventory must name the cache factory")

print("SupplyCacheVisualReadabilitySourceAudit: root authority, local depletion, bounds, cleanup, registry, docs, and Studio gate passed")
