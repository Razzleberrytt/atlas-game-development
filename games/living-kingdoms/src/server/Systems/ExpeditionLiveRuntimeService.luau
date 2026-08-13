--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)
local RewardConfig = require(ReplicatedStorage.Shared.Config.FirstDungeonRewardDecisionConfig)
local Contracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local VariationPlanner = require(ReplicatedStorage.Shared.Expeditions.RunVariationPlanner)
local EncounterView = require(ReplicatedStorage.Shared.Expeditions.RunVariationEncounterView)
local CompositionReadback = require(ReplicatedStorage.Shared.Expeditions.RunVariationCompositionDebugReadback)
local DebugSchema = require(ReplicatedStorage.Shared.Expeditions.RunVariationDebugSchema)
local Bootstrap = require(script.Parent.ExpeditionServerBootstrap)
local Placement = require(script.Parent.ExpeditionRoomPlacementService)
local Barrier = require(script.Parent.ExpeditionRoomBarrierStateService)
local RewardResolver = require(script.Parent.ExpeditionBossRewardTransitionResolver)
local EnemyDirector = require(script.Parent.EnemyDirectorService)
local RunBuild = require(script.Parent.RunBuildService)

export type StartOptions = { Seed: number?, PartySize: number?, RunId: string? }

local Service = {}
local activeBootstrap: any = nil
local activeVariation: any = nil
local activeEncounterView: any = nil
local activeComposition: any = nil
local heartbeatConnection: RBXScriptConnection? = nil
local accumulatedSeconds = 0
local started = false
local lastStartFailure: any = nil

local STEP_INTERVAL_SECONDS = 0.25
local BossRewardDecision = RewardConfig.DecisionByRoomId["keeper-core"]
local PhaseIds, OutcomeIds = Contracts.PhaseIds, Contracts.OutcomeIds
local developmentMode = false
pcall(function()
	developmentMode = RunService:IsStudio()
end)

local function result(accepted: boolean, reasonId: string, snapshot: any?)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Snapshot = snapshot })
end

local function startFailure(reasonId: string, runId: any, seed: any): any
	lastStartFailure = table.freeze({ ReasonId = reasonId, RunId = runId, Seed = seed })
	return result(false, reasonId, nil)
end

