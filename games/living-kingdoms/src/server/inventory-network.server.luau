--!strict

--[[
	Blueprint v2.0 owner-only inventory network plus the live persistence lifecycle.

	Inventory identity is always derived from the invoking Player. This script also
	owns the application-scoped lease lifecycle required by InventoryLiveService:
	load/acquire on join, periodic renewal while connected, release on leave, and
	final release on shutdown. A snapshot is only pushed after a successful load.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryLiveService = require(script.Parent.Systems.InventoryLiveService)

local LEASE_RENEW_INTERVAL_SECONDS = 30

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

local compareOwnedItem = Instance.new("RemoteFunction")
compareOwnedItem.Name = "CompareOwnedItem"
compareOwnedItem.Parent = network

local dismantleOwnedItem = Instance.new("RemoteFunction")
dismantleOwnedItem.Name = "DismantleOwnedItem"
dismantleOwnedItem.Parent = network

local state = Instance.new("RemoteEvent")
state.Name = "State"
state.Parent = network

local loadedPlayerIds: { [number]: boolean } = {}
local renewalAccumulatorSeconds = 0

local function rejected(reasonId: string): any
	return table.freeze({ Accepted = false, ReasonId = reasonId, Snapshot = nil })
end

local function readFor(player: Player): any
	return InventoryLiveService.readOwnedSnapshot(player.UserId, player.UserId)
end

-- Pushes the owner their own snapshot. Every send is addressed to exactly one
-- player and built from that player's identity, so one inventory can never fan
-- out to another player.
local function pushTo(player: Player)
	state:FireClient(player, readFor(player))
end

local function loadPlayer(player: Player)
	local loaded = InventoryLiveService.loadPlayer(player.UserId, os.time())
	if loaded.Accepted ~= true then
		warn(string.format("[InventoryNetwork] inventory load rejected for %d: %s", player.UserId, loaded.ReasonId))
		return
	end
	if player.Parent ~= Players then
		InventoryLiveService.releasePlayer(player.UserId)
		return
	end
	loadedPlayerIds[player.UserId] = true
	pushTo(player)
end

local function releasePlayer(player: Player)
	loadedPlayerIds[player.UserId] = nil
	local released = InventoryLiveService.releasePlayer(player.UserId)
	if released.Accepted ~= true and released.ReasonId ~= "LeaseNotOwned" then
		warn(
			string.format(
				"[InventoryNetwork] inventory lease release rejected for %d: %s",
				player.UserId,
				released.ReasonId
			)
		)
	end
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
	Comparison takes only a candidate instance id, and the server resolves both
	the candidate and the incumbent from the caller's own record. A client cannot
	submit item values to be compared, so it cannot have the server evaluate an
	item it does not hold.
]]
compareOwnedItem.OnServerInvoke = function(player: Player, candidateInstanceId: any): any
	if type(candidateInstanceId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidCandidateItem", Comparison = nil })
	end
	return InventoryLiveService.compareOwnedItem(player.UserId, player.UserId, candidateInstanceId)
end

--[[
	Destroys one owned item. The client supplies an instance id and a transaction
	id; the transaction id exists only so a retry after a dropped response is
	idempotent. The server derives the owner, the clock, and the item's value.

	The owner is pushed a fresh snapshot after an accepted destruction so the
	client corrects rather than tracking removals itself.
]]
dismantleOwnedItem.OnServerInvoke = function(player: Player, instanceId: any, transactionId: any): any
	if type(instanceId) ~= "string" or type(transactionId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidDismantleRequest", Outcome = nil })
	end
	local outcome =
		InventoryLiveService.dismantleOwnedItem(player.UserId, player.UserId, instanceId, transactionId, os.time())
	if outcome.Accepted == true then
		pushTo(player)
	end
	return table.freeze({
		Accepted = outcome.Accepted == true,
		ReasonId = outcome.ReasonId,
		Outcome = outcome.Outcome,
	})
end

local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)
local playerRemovingConnection = Players.PlayerRemoving:Connect(releasePlayer)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
	renewalAccumulatorSeconds += deltaTime
	if renewalAccumulatorSeconds < LEASE_RENEW_INTERVAL_SECONDS then
		return
	end
	renewalAccumulatorSeconds = 0
	local nowUnix = os.time()
	for _, player in Players:GetPlayers() do
		if loadedPlayerIds[player.UserId] then
			local renewed = InventoryLiveService.renewPlayer(player.UserId, nowUnix)
			if renewed.Accepted ~= true then
				warn(
					string.format(
						"[InventoryNetwork] inventory lease renewal rejected for %d: %s",
						player.UserId,
						renewed.ReasonId
					)
				)
			end
		end
	end
end)

game:BindToClose(function()
	heartbeatConnection:Disconnect()
	playerAddedConnection:Disconnect()
	playerRemovingConnection:Disconnect()
	table.clear(loadedPlayerIds)
	InventoryLiveService.destroy()
end)

print("[Living Kingdoms] Inventory network and lease lifecycle mounted")
