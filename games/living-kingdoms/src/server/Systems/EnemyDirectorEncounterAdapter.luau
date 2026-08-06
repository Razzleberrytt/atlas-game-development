--!strict

--[[
	VS-0110 narrow server-only adapter around the existing EnemyDirectorService.

	The adapter does not own combat truth and exposes no remotes. It translates an
	expedition encounter context into one authored wave or boss spawn, then polls
	the director's authoritative read methods until that exact encounter is clear.
	Completion is reported once to the server bootstrap, which may then call the
	expedition coordinator with its private token.
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

export type WaveDefinition = {
	id: string,
	name: string,
	x: number,
	y: number,
	z: number,
}

export type Director = {
	spawnAuthoredWave: (waveIndex: number, definitions: { WaveDefinition }) -> number,
	spawnBoss: (position: { x: number, y: number, z: number }, floodlightsRestored: boolean) -> boolean,
	readActiveEnemyCount: () -> number,
	readBossState: () -> {
		exists: boolean,
		isAlive: boolean,
		isDefeated: boolean,
	},
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
	BaselineEnemyCount: number,
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

function Adapter.new(director: Director, resolveDefinition: DefinitionResolver): Adapter
	assert(type(director) == "table", "director is required")
	assert(type(resolveDefinition) == "function", "definition resolver is required")
	return setmetatable({
		Director = director,
		ResolveDefinition = resolveDefinition,
		ActiveContext = nil,
		ActiveKind = nil,
		BaselineEnemyCount = 0,
		SawBoss = false,
		CompletionReported = false,
		Destroyed = false,
	} :: Internal, Adapter) :: any
end

function Adapter:start(context: EncounterContext): boolean
	local state: Internal = self :: any
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
	state.BaselineEnemyCount = state.Director.readActiveEnemyCount()

	if definition.Kind == "Wave" then
		local waveIndex = definition.WaveIndex
		local wave = definition.Wave
		if type(waveIndex) ~= "number" or waveIndex % 1 ~= 0 or type(wave) ~= "table" or #wave == 0 then
			return false
		end
		local accepted = state.Director.spawnAuthoredWave(waveIndex, wave)
		if accepted <= 0 then
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
	state.SawBoss = definition.Kind == "Boss"
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
		completed = state.Director.readActiveEnemyCount() <= state.BaselineEnemyCount
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
	if state.Destroyed or state.ActiveContext == nil then
		return nil
	end
	return state.ActiveContext.Token
end

function Adapter:cancel(context: EncounterContext, _reasonId: string)
	local state: Internal = self :: any
	if state.Destroyed or state.ActiveContext == nil or context.Token ~= state.ActiveContext.Token then
		return
	end
	state.Director.endOperationPressure()
	state.ActiveContext = nil
	state.ActiveKind = nil
	state.CompletionReported = false
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
	state.CompletionReported = false
end

return table.freeze(Adapter)
