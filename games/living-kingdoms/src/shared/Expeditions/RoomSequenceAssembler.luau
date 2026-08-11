--!strict

--[[
	VS-0104 deterministic, pure room-sequence assembly.
	The same seed and configuration always produce the same connected linear plan.
	No Roblox services, scene instances, or hidden randomness are used here.
]]

local Contracts = require(script.Parent.RoomAssemblyContracts)
local Config = require(script.Parent.Parent.Config.RoomAssemblyConfig)

local RoleIds = Contracts.RoleIds

local MODULUS = 2_147_483_647
local MULTIPLIER = 48_271

local function nextRandom(state: number): number
	return (state * MULTIPLIER) % MODULUS
end

local function chooseWeighted(candidates: { any }, state: number): (any, number)
	local totalWeight = 0
	for _, candidate in candidates do
		totalWeight += candidate.Weight
	end
	assert(totalWeight > 0, "room candidate weight must be positive")

	local nextState = nextRandom(state)
	local roll = (nextState % totalWeight) + 1
	local cumulative = 0
	for _, candidate in candidates do
		cumulative += candidate.Weight
		if roll <= cumulative then
			return candidate, nextState
		end
	end

	error("weighted room selection failed")
end

local function candidatesFor(role: string, depth: number, usedIds: { [string]: boolean }): { any }
	local candidates = {}
	for _, definition in Config.Rooms do
		if
			definition.Role == role
			and depth >= definition.MinimumDepth
			and depth <= definition.MaximumDepth
			and (definition.AllowRepeats or not usedIds[definition.Id])
		then
			table.insert(candidates, definition)
		end
	end
	return candidates
end

local function singletonFor(role: string): any
	local result = nil
	for _, definition in Config.Rooms do
		if definition.Role == role then
			assert(result == nil, "singleton room role has multiple definitions")
			result = definition
		end
	end
	assert(result ~= nil, "singleton room role is missing")
	return result
end

local function appendNode(nodes: { any }, definition: any, depth: number)
	local index = #nodes + 1
	local previous = if index > 1 then index - 1 else nil
	local node = {
		Index = index,
		Depth = depth,
		RoomId = definition.Id,
		RoomVersion = definition.Version,
		Role = definition.Role,
		PreviousIndex = previous,
		NextIndex = nil,
	}
	if previous ~= nil then
		nodes[previous].NextIndex = index
	end
	table.insert(nodes, node)
end

local function planIdentity(seed: number, nodes: { any }): string
	local roomIdentities = {}
	for _, node in nodes do
		table.insert(roomIdentities, `{node.RoomId}@{node.RoomVersion}`)
	end

	return `{Config.DefinitionId}@{Config.DefinitionVersion}|config={Config.Version}|seed={seed}|rooms={table.concat(
		roomIdentities,
		","
	)}`
end

local RoomSequenceAssembler = {}

function RoomSequenceAssembler.assemble(seed: number): any
	assert(type(seed) == "number" and seed % 1 == 0, "room plan seed must be an integer")
	assert(seed >= 1 and seed < MODULUS, "room plan seed is outside supported bounds")

	local state = seed
	state = nextRandom(state)
	local variableRange = Config.Route.MaximumVariableRooms - Config.Route.MinimumVariableRooms + 1
	local variableRoomCount = Config.Route.MinimumVariableRooms + (state % variableRange)
	local traversalCount = variableRoomCount - Config.Route.RequiredCombatRooms

	local roleSequence = {}
	for _ = 1, Config.Route.RequiredCombatRooms do
		table.insert(roleSequence, RoleIds.Combat)
	end
	for _ = 1, traversalCount do
		table.insert(roleSequence, RoleIds.Traversal)
	end

	for index = #roleSequence, 2, -1 do
		state = nextRandom(state)
		local swapIndex = (state % index) + 1
		roleSequence[index], roleSequence[swapIndex] = roleSequence[swapIndex], roleSequence[index]
	end

	local nodes = {}
	local usedIds = {}
	local entry = singletonFor(RoleIds.Entry)
	appendNode(nodes, entry, 0)
	usedIds[entry.Id] = true

	for depth, role in roleSequence do
		local candidates = candidatesFor(role, depth, usedIds)
		assert(#candidates > 0, `no compatible {role} room exists at depth {depth}`)
		local selected
		selected, state = chooseWeighted(candidates, state)
		appendNode(nodes, selected, depth)
		usedIds[selected.Id] = true
	end

	local elite = singletonFor(RoleIds.Elite)
	appendNode(nodes, elite, #nodes)
	local eliteIndex = #nodes

	local boss = singletonFor(RoleIds.Boss)
	appendNode(nodes, boss, #nodes)
	local bossIndex = #nodes
	local identity = planIdentity(seed, nodes)

	return table.freeze({
		Seed = seed,
		DefinitionId = Config.DefinitionId,
		DefinitionVersion = Config.DefinitionVersion,
		ConfigVersion = Config.Version,
		PlanIdentity = identity,
		Nodes = table.freeze(nodes),
		EntryIndex = 1,
		EliteIndex = eliteIndex,
		BossIndex = bossIndex,
	})
end

return table.freeze(RoomSequenceAssembler)
