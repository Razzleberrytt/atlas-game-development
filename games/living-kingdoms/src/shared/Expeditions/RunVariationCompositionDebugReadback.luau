--!strict

local Content = require(script.Parent.Parent.Config.FirstDungeonContentConfig)
local Planner = require(script.Parent.RunVariationPlanner)
local EncounterView = require(script.Parent.RunVariationEncounterView)
local Composer = require(script.Parent.RunVariationAuthoredEncounterComposer)
local Schema = require(script.Parent.RunVariationDebugSchema)

local DebugReadback = {}
DebugReadback.SchemaVersion = Schema.CompositionReadbackVersion
DebugReadback.FailureReasonIds = Schema.FailureReasonIds

local AuthoredByRoomId = Content.Encounters

local function failClosed(condition: boolean, reasonId: string, detail: string)
	assert(condition, reasonId .. ": " .. detail)
end

local function addCount(byId: { [string]: any }, id: string, original: number, applied: number)
	local value = byId[id]
	if value == nil then
		value = { OriginalUnitCount = 0, AppliedUnitCount = 0 }
		byId[id] = value
	end
	value.OriginalUnitCount += original
	value.AppliedUnitCount += applied
end

local function addArchetypes(byId: { [string]: any }, waves: { any }, field: string)
	for _, wave in waves do
		for _, unit in wave.Units do
			local value = byId[unit.ArchetypeId]
			if value == nil then
				value = { OriginalUnitCount = 0, AppliedUnitCount = 0 }
				byId[unit.ArchetypeId] = value
			end
			value[field] += unit.Count
		end
	end
end

local function freezeCounts(byId: { [string]: any }): { [string]: any }
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

