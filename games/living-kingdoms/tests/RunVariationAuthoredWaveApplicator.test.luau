--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "run variation authored wave applicator assertion failed", 2)
	end
end

local applicator =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationAuthoredWaveApplicator.luau"), {
		debugName = "RunVariationAuthoredWaveApplicator",
		injectGlobals = true,
	})()

local function consequence(delta: number, minimumRetainedUnits: number): any
	return {
		NodeIndex = 3,
		RoomId = "warden-barracks",
		EncounterSlotId = "StandardSquad",
		ApplicationKind = "AuthoredUnitCountDelta",
		UnitCountDelta = delta,
		MinimumRetainedUnits = minimumRetainedUnits,
		AllowNewArchetypes = false,
		AllowRewardChanges = false,
	}
end

local sourceWave = {
	Units = {
		{ ArchetypeId = "walker", Count = 2, HordeRoleId = "basic" },
		{ ArchetypeId = "walker", Count = 1, HordeRoleId = "runner" },
	},
}

local unchanged = applicator.apply(10, sourceWave, consequence(0, 1))
assert(unchanged.OriginalUnitCount == 3 and unchanged.AppliedUnitCount == 3, "zero delta must retain authored count")
assert(unchanged.SelectedUnitIndex == nil, "zero delta must not choose an authored unit group")
assert(unchanged.Units[1] ~= sourceWave.Units[1], "applicator must return copied authored unit records")
assert(table.isfrozen(unchanged) and table.isfrozen(unchanged.Units), "applied wave must be immutable")
assert(table.isfrozen(unchanged.Units[1]), "applied unit records must be immutable")

local denser = applicator.apply(10, sourceWave, consequence(1, 1))
assert(denser.SelectedUnitIndex == 2, "seed 10 and node 3 must deterministically select the second authored group")
assert(denser.OriginalUnitCount == 3 and denser.AppliedUnitCount == 4, "denser consequence must add exactly one unit")
assert(denser.Units[1].Count == 2 and denser.Units[2].Count == 2, "selected authored group must receive the added unit")
assert(denser.Units[2].ArchetypeId == sourceWave.Units[2].ArchetypeId, "added unit must reuse an authored archetype")
assert(denser.Units[2].HordeRoleId == sourceWave.Units[2].HordeRoleId, "added unit must reuse the authored role")

local repeated = applicator.apply(10, sourceWave, consequence(1, 1))
assert(repeated.SelectedUnitIndex == denser.SelectedUnitIndex, "same seed and node must reproduce unit selection")
assert(repeated.ApplicationIdentity == denser.ApplicationIdentity, "same inputs must reproduce application identity")

local alternateSeed = applicator.apply(11, sourceWave, consequence(1, 1))
assert(alternateSeed.SelectedUnitIndex == 1, "adjacent seed must exercise the alternate authored group in this fixture")
assert(
	alternateSeed.Units[1].Count == 3 and alternateSeed.Units[2].Count == 1,
	"alternate deterministic selection must remain bounded"
)

local quieter = applicator.apply(10, sourceWave, consequence(-1, 1))
assert(quieter.SelectedUnitIndex == 2, "quieter consequence must use the same deterministic group selection")
assert(
	quieter.OriginalUnitCount == 3 and quieter.AppliedUnitCount == 2,
	"quieter consequence must remove exactly one unit"
)
assert(#quieter.Units == 1, "removing a singleton authored group may remove that group from the applied wave")
assert(
	quieter.Units[1].Count == 2 and quieter.Units[1].HordeRoleId == "basic",
	"remaining authored group must stay unchanged"
)

assert(sourceWave.Units[1].Count == 2, "applicator must not mutate the first source group")
assert(sourceWave.Units[2].Count == 1, "applicator must not mutate the second source group")

local singleUnitWave = {
	Units = {
		{ ArchetypeId = "walker", Count = 1, HordeRoleId = "basic" },
	},
}

local function mustReject(callback: () -> (), message: string)
	local ok = pcall(callback)
	assert(not ok, message)
end

mustReject(function()
	applicator.apply(5, singleUnitWave, consequence(-1, 1))
end, "applicator must not remove the final retained encounter unit")

mustReject(function()
	local invalid = consequence(2, 1)
	applicator.apply(5, sourceWave, invalid)
end, "multi-unit deltas must fail closed")

mustReject(function()
	local invalid = consequence(1, 1)
	invalid.AllowNewArchetypes = true
	applicator.apply(5, sourceWave, invalid)
end, "new-archetype authorization must fail closed")

mustReject(function()
	local invalid = consequence(1, 1)
	invalid.AllowRewardChanges = true
	applicator.apply(5, sourceWave, invalid)
end, "reward-change authorization must fail closed")

mustReject(function()
	local invalid = consequence(1, 1)
	invalid.ApplicationKind = "Unknown"
	applicator.apply(5, sourceWave, invalid)
end, "unknown consequence application kinds must fail closed")

mustReject(function()
	applicator.apply(5, { Units = {} }, consequence(1, 1))
end, "positive deltas require an already-authored unit group")

local nonEncounter = consequence(0, 0)
nonEncounter.EncounterSlotId = "None"
local empty = applicator.apply(5, { Units = {} }, nonEncounter)
assert(empty.OriginalUnitCount == 0 and empty.AppliedUnitCount == 0, "zero-unit non-encounter waves must remain empty")
assert(#empty.Units == 0, "non-encounter application must not invent units")

print("Run variation authored wave applicator fixture passed")
