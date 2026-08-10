--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
	debugName = "EquipmentRewardContracts",
	injectGlobals = true,
})()
local CONTRACTS_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentComparisonResolver.luau"), {
	debugName = "EquipmentComparisonResolver",
	environment = {
		script = { Parent = { EquipmentRewardContracts = CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected comparison dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local function affix(id: string, effectId: string, value: number): any
	return {
		Id = id,
		Version = "1",
		DisplayName = id,
		EffectId = effectId,
		Value = value,
	}
end

local function reward(instanceId: string, affixes: { any }?): any
	return {
		InstanceId = instanceId,
		GrantId = "reward:affix-test:" .. instanceId,
		ContentSignature = "v2|" .. instanceId,
		DefinitionId = "frontier-rifle",
		DefinitionVersion = "1.0.0",
		DisplayName = "Frontier Rifle",
		Slot = contracts.SlotIds.Primary,
		Rarity = contracts.RarityIds.Rare,
		Power = 20,
		Affixes = affixes,
		SourceId = contracts.SourceIds.Boss,
		RunId = "run-affix-comparison",
		Seed = 101,
	}
end

local incumbent = reward("item-incumbent", {
	affix("old-damage", "DamagePercent", 4),
	affix("old-health", "MaxHealthPercent", 3),
})
local candidate = reward("item-candidate", {
	affix("new-damage-a", "DamagePercent", 5),
	affix("new-damage-b", "DamagePercent", 2),
	affix("new-haste", "AbilityHastePercent", 6),
})

local result = resolver.compare(candidate, incumbent, nil)
assertThat(result.Accepted and result.Comparison ~= nil, "valid affix comparison must resolve")
assertThat(result.Comparison.VerdictId == "Sidegrade", "affixes must not silently change the stat verdict")
assertThat(#result.Comparison.AffixDeltas == 3, "all changed effect families must be reported")

local deltas = result.Comparison.AffixDeltas
assertThat(deltas[1].EffectId == "AbilityHastePercent", "effect deltas must be sorted deterministically")
assertThat(deltas[1].CandidateValue == 6 and deltas[1].IncumbentValue == 0 and deltas[1].Delta == 6, "gained effect facts mismatch")
assertThat(deltas[2].EffectId == "DamagePercent", "damage should follow stable effect ordering")
assertThat(deltas[2].CandidateValue == 7 and deltas[2].IncumbentValue == 4 and deltas[2].Delta == 3, "same-effect rolls must aggregate")
assertThat(deltas[3].EffectId == "MaxHealthPercent", "lost health effect must remain visible")
assertThat(deltas[3].CandidateValue == 0 and deltas[3].IncumbentValue == 3 and deltas[3].Delta == -3, "lost effect facts mismatch")
assertThat(table.isfrozen(deltas), "affix delta collection must be immutable")
assertThat(table.isfrozen(deltas[1]), "affix delta entries must be immutable")

local repeated = resolver.compare(candidate, incumbent, nil)
for index, delta in repeated.Comparison.AffixDeltas do
	local original = deltas[index]
	assertThat(delta.EffectId == original.EffectId and delta.Delta == original.Delta, "same pair must reproduce affix facts")
end

local legacy = resolver.compare(reward("item-legacy", nil), incumbent, nil)
assertThat(legacy.Accepted, "missing pre-affix metadata must remain comparable")
assertThat(#legacy.Comparison.AffixDeltas == 2, "legacy candidate should report incumbent effects as losses")

local emptySlot = resolver.compare(candidate, nil, nil)
assertThat(emptySlot.Accepted and emptySlot.Comparison.FillsEmptySlot, "empty-slot comparison must still resolve")
assertThat(#emptySlot.Comparison.AffixDeltas == 2, "candidate effects should remain available to presentation for an empty slot")

local same = resolver.compare(candidate, candidate, nil)
assertThat(same.Comparison.VerdictId == "SameItem", "same-item verdict must be preserved")
assertThat(#same.Comparison.AffixDeltas == 0, "same item has no affix changes")

print("EquipmentAffixComparison: deterministic aggregated affix facts passed")
