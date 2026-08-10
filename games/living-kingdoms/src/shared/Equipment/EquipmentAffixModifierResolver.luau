--!strict

-- Patch 0.3 pure equipment-affix modifier adapter.
--
-- Durable equipment owns the affix facts. Existing canonical modifier arithmetic
-- owns damage/reload bounds; this adapter adds the durable-life maximum-health
-- ceiling needed before OperativeLifeService can consume armor affixes. It owns
-- no state and creates no runtime authority.

local EquipmentRewardContracts = require(script.Parent.EquipmentRewardContracts)
local RunModifierResolver = require(script.Parent.Parent.Progression.RunModifierResolver)

export type EquipmentAffixRoll = EquipmentRewardContracts.EquipmentAffixRoll
export type ResolvedModifiers = {
	damageMultiplier: number,
	reloadDurationMultiplier: number,
	maximumHealthMultiplier: number,
}

local EquipmentAffixModifierResolver = {}

local DAMAGE_EFFECT_ID = "DamagePercent"
local RELOAD_SPEED_EFFECT_ID = "ReloadSpeedPercent"
local MAXIMUM_HEALTH_EFFECT_ID = "MaxHealthPercent"
local PERCENT_SCALE = 100
-- Durable maximum health is defense-in-depth bounded independently from run
-- effects. Current authored rolls are far below this ceiling; 2x is a hard
-- safety limit for malformed/future content, not a balance target.
local MAXIMUM_HEALTH_MULTIPLIER_CEILING = 2

local function neutral(): ResolvedModifiers
	return table.freeze({
		damageMultiplier = 1,
		reloadDurationMultiplier = 1,
		maximumHealthMultiplier = 1,
	})
end

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

--[[
	Resolves only effects that have an identified canonical runtime owner. Patch
	0.3 routes DamagePercent through damage, ReloadSpeedPercent through reload,
	and exposes bounded MaxHealthPercent for OperativeLifeService. Movement and
	ability effects remain inert until their authority seams are wired explicitly.

	Malformed affix data fails the entire bundle closed to neutral instead of
	partially applying a suspicious build. Unknown-but-well-formed effects are
	ignored so newer saved gear can coexist with an older runtime safely.
]]
function EquipmentAffixModifierResolver.resolve(affixes: { EquipmentAffixRoll }?): ResolvedModifiers
	if affixes == nil then
		return neutral()
	end
	if type(affixes) ~= "table" then
		return neutral()
	end

	local damagePercent = 0
	local reloadSpeedPercent = 0
	local maximumHealthPercent = 0
	for _, affix in affixes :: any do
		if
			type(affix) ~= "table"
			or type(affix.EffectId) ~= "string"
			or affix.EffectId == ""
			or not isFiniteNonnegative(affix.Value)
		then
			return neutral()
		end
		if affix.EffectId == DAMAGE_EFFECT_ID then
			damagePercent += affix.Value
		elseif affix.EffectId == RELOAD_SPEED_EFFECT_ID then
			reloadSpeedPercent += affix.Value
		elseif affix.EffectId == MAXIMUM_HEALTH_EFFECT_ID then
			maximumHealthPercent += affix.Value
		end
	end

	local bounded = RunModifierResolver.resolve({
		damageBonus = damagePercent / PERCENT_SCALE,
		reloadDurationReduction = reloadSpeedPercent / PERCENT_SCALE,
	})
	return table.freeze({
		damageMultiplier = bounded.damageMultiplier,
		reloadDurationMultiplier = bounded.reloadDurationMultiplier,
		maximumHealthMultiplier = math.min(
			MAXIMUM_HEALTH_MULTIPLIER_CEILING,
			1 + maximumHealthPercent / PERCENT_SCALE
		),
	})
end

function EquipmentAffixModifierResolver.neutral(): ResolvedModifiers
	return neutral()
end

return table.freeze(EquipmentAffixModifierResolver)
