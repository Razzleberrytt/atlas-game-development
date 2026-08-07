--!strict

-- Pure deterministic layout plan for the first expedition graybox.
-- Every room uses a north/south connector pair and is placed on one linear axis.

local ROOM_LENGTH = 64
local ROOM_WIDTH = 48
local ROOM_HEIGHT = 20
local CONNECTOR_GAP = 8
local STEP = ROOM_LENGTH + CONNECTOR_GAP

local Planner = {}

function Planner.plan(roomPlan: any): any
	assert(type(roomPlan) == "table" and type(roomPlan.Nodes) == "table", "room plan is required")
	assert(#roomPlan.Nodes >= 2, "at least two rooms are required")

	local placements = {}
	for index, node in roomPlan.Nodes do
		assert(node.Index == index, "room indices must be contiguous")
		local centerZ = (index - 1) * STEP
		table.insert(
			placements,
			table.freeze({
				Index = index,
				RoomId = node.RoomId,
				RoleId = node.Role or node.RoleId,
				Center = table.freeze({ x = 0, y = ROOM_HEIGHT / 2, z = centerZ }),
				Size = table.freeze({ x = ROOM_WIDTH, y = ROOM_HEIGHT, z = ROOM_LENGTH }),
				Entrance = table.freeze({ x = 0, y = 4, z = centerZ - ROOM_LENGTH / 2 }),
				Exit = table.freeze({ x = 0, y = 4, z = centerZ + ROOM_LENGTH / 2 }),
			})
		)
	end

	local connectors = {}
	for index = 1, #placements - 1 do
		local from = placements[index]
		local to = placements[index + 1]
		local gap = to.Entrance.z - from.Exit.z
		assert(math.abs(gap - CONNECTOR_GAP) < 0.001, "connector gap drifted")
		table.insert(
			connectors,
			table.freeze({
				FromIndex = index,
				ToIndex = index + 1,
				Center = table.freeze({ x = 0, y = 4, z = from.Exit.z + gap / 2 }),
				Length = gap,
			})
		)
	end

	return table.freeze({
		Seed = roomPlan.Seed,
		RoomLength = ROOM_LENGTH,
		RoomWidth = ROOM_WIDTH,
		RoomHeight = ROOM_HEIGHT,
		Placements = table.freeze(placements),
		Connectors = table.freeze(connectors),
	})
end

return table.freeze(Planner)
