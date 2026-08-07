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

local HordeStateEarlyListener = {}

local started = false
local stateConnection: RBXScriptConnection? = nil
local latestSnapshot: any = nil
local snapshotSignal = Instance.new("BindableEvent")
snapshotSignal.Name = "HordeStateEarlyListenerSignal"

local function onState(message: unknown)
	if type(message) ~= "table" then
		return
	end
	latestSnapshot = message
	snapshotSignal:Fire(message)
end

function HordeStateEarlyListener.start()
	if started then
		return
	end
	started = true

	local network = ReplicatedStorage:WaitForChild("HordeNetwork")
	local stateRemote = network:WaitForChild("State")
	assert(stateRemote:IsA("RemoteEvent"), "HordeNetwork.State must be a RemoteEvent")

	-- Bind synchronously before the rest of the application controller graph is
	-- required or started. This is the R1 compatibility listener.
	stateConnection = stateRemote.OnClientEvent:Connect(onState)
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
end

return table.freeze(HordeStateEarlyListener)
