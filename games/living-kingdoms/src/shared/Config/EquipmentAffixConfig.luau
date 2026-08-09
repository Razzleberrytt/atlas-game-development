--!strict

-- Patch 0.3 first affix pool. Values are intentionally narrow until play data
-- justifies larger bands. Compatibility is authored from stable equipment slot
-- and tag vocabulary so later items can opt into the same resolver as data.

local Contracts = require(script.Parent.Parent.Equipment.EquipmentAffixContracts)
local EffectIds = Contracts.EffectIds

local function affix(
	id: string,
	displayName: string,
	effectId: string,
	minimumValue: number,
	maximumValue: number,
	allowedSlots: { string },
	requiredTags: { string }
)
	return table.freeze({
		Id = id,
		Version = "1.0.0",
		DisplayName = displayName,
		EffectId = effectId,
		MinimumValue = minimumValue,
		MaximumValue = maximumValue,
		AllowedSlots = table.freeze(allowedSlots),
		RequiredTags = table.freeze(requiredTags),
	})
end

local Config = {
	Version = "PATCH-0.3-AFFIX-v1",
	AffixCountByRarity = table.freeze({
		Common = 1,
		Uncommon = 1,
		Rare = 2,
	}),
	Definitions = table.freeze({
		affix("keen", "Keen", EffectIds.DamagePercent, 3, 6, { "Primary", "Secondary" }, {}),
		affix("swift-loader", "Swift Loader", EffectIds.ReloadSpeedPercent, 5, 10, { "Primary", "Secondary" }, {}),
		affix("deadeye", "Deadeye", EffectIds.DamagePercent, 4, 8, { "Primary" }, { "precision" }),
		affix("breacher", "Breacher", EffectIds.DamagePercent, 5, 9, { "Primary" }, { "close-range" }),
		affix("reinforced", "Reinforced", EffectIds.MaxHealthPercent, 4, 8, { "Armor" }, {}),
		affix("trailborn", "Trailborn", EffectIds.MoveSpeedPercent, 3, 6, { "Armor" }, {}),
		affix("resonant", "Resonant", EffectIds.AbilityHastePercent, 5, 10, { "Relic" }, {}),
		affix("focused", "Focused", EffectIds.AbilityPowerPercent, 4, 8, { "Relic" }, {}),
	}),
}

local validEffects = {}
for _, effectId in EffectIds do
	validEffects[effectId] = true
end

local seenIds = {}
for _, definition in Config.Definitions do
	assert(type(definition.Id) == "string" and #definition.Id > 0, "affix requires a stable ID")
	assert(seenIds[definition.Id] == nil, "affix IDs must be unique")
	seenIds[definition.Id] = true
	assert(validEffects[definition.EffectId] == true, definition.Id .. " uses an unknown effect")
	assert(
		type(definition.MinimumValue) == "number"
			and definition.MinimumValue % 1 == 0
			and definition.MaximumValue % 1 == 0
			and definition.MinimumValue > 0
			and definition.MaximumValue >= definition.MinimumValue,
		definition.Id .. " has invalid value bounds"
	)
	assert(#definition.AllowedSlots >= 1, definition.Id .. " must allow at least one slot")
end

for rarityId, count in Config.AffixCountByRarity do
	assert(
		type(rarityId) == "string" and type(count) == "number" and count % 1 == 0 and count >= 0 and count <= 3,
		"rarity affix counts must be bounded integers"
	)
end

return table.freeze(Config)
