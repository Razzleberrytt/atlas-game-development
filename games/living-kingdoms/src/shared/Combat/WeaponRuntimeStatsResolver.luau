--!strict

--[[
	Pure composition seam between immutable base weapon definitions and trusted
	server-owned item/equipment modifiers. This module deliberately knows nothing
	about inventory records or loot generation: Agent 3 (or a future item system)
	can translate an equipped item into this small modifier shape, while combat
	continues to consume one resolved runtime stat bundle.
]]

export type WeaponStatModifiers = {
	DamageMultiplier: number?,
	CadenceMultiplier: number?,
	MagazineCapacityMultiplier: number?,
	ReloadDurationMultiplier: number?,
	SpreadMultiplier: number?,
	HeadshotMultiplierBonus: number?,
}

export type ResolvedWeaponStats = {
	WeaponId: string,
	DamagePerHit: number,
	CadenceSeconds: number,
	MagazineCapacity: number,
	ReloadDurationSeconds: number,
	RangeStuds: number,
	FiringModeId: string,
	PelletCount: number,
	SpreadDegrees: number,
	HeadshotMultiplier: number,
	BurstCount: number,
	BurstIntervalSeconds: number,
}

local Resolver = {}

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function multiplier(value: unknown, minimum: number, maximum: number): number?
	if value == nil then
		return 1
	end
	if not finite(value) or value < minimum or value > maximum then
		return nil
	end
	return value :: number
end

function Resolver.resolve(baseDefinition: any, modifiers: WeaponStatModifiers?): ResolvedWeaponStats?
	if
		type(baseDefinition) ~= "table"
		or type(baseDefinition.WeaponId) ~= "string"
		or baseDefinition.WeaponId == ""
		or not finite(baseDefinition.DamagePerHit)
		or not finite(baseDefinition.CadenceSeconds)
		or not finite(baseDefinition.MagazineCapacity)
		or not finite(baseDefinition.ReloadDurationSeconds)
		or not finite(baseDefinition.RangeStuds)
		or type(baseDefinition.FiringModeId) ~= "string"
		or not finite(baseDefinition.PelletCount)
		or not finite(baseDefinition.SpreadDegrees)
		or not finite(baseDefinition.HeadshotMultiplier)
		or not finite(baseDefinition.BurstCount)
		or not finite(baseDefinition.BurstIntervalSeconds)
	then
		return nil
	end
	local values = modifiers or {}
	local damageMultiplier = multiplier(values.DamageMultiplier, 0.5, 2)
	local cadenceMultiplier = multiplier(values.CadenceMultiplier, 0.55, 1.5)
	local magazineMultiplier = multiplier(values.MagazineCapacityMultiplier, 0.5, 2)
	local reloadMultiplier = multiplier(values.ReloadDurationMultiplier, 0.55, 1.5)
	local spreadMultiplier = multiplier(values.SpreadMultiplier, 0.5, 2)
	local headshotBonus = values.HeadshotMultiplierBonus or 0
	if
		damageMultiplier == nil
		or cadenceMultiplier == nil
		or magazineMultiplier == nil
		or reloadMultiplier == nil
		or spreadMultiplier == nil
		or not finite(headshotBonus)
		or headshotBonus < 0
		or headshotBonus > 1
	then
		return nil
	end
	local damage = math.max(1, math.floor(baseDefinition.DamagePerHit * damageMultiplier + 0.5))
	local magazine = math.max(1, math.floor(baseDefinition.MagazineCapacity * magazineMultiplier + 0.5))
	return table.freeze({
		WeaponId = baseDefinition.WeaponId,
		DamagePerHit = math.min(300, damage),
		CadenceSeconds = math.clamp(baseDefinition.CadenceSeconds * cadenceMultiplier, 0.05, 3),
		MagazineCapacity = math.min(200, magazine),
		ReloadDurationSeconds = math.clamp(baseDefinition.ReloadDurationSeconds * reloadMultiplier, 0.5, 7.5),
		RangeStuds = baseDefinition.RangeStuds,
		FiringModeId = baseDefinition.FiringModeId,
		PelletCount = baseDefinition.PelletCount,
		SpreadDegrees = math.clamp(baseDefinition.SpreadDegrees * spreadMultiplier, 0, 30),
		HeadshotMultiplier = math.clamp(baseDefinition.HeadshotMultiplier + headshotBonus, 1, 3),
		BurstCount = baseDefinition.BurstCount,
		BurstIntervalSeconds = baseDefinition.BurstIntervalSeconds,
	})
end

function Resolver.resolveImpactDamage(stats: ResolvedWeaponStats, isCriticalHit: boolean): number?
	if type(stats) ~= "table" or type(isCriticalHit) ~= "boolean" then
		return nil
	end
	local multiplierValue = if isCriticalHit then stats.HeadshotMultiplier else 1
	if not finite(stats.DamagePerHit) or not finite(multiplierValue) or multiplierValue < 1 or multiplierValue > 3 then
		return nil
	end
	return math.max(1, math.min(900, math.floor(stats.DamagePerHit * multiplierValue + 0.5)))
end

return table.freeze(Resolver)
