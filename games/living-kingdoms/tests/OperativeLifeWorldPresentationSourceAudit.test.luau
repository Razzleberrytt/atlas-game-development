--!strict

local fs = require("@lune/fs")

local controller =
	fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeLifeWorldPresentationController.luau")
local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/OperativeLifePresentationResolver.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/operative/life-state-cues/asset-manifest.json")
local readme = fs.readFile("games/living-kingdoms/assets/visual/operative/life-state-cues/README.md")

for _, required in
	{
		"OperativeLifePresentationResolver.resolve",
		"player.AttributeChanged:Connect",
		"player.CharacterAdded:Connect",
		"Players.PlayerAdded:Connect",
		"Players.PlayerRemoving:Connect",
		'local CUE_MODEL_NAME = "OperativeLifeWorldCue"',
		'Instance.new("WeldConstraint")',
		'Instance.new("BillboardGui")',
		"billboard.AlwaysOnTop = false",
		"part.Massless = true",
		"part.CanCollide = false",
		"part.CanTouch = false",
		"part.CanQuery = false",
		"VisualAssetContracts.AssetKeys.InterfaceLifeState",
		'"ServerDisclosedPlayerAttributes"',
	}
do
	assert(string.find(controller, required, 1, true) ~= nil, "life world cue controller missing: " .. required)
end

for _, forbidden in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"FireClient",
		"RemoteEvent.new",
		"RunService",
		"Heartbeat",
		"RenderStepped",
		"task.delay",
		"task.spawn",
		"task.defer",
		"SetNetworkOwner",
		"PivotTo",
		"HumanoidRootPart.CFrame =",
		"torso.CFrame =",
		"WalkSpeed =",
		"JumpPower =",
		"Humanoid:Move",
		"TakeDamage",
		"applyAuthoritativeDamage",
		'SetAttribute("LK_P3_',
	}
do
	assert(
		not string.find(controller, forbidden, 1, true),
		"world cue controller contains authority token: " .. forbidden
	)
end

for _, required in
	{
		"cueId: CueId",
		'if facts.lifeStateId == "Dead" then',
		"if facts.soloRecoveryPending == true then",
		"facts.reviveTargetOperativeEntityId == facts.operativeEntityId",
		"math.clamp(facts.reviveProgress :: number, 0, 1)",
		'return presentation("Downed", "RescueCross", "DOWNED", nil)',
	}
do
	assert(string.find(resolver, required, 1, true) ~= nil, "life cue resolver missing: " .. required)
end

local requireIndex = string.find(bootstrap, "local OperativeLifeWorldPresentationController = require", 1, true)
local startIndex = string.find(bootstrap, "OperativeLifeWorldPresentationController.start()", 1, true)
assert(
	requireIndex ~= nil and startIndex ~= nil and requireIndex < startIndex,
	"client bootstrap must start world cues"
)

assert(string.find(manifest, '"maximumCuePartsPerOperative": 2', 1, true) ~= nil)
assert(string.find(manifest, '"globalConnections": 2', 1, true) ~= nil)
assert(string.find(manifest, '"connectionsPerPlayer": 2', 1, true) ~= nil)
assert(string.find(manifest, '"frameConnections": 0', 1, true) ~= nil)
assert(string.find(manifest, '"newRemoteCount": 0', 1, true) ~= nil)
assert(string.find(manifest, '"studioApproved": false', 1, true) ~= nil)
assert(string.find(readme, "geometry plus explicit text", 1, true) ~= nil)
assert(string.find(readme, "occlusion-respecting", 1, true) ~= nil)
assert(string.find(readme, "zero gameplay authority", 1, true) ~= nil)

print("OperativeLifeWorldPresentationSourceAudit: disclosure, geometry, accessibility, authority, and bounds passed")
