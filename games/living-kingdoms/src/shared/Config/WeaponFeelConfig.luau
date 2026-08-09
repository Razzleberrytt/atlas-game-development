--!strict

--[[
	Client-presentation tuning for the firearm roster. These profiles change only
	visual motion, muzzle/casing/tracer presentation, and client-local audio. They
	contain no damage, cadence, ammunition, targeting, hit, health, or reload
	authority.
]]

local FirearmConfig = require(script.Parent.FirearmConfig)

export type WeaponFeelProfile = {
	WeaponId: string,
	BoltTravelStuds: number,
	GripKickBackStuds: number,
	GripKickUpStuds: number,
	GripKickDegrees: number,
	CameraKickDegrees: number,
	CameraYawDegrees: number,
	CameraFovKickDegrees: number,
	CameraRecoveryDegreesPerSecond: number,
	ShotBackSeconds: number,
	ShotReturnSeconds: number,
	MagazineOutX: number,
	MagazineOutZ: number,
	MagazineRollDegrees: number,
	ReloadOutwardFraction: number,
	ReloadHoldFraction: number,
	ReloadReturnFraction: number,
	MuzzleFlashDiameter: number,
	MuzzleFlashSeconds: number,
	MuzzleLightBrightness: number,
	MuzzleLightRange: number,
	CasingKindId: string,
	CasingLength: number,
	CasingDiameter: number,
	EjectionRightSpeed: number,
	EjectionUpSpeed: number,
	EjectionForwardSpeed: number,
	EjectionSpin: number,
	TracerWidth: number,
	TracerLifetimeSeconds: number,
	TracerTransparency: number,
	ImpactDiameter: number,
	ImpactLifetimeSeconds: number,
	ImpactLightBrightness: number,
	AudioVolumeMultiplier: number,
	AudioPitchMinimumMultiplier: number,
	AudioPitchMaximumMultiplier: number,
	ReloadVolumeMultiplier: number,
	ReloadPlaybackSpeedMultiplier: number,
}

local function profile(values: WeaponFeelProfile): WeaponFeelProfile
	return table.freeze(values)
end

local SupportLMG = profile({
	WeaponId = FirearmConfig.LightMachineGun.WeaponId,
	BoltTravelStuds = 0.2,
	GripKickBackStuds = 0.08,
	GripKickUpStuds = 0.015,
	GripKickDegrees = 1.4,
	CameraKickDegrees = 0.75,
	CameraYawDegrees = 0.18,
	CameraFovKickDegrees = 0.45,
	CameraRecoveryDegreesPerSecond = 12,
	ShotBackSeconds = 0.045,
	ShotReturnSeconds = 0.065,
	MagazineOutX = 0.22,
	MagazineOutZ = -0.75,
	MagazineRollDegrees = 8,
	ReloadOutwardFraction = 0.36,
	ReloadHoldFraction = 0.22,
	ReloadReturnFraction = 0.42,
	MuzzleFlashDiameter = 0.46,
	MuzzleFlashSeconds = 0.045,
	MuzzleLightBrightness = 2.2,
	MuzzleLightRange = 7,
	CasingKindId = "Rifle",
	CasingLength = 0.14,
	CasingDiameter = 0.07,
	EjectionRightSpeed = 11,
	EjectionUpSpeed = 6,
	EjectionForwardSpeed = 1.5,
	EjectionSpin = 18,
	TracerWidth = 0.055,
	TracerLifetimeSeconds = 0.055,
	TracerTransparency = 0.22,
	ImpactDiameter = 0.42,
	ImpactLifetimeSeconds = 0.12,
	ImpactLightBrightness = 1.8,
	AudioVolumeMultiplier = 1,
	AudioPitchMinimumMultiplier = 1,
	AudioPitchMaximumMultiplier = 1,
	ReloadVolumeMultiplier = 1,
	ReloadPlaybackSpeedMultiplier = 0.9,
})

