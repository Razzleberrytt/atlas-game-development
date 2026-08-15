--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "modular asset integration assertion failed", 2)
	end
end

local configPath = "games/living-kingdoms/src/shared/Config/ModularAssetConfig.luau"
local servicePath = "games/living-kingdoms/src/server/Systems/ModularEnemyPresentationService.luau"
local roleServicePath = "games/living-kingdoms/src/server/Systems/HordeRolePresentationService.luau"

local config = luau.load(fs.readFile(configPath), {
	debugName = "ModularAssetConfig",
	injectGlobals = true,
})()

check(config.Version == "VIS-modular-assets-v1")
check(table.isfrozen(config))
check(#config.EnemySlots == 5)
check(#config.BodyIds == 3)
check(#config.WarPlateIds == 4)
check(#config.HornIds == 4)
check(#config.WeaponIds == 4)
check(#config.BackSpikeIds == 3)

for _, weaponId in { "Sword", "Axe", "Spear", "Staff" } do
	local profile = config.getWeaponProfile(weaponId)
	check(profile ~= nil, "missing modular weapon profile: " .. weaponId)
	check(profile.HandleLength > 0 and profile.HeadLength > 0 and profile.HeadWidth > 0)
end

for _, bodyId in config.BodyIds do
	local profile = config.getBodyProfile(bodyId)
	check(profile ~= nil, "missing modular body profile: " .. bodyId)
	check(#profile.TorsoScale == 3 and #profile.RibScale == 3 and #profile.HeadScale == 3)
end

local first = config.resolveEnemyVariant("enemy.walker|assault|12.0|-8.0")
local repeated = config.resolveEnemyVariant("enemy.walker|assault|12.0|-8.0")
check(first.BodyId == repeated.BodyId)
check(first.WarPlateId == repeated.WarPlateId)
check(first.HornId == repeated.HornId)
check(first.WeaponId == repeated.WeaponId)
check(first.BackSpikeId == repeated.BackSpikeId)
check(table.isfrozen(first))

local seenVariants = {}
local seenWeapons = {}
for index = 1, 128 do
	local variant = config.resolveEnemyVariant("walker-" .. tostring(index))
	local key = table.concat({
		variant.BodyId,
		variant.WarPlateId,
		variant.HornId,
		variant.WeaponId,
		variant.BackSpikeId,
	}, ":")
	seenVariants[key] = true
	seenWeapons[variant.WeaponId] = true
end
local variantCount = 0
for _ in seenVariants do
	variantCount += 1
end
check(variantCount >= 12, "catalog should generate substantial enemy variety")
for _, weaponId in config.WeaponIds do
	check(seenWeapons[weaponId] == true, "deterministic selection should exercise weapon: " .. weaponId)
end

-- The presentation module is deliberately visual-only and is called before
-- horde-role scaling so modular proportions remain compatible with role reads.
local serviceSource = fs.readFile(servicePath)
local roleSource = fs.readFile(roleServicePath)
check(string.find(serviceSource, "ModularWarPlateId", 1, true) ~= nil)
check(string.find(serviceSource, "ModularHornId", 1, true) ~= nil)
check(string.find(serviceSource, "ModularWeaponId", 1, true) ~= nil)
check(string.find(serviceSource, "ModularBackSpikeId", 1, true) ~= nil)
check(string.find(serviceSource, "Humanoid%.Health") == nil)
check(string.find(serviceSource, "TakeDamage", 1, true) == nil)
check(string.find(roleSource, "ModularEnemyPresentationService.applyPresentation(enemyModel)", 1, true) ~= nil)
