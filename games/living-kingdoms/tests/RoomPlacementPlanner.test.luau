--!strict

local Planner = require("../src/shared/Expeditions/RoomPlacementPlanner")

local function signature(layout: any): string
	local cells = {}
	for _, placement in layout.Placements do
		table.insert(cells, `{placement.Grid.x}:{placement.Grid.z}:{placement.EntranceSide}:{placement.ExitSide}`)
	end
	return table.concat(cells, "|")
end

local function sevenRoomPlan(seed: number): any
	return {
		Seed = seed,
		Nodes = {
			{ Index = 1, RoomId = "entry", Role = "Entry" },
			{ Index = 2, RoomId = "traversal-a", Role = "Traversal" },
			{ Index = 3, RoomId = "combat-a", Role = "Combat" },
			{ Index = 4, RoomId = "traversal-b", Role = "Traversal" },
			{ Index = 5, RoomId = "combat-b", Role = "Combat" },
			{ Index = 6, RoomId = "elite", Role = "Elite" },
			{ Index = 7, RoomId = "boss", Role = "Boss" },
		},
	}
end

local first = Planner.plan(sevenRoomPlan(42))
local replay = Planner.plan(sevenRoomPlan(42))
local different = Planner.plan(sevenRoomPlan(43))

assert(first.LayoutVersion == "rng-grid-v1")
assert(first.Seed == 42 and #first.Placements == 7 and #first.Connectors == 6)
assert(first.UsedFallback == false)
assert(signature(first) == signature(replay))
assert(signature(first) ~= signature(different))

local occupied = {}
local sawTurn = false
for index, placement in first.Placements do
	assert(placement.Index == index)
	local key = `{placement.Grid.x}:{placement.Grid.z}`
	assert(occupied[key] == nil)
	occupied[key] = true
	if placement.TurnId == "Left" or placement.TurnId == "Right" then
		sawTurn = true
	end
end
assert(sawTurn == true)

for index, connector in first.Connectors do
	local from = first.Placements[index]
	local to = first.Placements[index + 1]
	assert(connector.FromIndex == index and connector.ToIndex == index + 1)
	assert(connector.Length > 0)
	assert(connector.Axis == "X" or connector.Axis == "Z")

	local deltaX = to.Entrance.x - from.Exit.x
	local deltaZ = to.Entrance.z - from.Exit.z
	if connector.Axis == "X" then
		assert(math.abs(deltaZ) < 0.001)
		assert(math.abs(connector.Size.x - math.abs(deltaX)) < 0.001)
		assert(connector.Size.z == 8)
	else
		assert(math.abs(deltaX) < 0.001)
		assert(math.abs(connector.Size.z - math.abs(deltaZ)) < 0.001)
		assert(connector.Size.x == 8)
	end
end

local tiny = Planner.plan({
	Seed = 5,
	Nodes = {
		{ Index = 1, RoomId = "entry", Role = "Entry" },
		{ Index = 2, RoomId = "boss", Role = "Boss" },
	},
})
assert(#tiny.Placements == 2 and #tiny.Connectors == 1)
assert(tiny.Placements[1].EntranceSide ~= tiny.Placements[1].ExitSide)
assert(tiny.Placements[2].EntranceSide ~= tiny.Placements[2].ExitSide)

local badOk = pcall(function()
	Planner.plan({
		Seed = 1,
		Nodes = { { Index = 2, RoomId = "bad", Role = "Entry" }, { Index = 2, RoomId = "bad2", Role = "Boss" } },
	})
end)
assert(badOk == false)

print("RoomPlacementPlanner RNG dungeon fixture passed")
