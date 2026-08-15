--!strict

-- Studio-only deterministic run harness. It is server-only (ServerStorage
-- BindableFunction) and exposes no client remote or production mutation path.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Systems = script.Parent.Systems
local ExpeditionLiveRuntimeService = require(Systems.ExpeditionLiveRuntimeService)
local ExpeditionRunStateService = require(Systems.ExpeditionRunStateService)

local isStudio = false
pcall(function()
	isStudio = RunService:IsStudio()
end)
if not isStudio then
	return nil
end

local existing = ServerStorage:FindFirstChild("ExpeditionRunDevelopment")
if existing ~= nil then
	existing:Destroy()
end
local control = Instance.new("BindableFunction")
control.Name = "ExpeditionRunDevelopment"
control.Parent = ServerStorage

local function stopped(): any
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil then
		return table.freeze({ Accepted = false, ReasonId = "NoActiveExpedition" })
	end
	ExpeditionRunStateService.fail(snapshot.RunId, "DevelopmentForceCleanup", Workspace:GetServerTimeNow(), "Abandoned")
	return ExpeditionLiveRuntimeService.stopExpedition("DevelopmentForceCleanup")
end

control.OnInvoke = function(action: any, payload: any?): any
	if action == "StartSeed" then
		local request = if type(payload) == "table" then payload else {}
		return ExpeditionLiveRuntimeService.startExpedition({
			Seed = request.Seed,
			PartySize = request.PartySize or math.max(1, #Players:GetPlayers()),
			RunId = request.RunId,
		})
	elseif action == "ReplayLastSeed" then
		if ExpeditionLiveRuntimeService.readSnapshot() ~= nil then
			return table.freeze({ Accepted = false, ReasonId = "ExpeditionAlreadyActive" })
		end
		local previous = ExpeditionRunStateService.readLastResult()
		if previous == nil then
			return table.freeze({ Accepted = false, ReasonId = "NoPreviousRun" })
		end
		return ExpeditionLiveRuntimeService.startExpedition({
			Seed = previous.Seed,
			PartySize = math.max(1, #Players:GetPlayers()),
		})
	elseif action == "ReadSnapshot" then
		return ExpeditionLiveRuntimeService.readSnapshot()
	elseif action == "ReadRoomPlan" then
		return ExpeditionLiveRuntimeService.readRoomPlan()
	elseif action == "ReadRunState" then
		local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
		return if snapshot ~= nil then ExpeditionRunStateService.read(snapshot.RunId) else nil
	elseif action == "ReadLastRunResult" then
		return ExpeditionRunStateService.readLastResult()
	elseif action == "ForceCleanup" then
		return stopped()
	end
	return table.freeze({ Accepted = false, ReasonId = "UnknownAction" })
end

game:BindToClose(function()
	if control.Parent ~= nil then
		control:Destroy()
	end
end)

print("[Living Kingdoms] Expedition run development harness mounted")