local LegacyServiceFirearm = profile({
	WeaponId = FirearmConfig.BasicFirearm.WeaponId,
	BoltTravelStuds = SupportLMG.BoltTravelStuds,
	GripKickBackStuds = SupportLMG.GripKickBackStuds,
	GripKickUpStuds = SupportLMG.GripKickUpStuds,
	GripKickDegrees = SupportLMG.GripKickDegrees,
	CameraKickDegrees = SupportLMG.CameraKickDegrees,
	CameraYawDegrees = SupportLMG.CameraYawDegrees,
	CameraFovKickDegrees = SupportLMG.CameraFovKickDegrees,
	CameraRecoveryDegreesPerSecond = SupportLMG.CameraRecoveryDegreesPerSecond,
	ShotBackSeconds = SupportLMG.ShotBackSeconds,
	ShotReturnSeconds = SupportLMG.ShotReturnSeconds,
	MagazineOutX = SupportLMG.MagazineOutX,
	MagazineOutZ = SupportLMG.MagazineOutZ,
	MagazineRollDegrees = SupportLMG.MagazineRollDegrees,
	ReloadOutwardFraction = SupportLMG.ReloadOutwardFraction,
	ReloadHoldFraction = SupportLMG.ReloadHoldFraction,
	ReloadReturnFraction = SupportLMG.ReloadReturnFraction,
	MuzzleFlashDiameter = SupportLMG.MuzzleFlashDiameter,
	MuzzleFlashSeconds = SupportLMG.MuzzleFlashSeconds,
	MuzzleLightBrightness = SupportLMG.MuzzleLightBrightness,
	MuzzleLightRange = SupportLMG.MuzzleLightRange,
	CasingKindId = SupportLMG.CasingKindId,
	CasingLength = SupportLMG.CasingLength,
	CasingDiameter = SupportLMG.CasingDiameter,
	EjectionRightSpeed = SupportLMG.EjectionRightSpeed,
	EjectionUpSpeed = SupportLMG.EjectionUpSpeed,
	EjectionForwardSpeed = SupportLMG.EjectionForwardSpeed,
	EjectionSpin = SupportLMG.EjectionSpin,
	TracerWidth = SupportLMG.TracerWidth,
	TracerLifetimeSeconds = SupportLMG.TracerLifetimeSeconds,
	TracerTransparency = SupportLMG.TracerTransparency,
	ImpactDiameter = SupportLMG.ImpactDiameter,
	ImpactLifetimeSeconds = SupportLMG.ImpactLifetimeSeconds,
	ImpactLightBrightness = SupportLMG.ImpactLightBrightness,
	AudioVolumeMultiplier = SupportLMG.AudioVolumeMultiplier,
	AudioPitchMinimumMultiplier = SupportLMG.AudioPitchMinimumMultiplier,
	AudioPitchMaximumMultiplier = SupportLMG.AudioPitchMaximumMultiplier,
	ReloadVolumeMultiplier = SupportLMG.ReloadVolumeMultiplier,
	ReloadPlaybackSpeedMultiplier = SupportLMG.ReloadPlaybackSpeedMultiplier,
})

local BreachShotgun = profile({
	WeaponId = FirearmConfig.BreachShotgun.WeaponId,
	BoltTravelStuds = 0.3,
	GripKickBackStuds = 0.27,
	GripKickUpStuds = 0.08,
	GripKickDegrees = 5.5,
	CameraKickDegrees = 2.6,
	CameraYawDegrees = 0.45,
	CameraFovKickDegrees = 1.4,
	CameraRecoveryDegreesPerSecond = 9,
	ShotBackSeconds = 0.075,
	ShotReturnSeconds = 0.18,
	MagazineOutX = 0.16,
	MagazineOutZ = -0.62,
	MagazineRollDegrees = 12,
	ReloadOutwardFraction = 0.3,
	ReloadHoldFraction = 0.3,
	ReloadReturnFraction = 0.4,
	MuzzleFlashDiameter = 0.78,
	MuzzleFlashSeconds = 0.07,
	MuzzleLightBrightness = 4.1,
	MuzzleLightRange = 11,
	CasingKindId = "ShotgunShell",
	CasingLength = 0.23,
	CasingDiameter = 0.12,
	EjectionRightSpeed = 8,
	EjectionUpSpeed = 5,
	EjectionForwardSpeed = 0.5,
	EjectionSpin = 12,
	TracerWidth = 0.12,
	TracerLifetimeSeconds = 0.085,
	TracerTransparency = 0.14,
	ImpactDiameter = 0.88,
	ImpactLifetimeSeconds = 0.18,
	ImpactLightBrightness = 3.2,
	AudioVolumeMultiplier = 1.35,
	AudioPitchMinimumMultiplier = 0.82,
	AudioPitchMaximumMultiplier = 0.9,
	ReloadVolumeMultiplier = 1.1,
	ReloadPlaybackSpeedMultiplier = 0.86,
})

