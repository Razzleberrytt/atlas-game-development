--!strict

local Content = require(script.Parent.Parent.Config.FirstDungeonContentConfig)
local Planner = require(script.Parent.RunVariationPlanner)
local EncounterView = require(script.Parent.RunVariationEncounterView)
local Composer = require(script.Parent.RunVariationAuthoredEncounterComposer)
local Schema = require(script.Parent.RunVariationDebugSchema)

export type UnitCountSummary = { OriginalUnitCount: number, AppliedUnitCount: number, UnitCountDelta: number }
export type CompositionRecord = {
	NodeIndex: number, RoomId: string, EncounterSlotId: string, BaseIntensity: number, EffectiveIntensity: number,
	ModifierApplied: boolean, ModifierId: string?, UnitCountDelta: number, SelectedWaveIndex: number?,
	SelectedWaveIdentity: string?, OriginalUnitCount: number, AppliedUnitCount: number, CompositionIdentity: string,
}
export type Readback = {
	SchemaVersion: string, Seed: number, RoomPlanIdentity: string, VariationIdentity: string, RunModifierId: string?,
	RunModifierPlanIdentity: string?, HasSecretBranch: boolean, HasOptionalObjective: boolean,
	Records: { CompositionRecord }, RecordByRoomId: { [string]: CompositionRecord }, OriginalUnitCount: number,
	AppliedUnitCount: number, UnitCountDelta: number, EncounterCount: number, ModifiedEncounterCount: number,
	UnitCountsByEncounterSlotId: { [string]: UnitCountSummary }, UnitCountsByArchetypeId: { [string]: UnitCountSummary },
	ModifierSummary: string, EncounterSummary: string, SeedCommand: string, CompositionIdentity: string,
}

local DebugReadback = {}
DebugReadback.SchemaVersion = Schema.CompositionReadbackVersion
DebugReadback.FailureReasonIds = Schema.FailureReasonIds
local AuthoredByRoomId = Content.Encounters

local function addCount(byId: { [string]: any }, id: string, original: number, applied: number)
	local value = byId[id] or { OriginalUnitCount = 0, AppliedUnitCount = 0 }
	byId[id] = value
	value.OriginalUnitCount += original
	value.AppliedUnitCount += applied
end

local function addArchetypes(byId: { [string]: any }, waves: { any }, field: string)
	for _, wave in waves do
		for _, unit in wave.Units do
			local value = byId[unit.ArchetypeId] or { OriginalUnitCount = 0, AppliedUnitCount = 0 }
			byId[unit.ArchetypeId] = value
			value[field] += unit.Count
		end
	end
end

local function freezeCounts(byId: { [string]: any }): { [string]: UnitCountSummary }
	local result = {}
	for id, value in byId do
		result[id] = table.freeze({
			OriginalUnitCount = value.OriginalUnitCount,
			AppliedUnitCount = value.AppliedUnitCount,
			UnitCountDelta = value.AppliedUnitCount - value.OriginalUnitCount,
		})
	end
	return table.freeze(result)
end

