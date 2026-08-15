--!strict

-- Presentation-only mapping from authoritative gameplay weapon IDs to stable
-- modular asset IDs. Combat stats and ownership remain in FirearmConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local ModularAssetProductionCatalog = require(ReplicatedStorage.Shared.Config.ModularAssetProductionCatalog)

local assetIdByWeaponId = table.freeze({
	[FirearmConfig.BasicFirearm.WeaponId] = "weapon.assault_rifle.a",
	[FirearmConfig.LightMachineGun.WeaponId] = "weapon.lmg.a",
	[FirearmConfig.BreachShotgun.WeaponId] = "weapon.shotgun.a",
	[FirearmConfig.SniperRifle.WeaponId] = "weapon.sniper_rifle.a",
	[FirearmConfig.ServicePistol.WeaponId] = "weapon.hand_cannon.a",
	[FirearmConfig.SubmachineGun.WeaponId] = "weapon.smg.a",
})

local catalogWeaponIds: { [string]: boolean } = {}
for _, definition in ipairs(ModularAssetProductionCatalog.Weapons.Categories) do
	catalogWeaponIds[definition.id] = true
end

for weaponId, assetId in pairs(assetIdByWeaponId) do
	assert(FirearmConfig.get(weaponId) ~= nil, "modular weapon presentation references an unknown gameplay weapon")
	assert(catalogWeaponIds[assetId] == true, "modular weapon presentation references an unknown modular asset")
end

for weaponId in pairs(FirearmConfig.DefinitionsById) do
	assert(assetIdByWeaponId[weaponId] ~= nil, "every configured firearm requires a modular presentation mapping")
end

local Config = {
	Version = "MODULAR-WEAPON-PRESENTATION-v1",
	AssetIdByWeaponId = assetIdByWeaponId,
}

function Config.GetAssetId(weaponId: unknown): string?
	return if type(weaponId) == "string" then assetIdByWeaponId[weaponId] else nil
end

return table.freeze(Config)
