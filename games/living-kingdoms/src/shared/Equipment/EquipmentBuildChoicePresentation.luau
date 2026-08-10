--!strict

-- Compact, presentation-only formatting for equipment comparison facts.
-- This module does not rank builds or own gameplay truth. It turns deterministic
-- comparison/affix facts into short strings that can be reused by inventory,
-- reward-reveal, debrief, and future equipment surfaces.

export type AffixLike = {
	EffectId: string,
	Value: number,
}

export type AffixDeltaLike = {
	EffectId: string,
	CandidateValue: number,
	IncumbentValue: number,
	Delta: number,
}

export type ComparisonLike = {
	VerdictId: string,
	PowerDelta: number,
	RarityDelta: number,
	FillsEmptySlot: boolean,
}

local EFFECT_LABELS = table.freeze({
	DamagePercent = "DMG",
	ReloadSpeedPercent = "RELOAD",
	MaxHealthPercent = "HEALTH",
	MoveSpeedPercent = "MOVE",
	AbilityHastePercent = "HASTE",
	AbilityPowerPercent = "ABILITY",
})

local VERDICT_GLYPHS = table.freeze({
	Upgrade = "↑",
	Sidegrade = "↔",
	Downgrade = "↓",
	SameItem = "",
	NotComparable = "?",
})

local function labelForEffect(effectId: string): string
	return EFFECT_LABELS[effectId] or string.upper(effectId)
end

local function signedPercent(value: number): string
	return string.format("%+.0f%%", value)
end

local EquipmentBuildChoicePresentation = {}

function EquipmentBuildChoicePresentation.formatAffixes(affixes: { AffixLike }?): string
	if type(affixes) ~= "table" or #affixes == 0 then
		return "NO AFFIXES"
	end

	local ordered = table.clone(affixes)
	table.sort(ordered, function(a, b)
		return tostring(a.EffectId) < tostring(b.EffectId)
	end)

	local parts = {}
	for _, affix in ordered do
		if type(affix) == "table" and type(affix.EffectId) == "string" and type(affix.Value) == "number" then
			table.insert(parts, string.format("%s %s", labelForEffect(affix.EffectId), signedPercent(affix.Value)))
		end
	end
	return if #parts > 0 then table.concat(parts, " • ") else "NO AFFIXES"
end

function EquipmentBuildChoicePresentation.formatAffixDeltas(deltas: { AffixDeltaLike }?): string
	if type(deltas) ~= "table" or #deltas == 0 then
		return "NO AFFIX CHANGE"
	end

	local ordered = table.clone(deltas)
	table.sort(ordered, function(a, b)
		return tostring(a.EffectId) < tostring(b.EffectId)
	end)

	local parts = {}
	for _, delta in ordered do
		if type(delta) == "table" and type(delta.EffectId) == "string" and type(delta.Delta) == "number" then
			table.insert(parts, string.format("%s %s", labelForEffect(delta.EffectId), signedPercent(delta.Delta)))
		end
	end
	return if #parts > 0 then table.concat(parts, " • ") else "NO AFFIX CHANGE"
end

function EquipmentBuildChoicePresentation.formatVerdict(comparison: ComparisonLike?): string
	if type(comparison) ~= "table" then
		return ""
	end
	if comparison.FillsEmptySlot == true then
		return "↑ NEW"
	end
	local glyph = VERDICT_GLYPHS[comparison.VerdictId] or "?"
	if glyph == "" then
		return ""
	end
	local powerDelta = tonumber(comparison.PowerDelta) or 0
	return if powerDelta ~= 0 then string.format("%s %+.0fP", glyph, powerDelta) else glyph
end

return table.freeze(EquipmentBuildChoicePresentation)