local function nowUnix(): number return workspace:GetServerTimeNow() end
local function currentPartySize(): number
	return math.clamp(#Players:GetPlayers(), 1, ExpeditionConfig.Definitions.FirstExpedition.MaximumPlayers)
end
local function defaultSeed(): number
	local limits = ExpeditionConfig.RuntimeLimits
	return limits.MinimumSeed + (math.floor(nowUnix() * 1_000) % (limits.MaximumSeed - limits.MinimumSeed + 1))
end
local function validInteger(value: any): boolean return type(value) == "number" and value % 1 == 0 end
local function normalizeRunId(runId: any): any
	if type(runId) ~= "string" then return runId end
	return string.match(runId, "^%s*(.-)%s*$")
end
local function clearVariationState()
	activeVariation, activeEncounterView, activeComposition = nil, nil, nil
end
local function cleanupPartial()
	clearVariationState(); Barrier.reset(); Placement.destroy()
end

local function bindComposition(runId: string, variation: any, readback: any, durationMs: number?): any
	return table.freeze({
		RunId = runId,
		Seed = readback.Seed,
		RoomPlanIdentity = readback.RoomPlanIdentity,
		RunModifierId = readback.RunModifierId,
		HasSecretBranch = variation.SecretBranch ~= nil,
		HasOptionalObjective = variation.OptionalObjective ~= nil,
		CompositionDurationMs = durationMs,
		ActiveCompositionIdentity = DebugSchema.formatActiveCompositionIdentity(runId, readback.CompositionIdentity),
		Composition = readback,
	})
end

local function liveCompositionReadback(): any
	if activeBootstrap == nil or activeComposition == nil then return nil end
	local snapshot = activeBootstrap:getSnapshot()
	local context = activeBootstrap:getActiveEncounterContext()
	local currentRoomId = if context ~= nil then context.RoomId else nil
	local activeWaveIndex = nil
	if currentRoomId ~= nil and activeComposition.Composition ~= nil then
		local record = activeComposition.Composition.RecordByRoomId[currentRoomId]
		if record ~= nil then activeWaveIndex = record.SelectedWaveIndex end
	end
	local live = table.clone(activeComposition)
	live.CurrentEncounterPhaseId = if context ~= nil then context.PhaseId else if snapshot ~= nil then snapshot.PhaseId else nil
	live.CurrentRoomId = currentRoomId
	live.ActiveWaveIndex = activeWaveIndex
	return table.freeze(live)
end

local function disconnectHeartbeat()
	if heartbeatConnection ~= nil then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	accumulatedSeconds = 0
end

local function offerBossReward(previousSnapshot: any?, currentSnapshot: any?)
	local rewardEvent = RewardResolver.resolve(previousSnapshot, currentSnapshot, BossRewardDecision)
	if rewardEvent ~= nil then RunBuild.offerRelicRewardToParticipants(rewardEvent.EventId, rewardEvent.SourceId) end
end

local function driveStep()
	local bootstrap = activeBootstrap
	if bootstrap == nil then return end
	local previous = bootstrap:getSnapshot()
	local stepResult = bootstrap:step(nowUnix())
	local current = bootstrap:getSnapshot()
	Barrier.update(bootstrap:getActiveEncounterContext())
	if stepResult.Accepted == true then
		offerBossReward(previous, current)
	elseif stepResult.ReasonId ~= "EncounterInProgress" and stepResult.ReasonId ~= "PhaseMinimumDuration" and stepResult.ReasonId ~= "EncounterAlreadyActive" then
		warn("[ExpeditionLiveRuntime] step rejected:", stepResult.ReasonId)
	end
end

function Service.start()
	if started then return end
	started = true; accumulatedSeconds = 0
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < STEP_INTERVAL_SECONDS then return end
		accumulatedSeconds = 0; driveStep()
	end)
end

function Service.startExpedition(options: StartOptions?): any
	if not started then return result(false, "ServiceStopped", nil) end
	if activeBootstrap ~= nil then return result(false, "ExpeditionAlreadyActive", activeBootstrap:getSnapshot()) end
	clearVariationState()
	local requested = options or {}
	local seed = requested.Seed or defaultSeed()
	local partySize = requested.PartySize or currentPartySize()
	local runId = normalizeRunId(requested.RunId or ("expedition:" .. HttpService:GenerateGUID(false)))
	local limits, definition = ExpeditionConfig.RuntimeLimits, ExpeditionConfig.Definitions.FirstExpedition
	if not validInteger(seed) or seed < limits.MinimumSeed or seed > limits.MaximumSeed then return startFailure("InvalidSeed", runId, seed) end
	if not validInteger(partySize) or partySize < definition.MinimumPlayers or partySize > definition.MaximumPlayers then return startFailure("InvalidPartySize", runId, seed) end
	if type(runId) ~= "string" or #runId < 8 or #runId > 96 then return startFailure("InvalidRunId", runId, seed) end

	local ok, bootstrapOrError = pcall(function()
		return Bootstrap.new(EnemyDirector, { RunId = runId, Seed = seed, PartySize = partySize, StartedAtUnix = nowUnix() })
	end)
	if not ok then cleanupPartial(); warn("[ExpeditionLiveRuntime] failed to create expedition:", bootstrapOrError); return startFailure("ExpeditionCreationFailed", runId, seed) end
	local bootstrap = bootstrapOrError
	local roomPlan = bootstrap:getRoomPlan()

	local variationOk, variationOrError = pcall(function() return VariationPlanner.plan(roomPlan) end)
	if not variationOk then bootstrap:destroy(); cleanupPartial(); warn("[ExpeditionLiveRuntime] failed to compose run variation:", variationOrError); return startFailure("RunVariationPlanningFailed", runId, seed) end
	local viewOk, viewOrError = pcall(function() return EncounterView.build(roomPlan, variationOrError) end)
	if not viewOk then bootstrap:destroy(); cleanupPartial(); warn("[ExpeditionLiveRuntime] failed to compose run variation encounter view:", viewOrError); return startFailure("RunVariationEncounterViewFailed", runId, seed) end

	local compositionStarted = if developmentMode then os.clock() else nil
	local compositionOk, compositionOrError = pcall(function()
		local readback = CompositionReadback.build(roomPlan)
		local durationMs = if compositionStarted ~= nil then math.max(0, (os.clock() - compositionStarted) * 1_000) else nil
		return bindComposition(runId, variationOrError, readback, durationMs)
	end)
	if not compositionOk then bootstrap:destroy(); cleanupPartial(); warn("[ExpeditionLiveRuntime] failed to compose run variation readback:", compositionOrError); return startFailure("RunVariationCompositionFailed", runId, seed) end

	local placement = Placement.place(roomPlan)
	if placement.Accepted ~= true then bootstrap:destroy(); clearVariationState(); Barrier.reset(); Placement.destroy(); warn("[ExpeditionLiveRuntime] failed to place expedition rooms:", placement.ReasonId); return startFailure(placement.ReasonId, runId, seed) end
	Barrier.reset()
	activeBootstrap, activeVariation, activeEncounterView, activeComposition = bootstrap, variationOrError, viewOrError, compositionOrError
	lastStartFailure = nil; driveStep()
	return result(true, "ExpeditionStarted", activeBootstrap:getSnapshot())
