--!strict

--[[
	Application-scope compatibility listener for HordeNetwork.State.

	Blueprint v2.7 requires the legacy RemoteEvent to have an effective client
	listener before slower UI/presentation controllers are constructed. This
	module intentionally owns no gameplay and no presentation; it only consumes
	and retains the latest server-authored snapshot so startup publishes cannot
	accumulate in Roblox's unhandled RemoteEvent invocation queue.

	Domain controllers may migrate to subscribe() over time. Until then, their
	existing direct listeners can coexist during the controlled rollout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeRolloutConfig = require(ReplicatedStorage.Shared.Config.RuntimeRolloutConfig)

local HordeStateEarlyListener = {}

local started = false
local stateConnection: RBXScriptConnection? = nil
local latestSnapshot: any = nil
local receivedCount = 0
local invalidMessageCount = 0
local diagnosticNetwork: Instance? = nil
local snapshotSignal = Instance.new("BindableEvent")
snapshotSignal.Name = "HordeStateEarlyListenerSignal"

local function writeDiagnostics()
	if not RuntimeRolloutConfig.EnableRuntimeCounters then
		return
	end
	local network = diagnosticNetwork
	if network == nil then
		return
	end
	network:SetAttribute("V27_EarlyStateListenerBound", started and stateConnection ~= nil)
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
	started = true

	local network = ReplicatedStorage:WaitForChild("HordeNetwork")
	diagnosticNetwork = network
	local stateRemote = network:WaitForChild("State")
	assert(stateRemote:IsA("RemoteEvent"), "HordeNetwork.State must be a RemoteEvent")

	-- Bind synchronously before the rest of the application controller graph is
	-- required or started. This is the R1 compatibility listener.
	stateConnection = stateRemote.OnClientEvent:Connect(onState)
	writeDiagnostics()
end

function HordeStateEarlyListener.readLatest(): any
	return latestSnapshot
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
	end
	latestSnapshot = nil
	writeDiagnostics()
	diagnosticNetwork = nil
	receivedCount = 0
	invalidMessageCount = 0
end

return table.freeze(HordeStateEarlyListener)