local SniperRifle = profile({
	WeaponId = FirearmConfig.SniperRifle.WeaponId,
	BoltTravelStuds = 0.36,
	GripKickBackStuds = 0.34,
	GripKickUpStuds = 0.065,
	GripKickDegrees = 6.5,
	CameraKickDegrees = 3.4,
	CameraYawDegrees = 0.3,
	CameraFovKickDegrees = 1.8,
	CameraRecoveryDegreesPerSecond = 7,
	ShotBackSeconds = 0.09,
	ShotReturnSeconds = 0.24,
	MagazineOutX = 0.18,
	MagazineOutZ = -0.7,
	MagazineRollDegrees = 10,
	ReloadOutwardFraction = 0.34,
	ReloadHoldFraction = 0.24,
	ReloadReturnFraction = 0.42,
	MuzzleFlashDiameter = 0.66,
	MuzzleFlashSeconds = 0.065,
	MuzzleLightBrightness = 4.5,
	MuzzleLightRange = 14,
	CasingKindId = "HeavyRifle",
	CasingLength = 0.2,
	CasingDiameter = 0.09,
	EjectionRightSpeed = 10,
	EjectionUpSpeed = 7,
	EjectionForwardSpeed = 1,
	EjectionSpin = 16,
	TracerWidth = 0.08,
	TracerLifetimeSeconds = 0.12,
	TracerTransparency = 0.08,
	ImpactDiameter = 0.76,
	ImpactLifetimeSeconds = 0.2,
	ImpactLightBrightness = 3.5,
	AudioVolumeMultiplier = 1.45,
	AudioPitchMinimumMultiplier = 0.74,
	AudioPitchMaximumMultiplier = 0.82,
	ReloadVolumeMultiplier = 1.08,
	ReloadPlaybackSpeedMultiplier = 0.82,
})

local ServicePistol = profile({
	WeaponId = FirearmConfig.ServicePistol.WeaponId,
	BoltTravelStuds = 0.15,
	GripKickBackStuds = 0.075,
	GripKickUpStuds = 0.025,
	GripKickDegrees = 2.8,
	CameraKickDegrees = 1.2,
	CameraYawDegrees = 0.25,
	CameraFovKickDegrees = 0.7,
	CameraRecoveryDegreesPerSecond = 14,
	ShotBackSeconds = 0.035,
	ShotReturnSeconds = 0.05,
	MagazineOutX = 0.08,
	MagazineOutZ = -0.48,
	MagazineRollDegrees = 5,
	ReloadOutwardFraction = 0.28,
	ReloadHoldFraction = 0.2,
	ReloadReturnFraction = 0.52,
	MuzzleFlashDiameter = 0.3,
	MuzzleFlashSeconds = 0.035,
	MuzzleLightBrightness = 1.5,
	MuzzleLightRange = 5,
	CasingKindId = "Pistol",
	CasingLength = 0.1,
	CasingDiameter = 0.05,
	EjectionRightSpeed = 9,
	EjectionUpSpeed = 5,
	EjectionForwardSpeed = 0.8,
	EjectionSpin = 20,
	TracerWidth = 0.035,
	TracerLifetimeSeconds = 0.04,
	TracerTransparency = 0.32,
	ImpactDiameter = 0.32,
	ImpactLifetimeSeconds = 0.09,
	ImpactLightBrightness = 1.3,
	AudioVolumeMultiplier = 0.76,
	AudioPitchMinimumMultiplier = 1.1,
	AudioPitchMaximumMultiplier = 1.18,
	ReloadVolumeMultiplier = 0.82,
	ReloadPlaybackSpeedMultiplier = 1.24,
})

