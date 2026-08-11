--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "WeaponVisualSkinRegistry assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts =
	loadModule("games/living-kingdoms/src/shared/Visual/WeaponVisualSkinContracts.luau", "WeaponVisualSkinContracts")
local registry =
	loadModule("games/living-kingdoms/src/shared/Config/WeaponVisualSkinRegistry.luau", "WeaponVisualSkinRegistry")

local knownWeaponIds = {
	["weapon.basic_firearm"] = true,
	["weapon.light-machine-gun"] = true,
	["weapon.breach-shotgun"] = true,
	["weapon.sniper-rifle"] = true,
	["weapon.service-pistol"] = true,
	["weapon.submachine-gun"] = true,
}

check(registry.Version == "WEAPON-VISUAL-SKIN-v2")
check(#registry.Visuals == 5)
check(#registry.Skins == 12)
check(#contracts.validate(registry.Visuals, registry.Skins, knownWeaponIds) == 0)

local firearmSource = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")
for _, visual in registry.Visuals do
	check(string.find(firearmSource, visual.weaponId, 1, true) ~= nil, "visual must bind a canonical weapon id")
	check(visual.status == "PlannedCustomModel")
	check(visual.presentationOnly == true)
	check(visual.gameplayAuthorityOwnerId == nil)
	check(#visual.compatibleSkinIds == 12, "every current custom firearm must expose the shared twelve-skin library")
end

local seenSkinIds = {}
for _, skin in registry.Skins do
	check(not seenSkinIds[skin.skinId], "weapon skin ids must be unique")
	seenSkinIds[skin.skinId] = true
	check(skin.presentationOnly == true)
	check(skin.gameplayModifiers == nil)
	check(#skin.compatibleVisualIds == 5)
end

for _, requiredSkinId in
	{
		"skin.weapon.blackwater_issue",
		"skin.weapon.frontier_worn",
		"skin.weapon.corruption_scarred",
		"skin.weapon.mine_rescue",
		"skin.weapon.rust_bloom",
		"skin.weapon.ash_church",
		"skin.weapon.night_signal",
		"skin.weapon.marrow_white",
		"skin.weapon.creek_mud",
		"skin.weapon.hazard_stripe",
		"skin.weapon.relic_brass",
		"skin.weapon.frostbite",
	}
do
	check(seenSkinIds[requiredSkinId] == true, "expanded skin library missing " .. requiredSkinId)
end

local authorityClaim = table.clone(registry.Visuals[1])
authorityClaim.gameplayAuthorityOwnerId = "FakeWeaponGameplayService"
local authorityIssues = contracts.validate({ authorityClaim }, registry.Skins, knownWeaponIds)
local foundAuthorityIssue = false
for _, issue in authorityIssues do
	if issue.code == "GameplayAuthorityForbidden" then
		foundAuthorityIssue = true
	end
end
check(foundAuthorityIssue)

local statSkin = table.clone(registry.Skins[1])
statSkin.gameplayModifiers = { damage = 1.1 }
local skinIssues = contracts.validate(registry.Visuals, { statSkin }, knownWeaponIds)
local foundSkinAuthorityIssue = false
for _, issue in skinIssues do
	if issue.code == "SkinGameplayModifierForbidden" then
		foundSkinAuthorityIssue = true
	end
end
check(foundSkinAuthorityIssue)

local badVisual = table.clone(registry.Visuals[1])
badVisual.weaponId = "weapon.not-real"
local unknownWeaponIssues = contracts.validate({ badVisual }, {}, knownWeaponIds)
local foundUnknownWeapon = false
for _, issue in unknownWeaponIssues do
	if issue.code == "UnknownWeaponId" then
		foundUnknownWeapon = true
	end
end
check(foundUnknownWeapon)
