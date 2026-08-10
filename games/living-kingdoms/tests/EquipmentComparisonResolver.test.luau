--!strict

--[[
	Blueprint v2.0 queue item 2 — item comparison fixture.

	Proves the tradeoff facts a surface needs: a stable stat verdict, signed
	deltas, role changes reported as gained/lost tags, and fail-closed handling
	of inconsistent inventory state.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "equipment comparison assertion failed", 2)
	end
end

local affixContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixContracts.luau"), {
		debugName = "EquipmentAffixContracts",
		injectGlobals = true,
	})()
local AFFIX_CONTRACTS_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
	debugName = "EquipmentRewardContracts",
	environment = {
		script = { Parent = { EquipmentAffixContracts = AFFIX_CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assert(token == AFFIX_CONTRACTS_TOKEN, "unexpected reward contract dependency")
			return affixContracts
		end,
	},
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local Resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentComparisonResolver.luau"), {
	debugName = "EquipmentComparisonResolver",
	environment = {
		script = { Parent = { EquipmentRewardContracts = CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected comparison resolver dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local RarityIds = contracts.RarityIds
local SlotIds = contracts.SlotIds

-- The shared rarity ranking must stay contiguous and ordered, because deltas are
-- reported as step counts.
assert(contracts.RarityRanks[RarityIds.Common] == 1, "Common ranks lowest")
assert(contracts.RarityRanks[RarityIds.Uncommon] == 2, "Uncommon ranks above Common")
assert(contracts.RarityRanks[RarityIds.Rare] == 3, "Rare ranks highest")

local definitions = {
	["frontier-rifle"] = { Id = "frontier-rifle", Tags = { "rifle", "precision" } },
	["breach-shotgun"] = { Id = "breach-shotgun", Tags = { "shotgun", "close-range" } },
	["delver-plate"] = { Id = "delver-plate", Tags = { "armor", "survival" } },
}

local function lookup(definitionId: string): any
	return definitions[definitionId]
end

local function item(instanceId: string, definitionId: string, slot: string, rarity: string, power: number): any
	return {
		InstanceId = instanceId,
		GrantId = "reward:run-compare:" .. instanceId,
		ContentSignature = "v1|" .. instanceId,
		DefinitionId = definitionId,
		DefinitionVersion = "1.0.0",
		DisplayName = definitionId,
		Slot = slot,
		Rarity = rarity,
		Power = power,
		Affixes = {},
		SourceId = "Elite",
		RunId = "run-compare",
		Seed = 11,
	}
end

local rifleCommon10 = item("item_rifle_a", "frontier-rifle", SlotIds.Primary, RarityIds.Common, 10)
local rifleRare13 = item("item_rifle_b", "frontier-rifle", SlotIds.Primary, RarityIds.Rare, 13)
local rifleCommon8 = item("item_rifle_c", "frontier-rifle", SlotIds.Primary, RarityIds.Common, 8)
local shotgunRare12 = item("item_shotgun_a", "breach-shotgun", SlotIds.Primary, RarityIds.Rare, 12)
local plate = item("item_plate_a", "delver-plate", SlotIds.Armor, RarityIds.Common, 9)

-- Strictly better power and rarity is an upgrade with signed deltas.
local upgrade = Resolver.compare(rifleRare13, rifleCommon10, lookup)
assert(upgrade.Accepted == true and upgrade.ReasonId == "ComparisonResolved", "a valid pair resolves")
assert(upgrade.Comparison.VerdictId == "Upgrade", "more power and rarity is an upgrade")
assert(upgrade.Comparison.PowerDelta == 3, "power delta is signed toward the candidate")
assert(upgrade.Comparison.RarityDelta == 2, "rarity delta counts steps")
assert(upgrade.Comparison.SameDefinition == true, "same definition is reported")
assert(upgrade.Comparison.FillsEmptySlot == false, "the slot was occupied")
assert(upgrade.Comparison.IncumbentInstanceId == "item_rifle_a", "the incumbent is named")
assert(#upgrade.Comparison.GainedTags == 0 and #upgrade.Comparison.LostTags == 0, "same definition changes no role")

-- Strictly worse is a downgrade with negative deltas.
local downgrade = Resolver.compare(rifleCommon8, rifleCommon10, lookup)
assert(downgrade.Comparison.VerdictId == "Downgrade", "less power at equal rarity is a downgrade")
assert(downgrade.Comparison.PowerDelta == -2 and downgrade.Comparison.RarityDelta == 0, "deltas are signed")

-- Power and rarity disagreeing is the tradeoff case.
local mixed =
	Resolver.compare(rifleCommon10, item("item_x", "frontier-rifle", SlotIds.Primary, RarityIds.Rare, 9), lookup)
assert(mixed.Comparison.VerdictId == "Sidegrade", "more power but lower rarity is a sidegrade")
assert(mixed.Comparison.PowerDelta == 1 and mixed.Comparison.RarityDelta == -2, "both deltas are reported")

-- Identical stats on a different instance is still a sidegrade, never an upgrade.
local twin =
	Resolver.compare(item("item_twin", "frontier-rifle", SlotIds.Primary, RarityIds.Common, 10), rifleCommon10, lookup)
assert(twin.Comparison.VerdictId == "Sidegrade", "identical stats are a sidegrade")
assert(twin.Comparison.PowerDelta == 0 and twin.Comparison.RarityDelta == 0, "identical stats have zero deltas")

-- Rarity alone decides when power ties.
local rarityOnly =
	Resolver.compare(item("item_r", "frontier-rifle", SlotIds.Primary, RarityIds.Rare, 10), rifleCommon10, lookup)
assert(rarityOnly.Comparison.VerdictId == "Upgrade", "higher rarity at equal power is an upgrade")

-- A role change is reported as tags, independent of the stat verdict, so a
-- surface can say "stronger, but close-range" rather than guessing.
local roleSwap = Resolver.compare(shotgunRare12, rifleCommon10, lookup)
assert(roleSwap.Comparison.VerdictId == "Upgrade", "the stat verdict ignores role")
assert(roleSwap.Comparison.SameDefinition == false, "a different definition is reported")
assert(
	table.concat(roleSwap.Comparison.GainedTags, ",") == "close-range,shotgun",
	"gained tags are sorted and complete"
)
assert(table.concat(roleSwap.Comparison.LostTags, ",") == "precision,rifle", "lost tags are sorted and complete")

-- Tag facts are frozen and deterministic across repeated calls.
local repeated = Resolver.compare(shotgunRare12, rifleCommon10, lookup)
assert(table.isfrozen(repeated.Comparison :: any), "the comparison is frozen")
assert(table.isfrozen(repeated.Comparison.GainedTags :: any), "tag lists are frozen")
assert(
	table.concat(repeated.Comparison.GainedTags, ",") == table.concat(roleSwap.Comparison.GainedTags, ","),
	"comparison is deterministic"
)

-- An empty slot is an addition with no fabricated baseline.
local firstItem = Resolver.compare(rifleCommon10, nil, lookup)
assert(firstItem.Comparison.VerdictId == "Upgrade", "the first item for a slot is an upgrade")
assert(firstItem.Comparison.FillsEmptySlot == true, "the empty slot is reported")
assert(firstItem.Comparison.PowerDelta == 0, "an empty slot is not a zero-power baseline")
assert(firstItem.Comparison.IncumbentInstanceId == nil, "there is no incumbent")

-- Comparing the equipped item with itself is a legitimate UI state.
local same = Resolver.compare(rifleCommon10, rifleCommon10, lookup)
assert(same.Comparison.VerdictId == "SameItem", "an item does not differ from itself")

-- Cross-slot comparison is rejected rather than answered nonsensically.
local crossSlot = Resolver.compare(plate, rifleCommon10, lookup)
assert(crossSlot.Accepted == false and crossSlot.ReasonId == "SlotMismatch", "different slots cannot be compared")
assert(crossSlot.Comparison == nil, "a rejected comparison yields no facts")

-- Malformed input is rejected. Listed with an explicit count because a table
-- literal holding nil would silently stop generic iteration at the hole.
local malformedCandidates: { any } = { {}, "item", 7, { InstanceId = "x" }, { InstanceId = "", Power = 1 } }
assert(#malformedCandidates == 5, "every malformed candidate case must actually run")
for _, invalid in malformedCandidates do
	local bad = Resolver.compare(invalid, rifleCommon10, lookup)
	assert(bad.Accepted == false and bad.ReasonId == "InvalidCandidateItem", "a malformed candidate is rejected")
end
local missingCandidate = Resolver.compare(nil :: any, rifleCommon10, lookup)
assert(missingCandidate.Accepted == false, "a missing candidate is rejected")
assert(missingCandidate.ReasonId == "InvalidCandidateItem", "a missing candidate has the candidate reason")
local badIncumbent = Resolver.compare(rifleCommon10, { InstanceId = "y" } :: any, lookup)
assert(badIncumbent.Accepted == false and badIncumbent.ReasonId == "InvalidIncumbentItem", "bad incumbent rejected")

-- An unknown rarity cannot be ranked, so it is not comparable.
local unknownRarity =
	Resolver.compare(item("item_u", "frontier-rifle", SlotIds.Primary, "Mythic", 20), rifleCommon10, lookup)
assert(unknownRarity.Accepted == false, "an unrankable rarity is rejected")

-- Missing definitions yield no tag facts rather than a guess.
local noDefinition =
	Resolver.compare(item("item_n", "unknown-def", SlotIds.Primary, RarityIds.Common, 10), rifleCommon10, lookup)
assert(noDefinition.Accepted == true, "an unknown definition still compares on stats")
assert(#noDefinition.Comparison.GainedTags == 0, "an unknown definition contributes no gained tags")
assert(table.concat(noDefinition.Comparison.LostTags, ",") == "precision,rifle", "the known side still reports tags")

-- The resolver works with no definition lookup at all.
local noLookup = Resolver.compare(rifleRare13, rifleCommon10, nil)
assert(noLookup.Accepted == true and noLookup.Comparison.VerdictId == "Upgrade", "lookup is optional")
assert(#noLookup.Comparison.GainedTags == 0, "no lookup means no tag facts")

-- compareAgainstEquipped resolves the incumbent from owner state.
local itemsByInstanceId = {
	[rifleCommon10.InstanceId] = rifleCommon10,
	[shotgunRare12.InstanceId] = shotgunRare12,
	[plate.InstanceId] = plate,
}
local againstEquipped =
	Resolver.compareAgainstEquipped(shotgunRare12, { Primary = rifleCommon10.InstanceId }, itemsByInstanceId, lookup)
assert(againstEquipped.Accepted == true, "the equipped incumbent resolves")
assert(againstEquipped.Comparison.IncumbentInstanceId == rifleCommon10.InstanceId, "the equipped item is the baseline")

local emptySlot = Resolver.compareAgainstEquipped(plate, {}, itemsByInstanceId, lookup)
assert(emptySlot.Accepted == true and emptySlot.Comparison.FillsEmptySlot == true, "an empty slot is an addition")

-- A slot naming an unowned item is a server inconsistency and must fail closed
-- rather than report a free upgrade.
local ghost = Resolver.compareAgainstEquipped(shotgunRare12, { Primary = "item_missing" }, itemsByInstanceId, lookup)
assert(ghost.Accepted == false and ghost.ReasonId == "EquippedItemNotOwned", "a ghost equip fails closed")

local badState = Resolver.compareAgainstEquipped(shotgunRare12, nil :: any, itemsByInstanceId, lookup)
assert(badState.Accepted == false and badState.ReasonId == "InvalidInventoryState", "malformed owner state rejected")

print("EquipmentComparisonResolver fixture passed")
