--!strict

--[[
	Server-consumed firing-pattern definitions for the firearm roster. The shotgun
	pattern is now derived from the base weapon's bounded pellet/spread data, so a
	future item/stat resolver can change behavior without creating a copied firing
	script. These patterns never accept client target, damage or ammunition input.
]]

local FirearmConfig = require(script.Parent.FirearmConfig)

local ModeIds = table.freeze({
	SingleTarget = "SingleTarget",
	ConeCleave = "ConeCleave",
	LinePierce = "LinePierce",
})

export type WeaponPatternDefinition = {
	WeaponId: string,
	ModeId: string,
	MaximumSecondaryTargets: number,
	SecondaryDamageMultiplier: number,
	MaximumSecondaryRangeStuds: number,
	ConeHalfAngleDegrees: number?,
	PierceHalfWidthStuds: number?,
	MinimumBeyondPrimaryStuds: number?,
}

local function singleTarget(weaponId: string): WeaponPatternDefinition
	return table.freeze({
		WeaponId = weaponId,
		ModeId = ModeIds.SingleTarget,
		MaximumSecondaryTargets = 0,
		SecondaryDamageMultiplier = 1,
		MaximumSecondaryRangeStuds = 0,
		ConeHalfAngleDegrees = nil,
		PierceHalfWidthStuds = nil,
		MinimumBeyondPrimaryStuds = nil,
	})
end

local BasicFirearm = singleTarget(FirearmConfig.BasicFirearm.WeaponId)
local LightMachineGun = singleTarget(FirearmConfig.LightMachineGun.WeaponId)
local ServicePistol = singleTarget(FirearmConfig.ServicePistol.WeaponId)
local SubmachineGun = singleTarget(FirearmConfig.SubmachineGun.WeaponId)

local shotgunPelletCount = FirearmConfig.BreachShotgun.PelletCount or 4
local shotgunSpreadDegrees = FirearmConfig.BreachShotgun.SpreadDegrees or 26
local BreachShotgun: WeaponPatternDefinition = table.freeze({
	WeaponId = FirearmConfig.BreachShotgun.WeaponId,
	ModeId = ModeIds.ConeCleave,
	MaximumSecondaryTargets = math.min(3, math.max(0, shotgunPelletCount - 1)),
	SecondaryDamageMultiplier = 0.7,
	MaximumSecondaryRangeStuds = 30,
	ConeHalfAngleDegrees = shotgunSpreadDegrees,
	PierceHalfWidthStuds = nil,
	MinimumBeyondPrimaryStuds = nil,
})

local SniperRifle: WeaponPatternDefinition = table.freeze({
	WeaponId = FirearmConfig.SniperRifle.WeaponId,
	ModeId = ModeIds.LinePierce,
	MaximumSecondaryTargets = 1,
	SecondaryDamageMultiplier = 0.72,
	MaximumSecondaryRangeStuds = FirearmConfig.SniperRifle.RangeStuds,
	ConeHalfAngleDegrees = nil,
	PierceHalfWidthStuds = 3.25,
	MinimumBeyondPrimaryStuds = 2,
})

local DefinitionsById = table.freeze({
	[BasicFirearm.WeaponId] = BasicFirearm,
	[LightMachineGun.WeaponId] = LightMachineGun,
	[BreachShotgun.WeaponId] = BreachShotgun,
	[SniperRifle.WeaponId] = SniperRifle,
	[ServicePistol.WeaponId] = ServicePistol,
	[SubmachineGun.WeaponId] = SubmachineGun,
})

local function get(weaponId: unknown): WeaponPatternDefinition?
	return if type(weaponId) == "string" then DefinitionsById[weaponId] else nil
end

for weaponId, definition in DefinitionsById do
	assert(definition.WeaponId == weaponId, "weapon pattern identity must match its key")
	assert(
		definition.MaximumSecondaryTargets >= 0 and definition.MaximumSecondaryTargets <= 3,
		"secondary target count must remain tightly bounded"
	)
	assert(
		definition.SecondaryDamageMultiplier > 0 and definition.SecondaryDamageMultiplier <= 1,
		"secondary damage multiplier must be positive and cannot exceed primary damage"
	)
	if definition.ModeId == ModeIds.SingleTarget then
		assert(definition.MaximumSecondaryTargets == 0, "single-target weapons cannot emit secondary impacts")
	elseif definition.ModeId == ModeIds.ConeCleave then
		assert(definition.ConeHalfAngleDegrees ~= nil, "cone patterns require an angle")
		assert(
			definition.ConeHalfAngleDegrees > 0 and definition.ConeHalfAngleDegrees <= 30,
			"cone half-angle must remain bounded"
		)
		assert(
			definition.MaximumSecondaryTargets <= shotgunPelletCount - 1,
			"shotgun secondary impacts cannot exceed pellet budget"
		)
		assert(
			definition.MaximumSecondaryRangeStuds > 0
				and definition.MaximumSecondaryRangeStuds <= FirearmConfig.BreachShotgun.RangeStuds,
			"shotgun secondary range cannot exceed configured weapon range"
		)
	elseif definition.ModeId == ModeIds.LinePierce then
		assert(definition.PierceHalfWidthStuds ~= nil, "line-pierce patterns require a half-width")
		assert(definition.MinimumBeyondPrimaryStuds ~= nil, "line-pierce patterns require primary separation")
		assert(
			definition.PierceHalfWidthStuds > 0 and definition.PierceHalfWidthStuds <= 4,
			"pierce width must remain bounded"
		)
	else
		error("unknown weapon pattern mode: " .. definition.ModeId)
	end
end

for _, weaponId in FirearmConfig.SelectableWeaponIds do
	assert(DefinitionsById[weaponId] ~= nil, "every selectable firearm requires a pattern definition")
end

local Config = {
	Version = "WAVE-2-v1-data-driven-patterns",
	ModeIds = ModeIds,
	BasicFirearm = BasicFirearm,
	LightMachineGun = LightMachineGun,
	BreachShotgun = BreachShotgun,
	SniperRifle = SniperRifle,
	ServicePistol = ServicePistol,
	SubmachineGun = SubmachineGun,
	DefinitionsById = DefinitionsById,
	get = get,
}

return table.freeze(Config)
