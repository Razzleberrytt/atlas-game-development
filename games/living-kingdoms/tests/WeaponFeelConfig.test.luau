--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local FIREARM_CONFIG_TOKEN = {}
local weaponIds = {
	BasicFirearm = "weapon.basic-firearm",
	LightMachineGun = "weapon.light-machine-gun",
	BreachShotgun = "weapon.breach-shotgun",
	SniperRifle = "weapon.sniper-rifle",
	ServicePistol = "weapon.service-pistol",
	SubmachineGun = "weapon.submachine-gun",
}
local selectableWeaponIds = {
	weaponIds.LightMachineGun,
	weaponIds.BreachShotgun,
	weaponIds.SniperRifle,
	weaponIds.ServicePistol,
	weaponIds.SubmachineGun,
}
local firearmConfig = {
	BasicFirearm = { WeaponId = weaponIds.BasicFirearm },
	LightMachineGun = { WeaponId = weaponIds.LightMachineGun },
	BreachShotgun = { WeaponId = weaponIds.BreachShotgun },
	SniperRifle = { WeaponId = weaponIds.SniperRifle },
	ServicePistol = { WeaponId = weaponIds.ServicePistol },
	SubmachineGun = { WeaponId = weaponIds.SubmachineGun },
	SelectableWeaponIds = selectableWeaponIds,
}

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/WeaponFeelConfig.luau"), {
	debugName = "WeaponFeelConfig",
	environment = {
		script = { Parent = { FirearmConfig = FIREARM_CONFIG_TOKEN } },
		require = function(token: unknown)
			if token == FIREARM_CONFIG_TOKEN then
				return firearmConfig
			end
			error("unexpected WeaponFeelConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

assertThat(config.Version == "HROI-0123-v1-weapon-identity-feel", "weapon feel version drifted")
assertThat(config.get(weaponIds.BasicFirearm) ~= nil, "legacy firearm requires a compatibility profile")
for _, weaponId in selectableWeaponIds do
	local profile = config.get(weaponId)
	assertThat(profile ~= nil, "missing selectable weapon feel profile: " .. weaponId)
	assertThat(profile.WeaponId == weaponId, "profile identity mismatch: " .. weaponId)
	assertThat(profile.MuzzleFlashDiameter > 0, "muzzle flash must be visible")
	assertThat(profile.CasingLength > 0 and profile.CasingDiameter > 0, "casing dimensions must be positive")
	assertThat(profile.TracerWidth > 0, "tracer width must be positive")
	assertThat(profile.ImpactDiameter > 0, "impact size must be positive")
	assertThat(profile.AudioPitchMaximumMultiplier >= profile.AudioPitchMinimumMultiplier, "audio pitch must be ordered")
end

local shotgun = config.get(weaponIds.BreachShotgun)
local sniper = config.get(weaponIds.SniperRifle)
local pistol = config.get(weaponIds.ServicePistol)
local smg = config.get(weaponIds.SubmachineGun)
local lmg = config.get(weaponIds.LightMachineGun)
assertThat(shotgun.MuzzleFlashDiameter > lmg.MuzzleFlashDiameter, "shotgun requires the broadest close-range flash")
assertThat(sniper.TracerLifetimeSeconds > lmg.TracerLifetimeSeconds, "sniper tracer must read at long range")
assertThat(pistol.AudioPitchMinimumMultiplier > lmg.AudioPitchMinimumMultiplier, "pistol report must read lighter")
assertThat(smg.MuzzleFlashSeconds < lmg.MuzzleFlashSeconds, "SMG flash must stay brief under rapid fire")
assertThat(shotgun.CasingKindId == "ShotgunShell", "shotgun must eject a readable shell")

local source = fs.readFile("games/living-kingdoms/src/shared/Config/WeaponFeelConfig.luau")
local effectSource = fs.readFile("games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau")
local audioSource = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau")
local combined = source .. "\n" .. effectSource .. "\n" .. audioSource

for _, token in {
	"profile.MuzzleFlashDiameter",
	"profile.CasingKindId",
	"profile.TracerWidth",
	"profile.ImpactDiameter",
	"profile.AudioVolumeMultiplier",
	"profile.AudioPitchMinimumMultiplier",
	"profile.ReloadPlaybackSpeedMultiplier",
} do
	assertThat(string.find(combined, token, 1, true) ~= nil, "missing weapon feel integration token: " .. token)
end

for _, prohibited in {
	"FireServer",
	"InvokeServer",
	"OnServerEvent",
	"DamagePerHit =",
	"CadenceSeconds =",
	"MagazineCapacity =",
	"loadedRounds -=",
	"reserveRounds -=",
	"commitHealthState",
	"Humanoid:TakeDamage",
} do
	assertThat(not string.find(combined, prohibited, 1, true), "presentation feel widened authority: " .. prohibited)
end

print("WeaponFeelConfig: six bounded profiles drive distinct client-only effects and audio")
