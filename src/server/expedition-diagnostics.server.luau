--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Systems = script.Parent.Systems
local ExpeditionDiagnosticsService = require(Systems.ExpeditionDiagnosticsService)
local ExpeditionLiveRuntimeService = require(Systems.ExpeditionLiveRuntimeService)

local journal = ExpeditionDiagnosticsService.new(200)
local lastSignature = "none"
local accumulated = 0

local existing = ServerStorage:FindFirstChild("ExpeditionDiagnostics")
if existing then
	existing:Destroy()
end
local control = Instance.new("BindableFunction")
control.Name = "ExpeditionDiagnostics"
control.Parent = ServerStorage

local function signature(snapshot: any): string
	if snapshot == nil then
		return "none"
	end
	return table.concat(
		{ snapshot.RunId, snapshot.PhaseId, snapshot.OutcomeId, tostring(snapshot.SecretDiscovered) },
		"|"
	)
end

local function capture()
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	local nextSignature = signature(snapshot)
	if nextSignature == lastSignature then
		return
	end
	lastSignature = nextSignature
	if snapshot == nil then
		journal:record("ExpeditionCleared", { PlayerCount = #Players:GetPlayers() }, Workspace:GetServerTimeNow())
		return
	end
	journal:record("ExpeditionStateChanged", {
		RunId = snapshot.RunId,
		PhaseId = snapshot.PhaseId,
		OutcomeId = snapshot.OutcomeId,
		PartySize = snapshot.PartySize,
		PlayerCount = #Players:GetPlayers(),
		SecretDiscovered = snapshot.SecretDiscovered,
	}, Workspace:GetServerTimeNow())
end

control.OnInvoke = function(action: any): any
	if action == "Read" then
		return journal:read()
	end
	if action == "Clear" then
		journal:clear()
		return true
	end
	return nil
end

local connection = RunService.Heartbeat:Connect(function(deltaTime)
	accumulated += deltaTime
	if accumulated < 0.25 then
		return
	end
	accumulated = 0
	capture()
end)

Players.PlayerAdded:Connect(function(player)
	journal:record(
		"PlayerJoined",
		{ PlayerId = player.UserId, PlayerCount = #Players:GetPlayers() },
		Workspace:GetServerTimeNow()
	)
end)
Players.PlayerRemoving:Connect(function(player)
	journal:record(
		"PlayerRemoving",
		{ PlayerId = player.UserId, PlayerCount = #Players:GetPlayers() - 1 },
		Workspace:GetServerTimeNow()
	)
end)

game:BindToClose(function()
	connection:Disconnect()
	journal:record("ServerClosing", { PlayerCount = #Players:GetPlayers() }, Workspace:GetServerTimeNow())
	journal:destroy()
end)

print("[Living Kingdoms] Expedition diagnostics mounted")