local function auditComposition(composed: any, authored: any)
	assert(composed.SpawnSourceId == authored.SpawnSourceId, "composition must preserve authored spawn source")
	assert(composed.RewardSourceId == authored.RewardSourceId, "composition must preserve authored reward source")
	assert(
		composed.AppliedUnitCount >= composed.MinimumRetainedUnits,
		"composition must preserve the minimum retained authored-unit count"
	)

	if composed.EncounterSlotId == "BossEncounter" then
		assert(composed.BaseIntensity == composed.EffectiveIntensity, "boss composition intensity must remain authored")
		assert(composed.UnitCountDelta == 0, "boss composition unit count cannot vary")
		assert(composed.SelectedWaveIndex == nil, "boss composition cannot select a variation wave")
		assert(composed.OriginalUnitCount == composed.AppliedUnitCount, "boss composition count must remain authored")
		for _, wave in composed.Waves do
			assert(wave.VariationApplication.UnitCountDelta == 0, "boss authored waves cannot be varied")
		end
	elseif composed.EncounterSlotId == "None" then
		assert(composed.BaseIntensity == 0 and composed.EffectiveIntensity == 0, "empty room intensity must stay zero")
		assert(composed.UnitCountDelta == 0, "empty room unit count cannot vary")
		assert(composed.SelectedWaveIndex == nil, "empty room cannot select a variation wave")
		assert(
			composed.OriginalUnitCount == 0 and composed.AppliedUnitCount == 0,
			"empty room must remain without units"
		)
		assert(#composed.Waves == 0, "empty room must remain without waves")
	end
end

local function buildWaveDiagnostics(composed: any): ({ any }, number?, string?, string?)
	local diagnostics = {}
	local selectedUnitGroupIndex = nil
	local selectedArchetypeId = nil
	local selectedWaveIdentity = nil

	for waveIndex, wave in composed.Waves do
		local application = wave.VariationApplication
		local diagnostic = table.freeze({
			WaveIndex = waveIndex,
			OriginalUnitCount = application.OriginalUnitCount,
			AppliedUnitCount = application.AppliedUnitCount,
			UnitCountDelta = application.UnitCountDelta,
			WaveIdentity = application.ApplicationIdentity,
			SelectedUnitGroupIndex = application.SelectedUnitIndex,
			SelectedArchetypeId = application.SelectedArchetypeId,
		})
		table.insert(diagnostics, diagnostic)
		if waveIndex == composed.SelectedWaveIndex then
			selectedWaveIdentity = diagnostic.WaveIdentity
			selectedUnitGroupIndex = diagnostic.SelectedUnitGroupIndex
			selectedArchetypeId = diagnostic.SelectedArchetypeId
		end
	end

	return table.freeze(diagnostics), selectedUnitGroupIndex, selectedArchetypeId, selectedWaveIdentity
end

function DebugReadback.build(roomPlan: any): any
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.PlanIdentity) == "string" and roomPlan.PlanIdentity ~= "", "room plan identity is required")

	local variation = Planner.plan(roomPlan)
	local modifier = variation.RunModifier
	local view = EncounterView.build(roomPlan, variation)
	local expectedRooms = {}
	local expectedCount = 0
	for _, node in roomPlan.Nodes do
		if type(node.EncounterSlotId) == "string" and type(node.EncounterIntensity) == "number" then
			assert(AuthoredByRoomId[node.RoomId] ~= nil, "room plan encounter lacks authored content")
			expectedRooms[node.RoomId] = true
			expectedCount += 1
		end
	end

	local records = {}
	local byRoom = {}
	local identities = {}
	local bySlot = {}
	local byArchetype = {}
	local seenSlots = {}
	local originalTotal = 0
	local appliedTotal = 0
	local modifiedCount = 0
	local previousNodeIndex = 0

	for _, encounterRecord in view.Records do
		local authored = AuthoredByRoomId[encounterRecord.RoomId]
		assert(authored ~= nil, "debug readback requires authored encounter content")
		assert(expectedRooms[encounterRecord.RoomId] == true, "encounter view contains an unauthored room-plan record")

		local composed = Composer.compose(roomPlan.Seed, encounterRecord, authored)
		assert(composed.NodeIndex > previousNodeIndex, "composition records must remain strictly node-sorted")
		previousNodeIndex = composed.NodeIndex

		local slotKey = composed.RoomId .. "|" .. composed.EncounterSlotId
		failClosed(
			seenSlots[slotKey] == nil,
			Schema.FailureReasonIds.DuplicateEncounterSlot,
			"duplicate room encounter slot"
		)
		seenSlots[slotKey] = true
		auditComposition(composed, authored)

		local waveDiagnostics, selectedUnitGroupIndex, selectedArchetypeId, selectedWaveIdentity =
			buildWaveDiagnostics(composed)

		local record = table.freeze({
			NodeIndex = composed.NodeIndex,
			RoomId = composed.RoomId,
			EncounterSlotId = composed.EncounterSlotId,
			BaseIntensity = composed.BaseIntensity,
			EffectiveIntensity = composed.EffectiveIntensity,
			ModifierApplied = composed.ModifierApplied,
			ModifierId = if composed.ModifierApplied and modifier ~= nil then modifier.ModifierId else nil,
			UnitCountDelta = composed.UnitCountDelta,
			MinimumRetainedUnits = composed.MinimumRetainedUnits,
			SelectedWaveIndex = composed.SelectedWaveIndex,
			SelectedWaveIdentity = selectedWaveIdentity,
			SelectedUnitGroupIndex = selectedUnitGroupIndex,
			SelectedArchetypeId = selectedArchetypeId,
			OriginalUnitCount = composed.OriginalUnitCount,
			AppliedUnitCount = composed.AppliedUnitCount,
			SpawnSourceId = composed.SpawnSourceId,
			RewardSourceId = composed.RewardSourceId,
			WaveDiagnostics = waveDiagnostics,
			CompositionIdentity = composed.CompositionIdentity,
		})
		assert(byRoom[composed.RoomId] == nil, "debug readback requires unique composed room ids")
		table.insert(records, record)
		byRoom[composed.RoomId] = record
		table.insert(identities, composed.CompositionIdentity)

		originalTotal += composed.OriginalUnitCount
		appliedTotal += composed.AppliedUnitCount
		if composed.ModifierApplied then
			modifiedCount += 1
		end
		addCount(bySlot, composed.EncounterSlotId, composed.OriginalUnitCount, composed.AppliedUnitCount)
		addArchetypes(byArchetype, authored.Waves, "OriginalUnitCount")
		addArchetypes(byArchetype, composed.Waves, "AppliedUnitCount")
	end

	failClosed(
		#records == expectedCount,
		Schema.FailureReasonIds.CardinalityMismatch,
		"authored encounter and encounter-view cardinality mismatch"
	)

	local delta = appliedTotal - originalTotal
	local identity = Schema.formatCompositionIdentity(
		roomPlan.Seed,
		roomPlan.PlanIdentity,
		variation.VariationIdentity,
		originalTotal,
		appliedTotal,
		identities
	)
	failClosed(
		#identity <= Schema.MaximumCompositionIdentityLength,
		Schema.FailureReasonIds.IdentityTooLarge,
		"composition identity exceeds diagnostic bound"
	)

	return table.freeze({
		SchemaVersion = Schema.CompositionReadbackVersion,
		Seed = roomPlan.Seed,
		RoomPlanIdentity = roomPlan.PlanIdentity,
		VariationIdentity = variation.VariationIdentity,
		RunModifierId = if modifier ~= nil then modifier.ModifierId else nil,
		RunModifierPlanIdentity = if modifier ~= nil then modifier.PlanIdentity else nil,
		HasSecretBranch = variation.SecretBranch ~= nil,
		HasOptionalObjective = variation.OptionalObjective ~= nil,
		Records = table.freeze(records),
		RecordByRoomId = table.freeze(byRoom),
		OriginalUnitCount = originalTotal,
		AppliedUnitCount = appliedTotal,
		UnitCountDelta = delta,
		EncounterCount = #records,
		ModifiedEncounterCount = modifiedCount,
		UnitCountsByEncounterSlotId = freezeCounts(bySlot),
		UnitCountsByArchetypeId = freezeCounts(byArchetype),
		ModifierSummary = if modifier == nil
			then "No run modifier"
			else string.format("%s affects %d/%d encounters", modifier.ModifierId, modifiedCount, #records),
		EncounterSummary = string.format("%d encounters, %d units (%+d variation)", #records, appliedTotal, delta),
		SeedCommand = string.format('ExpeditionControl:Invoke("Start", { Seed = %d })', roomPlan.Seed),
		CompositionIdentity = identity,
	})
end

function DebugReadback.recordForRoom(readback: any, roomId: string): any
	assert(type(readback) == "table" and type(readback.RecordByRoomId) == "table", "readback is required")
	assert(type(roomId) == "string" and roomId ~= "", "room id is required")
	return readback.RecordByRoomId[roomId]
end

return table.freeze(DebugReadback)
