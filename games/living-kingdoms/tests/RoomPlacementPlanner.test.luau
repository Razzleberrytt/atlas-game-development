--!strict

local Planner = require("../src/shared/Expeditions/RoomPlacementPlanner")

local function planFor(seed: number, roomCount: number): any
	local nodes = {}
	for index = 1, roomCount do
		table.insert(nodes, {
			Index = index,
			RoomId = `room-{index}`,
			Role = if index == 1 then "Entry" elseif index == roomCount then "Boss" else "Traversal",
		})
	end
	return { Seed = seed, Nodes = nodes }
end

local function signature(layout: any): string
	local cells = {}
	for _, placement in layout.Placements do
		table.insert(cells, `{placement.GridCell.x}:{placement.GridCell.z}:{placement.TurnId}`)
	end
	return table.concat(cells, "|")
end

local plan = planFor(777, 8)
local first = Planner.plan(plan)
local second = Planner.plan(plan)
assert(first.Seed == 777 and first.LayoutVersion == 2)
assert(#first.Placements == 8 and #first.Connectors == 7)
assert(signature(first) == signature(second), "same seed must reproduce the exact spatial route")
assert(first.GenerationAttempt == second.GenerationAttempt and first.UsedFallback == second.UsedFallback)

local different = Planner.plan(planFor(778, 8))
assert(signature(different) ~= signature(first), "different seeds must demonstrate deterministic spatial variation")

local occupied = {}
for index, placement in first.Placements do
	assert(placement.Index == index and placement.RoomId == plan.Nodes[index].RoomId)
	assert(placement.GridCell.x % 1 == 0 and placement.GridCell.z % 1 == 0)
	local key = `{placement.GridCell.x}:{placement.GridCell.z}`
	assert(not occupied[key], "rooms must occupy unique cells")
	occupied[key] = true
	assert(placement.TurnId == "Straight" or placement.TurnId == "Left" or placement.TurnId == "Right")
	assert(placement.EntranceSide ~= placement.ExitSide)
end

for index, connector in first.Connectors do
	local from = first.Placements[index]
	local to = first.Placements[index + 1]
	local dx = to.GridCell.x - from.GridCell.x
	local dz = to.GridCell.z - from.GridCell.z
	assert(math.abs(dx) + math.abs(dz) == 1, "sequence neighbors must be cardinal grid neighbors")
	assert(connector.FromIndex == index and connector.ToIndex == index + 1)
	assert(connector.FromRoomId == from.RoomId and connector.ToRoomId == to.RoomId)
	if dx ~= 0 then
		assert(connector.Axis == "X" and connector.Size.x == 24 and connector.Size.z == 10)
	else
		assert(connector.Axis == "Z" and connector.Size.x == 10 and connector.Size.z == 8)
	end
	assert(connector.Length > 0)
end

-- Seed 246 with 100 cells deterministically exhausts all 16 self-avoiding
-- attempts under this planner and therefore proves the bounded fallback path is
-- executable rather than merely documented.
local fallback = Planner.plan(planFor(246, 100))
assert(fallback.UsedFallback == true, "stress fixture must exercise deterministic fallback")
assert(fallback.GenerationAttempt == fallback.MaximumGenerationAttempts + 1)
assert(#fallback.Placements == 100 and #fallback.Connectors == 99)
for index = 2, #fallback.Placements do
	local previous = fallback.Placements[index - 1].GridCell
	local current = fallback.Placements[index].GridCell
	assert(math.abs(current.x - previous.x) + math.abs(current.z - previous.z) == 1)
end

local badOk = pcall(function()
	Planner.plan({
		Seed = 1,
		Nodes = { { Index = 2, RoomId = "bad", Role = "Entry" }, { Index = 2, RoomId = "bad2", Role = "Boss" } },
	})
end)
assert(badOk == false)

print("RoomPlacementPlanner: deterministic cardinal variation, uniqueness, geometry, and fallback passed")
