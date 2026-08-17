--!strict

local RegistryModule = require("../src/shared/Expeditions/ExpeditionInstanceRegistry")

local registry = RegistryModule.new(3)
assert(registry:count() == 0)

local first = registry:create("run:alpha", 42, "plan:a")
local second = registry:create("run:bravo", 42, "plan:b")
assert(first.Accepted == true and first.ReasonId == "RunRegistered")
assert(second.Accepted == true and second.ReasonId == "RunRegistered")
assert(registry:count() == 2)
assert(first.Record.RunId == "run:alpha")
assert(second.Record.RunId == "run:bravo")
assert(first.Record.SlotIndex ~= second.Record.SlotIndex)
assert(first.Record.OriginX ~= second.Record.OriginX or first.Record.OriginZ ~= second.Record.OriginZ)
assert(first.Record.ReproductionKey == "run=run:alpha|seed=42|plan=plan:a")

local duplicate = registry:create("run:alpha", 42, "plan:a")
assert(duplicate.Accepted == false and duplicate.ReasonId == "RunAlreadyRegistered")
assert(duplicate.Record == first.Record)

local conflictSeed = registry:create("run:alpha", 43, "plan:a")
assert(conflictSeed.Accepted == false and conflictSeed.ReasonId == "ConflictingRunOwnership")
local conflictPlan = registry:create("run:alpha", 42, "plan:changed")
assert(conflictPlan.Accepted == false and conflictPlan.ReasonId == "ConflictingRunOwnership")

local third = registry:create("run:charlie", 99, "plan:c", "custom-reproduction-key")
assert(third.Accepted == true)
assert(third.Record.ReproductionKey == "custom-reproduction-key")
local capacity = registry:create("run:delta", 100, "plan:d")
assert(capacity.Accepted == false and capacity.ReasonId == "InstanceCapacityReached")

local alphaSlot = first.Record.SlotIndex
local removed = registry:remove("run:alpha")
assert(removed.Accepted == true and removed.ReasonId == "RunRemoved")
assert(registry:get("run:alpha") == nil)
assert(registry:get("run:bravo") == second.Record)
assert(registry:count() == 2)

local replacement = registry:create("run:delta", 100, "plan:d")
assert(replacement.Accepted == true)
assert(replacement.Record.SlotIndex == alphaSlot, "lowest available instance slot should be reused")
assert(registry:count() == 3)

local records = registry:list()
assert(#records == 3)
for index = 2, #records do
	assert(records[index - 1].SlotIndex < records[index].SlotIndex)
end

assert(registry:remove("run:missing").ReasonId == "RunNotRegistered")
assert(registry:create("short", 1, "plan").ReasonId == "InvalidRunId")
assert(registry:create("run:invalid-seed", 1.5, "plan").ReasonId == "InvalidSeed")
assert(registry:create("run:invalid-plan", 1, "").ReasonId == "InvalidPlanIdentity")

registry:reset()
assert(registry:count() == 0)
assert(#registry:list() == 0)
local afterReset = registry:create("run:reset", 7, "plan:reset")
assert(afterReset.Accepted == true and afterReset.Record.SlotIndex == 1)

print("ExpeditionInstanceRegistry fixture passed")
