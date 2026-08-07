--!strict

--[[
	VS-0105 server-owned bridge between expedition lifecycle and encounter owners.

	The coordinator does not trust clients and exposes no remote-facing completion
	path. Existing authoritative systems are injected as narrow adapters. Each
	active encounter receives a unique token, may complete exactly once, and may
	advance only the phase/room that originally started it.
]]

export type ExpeditionSnapshot = {
	RunId: string,
	PhaseId: string,
	PhaseIndex: number,
	PhaseStartedAtUnix: number,
	OutcomeId: string,
}

export type Runtime = {
	getSnapshot: (self: Runtime) -> ExpeditionSnapshot?,
	advancePhase: (self: Runtime, expectedPhaseId: string, nowUnix: number) -> any,
}

export type RoomNode = {
	Index: number,
	RoomId: string,
	RoleId: string,
}

export type RoomPlan = {
	Seed: number,
	Nodes: { RoomNode },
}

export type EncounterContext = {
	Token: string,
	RunId: string,
	PhaseId: string,
	RoomIndex: number?,
	RoomId: string?,
	RoomRoleId: string?,
	Seed: number,
}

export type EncounterAdapter = {
	start: (context: EncounterContext) -> boolean,
	cancel: ((context: EncounterContext, reasonId: string) -> ())?,
}

export type Adapters = {
	Approach: EncounterAdapter?,
	DungeonTraversal: EncounterAdapter?,
	DungeonCombat: EncounterAdapter?,
	Elite: EncounterAdapter?,
	Boss: EncounterAdapter?,
}

export type Coordinator = {
	sync: (self: Coordinator, nowUnix: number) -> { Accepted: boolean, ReasonId: string },
	completeActive: (self: Coordinator, token: string, nowUnix: number) -> { Accepted: boolean, ReasonId: string },
	getActiveContext: (self: Coordinator) -> EncounterContext?,
	destroy: (self: Coordinator) -> (),
}

type Internal = {
	Runtime: Runtime,
	RoomPlan: RoomPlan,
	Adapters: Adapters,
	Active: EncounterContext?,
	CompletedTokens: { [string]: boolean },
	NextDungeonNodeIndex: number,
	Nonce: number,
	Destroyed: boolean,
}

local ExpeditionEncounterCoordinator = {}
ExpeditionEncounterCoordinator.__index = ExpeditionEncounterCoordinator

local function result(accepted: boolean, reasonId: string)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId })
end

local function copyContext(context: EncounterContext): EncounterContext
	return table.freeze({
		Token = context.Token,
		RunId = context.RunId,
		PhaseId = context.PhaseId,
		RoomIndex = context.RoomIndex,
		RoomId = context.RoomId,
		RoomRoleId = context.RoomRoleId,
		Seed = context.Seed,
	})
end

local function adapterFor(state: Internal, phaseId: string, node: RoomNode?): EncounterAdapter?
	if phaseId == "Approach" then
		return state.Adapters.Approach
	elseif phaseId == "Dungeon" and node then
		if node.RoleId == "Combat" then
			return state.Adapters.DungeonCombat
		end
		return state.Adapters.DungeonTraversal
	elseif phaseId == "Elite" then
		return state.Adapters.Elite
	elseif phaseId == "Boss" then
		return state.Adapters.Boss
	end
	return nil
end

