--!strict

--[[
	VS-0110 server-owned composition root for the first expedition.

	This module composes the authoritative runtime, deterministic room plan,
	encounter coordinator, and existing enemy director adapter. It exposes no
	client remotes. Callers tick it from one bounded server loop and may read only
	sanitized snapshots for presentation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)
local RoomSequenceAssembler = require(ReplicatedStorage.Shared.Expeditions.RoomSequenceAssembler)
local ExpeditionRuntime = require(script.Parent.ExpeditionRuntime)
local ExpeditionEncounterCoordinator = require(script.Parent.ExpeditionEncounterCoordinator)
local EnemyDirectorEncounterAdapter = require(script.Parent.EnemyDirectorEncounterAdapter)

export type EnemyDirector = EnemyDirectorEncounterAdapter.Director
export type ExpeditionSnapshot = any

export type StartParameters = {
	RunId: string,
	Seed: number,
	PartySize: number,
	StartedAtUnix: number,
}

export type Service = {
	step: (self: Service, nowUnix: number) -> { Accepted: boolean, ReasonId: string },
	getSnapshot: (self: Service) -> ExpeditionSnapshot?,
	getRoomPlan: (self: Service) -> any,
	destroy: (self: Service) -> (),
}

type Internal = {
	Runtime: any,
	Coordinator: any,
	CombatAdapter: any,
	TraversalAdapter: any,
	RoomPlan: any,
	Destroyed: boolean,
}

local Bootstrap = {}
Bootstrap.__index = Bootstrap

local function result(accepted: boolean, reasonId: string)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId })
end

local function normalizedPlan(plan: any): any
	local nodes = {}
	for _, node in plan.Nodes do
		table.insert(nodes, table.freeze({
			Index = node.Index,
			RoomId = node.RoomId,
			RoleId = node.Role,
		}))
	end
	return table.freeze({ Seed = plan.Seed, Nodes = table.freeze(nodes) })
end

local function deterministicOffset(seed: number, ordinal: number): (number, number)
	local value = (seed * 48_271 + ordinal * 7_919) % 2_147_483_647
	local x = ((value % 17) - 8) * 6
	local z = ((math.floor(value / 17) % 11) - 5) * 6
	return x, z
end

local function resolveEncounter(context: any): any
	if context.PhaseId == "Boss" then
		return {
			Kind = "Boss",
			BossPosition = { x = 0, y = 4, z = 120 },
			FloodlightsRestored = true,
		}
	end

	local count = if context.PhaseId == "Elite" then 1 elseif context.PhaseId == "Approach" then 2 else 3
	local wave = {}
	for ordinal = 1, count do
		local x, z = deterministicOffset(context.Seed, ordinal + (context.RoomIndex or 0) * 5)
		table.insert(wave, {
			id = string.format("%s:enemy:%d", context.Token, ordinal),
			name = if context.PhaseId == "Elite" then "Warden Elite" else "Warden",
			x = x,
			y = 4,
			z = z + if context.PhaseId == "Approach" then 24 else 64,
		})
	end
	return {
		Kind = "Wave",
		WaveIndex = context.RoomIndex or (if context.PhaseId == "Elite" then 90 else 1),
		Wave = wave,
	}
end

local function passiveTraversalAdapter()
	local activeToken: string? = nil
	return {
		start = function(context: any): boolean
			if activeToken ~= nil then return false end
			activeToken = context.Token
			return true
		end,
		cancel = function(context: any, _reasonId: string)
			if activeToken == context.Token then activeToken = nil end
		end,
		pollCompletion = function(): (boolean, string?)
			if activeToken == nil then return false, "NoActiveEncounter" end
			return true, activeToken
		end,
	}
end

function Bootstrap.new(director: EnemyDirector, parameters: StartParameters): Service
	local definition = ExpeditionConfig.Definitions.FirstExpedition
	local runtime = ExpeditionRuntime.new(definition, parameters)
	local rawPlan = RoomSequenceAssembler.assemble(parameters.Seed)
	local plan = normalizedPlan(rawPlan)
	local combatAdapter = EnemyDirectorEncounterAdapter.new(director, resolveEncounter)
	local traversalAdapter = passiveTraversalAdapter()

	local coordinator = ExpeditionEncounterCoordinator.new(runtime, plan, {
		Approach = combatAdapter,
		DungeonTraversal = traversalAdapter,
		DungeonCombat = combatAdapter,
		Elite = combatAdapter,
		Boss = combatAdapter,
	})

	return setmetatable({
		Runtime = runtime,
		Coordinator = coordinator,
		CombatAdapter = combatAdapter,
		TraversalAdapter = traversalAdapter,
		RoomPlan = rawPlan,
		Destroyed = false,
	} :: Internal, Bootstrap) :: any
end

function Bootstrap:step(nowUnix: number)
	local state: Internal = self :: any
	if state.Destroyed then return result(false, "BootstrapDestroyed") end
	if type(nowUnix) ~= "number" or nowUnix < 0 then return result(false, "InvalidTimestamp") end

	local active = state.Coordinator:getActiveContext()
	if active ~= nil then
		local adapter = if active.RoomRoleId == "Traversal" then state.TraversalAdapter else state.CombatAdapter
		local completed, token = adapter:pollCompletion()
		if completed and token ~= nil then
			local completion = state.Coordinator:completeActive(token, nowUnix)
			adapter.cancel(active, "EncounterCompleted")
			if completion.Accepted ~= true then
				return result(false, completion.ReasonId)
			end
			return result(true, completion.ReasonId)
		end
		return result(false, "EncounterInProgress")
	end

	local sync = state.Coordinator:sync(nowUnix)
	return result(sync.Accepted == true, sync.ReasonId)
end

function Bootstrap:getSnapshot(): ExpeditionSnapshot?
	local state: Internal = self :: any
	if state.Destroyed then return nil end
	return state.Runtime:getSnapshot()
end

function Bootstrap:getRoomPlan(): any
	local state: Internal = self :: any
	if state.Destroyed then return nil end
	return state.RoomPlan
end

function Bootstrap:destroy()
	local state: Internal = self :: any
	if state.Destroyed then return end
	state.Destroyed = true
	state.Coordinator:destroy()
	state.CombatAdapter:destroy()
	state.Runtime:destroy()
end

return table.freeze(Bootstrap)
