--!strict

--[[
	VS-0110 narrow server-only adapter around the existing EnemyDirectorService.
	It exposes no remotes and never owns combat truth. Authored wave completion is
	based on the exact spawned entity IDs, not a fragile global population count.
]]

export type EncounterContext = {
	Token: string,
	RunId: string,
	PhaseId: string,
	RoomIndex: number?,
	RoomId: string?,
	RoomRoleId: string?,
	Seed: number,
}

export type WaveDefinition = { id: string, name: string, x: number, y: number, z: number }
export type Director = {
	spawnAuthoredWave: (waveIndex: number, definitions: { WaveDefinition }) -> number,
	spawnBoss: (position: { x: number, y: number, z: number }, floodlightsRestored: boolean) -> boolean,
	readEnemyCombatFacts: () -> { { entityId: string, isAlive: boolean } },
	readBossState: () -> { exists: boolean, isAlive: boolean, isDefeated: boolean },
	endOperationPressure: () -> (),
}
export type EncounterDefinition = {
	Kind: "Wave" | "Boss",
	WaveIndex: number?,
	Wave: { WaveDefinition }?,
	BossPosition: { x: number, y: number, z: number }?,
	FloodlightsRestored: boolean?,
}
export type DefinitionResolver = (context: EncounterContext) -> EncounterDefinition?
export type Adapter = {
	start: (context: EncounterContext) -> boolean,
	cancel: (context: EncounterContext, reasonId: string) -> (),
	pollCompletion: (self: Adapter) -> (boolean, string?),
	getActiveToken: (self: Adapter) -> string?,
	destroy: (self: Adapter) -> (),
}

type Internal = {
	Director: Director,
	ResolveDefinition: DefinitionResolver,
	ActiveContext: EncounterContext?,
	ActiveKind: ("Wave" | "Boss")?,
	TrackedEntityIds: { [string]: boolean },
	SawTrackedEntity: boolean,
	SawBoss: boolean,
	CompletionReported: boolean,
	Destroyed: boolean,
}

local Adapter = {}
Adapter.__index = Adapter

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

local function startEncounter(state: Internal, context: EncounterContext): boolean
	if state.Destroyed or state.ActiveContext ~= nil then
		return false
	end
	if type(context) ~= "table" or type(context.Token) ~= "string" or context.Token == "" then
		return false
	end
	local definition = state.ResolveDefinition(context)
	if definition == nil then
		return false
	end

	local tracked = {}
	if definition.Kind == "Wave" then
		local waveIndex, wave = definition.WaveIndex, definition.Wave
		if type(waveIndex) ~= "number" or waveIndex % 1 ~= 0 or type(wave) ~= "table" or #wave == 0 then
			return false
		end
		for _, enemy in wave do
			if type(enemy.id) ~= "string" or enemy.id == "" or tracked[enemy.id] then
				return false
			end
			tracked[enemy.id] = true
		end
		if state.Director.spawnAuthoredWave(waveIndex, wave) <= 0 then
			return false
		end
	elseif definition.Kind == "Boss" then
		local position = definition.BossPosition
		if type(position) ~= "table" then
			return false
		end
		if not state.Director.spawnBoss(position, definition.FloodlightsRestored == true) then
			return false
		end
	else
		return false
	end

	state.ActiveContext = copyContext(context)
	state.ActiveKind = definition.Kind
	state.TrackedEntityIds = tracked
	state.SawTrackedEntity = false
	state.SawBoss = false
	state.CompletionReported = false
	return true
end

function Adapter:pollCompletion(): (boolean, string?)
	local state: Internal = self :: any
	if state.Destroyed then
		return false, "AdapterDestroyed"
	end
	if state.ActiveContext == nil or state.ActiveKind == nil then
		return false, "NoActiveEncounter"
	end
	if state.CompletionReported then
		return false, "CompletionAlreadyReported"
	end

	local completed = false
	if state.ActiveKind == "Wave" then
		local aliveTracked = 0
		for _, fact in state.Director.readEnemyCombatFacts() do
			if state.TrackedEntityIds[fact.entityId] and fact.isAlive then
				state.SawTrackedEntity = true
				aliveTracked += 1
			end
		end
		completed = state.SawTrackedEntity and aliveTracked == 0
	else
		local boss = state.Director.readBossState()
		state.SawBoss = state.SawBoss or boss.exists
		completed = state.SawBoss and boss.isDefeated and not boss.isAlive
	end
	if not completed then
		return false, "EncounterInProgress"
	end
	state.CompletionReported = true
	return true, state.ActiveContext.Token
end

function Adapter:getActiveToken(): string?
	local state: Internal = self :: any
	return if not state.Destroyed and state.ActiveContext then state.ActiveContext.Token else nil
end

local function cancelEncounter(state: Internal, context: EncounterContext, _reasonId: string)
	if state.Destroyed or state.ActiveContext == nil or context.Token ~= state.ActiveContext.Token then
		return
	end
	state.Director.endOperationPressure()
	state.ActiveContext = nil
	state.ActiveKind = nil
	table.clear(state.TrackedEntityIds)
	state.CompletionReported = false
end

--[[
	`ExpeditionEncounterCoordinator.EncounterAdapter` declares `start` and
	`cancel` as self-less functions and invokes them with `.`, so they are bound
	to the instance here instead of being declared as `:` methods. The remaining
	members stay `:` methods, matching how the composition root calls them.
]]
function Adapter.new(director: Director, resolveDefinition: DefinitionResolver): Adapter
	assert(type(director) == "table", "director is required")
	assert(type(resolveDefinition) == "function", "definition resolver is required")
	local instance = setmetatable(
		{
			Director = director,
			ResolveDefinition = resolveDefinition,
			ActiveContext = nil,
			ActiveKind = nil,
			TrackedEntityIds = {},
			SawTrackedEntity = false,
			SawBoss = false,
			CompletionReported = false,
			Destroyed = false,
		} :: Internal,
		Adapter
	)

	local state: Internal = instance :: any
	local bound = instance :: any
	bound.start = function(context: EncounterContext): boolean
		return startEncounter(state, context)
	end
	bound.cancel = function(context: EncounterContext, reasonId: string)
		cancelEncounter(state, context, reasonId)
	end
	return bound :: any
end

function Adapter:destroy()
	local state: Internal = self :: any
	if state.Destroyed then
		return
	end
	state.Destroyed = true
	if state.ActiveContext ~= nil then
		state.Director.endOperationPressure()
	end
	state.ActiveContext = nil
	state.ActiveKind = nil
	table.clear(state.TrackedEntityIds)
	state.CompletionReported = false
end

return table.freeze(Adapter)
