--!strict

-- Pure fail-closed invariant validation for generated expedition layouts. The
-- planner may propose a route; this module decides whether that route is safe for
-- the Roblox placement owner to materialize.

local EPSILON = 0.001
local MODULUS = 2_147_483_647
local LAYOUT_VERSION = 2
local MAX_GENERATION_ATTEMPTS = 16
local GRID_STEP = 72
local ROOM_LENGTH = 64
local ROOM_WIDTH = 48
local ROOM_HEIGHT = 20
local DOORWAY_WIDTH = 10

local OPPOSITE = table.freeze({ North = "South", South = "North", East = "West", West = "East" })
local LEFT = table.freeze({ North = "West", West = "South", South = "East", East = "North" })
local RIGHT = table.freeze({ North = "East", East = "South", South = "West", West = "North" })
local DIRECTIONS = table.freeze({
	North = table.freeze({ x = 0, z = -1 }),
	East = table.freeze({ x = 1, z = 0 }),
	South = table.freeze({ x = 0, z = 1 }),
	West = table.freeze({ x = -1, z = 0 }),
})

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

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isInteger(value: any): boolean
	return isFiniteNumber(value) and value % 1 == 0
end

local function almostEqual(a: number, b: number): boolean
	return math.abs(a - b) <= EPSILON
end

local function roleOf(node: any): any
	if type(node) ~= "table" then
		return nil
	end
	return node.Role or node.RoleId
end

local function validPoint(point: any): boolean
	return type(point) == "table"
		and isFiniteNumber(point.x)
		and isFiniteNumber(point.y)
		and isFiniteNumber(point.z)
end

local function validSize(size: any): boolean
	return validPoint(size) and size.x > 0 and size.y > 0 and size.z > 0
end

local function directionBetween(fromGrid: any, toGrid: any): string?
	if type(fromGrid) ~= "table" or type(toGrid) ~= "table" then
		return nil
	end
	if not isInteger(fromGrid.x) or not isInteger(fromGrid.z) or not isInteger(toGrid.x) or not isInteger(toGrid.z) then
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

local function expectedTurn(index: number, roomCount: number, placements: { any }): string?
	if index == 1 or index == roomCount then
		return "Straight"
	end
	local incoming = directionBetween(placements[index - 1].GridCell, placements[index].GridCell)
	local outgoing = directionBetween(placements[index].GridCell, placements[index + 1].GridCell)
	if incoming == nil or outgoing == nil then
		return nil
	end
	if incoming == outgoing then
		return "Straight"
	elseif LEFT[incoming] == outgoing then
		return "Left"
	elseif RIGHT[incoming] == outgoing then
		return "Right"
	end
	return nil
end

local function expectedDoorway(center: any, sideId: string): any?
	local direction = DIRECTIONS[sideId]
	if direction == nil then
		return nil
	end
	local distance = if direction.x ~= 0 then ROOM_WIDTH / 2 else ROOM_LENGTH / 2
	return {
		x = center.x + direction.x * distance,
		y = 4,
		z = center.z + direction.z * distance,
	}
end

