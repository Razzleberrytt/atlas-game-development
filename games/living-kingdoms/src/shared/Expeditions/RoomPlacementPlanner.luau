--!strict

--[[
	Pure deterministic spatial resolution for an already-authored expedition room
	sequence. RoomSequenceAssembler owns which rooms exist and their gameplay order;
	this planner owns only where that canonical sequence lives in the instance.

	The route is a seeded, self-avoiding cardinal walk. Generation is bounded and
	falls back to a deterministic straight route if every authored attempt fails.
	No Roblox services, scene instances, or hidden randomness are used here.
]]

local ROOM_LENGTH = 64
local ROOM_WIDTH = 48
local ROOM_HEIGHT = 20
local CONNECTOR_GAP = 8
local DOORWAY_WIDTH = 10
local GRID_STEP = math.max(ROOM_LENGTH, ROOM_WIDTH) + CONNECTOR_GAP
local MAX_GENERATION_ATTEMPTS = 16
local LAYOUT_VERSION = 2

local MODULUS = 2_147_483_647
local MULTIPLIER = 48_271
local ATTEMPT_OFFSET = 104_729

local DIRECTION_IDS = table.freeze({ "North", "East", "South", "West" })
local DIRECTIONS = table.freeze({
	North = table.freeze({ x = 0, z = -1 }),
	East = table.freeze({ x = 1, z = 0 }),
	South = table.freeze({ x = 0, z = 1 }),
	West = table.freeze({ x = -1, z = 0 }),
})
local LEFT = table.freeze({ North = "West", West = "South", South = "East", East = "North" })
local RIGHT = table.freeze({ North = "East", East = "South", South = "West", West = "North" })
local OPPOSITE = table.freeze({ North = "South", South = "North", East = "West", West = "East" })

local Planner = {}

local function nextRandom(state: number): number
	return (state * MULTIPLIER) % MODULUS
end

local function stateForAttempt(seed: number, attempt: number): number
	local state = (seed + (attempt - 1) * ATTEMPT_OFFSET) % MODULUS
	if state < 1 then
		return 1
	end
	return state
end

local function gridKey(x: number, z: number): string
	return `{x}:{z}`
end

local function candidateOrder(headingId: string, state: number): ({ string }, number)
	local leftId = LEFT[headingId]
	local rightId = RIGHT[headingId]
	assert(leftId ~= nil and rightId ~= nil, "unknown dungeon heading")

	state = nextRandom(state)
	local routeRoll = state % 100
	state = nextRandom(state)
	local firstTurn = if state % 2 == 0 then leftId else rightId
	local secondTurn = if firstTurn == leftId then rightId else leftId

	if routeRoll < 55 then
		return { headingId, firstTurn, secondTurn }, state
	elseif routeRoll < 78 then
		return { leftId, headingId, rightId }, state
	end
	return { rightId, headingId, leftId }, state
end

