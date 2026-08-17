--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local SCARCITY_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirearmConfig.luau"), {
	debugName = "FirearmConfig.weapon-archetypes",
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

local modes = config.FiringModeIds
assert(config.LightMachineGun.FiringModeId == modes.Automatic, "LMG must prove automatic behavior")
assert(config.SubmachineGun.FiringModeId == modes.Automatic, "SMG must remain automatic")
assert(config.ServicePistol.FiringModeId == modes.SemiAutomatic, "pistol must prove semi-auto behavior")
assert(config.SniperRifle.FiringModeId == modes.SemiAutomatic, "precision rifle must be semi-auto")
assert(config.BasicFirearm.FiringModeId == modes.Burst, "compatibility rifle must prove burst behavior")
assert(config.BasicFirearm.BurstCount == 3, "burst rifle must fire three-round bursts")
assert(config.BreachShotgun.PelletCount > 1, "shotgun must expose multiple bounded pellets")
assert(config.BreachShotgun.PelletCount <= config.MaximumPelletCount, "shotgun pellet count must stay bounded")
assert(
	config.BreachShotgun.SpreadDegrees > config.SniperRifle.SpreadDegrees,
	"shotgun must be less accurate than sniper"
)
assert(
	config.SniperRifle.HeadshotMultiplier > config.LightMachineGun.HeadshotMultiplier,
	"precision archetype must reward weak points"
)

for weaponId, definition in config.DefinitionsById do
	assert(config.get(weaponId) == definition, "lookup must return canonical definition")
	assert(table.isfrozen(definition), "definitions must be immutable")
	assert(definition.PelletCount >= 1 and definition.PelletCount <= 8, "pellet bounds regressed")
	assert(definition.SpreadDegrees >= 0 and definition.SpreadDegrees <= 30, "spread bounds regressed")
	assert(definition.HeadshotMultiplier >= 1 and definition.HeadshotMultiplier <= 2.5, "headshot bounds regressed")
	assert(
		definition.BurstIntervalSeconds >= 0.05 and definition.BurstIntervalSeconds <= definition.CadenceSeconds,
		"burst timing bounds regressed"
	)
end

print("WeaponArchetypeConfig: automatic, semi, burst and multi-pellet archetypes passed")
