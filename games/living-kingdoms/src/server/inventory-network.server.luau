--!strict

--[[
	Blueprint v2.0 queue item 1 — the owner-only inventory read boundary.

	This is the only path by which inventory state reaches a client. The owner is
	always `player.UserId` taken from the invocation itself; no argument can name
	an inventory. A client that supplies an identity is rejected outright rather
	than silently ignored, so probing another player's inventory is observable as
	a rejection instead of quietly returning the caller's own data.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryLiveService = require(script.Parent.Systems.InventoryLiveService)

local existing = ReplicatedStorage:FindFirstChild("InventoryNetwork")
if existing ~= nil then
	existing:Destroy()
end

local network = Instance.new("Folder")
network.Name = "InventoryNetwork"
network.Parent = ReplicatedStorage

local readOwnInventory = Instance.new("RemoteFunction")
readOwnInventory.Name = "ReadOwnInventory"
readOwnInventory.Parent = network

local state = Instance.new("RemoteEvent")
state.Name = "State"
state.Parent = network

local function rejected(reasonId: string): any
	return table.freeze({ Accepted = false, ReasonId = reasonId, Snapshot = nil })
end

local function readFor(player: Player): any
	return InventoryLiveService.readOwnedSnapshot(player.UserId, player.UserId)
end

readOwnInventory.OnServerInvoke = function(player: Player, requestedOwnerId: any): any
	-- The remote takes no owner argument. Anything supplied is an attempt to
	-- read an inventory the connection does not own.
	if requestedOwnerId ~= nil then
		return rejected("CrossPlayerInventoryAccess")
	end
	return readFor(player)
end

--[[
	Pushes the owner their own snapshot. Every send is addressed to exactly one
	player and built from that player's identity, so a broadcast helper that
	could fan one inventory out to the server deliberately does not exist.
]]
local function pushTo(player: Player)
	state:FireClient(player, readFor(player))
end

Players.PlayerAdded:Connect(pushTo)
for _, player in Players:GetPlayers() do
	pushTo(player)
end

print("[Living Kingdoms] Inventory network mounted")
