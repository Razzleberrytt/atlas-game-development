--!strict

--[[
	Blueprint v2.0 queue item 2 — deterministic item comparison.

	The fun gate for this work is that a fresh player can explain an item's
	tradeoff without coaching. That is a presentation outcome, but it is only
	reachable if the server states the tradeoff as facts rather than leaving each
	surface to infer one. This resolver produces those facts.

	Deliberate boundary: the verdict describes the *stat* direction only
	(power, then rarity). Role changes are reported separately as gained and lost
	tags. A shotgun that out-powers an equipped rifle is an `Upgrade` that also
	loses `precision` and gains `close-range` — reporting both lets a surface say
	"stronger, but close-range" instead of the resolver encoding a balance
	opinion about which the player should prefer.

	This module owns no state, reads no services, and performs no mutation.
]]

local Contracts = require(script.Parent.EquipmentRewardContracts)

export type EquipmentReward = Contracts.EquipmentReward
export type EquipmentDefinition = Contracts.EquipmentDefinition
export type EquipmentSlotId = Contracts.EquipmentSlotId

local RarityRanks = Contracts.RarityRanks

export type ComparisonVerdictId = "Upgrade" | "Sidegrade" | "Downgrade" | "SameItem" | "NotComparable"

export type EquipmentComparison = {
	VerdictId: ComparisonVerdictId,
	Slot: EquipmentSlotId,
	CandidateInstanceId: string,
	IncumbentInstanceId: string?,
	-- Positive means the candidate is better. Both are 0 when there is nothing
	-- equipped in the slot, because there is no baseline to differ from.
	PowerDelta: number,
	RarityDelta: number,
	SameDefinition: boolean,
	FillsEmptySlot: boolean,
	GainedTags: { string },
	LostTags: { string },
}

export type ComparisonResult = {
	Accepted: boolean,
	ReasonId: string,
	Comparison: EquipmentComparison?,
}

export type DefinitionLookup = (definitionId: string) -> EquipmentDefinition?

local function reject(reasonId: string): ComparisonResult
	return table.freeze({ Accepted = false, ReasonId = reasonId, Comparison = nil })
end

local function isReward(value: any): boolean
	return type(value) == "table"
		and type(value.InstanceId) == "string"
		and value.InstanceId ~= ""
		and type(value.DefinitionId) == "string"
		and type(value.Power) == "number"
		and RarityRanks[value.Rarity] ~= nil
end

--[[
	Tags describe an item's role and live on the authored definition, not on the
	generated instance, so a missing definition yields no tag facts rather than a
	guess. Results are sorted so the same pair always reads the same way.
]]
local function tagDifference(fromTags: { string }?, toTags: { string }?): { string }
	local present = {}
	for _, tag in fromTags or {} do
		present[tag] = true
	end
	local difference = {}
	for _, tag in toTags or {} do
		if not present[tag] then
			table.insert(difference, tag)
		end
	end
	table.sort(difference)
	return table.freeze(difference)
end

local EquipmentComparisonResolver = {}

--[[
	Compares a candidate item against whatever currently occupies its slot.
	`incumbent` is nil when the slot is empty. `lookupDefinition` resolves authored
	definitions for tag facts and may return nil for an unknown definition.
]]
function EquipmentComparisonResolver.compare(
	candidate: EquipmentReward,
	incumbent: EquipmentReward?,
	lookupDefinition: DefinitionLookup?
): ComparisonResult
	if not isReward(candidate) then
		return reject("InvalidCandidateItem")
	end
	if incumbent ~= nil and not isReward(incumbent) then
		return reject("InvalidIncumbentItem")
	end
	if incumbent ~= nil and candidate.Slot ~= incumbent.Slot then
		return reject("SlotMismatch")
	end

	local lookup = lookupDefinition or function(_definitionId: string): EquipmentDefinition?
		return nil
	end
	local candidateDefinition = lookup(candidate.DefinitionId)
	local incumbentDefinition = if incumbent then lookup(incumbent.DefinitionId) else nil
	local candidateTags = if candidateDefinition then candidateDefinition.Tags else nil
	local incumbentTags = if incumbentDefinition then incumbentDefinition.Tags else nil

	local function build(verdictId: ComparisonVerdictId, powerDelta: number, rarityDelta: number): ComparisonResult
		return table.freeze({
			Accepted = true,
			ReasonId = "ComparisonResolved",
			Comparison = table.freeze({
				VerdictId = verdictId,
				Slot = candidate.Slot,
				CandidateInstanceId = candidate.InstanceId,
				IncumbentInstanceId = if incumbent then incumbent.InstanceId else nil,
				PowerDelta = powerDelta,
				RarityDelta = rarityDelta,
				SameDefinition = incumbent ~= nil and candidate.DefinitionId == incumbent.DefinitionId,
				FillsEmptySlot = incumbent == nil,
				GainedTags = tagDifference(incumbentTags, candidateTags),
				LostTags = tagDifference(candidateTags, incumbentTags),
			}),
		})
	end

	-- Nothing equipped: the candidate is strictly an addition, and there is no
	-- baseline, so the deltas stay zero rather than being measured against zero
	-- power (which would read as a large fake gain).
	if incumbent == nil then
		return build("Upgrade", 0, 0)
	end

	-- Re-comparing the equipped item with itself is a legitimate UI state, not an
	-- error, and must not read as a sidegrade.
	if candidate.InstanceId == incumbent.InstanceId then
		return build("SameItem", 0, 0)
	end

	local powerDelta = candidate.Power - incumbent.Power
	local rarityDelta = RarityRanks[candidate.Rarity] - RarityRanks[incumbent.Rarity]

	-- An upgrade is better on at least one axis and worse on neither; a downgrade
	-- is the mirror. Everything else — identical stats, or power and rarity
	-- disagreeing — is a genuine tradeoff the player has to weigh.
	local improves = powerDelta >= 0 and rarityDelta >= 0 and (powerDelta > 0 or rarityDelta > 0)
	local worsens = powerDelta <= 0 and rarityDelta <= 0 and (powerDelta < 0 or rarityDelta < 0)

	local verdictId: ComparisonVerdictId = "Sidegrade"
	if improves then
		verdictId = "Upgrade"
	elseif worsens then
		verdictId = "Downgrade"
	end

	return build(verdictId, powerDelta, rarityDelta)
end

--[[
	Convenience for the common surface case: compare a candidate against the item
	currently equipped in its slot, given an owner's equipped map and item lookup.
]]
function EquipmentComparisonResolver.compareAgainstEquipped(
	candidate: EquipmentReward,
	equippedBySlot: { [EquipmentSlotId]: string? },
	itemsByInstanceId: { [string]: EquipmentReward },
	lookupDefinition: DefinitionLookup?
): ComparisonResult
	if not isReward(candidate) then
		return reject("InvalidCandidateItem")
	end
	if type(equippedBySlot) ~= "table" or type(itemsByInstanceId) ~= "table" then
		return reject("InvalidInventoryState")
	end

	local equippedInstanceId = equippedBySlot[candidate.Slot]
	if equippedInstanceId == nil then
		return EquipmentComparisonResolver.compare(candidate, nil, lookupDefinition)
	end

	local incumbent = itemsByInstanceId[equippedInstanceId]
	if incumbent == nil then
		-- The slot names an item the owner does not hold. That is a server-side
		-- inconsistency, so fail closed instead of reporting a free upgrade.
		return reject("EquippedItemNotOwned")
	end
	return EquipmentComparisonResolver.compare(candidate, incumbent, lookupDefinition)
end

return table.freeze(EquipmentComparisonResolver)
