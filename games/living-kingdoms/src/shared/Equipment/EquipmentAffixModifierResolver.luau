--!strict

-- Patch 0.3 pure equipment-affix modifier adapter.
--
-- Durable equipment owns the affix facts; RunModifierResolver owns the global
-- arithmetic ceilings. This adapter only translates validated equipment effect
-- percentages into that canonical vocabulary. It owns no state and creates no
-- runtime authority.

local EquipmentRewardContracts = require(script.Parent.EquipmentRewardContracts)
local RunModifierResolver = require(script.Parent.Parent.Progression.RunModifierResolver)

export type EquipmentAffixRoll = EquipmentRewardContracts.EquipmentAffixRoll
export type ResolvedModifiers = {
	damageMultiplier: number,
}

local EquipmentAffixModifierResolver = {}

local DAMAGE_EFFECT_ID = "DamagePercent"
local PERCENT_SCALE = 100

local function neutral(): ResolvedModifiers
	return table.freeze({ damageMultiplier = 1 })
end

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
end

--[[
	Resolves only effects that have an existing canonical runtime owner. The first
	live Patch 0.3 application is DamagePercent; reload, life, movement, and ability
	effects remain inert until their own authority seams are wired explicitly.

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
		end
	end

	local bounded = RunModifierResolver.resolve({ damageBonus = damagePercent / PERCENT_SCALE })
	return table.freeze({ damageMultiplier = bounded.damageMultiplier })
end

function EquipmentAffixModifierResolver.neutral(): ResolvedModifiers
	return neutral()
end

return table.freeze(EquipmentAffixModifierResolver)
