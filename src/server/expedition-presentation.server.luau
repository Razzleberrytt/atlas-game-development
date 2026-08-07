--!strict

-- Read-only expedition presentation bridge. It discloses a sanitized snapshot
-- and accepts no client mutation. Late joiners may fetch the current view through
-- ReadState; consequential expedition control remains in ServerStorage only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ExpeditionLiveRuntimeService = require(script.Parent.Systems.ExpeditionLiveRuntimeService)

local existing = ReplicatedStorage:FindFirstChild("ExpeditionNetwork")
if existing ~= nil then
	existing:Destroy()
end

local network = Instance.new("Folder")
network.Name = "ExpeditionNetwork"
network.Parent = ReplicatedStorage

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = network

local readState = Instance.new("RemoteFunction")
readState.Name = "ReadState"
readState.Parent = network

local OBJECTIVE_BY_PHASE: { [string]: string } = {
	Preparation = "Prepare your loadout and enter the descent.",
	Approach = "Reach the ruined entrance and clear the approach.",
	Dungeon = "Advance through the seeded descent.",
	Elite = "Defeat the Warden blocking the inner gate.",
	Boss = "Defeat the Keeper at the expedition core.",
	Rewards = "Secure the expedition rewards.",
	Results = "Review the expedition outcome.",
}

local function safeSnapshot(): any
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil then
		return nil
	end
	return table.freeze({
		RunId = snapshot.RunId,
		PhaseId = snapshot.PhaseId,
		PhaseIndex = snapshot.PhaseIndex,
		PhaseCount = 7,
		OutcomeId = snapshot.OutcomeId,
		PartySize = snapshot.PartySize,
		SecretDiscovered = snapshot.SecretDiscovered,
		ObjectiveText = OBJECTIVE_BY_PHASE[snapshot.PhaseId] or "Continue the expedition.",
	})
end

readState.OnServerInvoke = function(_player: Player): any
	return safeSnapshot()
end

local lastSignature = ""
local accumulated = 0
local connection = RunService.Heartbeat:Connect(function(deltaTime)
	accumulated += deltaTime
	if accumulated < 0.5 then
		return
	end
	accumulated = 0
	local snapshot = safeSnapshot()
	local signature = if snapshot == nil
		then "none"
		else string.format(
			"%s|%s|%s|%s",
			snapshot.RunId,
			snapshot.PhaseId,
			snapshot.OutcomeId,
			tostring(snapshot.SecretDiscovered)
		)
	if signature == lastSignature then
		return
	end
	lastSignature = signature
	stateRemote:FireAllClients(snapshot)
end)

Players.PlayerAdded:Connect(function(player)
	local snapshot = safeSnapshot()
	if snapshot ~= nil then
		stateRemote:FireClient(player, snapshot)
	end
end)

game:BindToClose(function()
	connection:Disconnect()
end)