function DebugReadback.build(roomPlan: any): Readback
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.PlanIdentity) == "string" and roomPlan.PlanIdentity ~= "", "room plan identity is required")

	local variation = Planner.plan(roomPlan)
	local modifier = variation.RunModifier
	local view = EncounterView.build(roomPlan, variation)
	local records, byRoom, identities = {}, {}, {}
	local originalTotal, appliedTotal, modifiedCount = 0, 0, 0
	local bySlot, byArchetype, expectedRooms, seenSlots = {}, {}, {}, {}
	local expectedCount, previousNodeIndex = 0, 0

	for _, node in roomPlan.Nodes do
		if type(node.EncounterSlotId) == "string" and type(node.EncounterIntensity) == "number" then
			assert(AuthoredByRoomId[node.RoomId] ~= nil, "room plan encounter lacks authored content")
			expectedRooms[node.RoomId], expectedCount = true, expectedCount + 1
		end
	end

	for _, encounterRecord in view.Records do
		local authored = AuthoredByRoomId[encounterRecord.RoomId]
		assert(authored ~= nil, "debug readback requires authored encounter content")
		assert(expectedRooms[encounterRecord.RoomId] == true, "encounter view contains an unauthored room-plan record")
		local composed = Composer.compose(roomPlan.Seed, encounterRecord, authored)
		assert(composed.NodeIndex > previousNodeIndex, "composition records must remain strictly node-sorted")
		previousNodeIndex = composed.NodeIndex
		local slotKey = composed.RoomId .. "|" .. composed.EncounterSlotId
		assert(seenSlots[slotKey] == nil, Schema.FailureReasonIds.DuplicateEncounterSlot .. ": duplicate room encounter slot")
		seenSlots[slotKey] = true
		local waveIdentity = nil
		if composed.SelectedWaveIndex ~= nil then
			local wave = composed.Waves[composed.SelectedWaveIndex]
			assert(wave ~= nil, "selected composed wave is required")
			waveIdentity = wave.VariationApplication.ApplicationIdentity
		end
		local record = table.freeze({
			NodeIndex = composed.NodeIndex, RoomId = composed.RoomId, EncounterSlotId = composed.EncounterSlotId,
			BaseIntensity = composed.BaseIntensity, EffectiveIntensity = composed.EffectiveIntensity,
			ModifierApplied = composed.ModifierApplied,
			ModifierId = if composed.ModifierApplied and modifier ~= nil then modifier.ModifierId else nil,
			UnitCountDelta = composed.UnitCountDelta, SelectedWaveIndex = composed.SelectedWaveIndex,
			SelectedWaveIdentity = waveIdentity, OriginalUnitCount = composed.OriginalUnitCount,
			AppliedUnitCount = composed.AppliedUnitCount, CompositionIdentity = composed.CompositionIdentity,
		})
		assert(byRoom[composed.RoomId] == nil, "debug readback requires unique composed room ids")
		table.insert(records, record); byRoom[composed.RoomId] = record; table.insert(identities, composed.CompositionIdentity)
		originalTotal += composed.OriginalUnitCount; appliedTotal += composed.AppliedUnitCount
		if composed.ModifierApplied then modifiedCount += 1 end
		addCount(bySlot, composed.EncounterSlotId, composed.OriginalUnitCount, composed.AppliedUnitCount)
		addArchetypes(byArchetype, authored.Waves, "OriginalUnitCount"); addArchetypes(byArchetype, composed.Waves, "AppliedUnitCount")
	end
	assert(#records == expectedCount, Schema.FailureReasonIds.CardinalityMismatch .. ": authored encounter and encounter-view cardinality mismatch")

	local delta = appliedTotal - originalTotal
	local identity = Schema.formatCompositionIdentity(roomPlan.Seed, roomPlan.PlanIdentity, variation.VariationIdentity, originalTotal, appliedTotal, identities)
	assert(#identity <= Schema.MaximumCompositionIdentityLength, Schema.FailureReasonIds.IdentityTooLarge .. ": composition identity exceeds diagnostic bound")
	return table.freeze({
		SchemaVersion = Schema.CompositionReadbackVersion, Seed = roomPlan.Seed, RoomPlanIdentity = roomPlan.PlanIdentity,
		VariationIdentity = variation.VariationIdentity, RunModifierId = if modifier then modifier.ModifierId else nil,
		RunModifierPlanIdentity = if modifier then modifier.PlanIdentity else nil, HasSecretBranch = variation.SecretBranch ~= nil,
		HasOptionalObjective = variation.OptionalObjective ~= nil, Records = table.freeze(records), RecordByRoomId = table.freeze(byRoom),
		OriginalUnitCount = originalTotal, AppliedUnitCount = appliedTotal, UnitCountDelta = delta, EncounterCount = #records,
		ModifiedEncounterCount = modifiedCount, UnitCountsByEncounterSlotId = freezeCounts(bySlot), UnitCountsByArchetypeId = freezeCounts(byArchetype),
		ModifierSummary = if modifier == nil then "No run modifier" else string.format("%s affects %d/%d encounters", modifier.ModifierId, modifiedCount, #records),
		EncounterSummary = string.format("%d encounters, %d units (%+d variation)", #records, appliedTotal, delta),
		SeedCommand = string.format('ExpeditionControl:Invoke("Start", { Seed = %d })', roomPlan.Seed), CompositionIdentity = identity,
	})
end

function DebugReadback.recordForRoom(readback: Readback, roomId: string): CompositionRecord?
	assert(type(readback) == "table" and type(readback.RecordByRoomId) == "table", "readback is required")
	assert(type(roomId) == "string" and roomId ~= "", "room id is required")
	return readback.RecordByRoomId[roomId]
end

return table.freeze(DebugReadback)
