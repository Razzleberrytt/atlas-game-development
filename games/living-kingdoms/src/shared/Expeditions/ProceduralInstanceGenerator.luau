--!strict

--[[
	Reusable deterministic procedural-instance foundation.

	The room assembler owns content order. RoomPlacementPlanner owns seeded spatial
	variation. InstanceLayoutValidator is the fail-closed gate. This module only
	orchestrates those existing owners and exposes stable metadata hooks that
	server encounter/reward systems can consume later.
]]

local RoomSequenceAssembler = require(script.Parent.RoomSequenceAssembler)
local RoomPlacementPlanner = require(script.Parent.RoomPlacementPlanner)
local InstanceLayoutValidator = require(script.Parent.InstanceLayoutValidator)

export type GenerationOptions = {
	VariableRoomCount: number?,
}

local SOCKET_PROFILE_ID = "CardinalDoorway10-v1"
local SPAWN_OFFSETS = table.freeze({
	table.freeze({ x = -12, z = -8 }),
	table.freeze({ x = 12, z = -8 }),
	table.freeze({ x = -12, z = 8 }),
	table.freeze({ x = 12, z = 8 }),
	table.freeze({ x = 0, z = 12 }),
})

local Generator = {}

local function failure(reasonId: string, seed: any, planIdentity: any, detail: string?, validation: any?): any
	local reproductionKey = if type(seed) == "number"
		then `seed={seed}|plan={if type(planIdentity) == "string" then planIdentity else "unknown"}`
		else "seed=invalid|plan=unknown"
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		Seed = seed,
		PlanIdentity = planIdentity,
		ReproductionKey = reproductionKey,
		RoomCount = 0,
		RoomPlan = nil,
		Layout = nil,
		Rooms = nil,
		Validation = validation,
		Debug = detail,
	})
end

local function point(id: string, kind: string, x: number, y: number, z: number, tags: { string }): any
	return table.freeze({
		Id = id,
		Kind = kind,
		Position = table.freeze({ x = x, y = y, z = z }),
		Tags = table.freeze(tags),
	})
end

local function spawnMetadata(node: any, placement: any): any
	local points = {}
	local floorY = placement.Center.y - placement.Size.y / 2 + 1
	if (node.Role or node.RoleId) == "Entry" then
		table.insert(
			points,
			point("party-start", "Player", placement.Center.x, floorY, placement.Center.z, { "party", "start" })
		)
		return table.freeze(points)
	end

	if (node.Role or node.RoleId) == "Boss" then
		table.insert(
			points,
			point("boss-primary", "Boss", placement.Center.x, floorY, placement.Center.z + 8, { "boss", "primary" })
		)
	end

	if node.EncounterSlotId == nil or node.EncounterSlotId == "None" or (node.EncounterIntensity or 0) <= 0 then
		return table.freeze(points)
	end

	local spawnCount = math.clamp((node.EncounterIntensity or 1) + 1, 1, #SPAWN_OFFSETS)
	for index = 1, spawnCount do
		local offset = SPAWN_OFFSETS[index]
		table.insert(
			points,
			point(
				`enemy-{index}`,
				"Enemy",
				placement.Center.x + offset.x,
				floorY,
				placement.Center.z + offset.z,
				{ "encounter", string.lower(tostring(node.EncounterSlotId)) }
			)
		)
	end
	return table.freeze(points)
end

local function generatedRooms(roomPlan: any, layout: any): any
	local rooms = {}
	for index, node in roomPlan.Nodes do
		local placement = layout.Placements[index]
		local spawnPoints = spawnMetadata(node, placement)
		table.insert(
			rooms,
			table.freeze({
				Index = index,
				RoomId = node.RoomId,
				ModuleVersion = node.RoomVersion,
				RoleId = node.Role or node.RoleId,
				SocketProfileId = SOCKET_PROFILE_ID,
				Placement = placement,
				EncounterSlotId = node.EncounterSlotId,
				EncounterIntensity = node.EncounterIntensity or 0,
				SpawnPoints = spawnPoints,
				RewardSourceId = node.RewardSourceId,
				CompletionHookId = `room-complete:{index}:{node.RoomId}`,
			})
		)
	end
	return table.freeze(rooms)
end

function Generator.generateFromRoomPlan(roomPlan: any): any
	if type(roomPlan) ~= "table" or type(roomPlan.Nodes) ~= "table" then
		return failure(
			"InvalidRoomPlan",
			if type(roomPlan) == "table" then roomPlan.Seed else nil,
			nil,
			"room plan table is required"
		)
	end

	local ok, layoutOrError = pcall(RoomPlacementPlanner.plan, roomPlan)
	if not ok then
		return failure("LayoutPlanningFailed", roomPlan.Seed, roomPlan.PlanIdentity, tostring(layoutOrError))
	end
	local layout = layoutOrError
	local validation = InstanceLayoutValidator.validate(roomPlan, layout)
	if validation.Accepted ~= true then
		return failure(validation.ReasonId, roomPlan.Seed, roomPlan.PlanIdentity, validation.Detail, validation)
	end

	local planIdentity = if type(roomPlan.PlanIdentity) == "string"
		then roomPlan.PlanIdentity
		else `seed={roomPlan.Seed}`
	local reproductionKey = `seed={roomPlan.Seed}|plan={planIdentity}|layout={layout.LayoutVersion}`
	local rooms = generatedRooms(roomPlan, layout)
	return table.freeze({
		Accepted = true,
		ReasonId = "InstanceGenerated",
		Seed = roomPlan.Seed,
		PlanIdentity = planIdentity,
		ReproductionKey = reproductionKey,
		RoomCount = #rooms,
		RoomPlan = roomPlan,
		Layout = layout,
		Rooms = rooms,
		Validation = validation,
		Debug = table.freeze({
			LayoutVersion = layout.LayoutVersion,
			GenerationAttempt = layout.GenerationAttempt,
			UsedFallback = layout.UsedFallback,
		}),
	})
end

function Generator.generate(seed: number, options: GenerationOptions?): any
	local ok, roomPlanOrError = pcall(RoomSequenceAssembler.assemble, seed, options)
	if not ok then
		return failure("RoomAssemblyFailed", seed, nil, tostring(roomPlanOrError))
	end
	return Generator.generateFromRoomPlan(roomPlanOrError)
end

return table.freeze(Generator)