end

function Service.markSecretDiscovered(expectedRunId: string): any
	if not started then return result(false, "ServiceStopped", nil) end
	local bootstrap = activeBootstrap
	if bootstrap == nil then return result(false, "NoActiveExpedition", nil) end
	local snapshot = bootstrap:getSnapshot()
	if snapshot == nil then return result(false, "NoActiveExpedition", nil) end
	if type(expectedRunId) ~= "string" or expectedRunId ~= snapshot.RunId then return result(false, "StaleRun", snapshot) end
	if snapshot.OutcomeId ~= OutcomeIds.InProgress then return result(false, "RunTerminal", snapshot) end
	if snapshot.PhaseId ~= PhaseIds.Approach then return result(false, "DiscoveryPhaseInvalid", snapshot) end
	if snapshot.SecretDiscovered == true then return result(false, "SecretAlreadyDiscovered", snapshot) end
	local runtime = (bootstrap :: any).Runtime
	if runtime == nil or type(runtime.markSecretDiscovered) ~= "function" then return result(false, "SecretMutationUnavailable", snapshot) end
	if runtime:markSecretDiscovered() ~= true then return result(false, "SecretClaimRejected", bootstrap:getSnapshot()) end
	return result(true, "SecretDiscovered", bootstrap:getSnapshot())
end

function Service.stopExpedition(reasonId: string?): any
	local bootstrap = activeBootstrap
	if bootstrap == nil then return result(false, "NoActiveExpedition", nil) end
	local snapshot = bootstrap:getSnapshot()
	bootstrap:destroy(); activeBootstrap = nil; clearVariationState(); Barrier.reset(); Placement.destroy()
	return result(true, reasonId or "ExpeditionStopped", snapshot)
end

function Service.readSnapshot(): any return if activeBootstrap then activeBootstrap:getSnapshot() else nil end
function Service.readRoomPlan(): any return if activeBootstrap then activeBootstrap:getRoomPlan() else nil end
function Service.readRunVariationPlan(): any return if activeBootstrap then activeVariation else nil end
function Service.readRunVariationEncounterView(): any return if activeBootstrap then activeEncounterView else nil end
function Service.readRunVariationComposition(): any return liveCompositionReadback() end
function Service.readLastStartFailure(): any return lastStartFailure end

function Service.stop()
	if not started then return end
	started = false; disconnectHeartbeat()
	if activeBootstrap ~= nil then activeBootstrap:destroy(); activeBootstrap = nil end
	clearVariationState(); Barrier.reset(); Placement.destroy()
end

return table.freeze(Service)
