--!strict

--[[
	Patch 0.6 deterministic composition debug readback.

	This pure diagnostic helper reconstructs the server-owned run variation and
	authored encounter compositions for an existing deterministic room plan. The
	result is frozen, read-only metadata intended for debugging/replay comparison.
	It does not mutate the room plan, start encounters, spawn enemies, grant
	rewards, or change progression state.
]]

local FirstDungeonContentConfig = require(script.Parent.Parent.Config.FirstDungeonContentConfig)
local RunVariationPlanner = require(script.Parent.RunVariationPlanner)
local RunVariationEncounterView = require(script.Parent.RunVariationEncounterView)
local RunVariationAuthoredEncounterComposer = require(script.Parent.RunVariationAuthoredEncounterComposer)

export type CompositionRecord = {
	NodeIndex: number,
	RoomId: string,
	EncounterSlotId: string,
	BaseIntensity: number,
	EffectiveIntensity: number,
	ModifierApplied: boolean,
	UnitCountDelta: number,
	SelectedWaveIndex: number?,
	OriginalUnitCount: number,
	AppliedUnitCount: number,
	CompositionIdentity: string,
}

export type Readback = {
	Seed: number,
	RoomPlanIdentity: string,
	VariationIdentity: string,
	RunModifierId: string?,
	RunModifierPlanIdentity: string?,
	Records: { CompositionRecord },
	RecordByRoomId: { [string]: CompositionRecord },
	OriginalUnitCount: number,
	AppliedUnitCount: number,
	UnitCountDelta: number,
	EncounterCount: number,
	ModifiedEncounterCount: number,
	UnitCountsByEncounterSlotId: { [string]: UnitCountSummary },
	UnitCountsByArchetypeId: { [string]: UnitCountSummary },
	CompositionIdentity: string,
}

export type UnitCountSummary = {
	OriginalUnitCount: number,
	AppliedUnitCount: number,
	UnitCountDelta: number,
}

local DebugReadback = {}

local function addCount(summaryById: { [string]: any }, id: string, originalCount: number, appliedCount: number)
	local summary = summaryById[id]
	if summary == nil then
		summary = { OriginalUnitCount = 0, AppliedUnitCount = 0 }
		summaryById[id] = summary
	end
	summary.OriginalUnitCount += originalCount
	summary.AppliedUnitCount += appliedCount
end

local function countArchetypes(summaryById: { [string]: any }, waves: { any }, field: string)
	for _, wave in waves do
		for _, unit in wave.Units do
			local summary = summaryById[unit.ArchetypeId]
			if summary == nil then
				summary = { OriginalUnitCount = 0, AppliedUnitCount = 0 }
				summaryById[unit.ArchetypeId] = summary
			end
			summary[field] += unit.Count
		end
	end
end

local function freezeSummaries(summaryById: { [string]: any }): { [string]: UnitCountSummary }
	local frozen = {}
	for id, summary in summaryById do
		frozen[id] = table.freeze({
			OriginalUnitCount = summary.OriginalUnitCount,
			AppliedUnitCount = summary.AppliedUnitCount,
			UnitCountDelta = summary.AppliedUnitCount - summary.OriginalUnitCount,
		})
	end
	return table.freeze(frozen)
end

