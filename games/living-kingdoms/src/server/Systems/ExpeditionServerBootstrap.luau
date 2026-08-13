--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)
local FirstDungeonContentConfig = require(ReplicatedStorage.Shared.Config.FirstDungeonContentConfig)
local FirstOutdoorEncounterBeatConfig = require(ReplicatedStorage.Shared.Config.FirstOutdoorEncounterBeatConfig)
local HordeExperienceConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local SpecialEnemyConfig = require(ReplicatedStorage.Shared.Config.SpecialEnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local RoomPlacementPlanner = require(ReplicatedStorage.Shared.Expeditions.RoomPlacementPlanner)
local RoomSequenceAssembler = require(ReplicatedStorage.Shared.Expeditions.RoomSequenceAssembler)
local RunVariationPlanner = require(ReplicatedStorage.Shared.Expeditions.RunVariationPlanner)
local RunVariationEncounterView = require(ReplicatedStorage.Shared.Expeditions.RunVariationEncounterView)
local RunVariationAuthoredEncounterComposer =
	require(ReplicatedStorage.Shared.Expeditions.RunVariationAuthoredEncounterComposer)
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
	getActiveEncounterContext: (self: Service) -> any?,
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

local HordeRoleById = {}
for _, role in HordeExperienceConfig.Roles do
	HordeRoleById[role.Id] = role
end

local function result(accepted: boolean, reasonId: string)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId })
end

local function normalizedPlan(plan: any): any
	local nodes = {}
	for _, node in plan.Nodes do
		table.insert(nodes, table.freeze({ Index = node.Index, RoomId = node.RoomId, RoleId = node.Role }))
	end
	return table.freeze({ Seed = plan.Seed, Nodes = table.freeze(nodes) })
end

local function deterministicOffset(seed: number, ordinal: number): (number, number)
	local value = (seed * 48_271 + ordinal * 7_919) % 2_147_483_647
	local x = math.clamp(((value % 17) - 8) * 6, -18, 18)
	local z = math.clamp(((math.floor(value / 17) % 11) - 5) * 6, -24, 24)
	return x, z
end

local function displayNameForUnit(unit: any): string
	if unit.HordeRoleId ~= nil then
		local role = HordeRoleById[unit.HordeRoleId]
		if role ~= nil then
			return role.DisplayName
		end
	end
	if unit.ArchetypeId == EnemyContracts.EnemyArchetypeIds.BlightSpitter then
		return SpecialEnemyConfig.BlightSpitter.DisplayName
	end
	return "Warden"
end

local function buildAuthoredWave(
	context: any,
	authoredWave: any,
	anchor: any,
	startingOrdinal: number,
	compositionIdentity: string
): ({ any }, number)
	local definitions = {}
	local ordinal = startingOrdinal
	for _, unit in authoredWave.Units do
		for _ = 1, unit.Count do
			ordinal += 1
			local xOffset, zOffset = deterministicOffset(context.Seed, ordinal + (context.RoomIndex or 0) * 5)
			table.insert(definitions, {
				id = string.format("%s:enemy:%d", context.Token, ordinal),
				name = displayNameForUnit(unit),
				x = anchor.x + xOffset,
				y = anchor.y,
				z = anchor.z + zOffset,
				archetypeId = unit.ArchetypeId,
				hordeRoleId = unit.HordeRoleId,
			})
		end
	end
	return definitions, ordinal
end

local function buildAuthoredEncounterDefinition(context: any, encounter: any, anchor: any, baseWaveIndex: number): any
	if encounter == nil or type(encounter.Waves) ~= "table" or #encounter.Waves == 0 then
		return nil
	end

	local stages = {}
	assert(
		type(encounter.CompositionIdentity) == "string"
			and string.find(encounter.CompositionIdentity, "P06-AUTHORED-ENCOUNTER-COMPOSER-v1", 1, true) == 1,
		"runtime authored encounter requires a validated composition identity"
	)
	local ordinal = 0
	for waveIndex, authoredWave in encounter.Waves do
		local definitions
		definitions, ordinal = buildAuthoredWave(context, authoredWave, anchor, ordinal, encounter.CompositionIdentity)
		if #definitions == 0 then
			return nil
		end
		table.insert(stages, {
			WaveIndex = baseWaveIndex + waveIndex - 1,
			DelayAfterPreviousSeconds = if waveIndex == 1 then 0 else (authoredWave.DelayAfterPreviousSeconds or 0),
			Wave = definitions,
		})
	end

	if #stages == 1 then
		return {
			Kind = "Wave",
			CompositionIdentity = encounter.CompositionIdentity,
			WaveIndex = stages[1].WaveIndex,
			Wave = stages[1].Wave,
		}
	end
	return {
		Kind = "WaveSequence",
		CompositionIdentity = encounter.CompositionIdentity,
		Waves = stages,
		CompletionDelaySeconds = 0,
	}
