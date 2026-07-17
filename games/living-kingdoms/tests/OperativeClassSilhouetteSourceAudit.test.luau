--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = fs.readFile("games/living-kingdoms/src/shared/Visual/ClassSilhouetteConfig.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassSilhouetteController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/operative/class-silhouettes/asset-manifest.json")
local readme = fs.readFile("games/living-kingdoms/assets/visual/operative/class-silhouettes/README.md")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")
local inventory = fs.readFile("docs/specifications/visual-placeholder-inventory.md")

for _, required in {
	'AssetKey = "visual.operative.class-silhouette.fallback"',
	"MaximumPartsPerOperative = 10",
	"CombatSpecialistSilhouette",
	"MedicSilhouette",
	"EngineerSilhouette",
	"SpecialistGuardLeft",
	"MedicCanisterLeft",
	"EngineerAntennaStem",
} do
	assertThat(string.find(config, required, 1, true) ~= nil, "class silhouette config missing: " .. required)
end

for _, required in {
	"ClassContracts.validateSafeClassSelectionSnapshot",
	"stateRemote.OnClientEvent:Connect",
	"readStateFunction:InvokeServer()",
	"Players.PlayerAdded:Connect",
	"Players.PlayerRemoving:Connect",
	"player.CharacterAdded:Connect",
	"player:GetAttributeChangedSignal(OPERATIVE_ID_ATTRIBUTE):Connect",
	'Instance.new("WeldConstraint")',
	"part.Massless = true",
	"part.CanCollide = false",
	"part.CanTouch = false",
	"part.CanQuery = false",
	"part.CFrame = torso.CFrame",
	"OperativeClassSilhouette",
} do
	assertThat(string.find(controller, required, 1, true) ~= nil, "class silhouette controller missing: " .. required)
end

for _, forbidden in {
	"FireServer",
	"InvokeServer({",
	"OnServerEvent",
	"RemoteEvent.new",
	"RunService",
	"Heartbeat",
	"RenderStepped",
	"task.delay",
	"task.spawn",
	"task.defer",
	"SetNetworkOwner",
	"character:PivotTo",
	"torso.CFrame =",
	"HumanoidRootPart.CFrame =",
	"WalkSpeed =",
	"JumpPower =",
	"TakeDamage",
	"applyAuthoritativeDamage",
	"currentHealth =",
	"classId = member.classId,",
} do
	assertThat(not string.find(controller, forbidden, 1, true), "presentation controller contains authority token: " .. forbidden)
end

local requireIndex = string.find(bootstrap, "local ClassSilhouetteController = require", 1, true)
local startIndex = string.find(bootstrap, "ClassSilhouetteController.start()", 1, true)
assertThat(requireIndex ~= nil and startIndex ~= nil and requireIndex < startIndex, "client bootstrap must start class silhouettes")

assertThat(string.find(manifest, '"maximumPartsPerOperative": 10', 1, true) ~= nil, "manifest part budget missing")
assertThat(string.find(manifest, '"newRemoteCount": 0', 1, true) ~= nil, "manifest must record zero new remotes")
assertThat(string.find(manifest, '"frameConnections": 0', 1, true) ~= nil, "manifest must record zero frame loops")
assertThat(string.find(manifest, '"studioApproved": false', 1, true) ~= nil, "Studio approval must remain false")
assertThat(string.find(readme, "geometry, not color alone", 1, true) ~= nil, "README must document accessible silhouette policy")
assertThat(string.find(roadmap, "procedural shared armor base", 1, true) ~= nil, "VIS-0104 roadmap status missing")
assertThat(string.find(inventory, "ClassSilhouetteController", 1, true) ~= nil, "placeholder inventory must record runtime owner")

print("OperativeClassSilhouetteSourceAudit: roster truth, geometry, authority, bounds, and docs passed")
