--!strict

--[[
	Application-scope compatibility listener for HordeNetwork.State.

	Blueprint v2.7 requires the legacy RemoteEvent to have an effective client
	listener before slower UI/presentation controllers are constructed. This
	module intentionally owns no gameplay and no presentation; it only consumes
	and retains the latest server-authored snapshot so startup publishes cannot
	accumulate in Roblox's unhandled RemoteEvent invocation queue.

	All domain controllers consume this state through subscribe(). This module is
	the only owner of the physical HordeNetwork.State RemoteEvent connection.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NETWORK_WAIT_SECONDS = 20

local RuntimeRolloutConfig = require(ReplicatedStorage.Shared.Config.RuntimeRolloutConfig)

local HordeStateEarlyListener = {}

local started = false
local stateConnection: RBXScriptConnection? = nil
local activeListenerCount = 0
local latestSnapshot: any = nil
local receivedCount = 0
local invalidMessageCount = 0
local diagnosticNetwork: Instance? = nil
local snapshotSignal = Instance.new("BindableEvent")
snapshotSignal.Name = "HordeStateEarlyListenerSignal"

local function readActiveListenerCount(): number
	local connection = stateConnection
	if connection == nil or not connection.Connected then
		return 0
	end
	return activeListenerCount
end

local function writeDiagnostics()
	if not RuntimeRolloutConfig.EnableRuntimeCounters then
		return
	end
	local network = diagnosticNetwork
	if network == nil then
		return
	end
	local listenerCount = readActiveListenerCount()
	network:SetAttribute("V27_EarlyStateListenerBound", listenerCount == 1)
	network:SetAttribute("V27_EarlyStateListenerCount", listenerCount)
	network:SetAttribute("V27_StateMessagesReceived", receivedCount)
	network:SetAttribute("V27_StateInvalidMessages", invalidMessageCount)
	local snapshot = latestSnapshot
	local revision = if type(snapshot) == "table" then snapshot.revision else nil
	if type(revision) == "number" then
		network:SetAttribute("V27_StateLastRevision", revision)
	end
end

local function onState(message: unknown)
	if type(message) ~= "table" then
		invalidMessageCount += 1
		writeDiagnostics()
		return
	end
	receivedCount += 1
	latestSnapshot = message
	writeDiagnostics()
	snapshotSignal:Fire(message)
end

function HordeStateEarlyListener.start()
	if started then
		return
	end

	local network = ReplicatedStorage:WaitForChild("HordeNetwork", NETWORK_WAIT_SECONDS)
	assert(network ~= nil, "HordeNetwork did not become available before the client bootstrap timeout")
	diagnosticNetwork = network
	local stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS)
	assert(stateRemote ~= nil, "HordeNetwork.State did not become available before the client bootstrap timeout")
	assert(stateRemote:IsA("RemoteEvent"), "HordeNetwork.State must be a RemoteEvent")

	-- Bind synchronously before the rest of the application controller graph is
	-- required or started. This is the R1 compatibility listener.
	stateConnection = stateRemote.OnClientEvent:Connect(onState)
	activeListenerCount += 1
	started = true
	writeDiagnostics()
end

function HordeStateEarlyListener.readLatest(): any
	return latestSnapshot
end

function HordeStateEarlyListener.getActiveListenerCount(): number
	return readActiveListenerCount()
end

function HordeStateEarlyListener.subscribe(callback: (any) -> ()): RBXScriptConnection
	assert(type(callback) == "function", "subscribe callback must be a function")
	local connection = snapshotSignal.Event:Connect(callback)
	local snapshot = latestSnapshot
	if snapshot ~= nil then
		task.defer(callback, snapshot)
	end
	return connection
end

function HordeStateEarlyListener.stop()
	if not started then
		return
	end
	started = false
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
		activeListenerCount -= 1
	end
	assert(activeListenerCount == 0, "Horde state listener count must return to zero on stop")
	latestSnapshot = nil
	writeDiagnostics()
	diagnosticNetwork = nil
	receivedCount = 0
	invalidMessageCount = 0
end

return table.freeze(HordeStateEarlyListener)
