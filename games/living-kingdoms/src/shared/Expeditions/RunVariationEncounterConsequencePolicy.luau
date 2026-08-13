--!strict

--[[
	Patch 0.6 bounded encounter-consequence policy.

	The effective encounter view already decides which authored room pressure tier
	is active for a run. This policy converts that tier difference into one narrow
	consequence: a +/-1 authored-unit budget adjustment for eligible non-boss
	encounter slots. It does not choose units, spawn enemies, add archetypes,
	change rewards, or mutate room/variation state.
]]

local RoomAssemblyContracts = require(script.Parent.RoomAssemblyContracts)
local EncounterSlotIds = RoomAssemblyContracts.EncounterSlotIds

export type Consequence = {
	NodeIndex: number,
	RoomId: string,
	EncounterSlotId: string,
	BaseIntensity: number,
	EffectiveIntensity: number,
	ApplicationKind: "AuthoredUnitCountDelta",
	UnitCountDelta: number,
	MinimumRetainedUnits: number,
	AllowNewArchetypes: boolean,
	AllowRewardChanges: boolean,
}

local Policy = {}

local MINIMUM_PRESSURE_INTENSITY = 1
local MAXIMUM_PRESSURE_INTENSITY = 3

local ADJUSTABLE_SLOT_IDS = table.freeze({
	[EncounterSlotIds.LightPatrol] = true,
	[EncounterSlotIds.StandardSquad] = true,
	[EncounterSlotIds.EliteGuard] = true,
})

local function assertInteger(value: any, message: string)
	assert(type(value) == "number" and value % 1 == 0, message)
end

local function assertPressureIntensity(value: any, message: string)
	assertInteger(value, message)
	assert(value >= MINIMUM_PRESSURE_INTENSITY and value <= MAXIMUM_PRESSURE_INTENSITY, message)
end

function Policy.resolve(record: any): Consequence
	assert(type(record) == "table", "encounter record is required")
	assertInteger(record.NodeIndex, "encounter record node index must be an integer")
	assert(record.NodeIndex >= 1, "encounter record node index must be positive")
	assert(type(record.RoomId) == "string" and record.RoomId ~= "", "encounter record room id is required")
	assert(
		type(record.EncounterSlotId) == "string" and record.EncounterSlotId ~= "",
		"encounter record slot id is required"
	)
	assert(type(record.ModifierApplied) == "boolean", "encounter record modifier flag is required")

	local slotId = record.EncounterSlotId
	local unitCountDelta = 0
	local minimumRetainedUnits = 1

	if slotId == EncounterSlotIds.None then
		assert(record.BaseIntensity == 0, "non-encounter base intensity must be zero")
		assert(record.EffectiveIntensity == 0, "non-encounter effective intensity must be zero")
		assert(record.ModifierApplied == false, "non-encounter rooms cannot apply run modifiers")
		minimumRetainedUnits = 0
	elseif slotId == EncounterSlotIds.BossEncounter then
		assertPressureIntensity(
			record.BaseIntensity,
			"boss base intensity must stay within the authored pressure range"
		)
		assertPressureIntensity(
			record.EffectiveIntensity,
			"boss effective intensity must stay within the authored pressure range"
		)
		assert(record.EffectiveIntensity == record.BaseIntensity, "boss encounter intensity cannot be modified")
		assert(record.ModifierApplied == false, "boss encounter modifiers are not authorized")
	elseif ADJUSTABLE_SLOT_IDS[slotId] == true then
		assertPressureIntensity(
			record.BaseIntensity,
			"encounter base intensity must stay within the authored pressure range"
		)
		assertPressureIntensity(
			record.EffectiveIntensity,
			"encounter effective intensity must stay within the authored pressure range"
		)
		unitCountDelta = record.EffectiveIntensity - record.BaseIntensity
		assert(math.abs(unitCountDelta) <= 1, "run variation may change authored unit budget by at most one tier")
		assert(
			record.ModifierApplied == (unitCountDelta ~= 0),
			"encounter modifier flag must match the effective intensity difference"
		)
	else
		error("unsupported encounter slot id: " .. slotId)
	end

	return table.freeze({
		NodeIndex = record.NodeIndex,
		RoomId = record.RoomId,
		EncounterSlotId = slotId,
		BaseIntensity = record.BaseIntensity,
		EffectiveIntensity = record.EffectiveIntensity,
		ApplicationKind = "AuthoredUnitCountDelta",
		UnitCountDelta = unitCountDelta,
		MinimumRetainedUnits = minimumRetainedUnits,
		AllowNewArchetypes = false,
		AllowRewardChanges = false,
	})
end

return table.freeze(Policy)