local SubmachineGun = profile({
	WeaponId = FirearmConfig.SubmachineGun.WeaponId,
	BoltTravelStuds = 0.12,
	GripKickBackStuds = 0.05,
	GripKickUpStuds = 0.01,
	GripKickDegrees = 1.1,
	CameraKickDegrees = 0.45,
	CameraYawDegrees = 0.15,
	CameraFovKickDegrees = 0.3,
	CameraRecoveryDegreesPerSecond = 18,
	ShotBackSeconds = 0.028,
	ShotReturnSeconds = 0.04,
	MagazineOutX = 0.14,
	MagazineOutZ = -0.58,
	MagazineRollDegrees = 9,
	ReloadOutwardFraction = 0.31,
	ReloadHoldFraction = 0.18,
	ReloadReturnFraction = 0.51,
	MuzzleFlashDiameter = 0.32,
	MuzzleFlashSeconds = 0.026,
	MuzzleLightBrightness = 1.6,
	MuzzleLightRange = 5,
	CasingKindId = "Pistol",
	CasingLength = 0.1,
	CasingDiameter = 0.05,
	EjectionRightSpeed = 10,
	EjectionUpSpeed = 4,
	EjectionForwardSpeed = 1.2,
	EjectionSpin = 22,
	TracerWidth = 0.03,
	TracerLifetimeSeconds = 0.035,
	TracerTransparency = 0.35,
	ImpactDiameter = 0.28,
	ImpactLifetimeSeconds = 0.07,
	ImpactLightBrightness = 1.1,
	AudioVolumeMultiplier = 0.66,
	AudioPitchMinimumMultiplier = 1.18,
	AudioPitchMaximumMultiplier = 1.3,
	ReloadVolumeMultiplier = 0.88,
	ReloadPlaybackSpeedMultiplier = 1.1,
})

local DefinitionsById = table.freeze({
	[LegacyServiceFirearm.WeaponId] = LegacyServiceFirearm,
	[SupportLMG.WeaponId] = SupportLMG,
	[BreachShotgun.WeaponId] = BreachShotgun,
	[SniperRifle.WeaponId] = SniperRifle,
	[ServicePistol.WeaponId] = ServicePistol,
	[SubmachineGun.WeaponId] = SubmachineGun,
})

local function get(weaponId: unknown): WeaponFeelProfile?
	return if type(weaponId) == "string" then DefinitionsById[weaponId] else nil
end

for weaponId, entry in DefinitionsById do
	assert(entry.WeaponId == weaponId, "weapon feel profile identity must match its key")
	assert(entry.BoltTravelStuds > 0 and entry.BoltTravelStuds <= 0.5, "bolt travel must stay presentation-bounded")
	assert(entry.GripKickBackStuds >= 0 and entry.GripKickBackStuds <= 0.5, "grip kick must stay presentation-bounded")
	assert(entry.CameraKickDegrees > 0 and entry.CameraKickDegrees <= 4, "camera kick must stay readable and bounded")
	assert(entry.CameraYawDegrees >= 0 and entry.CameraYawDegrees <= 0.75, "camera yaw must stay presentation-bounded")
	assert(entry.CameraFovKickDegrees >= 0 and entry.CameraFovKickDegrees <= 2, "camera FOV kick must stay bounded")
	assert(
		entry.CameraRecoveryDegreesPerSecond >= 6 and entry.CameraRecoveryDegreesPerSecond <= 20,
		"camera recovery must remain responsive"
	)
	assert(entry.ShotBackSeconds >= 0.02 and entry.ShotBackSeconds <= 0.15, "shot back motion must stay bounded")
	assert(entry.ShotReturnSeconds >= 0.03 and entry.ShotReturnSeconds <= 0.3, "shot return motion must stay bounded")
	assert(
		math.abs(entry.ReloadOutwardFraction + entry.ReloadHoldFraction + entry.ReloadReturnFraction - 1) < 0.0001,
		"reload presentation fractions must total one"
	)
	assert(entry.MuzzleFlashDiameter > 0 and entry.MuzzleFlashDiameter <= 1, "muzzle flash must stay bounded")
	assert(entry.TracerWidth > 0 and entry.TracerWidth <= 0.15, "tracer width must stay bounded")
	assert(entry.AudioPitchMinimumMultiplier > 0, "audio pitch minimum must be positive")
	assert(entry.AudioPitchMaximumMultiplier >= entry.AudioPitchMinimumMultiplier, "audio pitch range must be ordered")
end

for _, weaponId in FirearmConfig.SelectableWeaponIds do
	assert(DefinitionsById[weaponId] ~= nil, "every selectable firearm requires a feel profile")
end

local Config = {
	Version = "MVP-0.1-v2-responsive-gunfeel",
	Default = SupportLMG,
	DefinitionsById = DefinitionsById,
	get = get,
}

return table.freeze(Config)
