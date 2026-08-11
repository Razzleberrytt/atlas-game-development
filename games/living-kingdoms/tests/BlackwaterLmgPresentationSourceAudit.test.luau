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
local source = fs.readFile(basePath .. "LightMachineGunPresentationFactory.luau")
local router = fs.readFile(basePath .. "WeaponPresentationFactory.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Visual/VisualAssetContracts.luau")

assert(contains(router, "require(script.Parent.LightMachineGunPresentationFactory)"))
assert(contains(router, "LightMachineGunPresentationFactory.create()"))
assert(
	not contains(router, "FirearmConfig.BasicFirearm.WeaponId or weaponId == FirearmConfig.LightMachineGun.WeaponId")
)
assert(contains(source, "blackwater-support-lmg.v2"))
assert(contains(source, "FirearmConfig.LightMachineGun.WeaponId"))
assert(contains(source, "VisualAssetContracts.AssetKeys.WeaponBasicFirearmModel"))
assert(contains(contracts, "WeaponBasicFirearmModel"))
assert(contains(source, "Builder.finish"))
assert(count(source, "Builder.") >= 28, "LMG model is too primitive for a dedicated heavy-weapon silhouette")

for _, partName in
	{
		"FeedCover",
		"BarrelJacket",
		"MuzzleBrake",
		"MagazineBody",
		"CarryHandle",
		"BipodLeftLeg",
		"BipodRightLeg",
		"IdentityPanel",
	}
do
	assert(contains(source, '"' .. partName), "LMG missing defining model component " .. partName)
end

for _, prohibited in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"DamagePerHit",
		"loadedRounds -=",
		"Humanoid.Health",
	}
do
	assert(not contains(source, prohibited), "LMG presentation gained gameplay authority token " .. prohibited)
end

print("BlackwaterLmgPresentationSourceAudit: dedicated heavy silhouette, rig identity, and authority boundaries passed")
