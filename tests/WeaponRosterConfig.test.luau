--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local SCARCITY_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirearmConfig.luau"), {
	debugName = "FirearmConfig.weapon-roster",
	environment = {
		script = {
			Parent = {
				AmmunitionScarcityConfig = SCARCITY_TOKEN,
				Parent = { Combat = { CombatContracts = CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return {
					WeaponIds = {
						BasicFirearm = "weapon.basic_firearm",
						LightMachineGun = "weapon.light-machine-gun",
						BreachShotgun = "weapon.breach-shotgun",
						SniperRifle = "weapon.sniper-rifle",
						ServicePistol = "weapon.service-pistol",
						SubmachineGun = "weapon.submachine-gun",
					},
					DamageTypeIds = { Ballistic = "Ballistic" },
				}
			end
			assert(token == SCARCITY_TOKEN, "unexpected firearm config dependency")
			return {
				BasicFirearm = {
					InitialLoadedRounds = 12,
					InitialReserveRounds = 24,
					MaximumReserveRounds = 48,
					AuthoredCacheRounds = 12,
				},
			}
		end,
	},
	injectGlobals = true,
})()

assert(#config.SelectableWeaponIds == 1, "only the pistol may be selected at insertion")
assert(config.DefaultSelectableWeaponId == config.ServicePistol.WeaponId, "pistol must be default")
assert(config.ServicePistol.MagazineCapacity == 8, "opening pistol must have a scarce eight-round magazine")
assert(config.ServicePistol.PrototypeInitialReserveRounds == 8, "opening reserve must be limited to one reload")
assert(#config.DiscoverableWeaponIds == 4, "four long guns must remain discoverable in-run")
assert(config.BreachShotgun.DamagePerHit > config.LightMachineGun.DamagePerHit, "shotgun must hit harder")
assert(config.SniperRifle.RangeStuds > config.LightMachineGun.RangeStuds, "sniper must own longest range")
assert(
	config.ServicePistol.ReloadDurationSeconds < config.LightMachineGun.ReloadDurationSeconds,
	"pistol must reload faster"
)
assert(config.SubmachineGun.CadenceSeconds < config.LightMachineGun.CadenceSeconds, "SMG must fire faster")
local seen = {}
for _, weaponId in config.SelectableWeaponIds do
	assert(not seen[weaponId], "weapon IDs must be unique")
	seen[weaponId] = true
	local definition = config.get(weaponId)
	assert(definition ~= nil and table.isfrozen(definition), "definitions must exist and be frozen")
end

print("WeaponRosterConfig: pistol-only insertion and discoverable weapon roster passed")
