--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local _, occurrences = string.gsub(source, token, "")
	return occurrences
end

local basePath = "games/living-kingdoms/src/client/Presentation/"
local router = fs.readFile(basePath .. "WeaponPresentationFactory.luau")
local builder = fs.readFile(basePath .. "WeaponVisualModelBuilder.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Visual/VisualAssetContracts.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")

local models = {
	{
		file = "BreachShotgunPresentationFactory.luau",
		factory = "BreachShotgunPresentationFactory",
		candidate = "morrow-breach-shotgun.v2",
		assetKey = "WeaponBreachShotgunModel",
		parts = { "HeatShield", "Pump", "ShellRack", "RackShell", "MagazineTube", "SideLight" },
	},
	{
		file = "SniperRiflePresentationFactory.luau",
		factory = "SniperRiflePresentationFactory",
		candidate = "longwatch-sniper-rifle.v2",
		assetKey = "WeaponSniperRifleModel",
		parts = { "HeavyBarrel", "MuzzleBrakeCore", "ScopeTube", "ObjectiveLens", "BoltHandleKnob", "BipodLeftLeg" },
	},
	{
		file = "ServicePistolPresentationFactory.luau",
		factory = "ServicePistolPresentationFactory",
		candidate = "vigil-service-pistol.v2",
		assetKey = "WeaponServicePistolModel",
		parts = { "Frame", "SlideTop", "RearSerration", "WeaponLightBody", "MagazineBase", "FrontSightDot" },
	},
	{
		file = "SubmachineGunPresentationFactory.luau",
		factory = "SubmachineGunPresentationFactory",
		candidate = "razor-compact-smg.v2",
		assetKey = "WeaponSubmachineGunModel",
		parts = { "BarrelShroud", "StockTopRail", "MagazineLower", "ReflexWindow", "VerticalForegrip", "IdentityPanel" },
	},
}

assert(not contains(router, "compactRig"), "generic scaled-box weapon placeholder must be removed")
for _, model in models do
	local source = fs.readFile(basePath .. model.file)
	assert(contains(router, "require(script.Parent." .. model.factory .. ")"), "router missing " .. model.factory)
	assert(contains(router, model.factory .. ".create()"), "router must create " .. model.factory)
	assert(contains(source, model.candidate), "model must expose stable candidate identity: " .. model.file)
	assert(
		contains(source, "VisualAssetContracts.AssetKeys." .. model.assetKey),
		"model missing asset identity: " .. model.file
	)
	assert(contains(contracts, model.assetKey), "visual contracts missing " .. model.assetKey)
	assert(contains(registry, "Keys." .. model.assetKey), "visual registry missing " .. model.assetKey)
	assert(contains(source, "Builder.finish"), "model must publish shared rig contract: " .. model.file)
	assert(count(source, "Builder.") >= 20, "model is too primitive to replace the placeholder: " .. model.file)
	for _, partName in model.parts do
		assert(contains(source, '"' .. partName), "missing defining model component " .. partName)
	end
	for _, prohibited in
		{ "FireServer", "InvokeServer", "OnServerEvent", "DamagePerHit", "loadedRounds -=", "Humanoid.Health" }
	do
		assert(not contains(source, prohibited), "visual model gained authority token " .. prohibited)
	end
end

for _, contractName in
	{
		"RightGripAttachment",
		"LeftGripAttachment",
		"Muzzle",
		"Magazine",
		"Ejection",
		"boltRestC0",
		"magazineRestC0",
	}
do
	assert(contains(builder, contractName), "shared model builder missing rig contract " .. contractName)
end
assert(not contains(builder, "RemoteEvent"), "shared model builder must remain client-local geometry")
assert(not contains(builder, "FireServer"), "shared model builder must not gain network authority")

print(
	"DetailedWeaponModelsSourceAudit: four dedicated models, asset identities, rig contracts, complexity, and authority boundaries passed"
)
