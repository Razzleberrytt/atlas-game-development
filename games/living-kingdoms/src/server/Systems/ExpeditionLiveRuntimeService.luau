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

local ExpeditionConfig = require(game:GetService("ReplicatedStorage").Shared.Config.ExpeditionConfig)
local ExpeditionServerBootstrap = require(script.Parent.ExpeditionServerBootstrap)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)

export type StartOptions = {
	Seed: number?,
	PartySize: number?,
	RunId: string?,
}

local Service = {}

local activeBootstrap: any = nil
local heartbeatConnection: RBXScriptConnection? = nil
local accumulatedSeconds = 0
local started = false

local STEP_INTERVAL_SECONDS = 0.25

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

local function driveStep()
	local bootstrap = activeBootstrap
	if bootstrap == nil then
		return
	end
	local stepResult = bootstrap:step(nowUnix())
	if stepResult.Accepted ~= true
		and stepResult.ReasonId ~= "EncounterInProgress"
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
	if not validInteger(partySize) or partySize < definition.MinimumPlayers or partySize > definition.MaximumPlayers then
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

	activeBootstrap = bootstrapOrError
	driveStep()
	return result(true, "ExpeditionStarted", activeBootstrap:getSnapshot())
end

function Service.stopExpedition(reasonId: string?): any
	local bootstrap = activeBootstrap
	if bootstrap == nil then
		return result(false, "NoActiveExpedition", nil)
	end
	local snapshot = bootstrap:getSnapshot()
	bootstrap:destroy()
	activeBootstrap = nil
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
end

return table.freeze(Service)
