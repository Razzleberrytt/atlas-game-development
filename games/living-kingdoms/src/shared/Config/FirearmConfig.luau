--!strict

--[[
	Authoritative firearm roster and behavior archetypes. Runtime code consumes
	these definitions instead of branching on individual weapon IDs. Presentation
	recoil remains in WeaponFeelConfig; generated item/equipment modifiers can be
	composed separately through WeaponRuntimeStatsResolver without changing the
	base roster.
]]
local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)

local FiringModeIds = table.freeze({
	Automatic = "Automatic",
	SemiAutomatic = "SemiAutomatic",
	Burst = "Burst",
})

export type FiringModeId = "Automatic" | "SemiAutomatic" | "Burst"

export type FirearmDefinition = {
	WeaponId: string,
	DisplayName: string,
	ShortName: string,
	RoleDescription: string,
	RangeStuds: number,
	CadenceSeconds: number,
	MagazineCapacity: number,
	PrototypeInitialLoadedRounds: number,
	PrototypeInitialReserveRounds: number,
	MaximumReserveRounds: number,
	AuthoredCacheRounds: number,
	ReloadDurationSeconds: number,
	DamagePerHit: number,
	DamageTypeId: string,
	FiringModeId: FiringModeId,
	PelletCount: number,
	SpreadDegrees: number,
	HeadshotMultiplier: number,
	BurstCount: number,
	BurstIntervalSeconds: number,
}

local scarcityModule = script.Parent.AmmunitionScarcityConfig
local scarcity
if scarcityModule ~= nil then
	scarcity = require(scarcityModule).BasicFirearm
else
	scarcity = {
		InitialLoadedRounds = 12,
		InitialReserveRounds = 24,
		MaximumReserveRounds = 48,
		AuthoredCacheRounds = 12,
	}
end

local WeaponIds = CombatContracts.WeaponIds
local BasicFirearm: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.BasicFirearm,
	DisplayName = "Legacy Service Burst Rifle",
	ShortName = "SERVICE BURST",
	RoleDescription = "Compatibility three-round burst rifle used before insertion locks.",
	RangeStuds = 80,
	CadenceSeconds = 0.48,
	MagazineCapacity = 12,
	PrototypeInitialLoadedRounds = scarcity.InitialLoadedRounds,
	PrototypeInitialReserveRounds = scarcity.InitialReserveRounds,
	MaximumReserveRounds = scarcity.MaximumReserveRounds,
	AuthoredCacheRounds = scarcity.AuthoredCacheRounds or 12,
	ReloadDurationSeconds = 2,
	DamagePerHit = 20,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
	FiringModeId = FiringModeIds.Burst,
	PelletCount = 1,
	SpreadDegrees = 1.2,
	HeadshotMultiplier = 1.5,
	BurstCount = 3,
	BurstIntervalSeconds = 0.09,
})

local LightMachineGun: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.LightMachineGun,
	DisplayName = "Blackwater Support LMG",
	ShortName = "SUPPORT LMG",
	RoleDescription = "Sustained automatic fire, deep magazine, slow reload.",
	RangeStuds = 92,
	CadenceSeconds = 0.12,
	MagazineCapacity = 48,
	PrototypeInitialLoadedRounds = 48,
	PrototypeInitialReserveRounds = 48,
	MaximumReserveRounds = 144,
	AuthoredCacheRounds = 24,
	ReloadDurationSeconds = 4.1,
	DamagePerHit = 12,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
	FiringModeId = FiringModeIds.Automatic,
	PelletCount = 1,
	SpreadDegrees = 1.8,
	HeadshotMultiplier = 1.4,
	BurstCount = 1,
	BurstIntervalSeconds = 0.12,
})

