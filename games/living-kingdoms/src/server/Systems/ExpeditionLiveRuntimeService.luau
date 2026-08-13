--!strict

--[[
	VS-0110 live server owner for the expedition composition root.

	One service owns at most one active expedition and one bounded Heartbeat
	connection. Start/stop/read operations are server-only; no RemoteEvent or
	RemoteFunction is created here. The live mount exposes these operations only
	through a BindableFunction stored in ServerStorage.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)
local FirstDungeonRewardDecisionConfig = require(ReplicatedStorage.Shared.Config.FirstDungeonRewardDecisionConfig)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local RunVariationPlanner = require(ReplicatedStorage.Shared.Expeditions.RunVariationPlanner)
local RunVariationEncounterView = require(ReplicatedStorage.Shared.Expeditions.RunVariationEncounterView)
local ExpeditionServerBootstrap = require(script.Parent.ExpeditionServerBootstrap)
local ExpeditionRoomPlacementService = require(script.Parent.ExpeditionRoomPlacementService)
local ExpeditionRoomBarrierStateService = require(script.Parent.ExpeditionRoomBarrierStateService)
local ExpeditionBossRewardTransitionResolver = require(script.Parent.ExpeditionBossRewardTransitionResolver)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local RunBuildService = require(script.Parent.RunBuildService)

export type StartOptions = {
	Seed: number?,
	PartySize: number?,
	RunId: string?,
}

local Service = {}

local activeBootstrap: any = nil
local activeRunVariationPlan: any = nil
local activeRunVariationEncounterView: any = nil
local heartbeatConnection: RBXScriptConnection? = nil
local accumulatedSeconds = 0
local started = false

local STEP_INTERVAL_SECONDS = 0.25
local BOSS_REWARD_ROOM_ID = "keeper-core"
local BossRewardDecision = FirstDungeonRewardDecisionConfig.DecisionByRoomId[BOSS_REWARD_ROOM_ID]
local PhaseIds = ExpeditionContracts.PhaseIds
local OutcomeIds = ExpeditionContracts.OutcomeIds

local function result(accepted: boolean, reasonId: string, snapshot: any?)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Snapshot = snapshot })
end

local function nowUnix(): number
	return workspace:GetServerTimeNow()
end

local function defaultSeed(): number
	local minimum = ExpeditionConfig.RuntimeLimits.MinimumSeed
	local maximum = ExpeditionConfig.RuntimeLimits.MaximumSeed
	local span = maximum - minimum + 1
	return minimum + (math.floor(nowUnix() * 1_000) % span)
end

local function currentPartySize(): number
	return math.clamp(#Players:GetPlayers(), 1, ExpeditionConfig.Definitions.FirstExpedition.MaximumPlayers)
end

local function validInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

local function disconnectHeartbeat()
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	accumulatedSeconds = 0
end

local function offerBossReward(previousSnapshot: any?, currentSnapshot: any?)
	local rewardEvent =
		ExpeditionBossRewardTransitionResolver.resolve(previousSnapshot, currentSnapshot, BossRewardDecision)
	if rewardEvent ~= nil then
		RunBuildService.offerRelicRewardToParticipants(rewardEvent.EventId, rewardEvent.SourceId)
	end
end

local function driveStep()
	local bootstrap = activeBootstrap
	if bootstrap == nil then
		return
	end
	local previousSnapshot = bootstrap:getSnapshot()
	local stepResult = bootstrap:step(nowUnix())
	local currentSnapshot = bootstrap:getSnapshot()
	ExpeditionRoomBarrierStateService.update(bootstrap:getActiveEncounterContext())
	if stepResult.Accepted == true then
		offerBossReward(previousSnapshot, currentSnapshot)
	elseif
		stepResult.ReasonId ~= "EncounterInProgress"
		and stepResult.ReasonId ~= "PhaseMinimumDuration"
		and stepResult.ReasonId ~= "EncounterAlreadyActive"
	then
		warn("[ExpeditionLiveRuntime] step rejected:", stepResult.ReasonId)
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	accumulatedSeconds = 0
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < STEP_INTERVAL_SECONDS then
			return
		end
		accumulatedSeconds = 0
		driveStep()
	end)
end

