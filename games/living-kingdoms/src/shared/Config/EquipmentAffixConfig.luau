--!strict

-- Patch 0.9 expands the proven affix pool without adding a second modifier
-- authority. Compatibility remains authored from stable equipment slot/tag
-- vocabulary and every role-specific tag is checked against the live durable
-- equipment catalog so impossible rolls cannot accumulate as dead content.

local Contracts = require(script.Parent.Parent.Equipment.EquipmentAffixContracts)
local EquipmentRewardConfig = require(script.Parent.EquipmentRewardConfig)
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
	Version = "PATCH-0.9-AFFIX-v4-gear-archetypes",
	AffixCountByRarity = table.freeze({ Common = 1, Uncommon = 1, Rare = 2 }),
	Definitions = table.freeze({
		affix("keen", "Keen", EffectIds.DamagePercent, 3, 6, { "Primary", "Secondary" }, {}),
		affix("swift-loader", "Swift Loader", EffectIds.ReloadSpeedPercent, 5, 10, { "Primary", "Secondary" }, {}),
		affix("deadeye", "Deadeye", EffectIds.DamagePercent, 4, 8, { "Primary" }, { "precision" }),
		affix("measured-cycle", "Measured Cycle", EffectIds.ReloadSpeedPercent, 6, 11, { "Primary" }, { "precision" }),
		affix("breacher", "Breacher", EffectIds.DamagePercent, 5, 9, { "Primary" }, { "close-range" }),
		affix("slam-loader", "Slam Loader", EffectIds.ReloadSpeedPercent, 6, 12, { "Primary" }, { "close-range" }),
		affix("suppressive", "Suppressive", EffectIds.DamagePercent, 4, 7, { "Primary" }, { "sustained-fire" }),
		affix("belt-fed", "Belt Fed", EffectIds.ReloadSpeedPercent, 7, 12, { "Primary" }, { "support" }),
		affix("crowd-cutter", "Crowd Cutter", EffectIds.DamagePercent, 4, 8, { "Primary" }, { "horde-control" }),
		affix("hot-swap", "Hot Swap", EffectIds.ReloadSpeedPercent, 6, 11, { "Primary" }, { "smg" }),
		affix("steady-hand", "Steady Hand", EffectIds.DamagePercent, 3, 6, { "Secondary" }, { "sidearm" }),
		affix("field-service", "Field Service", EffectIds.ReloadSpeedPercent, 6, 11, { "Secondary" }, { "reliable" }),

		-- Armor archetypes now split into durable/survival and mobile/skirmisher rolls.
		affix("reinforced", "Reinforced", EffectIds.MaxHealthPercent, 4, 8, { "Armor" }, {}),
		affix("trailborn", "Trailborn", EffectIds.MoveSpeedPercent, 3, 6, { "Armor" }, {}),
		affix("bulwark", "Bulwark", EffectIds.MaxHealthPercent, 5, 9, { "Armor" }, { "survival" }),
		affix("pathfinder", "Pathfinder", EffectIds.MoveSpeedPercent, 4, 7, { "Armor" }, { "survival" }),
		affix("skirmisher", "Skirmisher", EffectIds.MoveSpeedPercent, 5, 8, { "Armor" }, { "mobility" }),
		affix("flex-weave", "Flex Weave", EffectIds.MaxHealthPercent, 3, 6, { "Armor" }, { "mobility" }),

		-- Relic archetypes remain inside the existing class cooldown/output owners.
		affix("resonant", "Resonant", EffectIds.AbilityHastePercent, 5, 10, { "Relic" }, {}),
		affix("focused", "Focused", EffectIds.AbilityPowerPercent, 4, 8, { "Relic" }, {}),
		affix("quickening", "Quickening", EffectIds.AbilityHastePercent, 7, 12, { "Relic" }, { "ability" }),
		affix("overcharged", "Overcharged", EffectIds.AbilityPowerPercent, 6, 10, { "Relic" }, { "ability" }),
		affix("surge-tuned", "Surge Tuned", EffectIds.AbilityPowerPercent, 7, 11, { "Relic" }, { "offense" }),
		affix("rapid-channel", "Rapid Channel", EffectIds.AbilityHastePercent, 7, 12, { "Relic" }, { "offense" }),
	}),
}

local validEffects = {}
for _, effectId in EffectIds do
	validEffects[effectId] = true
end
local catalogTags = {}
for _, itemDefinition in EquipmentRewardConfig.Definitions do
	for _, tag in itemDefinition.Tags do
		catalogTags[tag] = true
	end
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
	for _, requiredTag in definition.RequiredTags do
		assert(
			catalogTags[requiredTag] == true,
			definition.Id .. " requires a tag no durable item owns: " .. requiredTag
		)
	end
end

local function hasRoleAwareAffix(itemDefinition: any): boolean
	for _, definition in Config.Definitions do
		if #definition.RequiredTags > 0 then
			local slotAllowed = false
			for _, slot in definition.AllowedSlots do
				if slot == itemDefinition.Slot then
					slotAllowed = true
					break
				end
			end
			if slotAllowed then
				local allTags = true
				for _, requiredTag in definition.RequiredTags do
					local found = false
					for _, itemTag in itemDefinition.Tags do
						if itemTag == requiredTag then
							found = true
							break
						end
					end
					if not found then
						allTags = false
						break
					end
				end
				if allTags then
					return true
				end
			end
		end
	end
	return false
end

-- Every durable archetype must have at least one tag-specific roll. Generic
-- affixes remain valid fallback content, but no new item may be merely a renamed
-- copy with no build identity.
for _, itemDefinition in EquipmentRewardConfig.Definitions do
	assert(hasRoleAwareAffix(itemDefinition), itemDefinition.Id .. " must have at least one role-aware affix")
end

for rarityId, count in Config.AffixCountByRarity do
	assert(
		type(rarityId) == "string" and type(count) == "number" and count % 1 == 0 and count >= 0 and count <= 3,
		"rarity affix counts must be bounded integers"
	)
end

return table.freeze(Config)
