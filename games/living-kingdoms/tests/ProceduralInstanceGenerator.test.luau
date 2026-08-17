--!strict

local Generator = require("../src/shared/Expeditions/ProceduralInstanceGenerator")

local function layoutSignature(layout: any): string
	local values = {}
	for _, placement in layout.Placements do
		table.insert(values, `{placement.RoomId}@{placement.GridCell.x}:{placement.GridCell.z}:{placement.TurnId}`)
	end
	return table.concat(values, "|")
end

local first = Generator.generate(777)
local repeated = Generator.generate(777)
assert(first.Accepted and repeated.Accepted, "valid current assembler seed must generate")
assert(first.ReasonId == "ProceduralInstanceGenerated")
assert(first.Validation.Accepted and first.Validation.ReasonId == "LayoutValid")
assert(
	first.RoomPlan.PlanIdentity == repeated.RoomPlan.PlanIdentity,
	"same seed must preserve canonical content identity"
)
assert(layoutSignature(first.Layout) == layoutSignature(repeated.Layout), "same seed must reproduce spatial layout")

local different = Generator.generate(778)
assert(different.Accepted, "second valid seed must generate")
assert(
	different.RoomPlan.PlanIdentity ~= first.RoomPlan.PlanIdentity
		or layoutSignature(different.Layout) ~= layoutSignature(first.Layout),
	"different seeds must change canonical content or spatial route"
)

for index, placement in first.Layout.Placements do
	assert(placement.Index == first.RoomPlan.Nodes[index].Index)
	assert(placement.RoomId == first.RoomPlan.Nodes[index].RoomId)
	assert(placement.RoleId == first.RoomPlan.Nodes[index].Role)
end

local malformedPlan = Generator.generateFromRoomPlan({ Seed = 777, Nodes = { { Index = 1 } } })
assert(not malformedPlan.Accepted and malformedPlan.ReasonId == "InvalidRoomPlan")

local invalidSeed = Generator.generate(0)
assert(not invalidSeed.Accepted and invalidSeed.ReasonId == "RoomAssemblyRejected")

local fractionalSeed = Generator.generate(1.5)
assert(not fractionalSeed.Accepted and fractionalSeed.ReasonId == "RoomAssemblyRejected")

print("ProceduralInstanceGenerator: current assembler -> planner -> validator orchestration passed")
