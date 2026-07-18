--!strict

-- Authoritative firearm roster. The legacy BasicFirearm definition remains for
-- compatibility while five selectable weapons provide distinct combat roles.
local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)

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
	DisplayName = "Legacy Service Firearm",
	ShortName = "SERVICE FIREARM",
	RoleDescription = "Compatibility loadout used only before insertion locks.",
	RangeStuds = 80,
	CadenceSeconds = 0.2,
	MagazineCapacity = 12,
	PrototypeInitialLoadedRounds = scarcity.InitialLoadedRounds,
	PrototypeInitialReserveRounds = scarcity.InitialReserveRounds,
	MaximumReserveRounds = scarcity.MaximumReserveRounds,
	AuthoredCacheRounds = scarcity.AuthoredCacheRounds or 12,
	ReloadDurationSeconds = 2,
	DamagePerHit = 20,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
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
})

local BreachShotgun: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.BreachShotgun,
	DisplayName = "Morrow Breach Shotgun",
	ShortName = "BREACH SHOTGUN",
	RoleDescription = "Devastating close-range blast with punishing downtime.",
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
})

local SniperRifle: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.SniperRifle,
	DisplayName = "Longwatch Sniper Rifle",
	ShortName = "SNIPER RIFLE",
	RoleDescription = "Extreme range and lethal single hits, very low fire rate.",
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
})

local ServicePistol: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.ServicePistol,
	DisplayName = "Vigil Service Pistol",
	ShortName = "SERVICE PISTOL",
	RoleDescription = "Fast handling, efficient ammunition, dependable fallback.",
	RangeStuds = 66,
	CadenceSeconds = 0.3,
	MagazineCapacity = 15,
	PrototypeInitialLoadedRounds = 15,
	PrototypeInitialReserveRounds = 45,
	MaximumReserveRounds = 90,
	AuthoredCacheRounds = 18,
	ReloadDurationSeconds = 1.35,
	DamagePerHit = 18,
	DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
})

local SubmachineGun: FirearmDefinition = table.freeze({
	WeaponId = WeaponIds.SubmachineGun,
	DisplayName = "Razor Compact SMG",
	ShortName = "COMPACT SMG",
	RoleDescription = "Highest fire rate and close-range horde control.",
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
	LightMachineGun.WeaponId,
	BreachShotgun.WeaponId,
	SniperRifle.WeaponId,
	ServicePistol.WeaponId,
	SubmachineGun.WeaponId,
})

local function get(weaponId: unknown): FirearmDefinition?
	return if type(weaponId) == "string" then definitionsById[weaponId] else nil
end

local function isKnownWeaponId(weaponId: unknown): boolean
	return get(weaponId) ~= nil
end

local Config = {
	Version = "HROI-0120-v1-server-owned-weapon-roster",
	BasicFirearm = BasicFirearm,
	LightMachineGun = LightMachineGun,
	BreachShotgun = BreachShotgun,
	SniperRifle = SniperRifle,
	ServicePistol = ServicePistol,
	SubmachineGun = SubmachineGun,
	DefaultSelectableWeaponId = LightMachineGun.WeaponId,
	DefinitionsById = definitionsById,
	SelectableWeaponIds = selectableWeaponIds,
	get = get,
	isKnownWeaponId = isKnownWeaponId,
}

local seen = {}
for _, weaponId in selectableWeaponIds do
	assert(not seen[weaponId], "selectable weapon IDs must be unique")
	seen[weaponId] = true
	local definition = definitionsById[weaponId]
	assert(definition ~= nil, "every selectable weapon requires a definition")
	assert(definition.MagazineCapacity > 0 and definition.MagazineCapacity % 1 == 0, "magazine must be positive")
	assert(definition.PrototypeInitialLoadedRounds == definition.MagazineCapacity, "selectable weapons start loaded")
	assert(definition.PrototypeInitialReserveRounds <= definition.MaximumReserveRounds, "reserve must fit carry cap")
	assert(definition.CadenceSeconds >= 0.05 and definition.CadenceSeconds <= 2, "cadence must remain bounded")
	assert(definition.RangeStuds >= 30 and definition.RangeStuds <= 180, "weapon range must remain bounded")
	assert(definition.DamagePerHit > 0 and definition.DamagePerHit <= 150, "weapon damage must remain bounded")
	assert(
		definition.ReloadDurationSeconds >= 1 and definition.ReloadDurationSeconds <= 5,
		"reload must remain bounded"
	)
end
assert(#selectableWeaponIds == 5, "the first weapon roster must contain exactly five selectable weapons")

return table.freeze(Config)
