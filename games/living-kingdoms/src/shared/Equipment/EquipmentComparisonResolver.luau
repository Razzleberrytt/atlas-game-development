--!strict

--[[
	Deterministic item comparison facts for equipment/reward surfaces.

	The verdict describes stat direction only (power, then rarity). Role and affix
	changes remain separate facts so presentation can explain a tradeoff without
	this resolver encoding a balance opinion about which build a player should
	prefer.

	The comparison input is intentionally the smallest durable equipment shape
	required by the resolver. Full server reward records and sanitized owner-only
	inventory views can therefore share this one comparison path instead of
	creating parallel UI/server comparison logic.
]]

local Contracts = require(script.Parent.EquipmentRewardContracts)

export type EquipmentReward = Contracts.EquipmentReward
export type EquipmentDefinition = Contracts.EquipmentDefinition
export type EquipmentSlotId = Contracts.EquipmentSlotId
export type EquipmentRarityId = Contracts.EquipmentRarityId
export type EquipmentAffixRoll = Contracts.EquipmentAffixRoll
export type EquipmentAffixEffectId = Contracts.EquipmentAffixEffectId

export type ComparableEquipmentItem = {
	InstanceId: string,
	DefinitionId: string,
	Slot: EquipmentSlotId,
	Rarity: EquipmentRarityId,
	Power: number,
	Affixes: { EquipmentAffixRoll },
}

local RarityRanks = Contracts.RarityRanks

export type ComparisonVerdictId = "Upgrade" | "Sidegrade" | "Downgrade" | "SameItem" | "NotComparable"

export type EquipmentAffixDelta = {
	EffectId: EquipmentAffixEffectId,
	CandidateValue: number,
	IncumbentValue: number,
	Delta: number,
}

export type EquipmentComparison = {
	VerdictId: ComparisonVerdictId,
	Slot: EquipmentSlotId,
	CandidateInstanceId: string,
	IncumbentInstanceId: string?,
	PowerDelta: number,
	RarityDelta: number,
	SameDefinition: boolean,
	FillsEmptySlot: boolean,
	GainedTags: { string },
	LostTags: { string },
	AffixDeltas: { EquipmentAffixDelta },
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

local function isComparableItem(value: any): boolean
	return type(value) == "table"
		and type(value.InstanceId) == "string"
		and value.InstanceId ~= ""
		and type(value.DefinitionId) == "string"
		and type(value.Slot) == "string"
		and type(value.Power) == "number"
		and RarityRanks[value.Rarity] ~= nil
		and (value.Affixes == nil or type(value.Affixes) == "table")
end

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

local function sumAffixEffects(affixes: { EquipmentAffixRoll }?): { [string]: number }
	local totals = {}
	for _, affix in affixes or {} do
		if type(affix) == "table" and type(affix.EffectId) == "string" and type(affix.Value) == "number" then
			totals[affix.EffectId] = (totals[affix.EffectId] or 0) + affix.Value
		end
	end
	return totals
end

local function affixDeltas(
	candidate: ComparableEquipmentItem,
	incumbent: ComparableEquipmentItem?
): { EquipmentAffixDelta }
	local candidateTotals = sumAffixEffects(candidate.Affixes)
	local incumbentTotals = sumAffixEffects(if incumbent then incumbent.Affixes else nil)
	local effectIds = {}
	local seen = {}
	for effectId in candidateTotals do
		seen[effectId] = true
		table.insert(effectIds, effectId)
	end
	for effectId in incumbentTotals do
		if not seen[effectId] then
			table.insert(effectIds, effectId)
		end
	end
	table.sort(effectIds)

	local deltas = {}
	for _, effectId in effectIds do
		local candidateValue = candidateTotals[effectId] or 0
		local incumbentValue = incumbentTotals[effectId] or 0
		local delta = candidateValue - incumbentValue
		if delta ~= 0 then
			table.insert(
				deltas,
				table.freeze({
					EffectId = effectId :: EquipmentAffixEffectId,
					CandidateValue = candidateValue,
					IncumbentValue = incumbentValue,
					Delta = delta,
				})
			)
		end
	end
	return table.freeze(deltas)
end

local EquipmentComparisonResolver = {}

function EquipmentComparisonResolver.compare(
	candidate: ComparableEquipmentItem,
	incumbent: ComparableEquipmentItem?,
	lookupDefinition: DefinitionLookup?
): ComparisonResult
	if not isComparableItem(candidate) then
		return reject("InvalidCandidateItem")
	end
	if incumbent ~= nil and not isComparableItem(incumbent) then
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
				AffixDeltas = affixDeltas(candidate, incumbent),
			}),
		})
	end

	if incumbent == nil then
		return build("Upgrade", 0, 0)
	end

	if candidate.InstanceId == incumbent.InstanceId then
		return build("SameItem", 0, 0)
	end

	local powerDelta = candidate.Power - incumbent.Power
	local rarityDelta = RarityRanks[candidate.Rarity] - RarityRanks[incumbent.Rarity]
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

function EquipmentComparisonResolver.compareAgainstEquipped(
	candidate: ComparableEquipmentItem,
	equippedBySlot: { [EquipmentSlotId]: string? },
	itemsByInstanceId: { [string]: ComparableEquipmentItem },
	lookupDefinition: DefinitionLookup?
): ComparisonResult
	if not isComparableItem(candidate) then
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
		return reject("EquippedItemNotOwned")
	end
	return EquipmentComparisonResolver.compare(candidate, incumbent, lookupDefinition)
end

return table.freeze(EquipmentComparisonResolver)
