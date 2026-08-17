--!strict

-- Client presentation safety veto for mutually exclusive expedition surfaces.
-- It never sends requests. While a run is active it force-closes preparation
-- and terminal surfaces; outside a run, the hub interaction layer decides when
-- the lobby is opened instead of this controller forcing it visible.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NETWORK_WAIT_SECONDS = 20

local Controller = {}
local started = false
local connection: RBXScriptConnection? = nil

local function setEnabled(name: string, enabled: boolean)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	local gui = playerGui:FindFirstChild(name)
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = enabled
	end
end

local function apply(snapshot: any)
	local active = type(snapshot) == "table" and snapshot.OutcomeId == "InProgress"
	if active then
		setEnabled("LK_ExpeditionLobby", false)
		setEnabled("LK_ExpeditionResult", false)
		setEnabled("LK_ExpeditionReturn", false)
		setEnabled("LK_ExpeditionReplayDecision", false)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	local network = ReplicatedStorage:WaitForChild("ExpeditionNetwork", NETWORK_WAIT_SECONDS)
	assert(network ~= nil, "ExpeditionNetwork did not become available before the client bootstrap timeout")
	local state = network:WaitForChild("State", NETWORK_WAIT_SECONDS)
	assert(state ~= nil, "ExpeditionNetwork.State did not become available before the client bootstrap timeout")
	local readState = network:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)
	assert(readState ~= nil, "ExpeditionNetwork.ReadState did not become available before the client bootstrap timeout")
	connection = state.OnClientEvent:Connect(apply)
	local ok, snapshot = pcall(function()
		return readState:InvokeServer()
	end)
	if ok then
		apply(snapshot)
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Controller
