--!strict

--[[
	VS-0110 narrow server-only adapter around the existing EnemyDirectorService.
	It exposes no remotes and never owns combat truth. Authored wave completion is
	based on the exact spawned entity IDs, not a fragile global population count.

	Typed authored definitions are forwarded into the director's existing
	spawnEnemy authority so special archetypes and canonical horde roles retain
	their real mechanics. The existing spawnAuthoredWave entry point is still used
	with an empty definition list to preserve authored-pressure/recovery pacing
	without creating duplicate enemies.

	A bounded WaveSequence definition may chain several typed authored waves under
	one encounter token. The caller supplies server-owned timestamps to
	pollCompletion so inter-wave and post-clear recovery windows stay deterministic
	without creating a second timer or combat authority.
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
	archetypeId: string,
	hordeRoleId: string?,
}
export type WaveStage = {
	WaveIndex: number,
	DelayAfterPreviousSeconds: number,
	Wave: { WaveDefinition },
}
export type SpawnResult = {
	didSpawn: boolean,
	wasDeferred: boolean,
	rejectionReasonId: string?,
}
export type Director = {
	spawnAuthoredWave: (waveIndex: number, definitions: { any }) -> number,
	spawnEnemy: (request: any) -> SpawnResult,
	spawnBoss: (position: { x: number, y: number, z: number }, floodlightsRestored: boolean) -> boolean,
	readEnemyCombatFacts: () -> { { entityId: string, isAlive: boolean } },
	readBossState: () -> { exists: boolean, isAlive: boolean, isDefeated: boolean },
	endOperationPressure: () -> (),
}
export type EncounterDefinition = {
	Kind: "Wave" | "WaveSequence" | "Boss",
	WaveIndex: number?,
	Wave: { WaveDefinition }?,
	Waves: { WaveStage }?,
	CompletionDelaySeconds: number?,
	BossPosition: { x: number, y: number, z: number }?,
	FloodlightsRestored: boolean?,
	CompositionIdentity: string?,
}
export type DefinitionResolver = (context: EncounterContext) -> EncounterDefinition?
export type Adapter = {
	start: (context: EncounterContext) -> boolean,
	cancel: (context: EncounterContext, reasonId: string) -> (),
	pollCompletion: (self: Adapter, nowUnix: number?) -> (boolean, string?),
	getActiveToken: (self: Adapter) -> string?,
	destroy: (self: Adapter) -> (),
}

type Internal = {
	Director: Director,
	ResolveDefinition: DefinitionResolver,
	ActiveContext: EncounterContext?,
	ActiveKind: ("Wave" | "WaveSequence" | "Boss")?,
	ActiveCompositionIdentity: string?,
	TrackedEntityIds: { [string]: boolean },
	SawTrackedEntity: boolean,
	SawBoss: boolean,
	SequenceStages: { WaveStage }?,
	SequenceStageIndex: number,
	SequenceCompletionDelaySeconds: number,
	NextSequenceStageEligibleAtUnix: number?,
	SequenceCompletionEligibleAtUnix: number?,
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

local function startTypedWave(
	state: Internal,
	waveIndex: number,
	wave: { WaveDefinition },
	compositionIdentity: string
): boolean
	-- Preserve the director's existing authored-wave escalation/recovery side
	-- effects, but do not let that legacy helper mint generic walkers for typed
	-- First Descent definitions.
	state.Director.spawnAuthoredWave(waveIndex, {})

	local accepted = 0
	for _, enemy in wave do
		local spawnResult = state.Director.spawnEnemy({
			entityId = enemy.id,
			archetypeId = enemy.archetypeId,
			spawnSourceId = "AuthoredWave",
			displayName = enemy.name,
			position = { x = enemy.x, y = enemy.y, z = enemy.z },
			isHordePulse = enemy.hordeRoleId ~= nil,
			hordeRoleId = enemy.hordeRoleId,
			compositionIdentity = compositionIdentity,
		})
		if spawnResult.didSpawn or spawnResult.wasDeferred then
			accepted += 1
		end
	end
	return accepted > 0
end

local function validateWave(waveIndex: unknown, wave: unknown, knownIds: { [string]: boolean }): boolean
	if type(waveIndex) ~= "number" or waveIndex % 1 ~= 0 or type(wave) ~= "table" or #wave == 0 then
		return false
	end
	for _, enemy in wave do
		if
			type(enemy.id) ~= "string"
			or enemy.id == ""
			or knownIds[enemy.id]
			or type(enemy.archetypeId) ~= "string"
			or enemy.archetypeId == ""
		then
			return false
		end
		knownIds[enemy.id] = true
	end
	return true
end

local function beginWave(
	state: Internal,
	waveIndex: number,
	wave: { WaveDefinition },
	compositionIdentity: string
): boolean
	local tracked = {}
	for _, enemy in wave do
		tracked[enemy.id] = true
	end
	if not startTypedWave(state, waveIndex, wave, compositionIdentity) then
		return false
	end
	state.TrackedEntityIds = tracked
	state.SawTrackedEntity = false
	return true
end

local function trackedWaveCleared(state: Internal): boolean
	local aliveTracked = 0
	for _, fact in state.Director.readEnemyCombatFacts() do
		if state.TrackedEntityIds[fact.entityId] and fact.isAlive then
			state.SawTrackedEntity = true
			aliveTracked += 1
		end
	end
	return state.SawTrackedEntity and aliveTracked == 0
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

	local knownIds = {}
	if definition.Kind == "Wave" then
		local compositionIdentity = definition.CompositionIdentity
		if type(compositionIdentity) ~= "string" or compositionIdentity == "" then
			return false
		end
		local waveIndex, wave = definition.WaveIndex, definition.Wave
		if not validateWave(waveIndex, wave, knownIds) then
			return false
		end
		if not beginWave(state, waveIndex :: number, wave :: { WaveDefinition }, compositionIdentity) then
			return false
		end
	elseif definition.Kind == "WaveSequence" then
		local compositionIdentity = definition.CompositionIdentity
		if type(compositionIdentity) ~= "string" or compositionIdentity == "" then
			return false
		end
		local stages = definition.Waves
		local completionDelaySeconds = definition.CompletionDelaySeconds or 0
		if type(stages) ~= "table" or #stages == 0 then
			return false
		end
		if type(completionDelaySeconds) ~= "number" or completionDelaySeconds < 0 then
			return false
		end
		for index, stage in stages do
			if type(stage) ~= "table" or type(stage.DelayAfterPreviousSeconds) ~= "number" then
				return false
			end
			if stage.DelayAfterPreviousSeconds < 0 or (index == 1 and stage.DelayAfterPreviousSeconds ~= 0) then
				return false
			end
			if not validateWave(stage.WaveIndex, stage.Wave, knownIds) then
				return false
			end
		end
		local firstStage = stages[1]
		if not beginWave(state, firstStage.WaveIndex, firstStage.Wave, compositionIdentity) then
			return false
		end
		state.SequenceStages = stages
		state.SequenceStageIndex = 1
		state.SequenceCompletionDelaySeconds = completionDelaySeconds
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
	state.ActiveCompositionIdentity = definition.CompositionIdentity
	state.SawBoss = false
	state.NextSequenceStageEligibleAtUnix = nil
	state.SequenceCompletionEligibleAtUnix = nil
	state.CompletionReported = false
	return true
end

local function pollWaveSequence(state: Internal, nowUnix: number?): (boolean, string?)
	local stages = state.SequenceStages
	if stages == nil or #stages == 0 or state.SequenceStageIndex < 1 or state.SequenceStageIndex > #stages then
		return false, "InvalidWaveSequenceState"
	end
	if not trackedWaveCleared(state) then
		return false, "EncounterInProgress"
	end
	if type(nowUnix) ~= "number" or nowUnix < 0 then
		return false, "SequenceClockRequired"
	end

	local nextStageIndex = state.SequenceStageIndex + 1
	if nextStageIndex <= #stages then
		local nextStage = stages[nextStageIndex]
		if state.NextSequenceStageEligibleAtUnix == nil then
			state.NextSequenceStageEligibleAtUnix = nowUnix + nextStage.DelayAfterPreviousSeconds
		end
		if nowUnix < state.NextSequenceStageEligibleAtUnix then
			return false, "SequenceRecovery"
		end
		local compositionIdentity = state.ActiveCompositionIdentity
		if type(compositionIdentity) ~= "string" or compositionIdentity == "" then
			return false, "CompositionIdentityMissing"
		end
		if not beginWave(state, nextStage.WaveIndex, nextStage.Wave, compositionIdentity) then
			return false, "SequenceWaveStartRejected"
		end
		state.SequenceStageIndex = nextStageIndex
		state.NextSequenceStageEligibleAtUnix = nil
		return false, "SequenceWaveStarted"
	end

	if state.SequenceCompletionDelaySeconds > 0 then
		if state.SequenceCompletionEligibleAtUnix == nil then
			state.SequenceCompletionEligibleAtUnix = nowUnix + state.SequenceCompletionDelaySeconds
		end
		if nowUnix < state.SequenceCompletionEligibleAtUnix then
			return false, "SequenceRecovery"
		end
	end
	return true, state.ActiveContext and state.ActiveContext.Token or nil
end

function Adapter:pollCompletion(nowUnix: number?): (boolean, string?)
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
	local token: string? = nil
	if state.ActiveKind == "Wave" then
		completed = trackedWaveCleared(state)
		if completed then
			token = state.ActiveContext.Token
		end
	elseif state.ActiveKind == "WaveSequence" then
		local sequenceCompleted, sequenceResult = pollWaveSequence(state, nowUnix)
		if sequenceCompleted then
			completed = true
			token = sequenceResult
		else
			return false, sequenceResult
		end
	else
		local boss = state.Director.readBossState()
		state.SawBoss = state.SawBoss or boss.exists
		completed = state.SawBoss and boss.isDefeated and not boss.isAlive
		if completed then
			token = state.ActiveContext.Token
		end
	end
	if not completed then
		return false, "EncounterInProgress"
	end
	state.CompletionReported = true
	return true, token
end

function Adapter:getActiveToken(): string?
	local state: Internal = self :: any
	return if not state.Destroyed and state.ActiveContext then state.ActiveContext.Token else nil
end

local function clearEncounterState(state: Internal)
	state.ActiveContext = nil
	state.ActiveKind = nil
	table.clear(state.TrackedEntityIds)
	state.SawTrackedEntity = false
	state.SawBoss = false
	state.SequenceStages = nil
	state.SequenceStageIndex = 0
	state.SequenceCompletionDelaySeconds = 0
	state.NextSequenceStageEligibleAtUnix = nil
	state.SequenceCompletionEligibleAtUnix = nil
	state.CompletionReported = false
end

local function cancelEncounter(state: Internal, context: EncounterContext, _reasonId: string)
	if state.Destroyed or state.ActiveContext == nil or context.Token ~= state.ActiveContext.Token then
		return
	end
	state.Director.endOperationPressure()
	clearEncounterState(state)
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
			SequenceStages = nil,
			SequenceStageIndex = 0,
			SequenceCompletionDelaySeconds = 0,
			NextSequenceStageEligibleAtUnix = nil,
			SequenceCompletionEligibleAtUnix = nil,
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
	clearEncounterState(state)
end

return table.freeze(Adapter)
