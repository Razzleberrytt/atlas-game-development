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
}

local DebugReadback = {}

function DebugReadback.build(roomPlan: any): Readback
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.PlanIdentity) == "string" and roomPlan.PlanIdentity ~= "", "room plan identity is required")

	local variationPlan = RunVariationPlanner.plan(roomPlan)
	local encounterView = RunVariationEncounterView.build(roomPlan, variationPlan)
	local records = {}

	for _, encounterRecord in encounterView.Records do
		local authoredEncounter = FirstDungeonContentConfig.Encounters[encounterRecord.RoomId]
		assert(authoredEncounter ~= nil, "debug readback requires authored encounter content")

		local composed = RunVariationAuthoredEncounterComposer.compose(
			roomPlan.Seed,
			encounterRecord,
			authoredEncounter
		)

		table.insert(
			records,
			table.freeze({
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
		)
	end

	local runModifier = variationPlan.RunModifier
	return table.freeze({
		Seed = roomPlan.Seed,
		RoomPlanIdentity = roomPlan.PlanIdentity,
		VariationIdentity = variationPlan.VariationIdentity,
		RunModifierId = if runModifier ~= nil then runModifier.ModifierId else nil,
		RunModifierPlanIdentity = if runModifier ~= nil then runModifier.PlanIdentity else nil,
		Records = table.freeze(records),
	})
end

return table.freeze(DebugReadback)