function Service.startExpedition(options: StartOptions?): any
	if not started then
		return result(false, "ServiceStopped", nil)
	end
	if activeBootstrap ~= nil then
		return result(false, "ExpeditionAlreadyActive", activeBootstrap:getSnapshot())
	end

	local requested = options or {}
	local seed = requested.Seed or defaultSeed()
	local partySize = requested.PartySize or currentPartySize()
	local runId = requested.RunId or ("expedition:" .. HttpService:GenerateGUID(false))
	local limits = ExpeditionConfig.RuntimeLimits
	local definition = ExpeditionConfig.Definitions.FirstExpedition

	if not validInteger(seed) or seed < limits.MinimumSeed or seed > limits.MaximumSeed then
		return result(false, "InvalidSeed", nil)
	end
	if
		not validInteger(partySize)
		or partySize < definition.MinimumPlayers
		or partySize > definition.MaximumPlayers
	then
		return result(false, "InvalidPartySize", nil)
	end
	if type(runId) ~= "string" or #runId < 8 or #runId > 96 then
		return result(false, "InvalidRunId", nil)
	end

	local ok, bootstrapOrError = pcall(function()
		return ExpeditionServerBootstrap.new(EnemyDirectorService, {
			RunId = runId,
			Seed = seed,
			PartySize = partySize,
			StartedAtUnix = nowUnix(),
		})
	end)
	if not ok then
		warn("[ExpeditionLiveRuntime] failed to create expedition:", bootstrapOrError)
		return result(false, "ExpeditionCreationFailed", nil)
	end

	local bootstrap = bootstrapOrError
	local roomPlan = bootstrap:getRoomPlan()
	local variationOk, variationPlanOrError = pcall(function()
		return RunVariationPlanner.plan(roomPlan)
	end)
	if not variationOk then
		bootstrap:destroy()
		warn("[ExpeditionLiveRuntime] failed to compose run variation:", variationPlanOrError)
		return result(false, "RunVariationPlanningFailed", nil)
	end

	local encounterViewOk, encounterViewOrError = pcall(function()
		return RunVariationEncounterView.build(roomPlan, variationPlanOrError)
	end)
	if not encounterViewOk then
		bootstrap:destroy()
		warn("[ExpeditionLiveRuntime] failed to compose run variation encounter view:", encounterViewOrError)
		return result(false, "RunVariationEncounterViewFailed", nil)
	end

	local placement = ExpeditionRoomPlacementService.place(roomPlan)
	if placement.Accepted ~= true then
		bootstrap:destroy()
		warn("[ExpeditionLiveRuntime] failed to place expedition rooms:", placement.ReasonId)
		return result(false, placement.ReasonId, nil)
	end

	ExpeditionRoomBarrierStateService.reset()
	activeBootstrap = bootstrap
	activeRunVariationPlan = variationPlanOrError
	activeRunVariationEncounterView = encounterViewOrError
	driveStep()
	return result(true, "ExpeditionStarted", activeBootstrap:getSnapshot())
end

-- BA-052: the live composition root is the only integration surface allowed to
-- mutate the expedition's existing SecretDiscovered state. The caller must bind
-- the claim to the currently observed run id; stale run claims and non-Approach
-- claims are rejected before the authoritative runtime is touched.
function Service.markSecretDiscovered(expectedRunId: string): any
	if not started then
		return result(false, "ServiceStopped", nil)
	end
	local bootstrap = activeBootstrap
	if bootstrap == nil then
		return result(false, "NoActiveExpedition", nil)
	end
	local snapshot = bootstrap:getSnapshot()
	if snapshot == nil then
		return result(false, "NoActiveExpedition", nil)
	end
	if type(expectedRunId) ~= "string" or expectedRunId ~= snapshot.RunId then
		return result(false, "StaleRun", snapshot)
	end
	if snapshot.OutcomeId ~= OutcomeIds.InProgress then
		return result(false, "RunTerminal", snapshot)
	end
	if snapshot.PhaseId ~= PhaseIds.Approach then
		return result(false, "DiscoveryPhaseInvalid", snapshot)
	end
	if snapshot.SecretDiscovered == true then
		return result(false, "SecretAlreadyDiscovered", snapshot)
	end

	-- ExpeditionServerBootstrap owns this exact ExpeditionRuntime instance. The
	-- mutation stays inside the composition root and does not create a parallel
	-- discovery state store or any client-authoritative path.
	local runtime = (bootstrap :: any).Runtime
	if runtime == nil or type(runtime.markSecretDiscovered) ~= "function" then
		return result(false, "SecretMutationUnavailable", snapshot)
	end
	if runtime:markSecretDiscovered() ~= true then
		return result(false, "SecretClaimRejected", bootstrap:getSnapshot())
	end
	return result(true, "SecretDiscovered", bootstrap:getSnapshot())
end

function Service.stopExpedition(reasonId: string?): any
	local bootstrap = activeBootstrap
	if bootstrap == nil then
		return result(false, "NoActiveExpedition", nil)
	end
	local snapshot = bootstrap:getSnapshot()
	bootstrap:destroy()
	activeBootstrap = nil
	activeRunVariationPlan = nil
	activeRunVariationEncounterView = nil
	ExpeditionRoomBarrierStateService.reset()
	ExpeditionRoomPlacementService.destroy()
	return result(true, reasonId or "ExpeditionStopped", snapshot)
end

function Service.readSnapshot(): any
	if activeBootstrap == nil then
		return nil
	end
	return activeBootstrap:getSnapshot()
end

function Service.readRoomPlan(): any
	if activeBootstrap == nil then
		return nil
	end
	return activeBootstrap:getRoomPlan()
end

function Service.readRunVariationPlan(): any
	if activeBootstrap == nil then
		return nil
	end
	return activeRunVariationPlan
end

function Service.readRunVariationEncounterView(): any
	if activeBootstrap == nil then
		return nil
	end
	return activeRunVariationEncounterView
end

function Service.stop()
	if not started then
		return
	end
	started = false
	disconnectHeartbeat()
	if activeBootstrap ~= nil then
		activeBootstrap:destroy()
		activeBootstrap = nil
	end
	activeRunVariationPlan = nil
	activeRunVariationEncounterView = nil
	ExpeditionRoomBarrierStateService.reset()
	ExpeditionRoomPlacementService.destroy()
end

return table.freeze(Service)