local function generateAttempt(roomCount: number, seed: number, attempt: number): (any?, any?)
	local state = stateForAttempt(seed, attempt)
	state = nextRandom(state)
	local headingId = DIRECTION_IDS[(state % #DIRECTION_IDS) + 1]

	local positions = { { x = 0, z = 0 } }
	local moves = {}
	local occupied = { [gridKey(0, 0)] = true }

	for index = 2, roomCount do
		local order
		order, state = candidateOrder(headingId, state)
		local current = positions[index - 1]
		local selectedHeading = nil
		local selectedPosition = nil

		for _, candidateHeading in order do
			local direction = DIRECTIONS[candidateHeading]
			assert(direction ~= nil, "unknown dungeon direction")
			local candidate = {
				x = current.x + direction.x,
				z = current.z + direction.z,
			}
			if occupied[gridKey(candidate.x, candidate.z)] ~= true then
				selectedHeading = candidateHeading
				selectedPosition = candidate
				break
			end
		end

		if selectedHeading == nil or selectedPosition == nil then
			return nil, nil
		end

		headingId = selectedHeading
		positions[index] = selectedPosition
		moves[index - 1] = selectedHeading
		occupied[gridKey(selectedPosition.x, selectedPosition.z)] = true
	end

	return positions, moves
end

local function straightFallback(roomCount: number, seed: number): (any, any)
	local state = nextRandom(seed)
	local headingId = DIRECTION_IDS[(state % #DIRECTION_IDS) + 1]
	local direction = DIRECTIONS[headingId]
	assert(direction ~= nil, "fallback direction is missing")

	local positions = {}
	local moves = {}
	for index = 1, roomCount do
		positions[index] = {
			x = (index - 1) * direction.x,
			z = (index - 1) * direction.z,
		}
		if index < roomCount then
			moves[index] = headingId
		end
	end
	return positions, moves
end

local function generatePath(roomCount: number, seed: number): (any, any, number, boolean)
	for attempt = 1, MAX_GENERATION_ATTEMPTS do
		local positions, moves = generateAttempt(roomCount, seed, attempt)
		if positions ~= nil and moves ~= nil then
			return positions, moves, attempt, false
		end
	end

	local positions, moves = straightFallback(roomCount, seed)
	return positions, moves, MAX_GENERATION_ATTEMPTS + 1, true
end

local function doorwayPoint(centerX: number, centerZ: number, sideId: string): any
	local direction = DIRECTIONS[sideId]
	assert(direction ~= nil, "doorway side is invalid")
	local distance = if direction.x ~= 0 then ROOM_WIDTH / 2 else ROOM_LENGTH / 2
	return table.freeze({
		x = centerX + direction.x * distance,
		y = 4,
		z = centerZ + direction.z * distance,
	})
end

local function turnId(index: number, roomCount: number, moves: any): string
	if index == 1 or index == roomCount then
		return "Straight"
	end

	local incoming = moves[index - 1]
	local outgoing = moves[index]
	if outgoing == incoming then
		return "Straight"
	elseif LEFT[incoming] == outgoing then
		return "Left"
	elseif RIGHT[incoming] == outgoing then
		return "Right"
	end
	error("dungeon route attempted an unsupported U-turn")
end

function Planner.plan(roomPlan: any): any
	assert(type(roomPlan) == "table" and type(roomPlan.Nodes) == "table", "room plan is required")
	assert(#roomPlan.Nodes >= 2, "at least two rooms are required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0, "room plan seed must be an integer")
	assert(roomPlan.Seed >= 1 and roomPlan.Seed < MODULUS, "room plan seed is outside supported bounds")

	local positions, moves, generationAttempt, usedFallback = generatePath(#roomPlan.Nodes, roomPlan.Seed)
	local placements = {}
	for index, node in roomPlan.Nodes do
		assert(type(node) == "table" and node.Index == index, "room indices must be contiguous")
		assert(type(node.RoomId) == "string" and node.RoomId ~= "", "room identity is required")
		local roleId = node.Role or node.RoleId
		assert(type(roleId) == "string" and roleId ~= "", "room role is required")

		local gridCell = positions[index]
		local centerX = gridCell.x * GRID_STEP
		local centerZ = gridCell.z * GRID_STEP
		local entranceSide = if index == 1 then OPPOSITE[moves[1]] else OPPOSITE[moves[index - 1]]
		local exitSide = if index == #roomPlan.Nodes then moves[#moves] else moves[index]
		assert(entranceSide ~= nil and exitSide ~= nil, "room doorway direction is missing")

		table.insert(
			placements,
			table.freeze({
				Index = index,
				RoomId = node.RoomId,
				RoleId = roleId,
				GridCell = table.freeze({ x = gridCell.x, z = gridCell.z }),
				TurnId = turnId(index, #roomPlan.Nodes, moves),
				EntranceSide = entranceSide,
				ExitSide = exitSide,
				Center = table.freeze({ x = centerX, y = ROOM_HEIGHT / 2, z = centerZ }),
				Size = table.freeze({ x = ROOM_WIDTH, y = ROOM_HEIGHT, z = ROOM_LENGTH }),
				Entrance = doorwayPoint(centerX, centerZ, entranceSide),
				Exit = doorwayPoint(centerX, centerZ, exitSide),
			})
		)
	end

	local connectors = {}
	for index = 1, #placements - 1 do
		local from = placements[index]
		local to = placements[index + 1]
		local deltaX = to.Entrance.x - from.Exit.x
		local deltaZ = to.Entrance.z - from.Exit.z
		local isX = math.abs(deltaX) > 0.001
		local isZ = math.abs(deltaZ) > 0.001
		assert(isX ~= isZ, "connector endpoints must be cardinally aligned")
		local length = if isX then math.abs(deltaX) else math.abs(deltaZ)
		assert(length >= CONNECTOR_GAP, "connector gap is too small")

		table.insert(
			connectors,
			table.freeze({
				FromIndex = index,
				ToIndex = index + 1,
				FromRoomId = from.RoomId,
				ToRoomId = to.RoomId,
				Axis = if isX then "X" else "Z",
				Center = table.freeze({
					x = (from.Exit.x + to.Entrance.x) / 2,
					y = 0,
					z = (from.Exit.z + to.Entrance.z) / 2,
				}),
				Size = table.freeze({
					x = if isX then length else DOORWAY_WIDTH,
					y = 1,
					z = if isZ then length else DOORWAY_WIDTH,
				}),
				Length = length,
			})
		)
	end

	return table.freeze({
		Seed = roomPlan.Seed,
		LayoutVersion = LAYOUT_VERSION,
		GenerationAttempt = generationAttempt,
		MaximumGenerationAttempts = MAX_GENERATION_ATTEMPTS,
		UsedFallback = usedFallback,
		GridStep = GRID_STEP,
		RoomLength = ROOM_LENGTH,
		RoomWidth = ROOM_WIDTH,
		RoomHeight = ROOM_HEIGHT,
		DoorwayWidth = DOORWAY_WIDTH,
		Placements = table.freeze(placements),
		Connectors = table.freeze(connectors),
	})
end

return table.freeze(Planner)