function DebugReadback.build(roomPlan: any): Readback
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.PlanIdentity) == "string" and roomPlan.PlanIdentity ~= "", "room plan identity is required")

	local variationPlan = RunVariationPlanner.plan(roomPlan)
	local encounterView = RunVariationEncounterView.build(roomPlan, variationPlan)
	local records = {}
	local recordByRoomId = {}
	local compositionIdentities = {}
	local originalUnitCount = 0
	local appliedUnitCount = 0
	local modifiedEncounterCount = 0
	local unitCountsByEncounterSlotId = {}
	local unitCountsByArchetypeId = {}
	local expectedRoomIds = {}
	local expectedEncounterCount = 0
	for _, node in roomPlan.Nodes do
		if type(node.EncounterSlotId) == "string" and type(node.EncounterIntensity) == "number" then
			assert(
				FirstDungeonContentConfig.Encounters[node.RoomId] ~= nil,
				"room plan encounter lacks authored content"
			)
			expectedRoomIds[node.RoomId] = true
			expectedEncounterCount += 1
		end
	end

	for _, encounterRecord in encounterView.Records do
		local authoredEncounter = FirstDungeonContentConfig.Encounters[encounterRecord.RoomId]
		assert(authoredEncounter ~= nil, "debug readback requires authored encounter content")
		assert(
			expectedRoomIds[encounterRecord.RoomId] == true,
			"encounter view contains an unauthored room-plan record"
		)

		local composed =
			RunVariationAuthoredEncounterComposer.compose(roomPlan.Seed, encounterRecord, authoredEncounter)

		local record = table.freeze({
			NodeIndex = composed.NodeIndex,
			RoomId = composed.RoomId,
			EncounterSlotId = composed.EncounterSlotId,
			BaseIntensity = composed.BaseIntensity,
			EffectiveIntensity = composed.EffectiveIntensity,
			ModifierApplied = composed.ModifierApplied,
			UnitCountDelta = composed.UnitCountDelta,
			SelectedWaveIndex = composed.SelectedWaveIndex,
			OriginalUnitCount = composed.OriginalUnitCount,
			AppliedUnitCount = composed.AppliedUnitCount,
			CompositionIdentity = composed.CompositionIdentity,
		})
		assert(recordByRoomId[composed.RoomId] == nil, "debug readback requires unique composed room ids")
		table.insert(records, record)
		recordByRoomId[composed.RoomId] = record
		table.insert(compositionIdentities, composed.CompositionIdentity)
		originalUnitCount += composed.OriginalUnitCount
		appliedUnitCount += composed.AppliedUnitCount
		if composed.ModifierApplied then
			modifiedEncounterCount += 1
		end
		addCount(
			unitCountsByEncounterSlotId,
			composed.EncounterSlotId,
			composed.OriginalUnitCount,
			composed.AppliedUnitCount
		)
		countArchetypes(unitCountsByArchetypeId, authoredEncounter.Waves, "OriginalUnitCount")
		countArchetypes(unitCountsByArchetypeId, composed.Waves, "AppliedUnitCount")
	end
	assert(#records == expectedEncounterCount, "authored encounter and encounter-view cardinality mismatch")

	local runModifier = variationPlan.RunModifier
	local unitCountDelta = appliedUnitCount - originalUnitCount
	local compositionIdentity = string.format(
		"P06-COMPOSITION-READBACK-v1|seed=%d|roomPlan=%s|variation=%s|units=%d>%d|records=%s",
		roomPlan.Seed,
		roomPlan.PlanIdentity,
		variationPlan.VariationIdentity,
		originalUnitCount,
		appliedUnitCount,
		table.concat(compositionIdentities, ";")
	)
	return table.freeze({
		Seed = roomPlan.Seed,
		RoomPlanIdentity = roomPlan.PlanIdentity,
		VariationIdentity = variationPlan.VariationIdentity,
		RunModifierId = if runModifier ~= nil then runModifier.ModifierId else nil,
		RunModifierPlanIdentity = if runModifier ~= nil then runModifier.PlanIdentity else nil,
		Records = table.freeze(records),
		RecordByRoomId = table.freeze(recordByRoomId),
		OriginalUnitCount = originalUnitCount,
		AppliedUnitCount = appliedUnitCount,
		UnitCountDelta = unitCountDelta,
		EncounterCount = #records,
		ModifiedEncounterCount = modifiedEncounterCount,
		UnitCountsByEncounterSlotId = freezeSummaries(unitCountsByEncounterSlotId),
		UnitCountsByArchetypeId = freezeSummaries(unitCountsByArchetypeId),
		CompositionIdentity = compositionIdentity,
	})
end

return table.freeze(DebugReadback)