local function pointsMatch(actual: any, expected: any): boolean
	return validPoint(actual)
		and validPoint(expected)
		and almostEqual(actual.x, expected.x)
		and almostEqual(actual.y, expected.y)
		and almostEqual(actual.z, expected.z)
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
	if not isInteger(roomPlan.Seed) or roomPlan.Seed < 1 or roomPlan.Seed >= MODULUS then
		return failure("InvalidRoomPlan", nil, nil, "room plan seed is outside supported bounds")
	end
	if type(layout) ~= "table" or type(layout.Placements) ~= "table" or type(layout.Connectors) ~= "table" then
		return failure("InvalidLayout", nil, nil, "layout placements/connectors are required")
	end
	if layout.Seed ~= roomPlan.Seed then
		return failure("SeedMismatch", nil, nil, "layout seed differs from room-plan seed")
	end
	if layout.LayoutVersion ~= LAYOUT_VERSION then
		return failure("LayoutVersionMismatch", nil, nil, "layout version is not supported")
	end
	if layout.GridStep ~= GRID_STEP
		or layout.RoomLength ~= ROOM_LENGTH
		or layout.RoomWidth ~= ROOM_WIDTH
		or layout.RoomHeight ~= ROOM_HEIGHT
		or layout.DoorwayWidth ~= DOORWAY_WIDTH
	then
		return failure("LayoutGeometryContractMismatch", nil, nil, "layout geometry metadata drifted")
	end
	if layout.MaximumGenerationAttempts ~= MAX_GENERATION_ATTEMPTS then
		return failure("GenerationBudgetMismatch", nil, nil, "layout generation budget drifted")
	end
	if not isInteger(layout.GenerationAttempt) or layout.GenerationAttempt < 1 then
		return failure("InvalidGenerationAttempt", nil, nil, "generation attempt must be a positive integer")
	end
	if type(layout.UsedFallback) ~= "boolean" then
		return failure("InvalidFallbackMetadata", nil, nil, "fallback metadata must be boolean")
	end
	if layout.UsedFallback then
		if layout.GenerationAttempt ~= MAX_GENERATION_ATTEMPTS + 1 then
			return failure("InvalidFallbackMetadata", nil, nil, "fallback must occur after the bounded attempt budget")
		end
	elseif layout.GenerationAttempt > MAX_GENERATION_ATTEMPTS then
		return failure("InvalidGenerationAttempt", nil, nil, "non-fallback generation exceeded the attempt budget")
	end
	if #layout.Placements ~= #roomPlan.Nodes then
		return failure("RoomCountMismatch", nil, nil, "layout room count differs from room plan")
	end
	if #layout.Connectors ~= #roomPlan.Nodes - 1 then
		return failure("ConnectorCountMismatch", nil, nil, "canonical route requires one connector between every room")
	end
	if roleOf(roomPlan.Nodes[1]) ~= "Entry" then
		return failure("MissingStartRoom", 1, nil, "first room must be Entry")
	end
	if roleOf(roomPlan.Nodes[#roomPlan.Nodes]) ~= "Boss" then
		return failure("MissingBossRoom", #roomPlan.Nodes, nil, "last room must be Boss")
	end

	local occupied: { [string]: number } = {}
	for index, placement in layout.Placements do
		local node = roomPlan.Nodes[index]
		if type(node) ~= "table" or node.Index ~= index or type(placement) ~= "table" or placement.Index ~= index then
			return failure("NonContiguousRoomIndex", index, nil, "room indices must match canonical sequence order")
		end
		if placement.RoomId ~= node.RoomId or placement.RoleId ~= roleOf(node) then
			return failure("RoomPlacementMismatch", index, nil, "placement identity differs from canonical room node")
		end
		if type(placement.GridCell) ~= "table"
			or not isInteger(placement.GridCell.x)
			or not isInteger(placement.GridCell.z)
		then
			return failure("InvalidGridCell", index, nil, "placement grid coordinates must be integers")
		end
		if not validPoint(placement.Center) or not validSize(placement.Size) then
			return failure("InvalidRoomGeometry", index, nil, "room center/size must contain finite positive geometry")
		end
		if not almostEqual(placement.Center.x, placement.GridCell.x * GRID_STEP)
			or not almostEqual(placement.Center.y, ROOM_HEIGHT / 2)
			or not almostEqual(placement.Center.z, placement.GridCell.z * GRID_STEP)
		then
			return failure("RoomCenterMismatch", index, nil, "room center must match its canonical grid cell")
		end
		if not almostEqual(placement.Size.x, ROOM_WIDTH)
			or not almostEqual(placement.Size.y, ROOM_HEIGHT)
			or not almostEqual(placement.Size.z, ROOM_LENGTH)
		then
			return failure("RoomSizeMismatch", index, nil, "room size must match the canonical spatial contract")
		end
		if OPPOSITE[placement.EntranceSide] == nil or OPPOSITE[placement.ExitSide] == nil then
			return failure("InvalidDoorSocket", index, nil, "entrance/exit sides must be cardinal")
		end
		if placement.EntranceSide == placement.ExitSide then
			return failure("InvalidDoorSocket", index, nil, "room cannot enter and exit through the same socket")
		end
		local expectedEntrance = expectedDoorway(placement.Center, placement.EntranceSide)
		local expectedExit = expectedDoorway(placement.Center, placement.ExitSide)
		if expectedEntrance == nil or not pointsMatch(placement.Entrance, expectedEntrance) then
			return failure("DoorwayGeometryMismatch", index, nil, "entrance point does not match its authored side")
		end
		if expectedExit == nil or not pointsMatch(placement.Exit, expectedExit) then
			return failure("DoorwayGeometryMismatch", index, nil, "exit point does not match its authored side")
		end

		local cellKey = `{placement.GridCell.x}:{placement.GridCell.z}`
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

	for index, placement in layout.Placements do
		local turn = expectedTurn(index, #layout.Placements, layout.Placements)
		if turn == nil then
			return failure("InvalidGridConnection", index, nil, "canonical neighbors must be cardinal and cannot U-turn")
		end
		if placement.TurnId ~= turn then
			return failure("TurnMetadataMismatch", index, nil, "turn metadata differs from neighboring room cells")
		end
	end

	for index, connector in layout.Connectors do
		local from = layout.Placements[index]
		local to = layout.Placements[index + 1]
		if type(connector) ~= "table" or connector.FromIndex ~= index or connector.ToIndex ~= index + 1 then
			return failure("InvalidConnectorOrder", nil, index, "connector must preserve canonical room order")
		end
		if connector.FromRoomId ~= from.RoomId or connector.ToRoomId ~= to.RoomId then
			return failure("ConnectorIdentityMismatch", nil, index, "connector room identities differ from canonical order")
		end
		local direction = directionBetween(from.GridCell, to.GridCell)
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
		if expectedLength <= EPSILON then
			return failure("ConnectorTooShort", nil, index, "connector must have positive length")
		end
		if connector.Axis ~= expectedAxis or not isFiniteNumber(connector.Length) or not almostEqual(connector.Length, expectedLength) then
			return failure("ConnectorGeometryMismatch", nil, index, "connector axis/length does not match sockets")
		end
		if not validPoint(connector.Center) or not validSize(connector.Size) then
			return failure("ConnectorGeometryMismatch", nil, index, "connector center/size must contain finite geometry")
		end
		if not almostEqual(connector.Center.x, (from.Exit.x + to.Entrance.x) / 2)
			or not almostEqual(connector.Center.y, 0)
			or not almostEqual(connector.Center.z, (from.Exit.z + to.Entrance.z) / 2)
		then
			return failure("ConnectorCenterMismatch", nil, index, "connector center must bisect its two sockets")
		end
		local expectedSizeX = if isX then expectedLength else DOORWAY_WIDTH
		local expectedSizeZ = if isZ then expectedLength else DOORWAY_WIDTH
		if not almostEqual(connector.Size.x, expectedSizeX)
			or not almostEqual(connector.Size.y, 1)
			or not almostEqual(connector.Size.z, expectedSizeZ)
		then
			return failure("ConnectorGeometryMismatch", nil, index, "connector size does not match its axis and sockets")
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
