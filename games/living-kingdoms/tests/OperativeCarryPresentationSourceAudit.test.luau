--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/OperativeCarryPoseResolver.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeCarryPresentationController.luau")
local weapon = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local readme = fs.readFile("games/living-kingdoms/assets/visual/operative/carry-poses/README.md")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/operative/carry-poses/asset-manifest.json")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")
local inventory = fs.readFile("docs/specifications/visual-placeholder-inventory.md")

for _, required in
	{
		'export type PoseId = "Hidden" | "Ready" | "Reviving" | "Incapacitated" | "Dead"',
		"DefinitionsByRigId",
		'lifeStateId == "Dead"',
		'lifeStateId == "Incapacitated"',
		"reviveReviverOperativeEntityId == facts.operativeEntityId",
		"function Resolver.definitionFor",
	}
do
	assertThat(string.find(resolver, required, 1, true) ~= nil, "carry resolver missing: " .. required)
end

for _, required in
	{
		"player.CharacterAdded:Connect",
		"player.CharacterRemoving:Connect",
		"player.AttributeChanged:Connect",
		"character.DescendantAdded:Connect",
		"character.DescendantRemoving:Connect",
		"OperativeCarryPoseResolver.resolve",
		"OperativeCarryPoseResolver.definitionFor",
		"motor.C0 = baseC0",
		"gripMotor.C0 = baseC0",
		"restoreBinding(binding)",
		"RightShoulder",
		'"Right Shoulder"',
		"WeaponGrip",
	}
do
	assertThat(string.find(controller, required, 1, true) ~= nil, "carry controller missing: " .. required)
end

for _, forbidden in
	{
		"RunService",
		"RenderStepped",
		"Heartbeat",
		"Stepped",
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"RemoteEvent",
		"RemoteFunction",
		"task.delay",
		"task.spawn",
		"task.defer",
		"SetNetworkOwner",
		"PivotTo",
		"HumanoidRootPart.CFrame",
		"AssemblyLinearVelocity",
		"AssemblyAngularVelocity",
		"WalkSpeed",
		"JumpPower",
		"JumpHeight",
		"TakeDamage",
		"player:SetAttribute(LIFE_STATE_ATTRIBUTE",
		"player:SetAttribute(OPERATIVE_ID_ATTRIBUTE",
		"reloadState =",
		"selectedTargetEntityId =",
	}
do
	assertThat(
		not string.find(controller, forbidden, 1, true),
		"carry controller contains authority token: " .. forbidden
	)
end

for _, required in
	{
		"gripMotors: { [Player]: Motor6D }",
		"local gripMotor = state.gripMotors[player]",
		"gripMotor:Destroy()",
		"state.gripMotors[player] = nil",
		"state.gripMotors[player] = gripMotor",
		'hand:FindFirstChild("WeaponGrip")',
	}
do
	assertThat(string.find(weapon, required, 1, true) ~= nil, "weapon grip cleanup missing: " .. required)
end

local weaponStart = string.find(bootstrap, "WeaponPresentationController.start()", 1, true)
local carryStart = string.find(bootstrap, "OperativeCarryPresentationController.start()", 1, true)
assertThat(
	weaponStart ~= nil and carryStart ~= nil and weaponStart < carryStart,
	"weapon presentation must start before carry poses"
)

assertThat(string.find(readme, "R6 and R15", 1, true) ~= nil, "README must record rig coverage")
assertThat(
	string.find(readme, "Roblox Studio approval remains pending", 1, true) ~= nil,
	"README must preserve Studio gate"
)
assertThat(string.find(manifest, '"frameConnections": 0', 1, true) ~= nil, "manifest must record zero frame loops")
assertThat(string.find(manifest, '"newRemoteCount": 0', 1, true) ~= nil, "manifest must record zero new remotes")
assertThat(string.find(manifest, '"maximumMotorWritesPerOperative": 3', 1, true) ~= nil, "manifest motor bound missing")
assertThat(string.find(manifest, '"studioApproved": false', 1, true) ~= nil, "manifest must preserve Studio gate")
assertThat(string.find(roadmap, "event-driven upper-body carry poses", 1, true) ~= nil, "VIS-0104 carry status missing")
assertThat(
	string.find(inventory, "OperativeCarryPresentationController", 1, true) ~= nil,
	"placeholder inventory must name carry owner"
)

print("OperativeCarryPresentationSourceAudit: truth, bounded joints, cleanup, authority, docs, and Studio gate passed")