end

local function buildOutdoorApproachSequence(context: any): any
	assert(
		FirstOutdoorEncounterBeatConfig.RuntimeConsumptionActive == true,
		"authored outdoor approach combat must be runtime-enabled"
	)
	assert(
		FirstOutdoorEncounterBeatConfig.RuntimeConsumptionScopeId == "ApproachCombatSequenceOnly",
		"outdoor encounter runtime scope must remain combat-only"
	)

	-- BA-050 route geometry remains held, so the live combat sequence intentionally
	-- uses the existing Approach combat anchor rather than inventing landmark
	-- coordinates or a second traversal authority.
	local anchor = { x = 0, y = 4, z = 24 }
	local stages = {}
	local stageOrdinal = 0
	local enemyOrdinal = 0
	local previousBeatRecoverySeconds = 0

	for beatIndex, beat in FirstOutdoorEncounterBeatConfig.Beats do
		for waveIndex, authoredWave in beat.Waves do
			stageOrdinal += 1
			local definitions = {}
			for _, unit in authoredWave.Units do
				for _ = 1, unit.Count do
					enemyOrdinal += 1
					local xOffset, zOffset = deterministicOffset(context.Seed, enemyOrdinal + stageOrdinal * 7)
					table.insert(definitions, {
						id = string.format("%s:approach:%d:%d", context.Token, stageOrdinal, enemyOrdinal),
						name = displayNameForUnit(unit),
						x = anchor.x + xOffset,
						y = anchor.y,
						z = anchor.z + zOffset,
						archetypeId = unit.ArchetypeId,
						hordeRoleId = unit.HordeRoleId,
					})
				end
			end

			local delayAfterPreviousSeconds = authoredWave.DelayAfterPreviousSeconds
			if waveIndex == 1 and beatIndex > 1 then
				delayAfterPreviousSeconds = previousBeatRecoverySeconds
			end
			table.insert(stages, {
				WaveIndex = stageOrdinal,
				DelayAfterPreviousSeconds = delayAfterPreviousSeconds,
				Wave = definitions,
			})
		end
		previousBeatRecoverySeconds = beat.PostClearRecoverySeconds
	end

	assert(#stages >= 1, "authored outdoor approach requires at least one live wave stage")
	return {
		Kind = "WaveSequence",
		CompositionIdentity = string.format("P06-OUTDOOR-AUTHORED-v1|run=%s|seed=%d", context.RunId, context.Seed),
		Waves = stages,
		CompletionDelaySeconds = previousBeatRecoverySeconds,
	}
end

local function buildEncounterResolver(rawPlan: any): (any) -> any
	local layout = RoomPlacementPlanner.plan(rawPlan)
	local placementByRoomId = {}
	local placementByRoleId = {}
	for _, placement in layout.Placements do
		placementByRoomId[placement.RoomId] = placement
		placementByRoleId[placement.RoleId] = placement
	end

	local variationPlan = RunVariationPlanner.plan(rawPlan)
	local encounterView = RunVariationEncounterView.build(rawPlan, variationPlan)
	local composedEncounterByRoomId = {}
	for _, record in encounterView.Records do
		local authoredEncounter = FirstDungeonContentConfig.Encounters[record.RoomId]
		if authoredEncounter ~= nil then
			composedEncounterByRoomId[record.RoomId] =
				RunVariationAuthoredEncounterComposer.compose(rawPlan.Seed, record, authoredEncounter)
		end
	end

	local function placementFor(context: any): any?
		if context.PhaseId == "Dungeon" and type(context.RoomId) == "string" then
			return placementByRoomId[context.RoomId]
		elseif context.PhaseId == "Elite" or context.PhaseId == "Boss" then
			return placementByRoleId[context.PhaseId]
		end
		return nil
	end

	return function(context: any): any
		if context.PhaseId == "Approach" then
			return buildOutdoorApproachSequence(context)
		end

		local placement = placementFor(context)
		if placement == nil then
			return nil
		end
		local anchor = { x = placement.Center.x, y = 4, z = placement.Center.z }
		if context.PhaseId == "Boss" then
			return { Kind = "Boss", BossPosition = anchor, FloodlightsRestored = true }
		end

		local roomId = if context.PhaseId == "Dungeon" then context.RoomId else placement.RoomId
		if type(roomId) ~= "string" then
			return nil
		end
		local encounter = composedEncounterByRoomId[roomId]
		local baseWaveIndex = context.RoomIndex or (if context.PhaseId == "Elite" then 90 else 1)
		return buildAuthoredEncounterDefinition(context, encounter, anchor, baseWaveIndex)
	end
end

local function passiveTraversalAdapter()
	local activeToken: string? = nil
	return {
		start = function(context: any): boolean
			if activeToken ~= nil then
				return false
			end
			activeToken = context.Token
			return true
		end,
		cancel = function(context: any, _reasonId: string)
			if activeToken == context.Token then
				activeToken = nil
			end
		end,
		pollCompletion = function(): (boolean, string?)
			if activeToken == nil then
				return false, "NoActiveEncounter"
			end
			return true, activeToken
		end,
	}
end

function Bootstrap.new(director: EnemyDirector, parameters: StartParameters): Service
	local definition = ExpeditionConfig.Definitions.FirstExpedition
	local runtime = ExpeditionRuntime.new(definition, parameters)
	local rawPlan = RoomSequenceAssembler.assemble(parameters.Seed)
	local plan = normalizedPlan(rawPlan)
	local combatAdapter = EnemyDirectorEncounterAdapter.new(director, buildEncounterResolver(rawPlan))
	local traversalAdapter = passiveTraversalAdapter()
	local coordinator = ExpeditionEncounterCoordinator.new(runtime, plan, {
		Approach = combatAdapter,
		DungeonTraversal = traversalAdapter,
		DungeonCombat = combatAdapter,
		Elite = combatAdapter,
		Boss = combatAdapter,
	})
	return setmetatable(
		{
			Runtime = runtime,
			Coordinator = coordinator,
			CombatAdapter = combatAdapter,
			TraversalAdapter = traversalAdapter,
			RoomPlan = rawPlan,
			Destroyed = false,
		} :: Internal,
		Bootstrap
	) :: any
end

function Bootstrap:step(nowUnix: number)
	local state: Internal = self :: any
	if state.Destroyed then
		return result(false, "BootstrapDestroyed")
	end
	if type(nowUnix) ~= "number" or nowUnix < 0 then
		return result(false, "InvalidTimestamp")
	end
	local snapshot = state.Runtime:getSnapshot()
	if
		snapshot ~= nil
		and snapshot.PhaseId == ExpeditionContracts.PhaseIds.Results
		and snapshot.OutcomeId == ExpeditionContracts.OutcomeIds.InProgress
	then
		local finish = state.Runtime:finish(ExpeditionContracts.OutcomeIds.Completed, snapshot.PhaseId, nowUnix)
		return result(finish.Accepted == true, finish.ReasonId)
	end
	local active = state.Coordinator:getActiveContext()
	if active ~= nil then
		local adapter = if active.RoomRoleId == "Traversal" then state.TraversalAdapter else state.CombatAdapter
		local completed, token = adapter:pollCompletion(nowUnix)
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
	if state.Destroyed then
		return nil
	end
	return state.Runtime:getSnapshot()
end

function Bootstrap:getRoomPlan(): any
	local state: Internal = self :: any
	if state.Destroyed then
		return nil
	end
	return state.RoomPlan
end

function Bootstrap:getActiveEncounterContext(): any?
	local state: Internal = self :: any
	if state.Destroyed then
		return nil
	end
	return state.Coordinator:getActiveContext()
end

function Bootstrap:destroy()
	local state: Internal = self :: any
	if state.Destroyed then
		return
	end
	state.Destroyed = true
	state.Coordinator:destroy()
	state.CombatAdapter:destroy()
	state.Runtime:destroy()
end

return table.freeze(Bootstrap)
