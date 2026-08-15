--!strict

-- Pure invariant validation for generated expedition layouts. The planner may
-- choose a route, but this module decides whether that route is safe to spawn.

local EPSILON = 0.001
local OPPOSITE = table.freeze({ North = "South", South = "North", East = "West", West = "East" })

local Validator = {}

local function failure(reasonId: string, roomIndex: number?, connectorIndex: number?, detail: string?): any
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		RoomIndex = roomIndex,
		ConnectorIndex = connectorIndex,
		Detail = detail,
	})
end

local function roleOf(node: any): any
	return node.Role or node.RoleId
end

local function directionBetween(fromGrid: any, toGrid: any): string?
	if type(fromGrid) ~= "table" or type(toGrid) ~= "table" then
		return nil
	end
	local dx = toGrid.x - fromGrid.x
	local dz = toGrid.z - fromGrid.z
	if dx == 1 and dz == 0 then
		return "East"
	elseif dx == -1 and dz == 0 then
		return "West"
	elseif dx == 0 and dz == 1 then
		return "South"
	elseif dx == 0 and dz == -1 then
		return "North"
	end
	return nil
end

local function roomsOverlap(a: any, b: any): boolean
	local dx = math.abs(a.Center.x - b.Center.x)
	local dz = math.abs(a.Center.z - b.Center.z)
	local requiredX = (a.Size.x + b.Size.x) / 2
	local requiredZ = (a.Size.z + b.Size.z) / 2
	return dx < requiredX - EPSILON and dz < requiredZ - EPSILON
end

function Validator.validate(roomPlan: any, layout: any): any
	if type(roomPlan) ~= "table" or type(roomPlan.Nodes) ~= "table" or #roomPlan.Nodes < 2 then
		return failure("InvalidRoomPlan", nil, nil, "room plan requires at least two nodes")
	end
	if type(layout) ~= "table" or type(layout.Placements) ~= "table" or type(layout.Connectors) ~= "table" then
		return failure("InvalidLayout", nil, nil, "layout placements/connectors are required")
	end
	if layout.Seed ~= roomPlan.Seed then
		return failure("SeedMismatch", nil, nil, "layout seed differs from room-plan seed")
	end
	if #layout.Placements ~= #roomPlan.Nodes then
		return failure("RoomCountMismatch", nil, nil, "layout room count differs from room plan")
	end
	if #layout.Connectors ~= #roomPlan.Nodes - 1 then
		return failure("ConnectorCountMismatch", nil, nil, "linear route requires one connector between every room")
	end
	if roleOf(roomPlan.Nodes[1]) ~= "Entry" then
		return failure("MissingStartRoom", 1, nil, "first room must be Entry")
	end
	if roleOf(roomPlan.Nodes[#roomPlan.Nodes]) ~= "Boss" then
		return failure("MissingBossRoom", #roomPlan.Nodes, nil, "last room must be Boss")
	end

	local occupied = {}
	for index, placement in layout.Placements do
		local node = roomPlan.Nodes[index]
		if node == nil or node.Index ~= index or placement.Index ~= index then
			return failure("NonContiguousRoomIndex", index, nil, "room indices must match canonical sequence order")
		end
		if placement.RoomId ~= node.RoomId or placement.RoleId ~= roleOf(node) then
			return failure("RoomPlacementMismatch", index, nil, "placement identity differs from canonical room node")
		end
		if
			type(placement.Grid) ~= "table"
			or type(placement.Grid.x) ~= "number"
			or type(placement.Grid.z) ~= "number"
		then
			return failure("InvalidGridCell", index, nil, "placement grid coordinates are required")
		end
		if placement.Grid.x % 1 ~= 0 or placement.Grid.z % 1 ~= 0 then
			return failure("InvalidGridCell", index, nil, "placement grid coordinates must be integers")
		end
		if OPPOSITE[placement.EntranceSide] == nil or OPPOSITE[placement.ExitSide] == nil then
			return failure("InvalidDoorSocket", index, nil, "entrance/exit sides must be cardinal")
		end
		if placement.EntranceSide == placement.ExitSide then
			return failure("InvalidDoorSocket", index, nil, "room cannot enter and exit through the same socket")
		end

		local cellKey = `{placement.Grid.x}:{placement.Grid.z}`
		if occupied[cellKey] ~= nil then
			return failure("DuplicateGridCell", index, nil, `grid cell already occupied by room {occupied[cellKey]}`)
		end
		occupied[cellKey] = index

		for previousIndex = 1, index - 1 do
			if roomsOverlap(placement, layout.Placements[previousIndex]) then
				return failure("RoomOverlap", index, nil, `room overlaps room {previousIndex}`)
			end
		end
	end

	for index, connector in layout.Connectors do
		local from = layout.Placements[index]
		local to = layout.Placements[index + 1]
		if connector.FromIndex ~= index or connector.ToIndex ~= index + 1 then
			return failure("InvalidConnectorOrder", nil, index, "connector must preserve canonical room order")
		end
		local direction = directionBetween(from.Grid, to.Grid)
		if direction == nil then
			return failure("InvalidGridConnection", nil, index, "adjacent rooms must occupy cardinal neighboring cells")
		end
		if from.ExitSide ~= direction or to.EntranceSide ~= OPPOSITE[direction] then
			return failure("SocketDirectionMismatch", nil, index, "door sockets do not face their connecting room")
		end

		local deltaX = to.Entrance.x - from.Exit.x
		local deltaZ = to.Entrance.z - from.Exit.z
		local isX = math.abs(deltaX) > EPSILON
		local isZ = math.abs(deltaZ) > EPSILON
		if isX == isZ then
			return failure("ConnectorNotCardinal", nil, index, "connector endpoints must align on exactly one axis")
		end
		local expectedAxis = if isX then "X" else "Z"
		local expectedLength = if isX then math.abs(deltaX) else math.abs(deltaZ)
		if connector.Axis ~= expectedAxis or math.abs(connector.Length - expectedLength) > EPSILON then
			return failure("ConnectorGeometryMismatch", nil, index, "connector axis/length does not match sockets")
		end
		if expectedLength <= EPSILON then
			return failure("ConnectorTooShort", nil, index, "connector must have positive length")
		end
		if
			math.abs(connector.Center.x - (from.Exit.x + to.Entrance.x) / 2) > EPSILON
			or math.abs(connector.Center.z - (from.Exit.z + to.Entrance.z) / 2) > EPSILON
		then
			return failure("ConnectorCenterMismatch", nil, index, "connector center must bisect its two sockets")
		end
	end

	return table.freeze({
		Accepted = true,
		ReasonId = "LayoutValid",
		RoomIndex = nil,
		ConnectorIndex = nil,
		Detail = nil,
		ValidatedRoomCount = #layout.Placements,
		ValidatedConnectorCount = #layout.Connectors,
	})
end

return table.freeze(Validator)