local BreachShotgun: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.BreachShotgun,
	DisplayName = "Morrow Breach Shotgun",
	ShortName = "BREACH SHOTGUN",
	RoleDescription = "Semi-automatic close-range multi-pellet blast with punishing downtime.",
	RangeStuds = 38,
	CadenceSeconds = 0.82,
	MagazineCapacity = 6,
	PrototypeInitialLoadedRounds = 6,
	PrototypeInitialReserveRounds = 18,
	MaximumReserveRounds = 36,
	AuthoredCacheRounds = 8,
	ReloadDurationSeconds = 2.7,
	DamagePerHit = 78,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
	FiringModeId = FiringModeIds.SemiAutomatic,
	PelletCount = 4,
	SpreadDegrees = 26,
	HeadshotMultiplier = 1.25,
	BurstCount = 1,
	BurstIntervalSeconds = 0.82,
})

local SniperRifle: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.SniperRifle,
	DisplayName = "Longwatch Sniper Rifle",
	ShortName = "SNIPER RIFLE",
	RoleDescription = "Semi-automatic precision rifle with extreme range and weak-point payoff.",
	RangeStuds = 165,
	CadenceSeconds = 1.35,
	MagazineCapacity = 5,
	PrototypeInitialLoadedRounds = 5,
	PrototypeInitialReserveRounds = 10,
	MaximumReserveRounds = 25,
	AuthoredCacheRounds = 5,
	ReloadDurationSeconds = 2.9,
	DamagePerHit = 120,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
	FiringModeId = FiringModeIds.SemiAutomatic,
	PelletCount = 1,
	SpreadDegrees = 0.25,
	HeadshotMultiplier = 2,
	BurstCount = 1,
	BurstIntervalSeconds = 1.35,
})

local ServicePistol: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.ServicePistol,
	DisplayName = "Vigil Service Pistol",
	ShortName = "SERVICE PISTOL",
	RoleDescription = "Semi-automatic scarce-ammo survival sidearm. Make every shot count.",
	RangeStuds = 66,
	CadenceSeconds = 0.34,
	MagazineCapacity = 8,
	PrototypeInitialLoadedRounds = 8,
	PrototypeInitialReserveRounds = 8,
	MaximumReserveRounds = 32,
	AuthoredCacheRounds = 6,
	ReloadDurationSeconds = 1.35,
	DamagePerHit = 28,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
	FiringModeId = FiringModeIds.SemiAutomatic,
	PelletCount = 1,
	SpreadDegrees = 1,
	HeadshotMultiplier = 1.6,
	BurstCount = 1,
	BurstIntervalSeconds = 0.34,
})

local SubmachineGun: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.SubmachineGun,
	DisplayName = "Razor Compact SMG",
	ShortName = "COMPACT SMG",
	RoleDescription = "Highest automatic fire rate with aggressive close-range spread.",
	RangeStuds = 54,
	CadenceSeconds = 0.085,
	MagazineCapacity = 30,
	PrototypeInitialLoadedRounds = 30,
	PrototypeInitialReserveRounds = 60,
	MaximumReserveRounds = 150,
	AuthoredCacheRounds = 30,
	ReloadDurationSeconds = 1.9,
	DamagePerHit = 8,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
	FiringModeId = FiringModeIds.Automatic,
	PelletCount = 1,
	SpreadDegrees = 3.2,
	HeadshotMultiplier = 1.35,
	BurstCount = 1,
	BurstIntervalSeconds = 0.085,
})

local definitionsById = table.freeze({
	[BasicFirearm.WeaponId] = BasicFirearm,
	[LightMachineGun.WeaponId] = LightMachineGun,
	[BreachShotgun.WeaponId] = BreachShotgun,
	[SniperRifle.WeaponId] = SniperRifle,
	[ServicePistol.WeaponId] = ServicePistol,
	[SubmachineGun.WeaponId] = SubmachineGun,
})
local selectableWeaponIds = table.freeze({
	ServicePistol.WeaponId,
})

-- These remain server-owned definitions for exceptionally rare in-run finds.
-- They are deliberately absent from insertion selection and are not monetized.
local discoverableWeaponIds = table.freeze({
	LightMachineGun.WeaponId,
	BreachShotgun.WeaponId,
	SniperRifle.WeaponId,
	SubmachineGun.WeaponId,
})

