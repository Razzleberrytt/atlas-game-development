--!strict

local Planner = require("../src/shared/Expeditions/RoomPlacementPlanner")

local plan = {
	Seed = 777,
	Nodes = {
		{ Index = 1, RoomId = "entry", Role = "Entry" },
		{ Index = 2, RoomId = "combat-a", Role = "Combat" },
		{ Index = 3, RoomId = "boss", Role = "Boss" },
	},
}

local first = Planner.plan(plan)
local second = Planner.plan(plan)
assert(first.Seed == 777 and #first.Placements == 3 and #first.Connectors == 2)
assert(first.Placements[1].Center.z == second.Placements[1].Center.z)
assert(first.Placements[3].Exit.z == second.Placements[3].Exit.z)

for index, connector in first.Connectors do
	local from = first.Placements[index]
	local to = first.Placements[index + 1]
	assert(connector.FromIndex == index and connector.ToIndex == index + 1)
	assert(math.abs((to.Entrance.z - from.Exit.z) - connector.Length) < 0.001)
	assert(connector.Length > 0)
end

local badOk = pcall(function()
	Planner.plan({
		Seed = 1,
		Nodes = { { Index = 2, RoomId = "bad", Role = "Entry" }, { Index = 2, RoomId = "bad2", Role = "Boss" } },
	})
end)
assert(badOk == false)

print("RoomPlacementPlanner fixture passed")
