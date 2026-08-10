--!strict

-- Read-only client disclosure for durable Operative Rank. There is deliberately
-- no progression mutation RemoteEvent: the client can ask only for its own
-- server-derived snapshot after the inventory owner has loaded durable state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeProgressionService = require(script.Parent.Systems.OperativeProgressionService)

local existing = ReplicatedStorage:FindFirstChild("OperativeProgressionNetwork")
if existing ~= nil then
	existing:Destroy()
end

local network = Instance.new("Folder")
network.Name = "OperativeProgressionNetwork"
network.Parent = ReplicatedStorage

local readState = Instance.new("RemoteFunction")
readState.Name = "ReadState"
readState.Parent = network

readState.OnServerInvoke = function(player: Player): any
	return OperativeProgressionService.readOwnedSnapshot(player.UserId, player.UserId)
end

print("[Living Kingdoms] Read-only operative progression network mounted")