local function get(weaponId: unknown): FirearmDefinition?
	return if type(weaponId) == "string" then definitionsById[weaponId] else nil
end

local function isKnownWeaponId(weaponId: unknown): boolean
	return get(weaponId) ~= nil
end

local seen = {}
for weaponId, definition in definitionsById do
	assert(not seen[weaponId], "weapon IDs must be unique")
	seen[weaponId] = true
	assert(definition.WeaponId == weaponId, "weapon definition identity must match its key")
	assert(definition.MagazineCapacity > 0 and definition.MagazineCapacity % 1 == 0, "magazine must be positive")
	assert(definition.PrototypeInitialLoadedRounds <= definition.MagazineCapacity, "initial load must fit magazine")
	assert(definition.PrototypeInitialReserveRounds <= definition.MaximumReserveRounds, "reserve must fit carry cap")
	assert(definition.CadenceSeconds >= 0.05 and definition.CadenceSeconds <= 2, "cadence must remain bounded")
	assert(definition.RangeStuds >= 30 and definition.RangeStuds <= 180, "weapon range must remain bounded")
	assert(definition.DamagePerHit > 0 and definition.DamagePerHit <= 150, "weapon damage must remain bounded")
	assert(definition.ReloadDurationSeconds >= 1 and definition.ReloadDurationSeconds <= 5, "reload must remain bounded")
	assert(definition.PelletCount >= 1 and definition.PelletCount <= 8 and definition.PelletCount % 1 == 0, "pellet count must stay bounded")
	assert(definition.SpreadDegrees >= 0 and definition.SpreadDegrees <= 30, "spread must stay bounded")
	assert(definition.HeadshotMultiplier >= 1 and definition.HeadshotMultiplier <= 2.5, "headshot multiplier must stay bounded")
	assert(definition.BurstCount >= 1 and definition.BurstCount <= 5 and definition.BurstCount % 1 == 0, "burst count must stay bounded")
	assert(definition.BurstIntervalSeconds >= 0.05 and definition.BurstIntervalSeconds <= definition.CadenceSeconds, "burst interval must fit cadence")
	if definition.FiringModeId == FiringModeIds.Burst then
		assert(definition.BurstCount >= 2, "burst weapons require multiple shots")
	else
		assert(definition.BurstCount == 1, "non-burst weapons must use one-shot bursts")
	end
	if definition.PelletCount > 1 then
		assert(definition.FiringModeId == FiringModeIds.SemiAutomatic, "multi-pellet weapons must be semi-automatic")
	end
end

for _, weaponId in selectableWeaponIds do
	local definition = definitionsById[weaponId]
	assert(definition ~= nil, "every selectable weapon requires a definition")
	assert(definition.PrototypeInitialLoadedRounds == definition.MagazineCapacity, "selectable weapons start loaded")
end
assert(#selectableWeaponIds == 1, "insertion must expose only the service pistol")
assert(selectableWeaponIds[1] == ServicePistol.WeaponId, "the service pistol must own the opening loadout")

local Config = {
	Version = "WAVE-2-v1-data-driven-weapon-archetypes",
	FiringModeIds = FiringModeIds,
	MaximumPelletCount = 8,
	BasicFirearm = BasicFirearm,
	LightMachineGun = LightMachineGun,
	BreachShotgun = BreachShotgun,
	SniperRifle = SniperRifle,
	ServicePistol = ServicePistol,
	SubmachineGun = SubmachineGun,
	DefaultSelectableWeaponId = ServicePistol.WeaponId,
	DefinitionsById = definitionsById,
	SelectableWeaponIds = selectableWeaponIds,
	DiscoverableWeaponIds = discoverableWeaponIds,
	get = get,
	isKnownWeaponId = isKnownWeaponId,
}

return table.freeze(Config)