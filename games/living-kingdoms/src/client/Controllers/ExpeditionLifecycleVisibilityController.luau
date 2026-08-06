--!strict

-- Central client presentation policy for mutually exclusive expedition surfaces.
-- It never sends requests; it only hides preparation UI while a run is active
-- and restores it when no run exists or a terminal result is reached.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local started = false
local connection: RBXScriptConnection? = nil

local function setEnabled(name: string, enabled: boolean)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(name)
	if gui and gui:IsA("ScreenGui") then gui.Enabled = enabled end
end

local function apply(snapshot: any)
	local active = type(snapshot) == "table" and snapshot.OutcomeId == "InProgress"
	setEnabled("LK_ExpeditionLobby", not active)
	if active then
		setEnabled("LK_ExpeditionResult", false)
		setEnabled("LK_ExpeditionReturn", false)
		setEnabled("LK_ExpeditionReplayDecision", false)
	end
end

function Controller.start()
	if started then return end
	started = true
	local network = ReplicatedStorage:WaitForChild("ExpeditionNetwork")
	local state = network:WaitForChild("State") :: RemoteEvent
	local readState = network:WaitForChild("ReadState") :: RemoteFunction
	connection = state.OnClientEvent:Connect(apply)
	local ok, snapshot = pcall(function() return readState:InvokeServer() end)
	if ok then apply(snapshot) end
end

function Controller.stop()
	if not started then return end
	started = false
	if connection then connection:Disconnect(); connection = nil end
end

return Controller
