--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local factoryPath = "games/living-kingdoms/src/client/Presentation/BasicFirearmPresentationFactory.luau"
local controllerPath = "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau"
local bootstrapPath = "games/living-kingdoms/src/client/init.client.luau"
local registryPath = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"

local factory = fs.readFile(factoryPath)
local controller = fs.readFile(controllerPath)
local bootstrap = fs.readFile(bootstrapPath)
local registry = fs.readFile(registryPath)
local combined = factory .. "\n" .. controller

for _, componentName in
	{
		"Receiver",
		"Handguard",
		"StockCore",
		"Buttstock",
		"Barrel",
		"MuzzleDevice",
		"PistolGrip",
		"Magazine",
		"Bolt",
		"TopRail",
		"RearSight",
		"FrontSight",
		"TriggerGuardFront",
		"Trigger",
		"StockLatch",
		"HandStop",
		"WarningStripe",
		"RearSlingMount",
		"FrontSlingMount",
	}
do
	assertThat(
		string.find(factory, '"' .. componentName .. '"', 1, true) ~= nil,
		"missing carbine component " .. componentName
	)
end

for _, attachmentName in
	{
		"RightGripAttachment",
		"LeftGripAttachment",
		"Muzzle",
		"Magazine",
		"Ejection",
	}
do
	assertThat(
		string.find(factory, '"' .. attachmentName .. '"', 1, true) ~= nil,
		"missing carbine attachment " .. attachmentName
	)
end

assertThat(
	string.find(factory, 'model.Name = "BasicFirearmPresentation"', 1, true) ~= nil,
	"factory must create one stable model name"
)
assertThat(
	string.find(factory, 'model:SetAttribute("VisualStatus", "ProceduralFallback")', 1, true) ~= nil,
	"runtime model must remain honestly marked as a fallback"
)
assertThat(
	string.find(factory, 'model:SetAttribute("GameplayFootprintId", "weapon.basic-firearm")', 1, true) ~= nil,
	"presentation must declare the stable firearm footprint"
)
assertThat(string.find(factory, "boltMotor.C0", 1, true) ~= nil, "factory must expose a movable bolt")
assertThat(string.find(factory, "magazineMotor.C0", 1, true) ~= nil, "factory must expose a movable magazine")

for _, forbidden in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		'RemoteEvent")',
		"DamagePerHit =",
		"CadenceSeconds =",
		"ReloadDurationSeconds =",
		"loadedRounds -=",
		"reserveRounds -=",
	}
do
	assertThat(
		not string.find(combined, forbidden, 1, true),
		"weapon presentation must not contain authority token " .. forbidden
	)
end

assertThat(
	string.find(controller, "presentationRemote.OnClientEvent:Connect", 1, true) ~= nil,
	"animation must consume server-disclosed presentation"
)
assertThat(
	string.find(controller, "Workspace:GetServerTimeNow()", 1, true) ~= nil,
	"reload presentation must follow the authoritative deadline"
)
assertThat(
	string.find(controller, "MAX_PRESENTED_SHOT_IDS = 128", 1, true) ~= nil,
	"shot replay memory must remain bounded"
)
assertThat(
	string.find(controller, "player.CharacterRemoving:Connect", 1, true) ~= nil,
	"character cleanup must be explicit"
)
assertThat(string.find(controller, "Players.PlayerRemoving:Connect", 1, true) ~= nil, "player cleanup must be explicit")
assertThat(
	string.find(controller, "rig.model:Destroy()", 1, true) ~= nil,
	"presentation rig cleanup must destroy the model"
)

local weaponStart = string.find(bootstrap, "WeaponController.start()", 1, true)
local presentationStart = string.find(bootstrap, "WeaponPresentationController.start()", 1, true)
assertThat(
	weaponStart ~= nil and presentationStart ~= nil and weaponStart < presentationStart,
	"authoritative weapon presentation listener must start after combat input/presentation"
)

assertThat(
	string.find(registry, "canonical imported production approval remains pending.", 1, true) ~= nil,
	"runtime fallback must not falsely claim production approval"
)
