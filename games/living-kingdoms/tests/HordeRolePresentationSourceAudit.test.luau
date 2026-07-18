--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local config = fs.readFile("games/living-kingdoms/src/shared/Config/HordeRolePresentationConfig.luau")
local horde = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local presenter = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyPresentationService.luau")
local roleService = fs.readFile("games/living-kingdoms/src/server/Systems/HordeRolePresentationService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau")
local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")

for _, token in {
	"standard-hollow",
	"razor-sprinter",
	"grave-low-crawl",
	"choir-beacon",
	"rot-pressure-sac",
	"grief-heavy-frame",
	"ComponentGroups",
	"TorsoPitchDegrees",
	"StridesPerSecond",
} do
	assertThat(contains(config, token), "role presentation config missing " .. token)
end

assertThat(not contains(horde, "record.model:ScaleTo"), "role decoration must not scale the authoritative enemy model")
assertThat(
	contains(horde, "HordeRolePresentationService.applyRolePresentation(record.model)"),
	"role assignment must refresh the stateless visual applicator"
)
assertThat(
	contains(presenter, "HordeRolePresentationService.applyRolePresentation(enemyModel)"),
	"shell attachment must apply the current role regardless of spawn-order"
)
assertThat(contains(presenter, 'motor:SetAttribute("HordeRoleBaseC0", motor.C0)'), "motor bases must exist before replication")
assertThat(contains(presenter, 'part:SetAttribute("HordeRoleBaseSize", size)'), "part bases must exist before replication")

for _, token in {
	"HordeRolePresentationConfig",
	"HordeRoleBaseSize",
	"HordeRoleBaseC0",
	"HordeRoleVisualSignature",
	"function HordeRolePresentationService.applyRolePresentation",
	"profile.SensorBrightness",
	"profile.SensorRange",
	"applyPosture",
	"presentation:GetDescendants()",
} do
	assertThat(contains(roleService, token), "stateless role applicator missing " .. token)
end

for _, token in {
	"HordeRolePresentationConfig",
	'local roleId = readStringAttribute(model, "HordeRoleId")',
	"roleProfile(record.roleId)",
	"posture.TorsoHeightStuds",
	"profile.StridesPerSecond",
	"colorFromTuple(profile.Colors.Sensor)",
	'record.poseId = ""',
	'GetAttribute("HordeRoleBaseC0")',
} do
	assertThat(contains(controller, token), "client role composition missing " .. token)
end

for _, forbidden in {
	"root.Size =",
	"root.CFrame =",
	"root.Position =",
	"Humanoid:MoveTo",
	"TakeDamage",
	"FireServer",
	"OnServerEvent",
} do
	assertThat(not contains(roleService .. controller, forbidden), "role presentation cannot mutate authority: " .. forbidden)
end

assertThat(contains(director, "root.Size = Vector3.new(3, 5.6, 3)"), "authoritative root footprint must remain fixed")
local _, serverListenerCount = string.gsub(presenter, "ChildAdded:Connect", "")
assertThat(serverListenerCount == 1, "server presentation must retain one folder listener")
local _, clientFrameCount = string.gsub(controller, "RenderStepped:Connect", "")
assertThat(clientFrameCount == 1, "client role motion must reuse one frame connection")
assertThat(not contains(roleService, ":Connect"), "stateless role applicator cannot own connections")
assertThat(not contains(controller, "GetAttributeChangedSignal"), "role readability cannot add per-enemy attribute listeners")
assertThat(not contains(controller, ".Changed:Connect"), "role readability cannot add per-enemy changed listeners")

print("HordeRolePresentationSourceAudit: six-role readability, replication-safe bases, and bounded lifecycle passed")
