--!strict

--[[
	Patch 0.6 deterministic authored-wave applicator.

	The encounter consequence policy authorizes only a bounded -1/0/+1 change to
	the number of already-authored units in an eligible encounter. This pure
	applicator chooses which existing authored unit group receives that change from
	the server-owned run seed and node identity. It does not spawn enemies, invent
	archetypes, change rewards, or mutate the source wave.
]]

export type AppliedWave = {
	Seed: number,
	NodeIndex: number,
	RoomId: string,
	EncounterSlotId: string,
	ApplicationIdentity: string,
	UnitCountDelta: number,
	OriginalUnitCount: number,
	AppliedUnitCount: number,
	SelectedUnitIndex: number?,
	Units: { any },
}

local Applicator = {}

local IDENTITY_VERSION = "P06-AUTHORED-WAVE-APPLICATOR-v1"
local MODULUS = 2_147_483_647
local SEED_MULTIPLIER = 48_271
local NODE_MULTIPLIER = 7_919

local function assertInteger(value: any, message: string)
	assert(type(value) == "number" and value % 1 == 0, message)
end

local function totalUnitCount(units: { any }): number
	local total = 0
	for _, unit in units do
		assert(type(unit) == "table", "authored wave units must be tables")
		assert(type(unit.ArchetypeId) == "string" and unit.ArchetypeId ~= "", "authored unit archetype id is required")
		assertInteger(unit.Count, "authored unit count must be an integer")
		assert(unit.Count >= 1, "authored unit count must be positive")
		total += unit.Count
	end
	return total
end

local function selectedIndex(seed: number, nodeIndex: number, unitGroupCount: number): number
	local value = (seed * SEED_MULTIPLIER + nodeIndex * NODE_MULTIPLIER) % MODULUS
	return (value % unitGroupCount) + 1
end

local function frozenCopy(unit: any, count: number): any
	local copy = table.clone(unit)
	copy.Count = count
	return table.freeze(copy)
end

function Applicator.apply(seed: number, authoredWave: any, consequence: any): AppliedWave
	assertInteger(seed, "run seed must be an integer")
	assert(seed > 0, "run seed must be positive")
	assert(type(authoredWave) == "table" and type(authoredWave.Units) == "table", "authored wave units are required")
	assert(type(consequence) == "table", "encounter consequence is required")
	assert(consequence.ApplicationKind == "AuthoredUnitCountDelta", "unsupported encounter consequence application kind")
	assert(consequence.AllowNewArchetypes == false, "wave applicator cannot authorize new archetypes")
	assert(consequence.AllowRewardChanges == false, "wave applicator cannot authorize reward changes")
	assertInteger(consequence.NodeIndex, "encounter consequence node index must be an integer")
	assert(consequence.NodeIndex >= 1, "encounter consequence node index must be positive")
	assert(type(consequence.RoomId) == "string" and consequence.RoomId ~= "", "encounter consequence room id is required")
	assert(
		type(consequence.EncounterSlotId) == "string" and consequence.EncounterSlotId ~= "",
		"encounter consequence slot id is required"
	)
	assertInteger(consequence.UnitCountDelta, "encounter consequence unit delta must be an integer")
	assert(math.abs(consequence.UnitCountDelta) <= 1, "encounter consequence unit delta must stay within one authored unit")
	assertInteger(consequence.MinimumRetainedUnits, "minimum retained unit count must be an integer")
	assert(consequence.MinimumRetainedUnits >= 0, "minimum retained unit count cannot be negative")

	local sourceUnits = authoredWave.Units
	local originalUnitCount = totalUnitCount(sourceUnits)
	local delta = consequence.UnitCountDelta
	local appliedUnitCount = originalUnitCount + delta
	assert(
		appliedUnitCount >= consequence.MinimumRetainedUnits,
		"encounter consequence would violate the minimum retained authored-unit count"
	)
	if delta ~= 0 then
		assert(#sourceUnits >= 1, "an authored-unit delta requires at least one existing authored unit group")
	end

	local chosenIndex = if delta == 0 then nil else selectedIndex(seed, consequence.NodeIndex, #sourceUnits)
	local appliedUnits = {}
	for index, unit in sourceUnits do
		local nextCount = unit.Count
		if index == chosenIndex then
			nextCount += delta
		end
		if nextCount > 0 then
			table.insert(appliedUnits, frozenCopy(unit, nextCount))
		end
	end

	assert(totalUnitCount(appliedUnits) == appliedUnitCount, "applied authored-wave unit count drifted from consequence")
	local selectedIdentity = if chosenIndex == nil then "none" else tostring(chosenIndex)
	local identity = string.format(
		"%s|seed=%d|node=%d|room=%s|slot=%s|delta=%d|selected=%s|count=%d>%d",
		IDENTITY_VERSION,
		seed,
		consequence.NodeIndex,
		consequence.RoomId,
		consequence.EncounterSlotId,
		delta,
		selectedIdentity,
		originalUnitCount,
		appliedUnitCount
	)

	return table.freeze({
		Seed = seed,
		NodeIndex = consequence.NodeIndex,
		RoomId = consequence.RoomId,
		EncounterSlotId = consequence.EncounterSlotId,
		ApplicationIdentity = identity,
		UnitCountDelta = delta,
		OriginalUnitCount = originalUnitCount,
		AppliedUnitCount = appliedUnitCount,
		SelectedUnitIndex = chosenIndex,
		Units = table.freeze(appliedUnits),
	})
end

return table.freeze(Applicator)