function ExpeditionEncounterCoordinator.new(runtime: Runtime, roomPlan: RoomPlan, adapters: Adapters): Coordinator
	assert(runtime ~= nil, "runtime is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0, "room plan seed must be an integer")
	assert(#roomPlan.Nodes >= 2, "room plan requires at least entry and boss nodes")

	local state: Internal = {
		Runtime = runtime,
		RoomPlan = roomPlan,
		Adapters = adapters,
		Active = nil,
		CompletedTokens = {},
		NextDungeonNodeIndex = 1,
		Nonce = 0,
		Destroyed = false,
	}
	return setmetatable({ _state = state }, ExpeditionEncounterCoordinator) :: any
end

function ExpeditionEncounterCoordinator:getActiveContext(): EncounterContext?
	local state: Internal = (self :: any)._state
	if state.Destroyed or not state.Active then
		return nil
	end
	return copyContext(state.Active)
end

function ExpeditionEncounterCoordinator:sync(_nowUnix: number)
	local state: Internal = (self :: any)._state
	if state.Destroyed then
		return result(false, "CoordinatorDestroyed")
	end
	if state.Active then
		return result(false, "EncounterAlreadyActive")
	end

	local snapshot = state.Runtime:getSnapshot()
	if not snapshot then
		return result(false, "RunUnavailable")
	end
	if snapshot.OutcomeId ~= "InProgress" then
		return result(false, "RunTerminal")
	end

	local node: RoomNode? = nil
	if snapshot.PhaseId == "Dungeon" then
		while state.NextDungeonNodeIndex <= #state.RoomPlan.Nodes do
			local candidate = state.RoomPlan.Nodes[state.NextDungeonNodeIndex]
			state.NextDungeonNodeIndex += 1
			if candidate.RoleId ~= "Entry" and candidate.RoleId ~= "Elite" and candidate.RoleId ~= "Boss" then
				node = candidate
				break
			end
		end
		if not node then
			local advance = state.Runtime:advancePhase(snapshot.PhaseId, _nowUnix)
			return result(advance.Accepted == true, advance.ReasonId or "DungeonPhaseAdvanceRejected")
		end
	end

	local adapter = adapterFor(state, snapshot.PhaseId, node)
	if not adapter then
		local advance = state.Runtime:advancePhase(snapshot.PhaseId, _nowUnix)
		return result(advance.Accepted == true, advance.ReasonId or "NoEncounterForPhase")
	end

	state.Nonce += 1
	local context: EncounterContext = table.freeze({
		Token = string.format("%s:%s:%d", snapshot.RunId, snapshot.PhaseId, state.Nonce),
		RunId = snapshot.RunId,
		PhaseId = snapshot.PhaseId,
		RoomIndex = if node then node.Index else nil,
		RoomId = if node then node.RoomId else nil,
		RoomRoleId = if node then node.RoleId else nil,
		Seed = state.RoomPlan.Seed,
	})

	if adapter.start(context) ~= true then
		return result(false, "EncounterOwnerRejectedStart")
	end
	state.Active = context
	return result(true, "EncounterStarted")
end

function ExpeditionEncounterCoordinator:completeActive(token: string, nowUnix: number)
	local state: Internal = (self :: any)._state
	if state.Destroyed then
		return result(false, "CoordinatorDestroyed")
	end
	if type(token) ~= "string" or token == "" then
		return result(false, "InvalidToken")
	end
	if state.CompletedTokens[token] then
		return result(false, "EncounterAlreadyCompleted")
	end
	local active = state.Active
	if not active then
		return result(false, "NoActiveEncounter")
	end
	if token ~= active.Token then
		return result(false, "StaleEncounterToken")
	end

	state.CompletedTokens[token] = true
	state.Active = nil

	if active.PhaseId == "Dungeon" then
		return result(true, "DungeonRoomCompleted")
	end

	local advance = state.Runtime:advancePhase(active.PhaseId, nowUnix)
	if advance.Accepted ~= true then
		return result(false, advance.ReasonId or "PhaseAdvanceRejected")
	end
	return result(true, "EncounterCompletedAndPhaseAdvanced")
end

function ExpeditionEncounterCoordinator:destroy()
	local state: Internal = (self :: any)._state
	if state.Destroyed then
		return
	end
	state.Destroyed = true
	local active = state.Active
	if active then
		local adapter = adapterFor(
			state,
			active.PhaseId,
			if active.RoomIndex
				then {
					Index = active.RoomIndex,
					RoomId = active.RoomId or "",
					RoleId = active.RoomRoleId or "Traversal",
				}
				else nil
		)
		if adapter and adapter.cancel then
			adapter.cancel(active, "CoordinatorDestroyed")
		end
	end
	state.Active = nil
end

return table.freeze(ExpeditionEncounterCoordinator)
