--!strict

--[[
	Patch 0.6 deterministic authored-encounter composer.

	This pure composition layer joins an effective encounter-intensity record to
	the existing bounded consequence policy and authored-wave applicator. A
	non-zero encounter delta is applied to exactly one deterministically selected
	authored wave, so multi-wave encounters cannot accidentally multiply a +/-1
	encounter budget change. It does not spawn enemies, invent archetypes, change
	rewards, or mutate authored content.
]]

local RunVariationAuthoredWaveApplicator = require(script.Parent.RunVariationAuthoredWaveApplicator)
local RunVariationEncounterConsequencePolicy = require(script.Parent.RunVariationEncounterConsequencePolicy)

export type ComposedEncounter = {
	Seed: number,
	NodeIndex: number,
	RoomId: string,
	EncounterSlotId: string,
	BaseIntensity: number,
	EffectiveIntensity: number,
	ModifierApplied: boolean,
	SpawnSourceId: string?,
	RewardSourceId: string?,
	UnitCountDelta: number,
	MinimumRetainedUnits: number,
	SelectedWaveIndex: number?,
	OriginalUnitCount: number,
	AppliedUnitCount: number,
	CompositionIdentity: string,
	Waves: { any },
}

local Composer = {}

local IDENTITY_VERSION = "P06-AUTHORED-ENCOUNTER-COMPOSER-v1"
local MODULUS = 2_147_483_647
local WAVE_SEED_MULTIPLIER = 104_729
local WAVE_NODE_MULTIPLIER = 13_007

local function assertInteger(value: any, message: string)
	assert(type(value) == "number" and value % 1 == 0, message)
end

local function selectedWaveIndex(seed: number, nodeIndex: number, waveCount: number): number
	local value = (seed * WAVE_SEED_MULTIPLIER + nodeIndex * WAVE_NODE_MULTIPLIER) % MODULUS
	return (value % waveCount) + 1
end

local function identityValue(value: any): string
	if value == nil then
		return "none"
	end
	return tostring(value)
end

local function unitSignature(units: { any }): string
	local parts = {}
	for _, unit in units do
		table.insert(parts, string.format("%s:%s:%d", unit.ArchetypeId, identityValue(unit.HordeRoleId), unit.Count))
	end
	return table.concat(parts, ",")
end

local function zeroDeltaConsequence(consequence: any): any
	local copy = table.clone(consequence)
	copy.UnitCountDelta = 0
	return table.freeze(copy)
end

function Composer.compose(seed: number, encounterRecord: any, authoredEncounter: any): ComposedEncounter
	assertInteger(seed, "run seed must be an integer")
	assert(seed > 0, "run seed must be positive")
	assert(type(encounterRecord) == "table", "encounter intensity record is required")
	assert(type(authoredEncounter) == "table", "authored encounter is required")
	assert(type(authoredEncounter.Waves) == "table", "authored encounter waves are required")
	assert(authoredEncounter.RoomId == encounterRecord.RoomId, "authored encounter room must match encounter record")
	assert(
		authoredEncounter.EncounterSlotId == encounterRecord.EncounterSlotId,
		"authored encounter slot must match encounter record"
	)
	assert(
		authoredEncounter.EncounterIntensity == encounterRecord.BaseIntensity,
		"authored encounter intensity must match the encounter record base intensity"
	)

	local consequence = RunVariationEncounterConsequencePolicy.resolve(encounterRecord)
	local sourceWaves = authoredEncounter.Waves
	--[[
		The applicator reads `wave.Units` directly, so a malformed authored wave
		would surface as an index error naming neither the room nor the wave.
		Validate the authored shape here, where that identity is still in hand.
	]]
	for waveIndex, authoredWave in sourceWaves do
		assert(
			type(authoredWave) == "table" and type(authoredWave.Units) == "table",
			string.format(
				"authored encounter %s wave %d is missing its unit list",
				tostring(authoredEncounter.RoomId),
				waveIndex
			)
		)
	end
	local waveCount = #sourceWaves
	local selectedIndex = nil
	if consequence.UnitCountDelta ~= 0 then
		assert(waveCount >= 1, "non-zero encounter variation requires an authored wave")
		selectedIndex = selectedWaveIndex(seed, consequence.NodeIndex, waveCount)
	end

	local unchangedConsequence = zeroDeltaConsequence(consequence)
	local composedWaves = {}
	local identityParts = {}
	local originalUnitCount = 0
	local appliedUnitCount = 0

	for waveIndex, authoredWave in sourceWaves do
		local waveConsequence = if waveIndex == selectedIndex then consequence else unchangedConsequence
		local appliedWave = RunVariationAuthoredWaveApplicator.apply(seed, authoredWave, waveConsequence)
		originalUnitCount += appliedWave.OriginalUnitCount
		appliedUnitCount += appliedWave.AppliedUnitCount

		local composedWave = table.clone(authoredWave)
		composedWave.Units = appliedWave.Units
		composedWave.VariationApplication = table.freeze({
			ApplicationIdentity = appliedWave.ApplicationIdentity,
			UnitCountDelta = appliedWave.UnitCountDelta,
			OriginalUnitCount = appliedWave.OriginalUnitCount,
			AppliedUnitCount = appliedWave.AppliedUnitCount,
			SelectedUnitIndex = appliedWave.SelectedUnitIndex,
			SelectedArchetypeId = appliedWave.SelectedArchetypeId,
		})
		table.insert(composedWaves, table.freeze(composedWave))
		table.insert(
			identityParts,
			string.format("%d[%s|%s]", waveIndex, appliedWave.ApplicationIdentity, unitSignature(appliedWave.Units))
		)
	end

	assert(
		appliedUnitCount - originalUnitCount == consequence.UnitCountDelta,
		"composed encounter unit delta must match the bounded encounter consequence"
	)
	assert(
		appliedUnitCount >= consequence.MinimumRetainedUnits,
		"composed encounter must preserve the minimum retained authored-unit count"
	)

	local selectedIdentity = if selectedIndex == nil then "none" else tostring(selectedIndex)
	local compositionIdentity = string.format(
		"%s|seed=%d|node=%d|room=%s|slot=%s|intensity=%d>%d|delta=%d|selectedWave=%s|spawn=%s|reward=%s|waves=%s",
		IDENTITY_VERSION,
		seed,
		consequence.NodeIndex,
		consequence.RoomId,
		consequence.EncounterSlotId,
		consequence.BaseIntensity,
		consequence.EffectiveIntensity,
		consequence.UnitCountDelta,
		selectedIdentity,
		identityValue(authoredEncounter.SpawnSourceId),
		identityValue(authoredEncounter.RewardSourceId),
		table.concat(identityParts, ";")
	)

	return table.freeze({
		Seed = seed,
		NodeIndex = consequence.NodeIndex,
		RoomId = consequence.RoomId,
		EncounterSlotId = consequence.EncounterSlotId,
		BaseIntensity = consequence.BaseIntensity,
		EffectiveIntensity = consequence.EffectiveIntensity,
		ModifierApplied = encounterRecord.ModifierApplied,
		SpawnSourceId = authoredEncounter.SpawnSourceId,
		RewardSourceId = authoredEncounter.RewardSourceId,
		UnitCountDelta = consequence.UnitCountDelta,
		MinimumRetainedUnits = consequence.MinimumRetainedUnits,
		SelectedWaveIndex = selectedIndex,
		OriginalUnitCount = originalUnitCount,
		AppliedUnitCount = appliedUnitCount,
		CompositionIdentity = compositionIdentity,
		Waves = table.freeze(composedWaves),
	})
end

return table.freeze(Composer)
