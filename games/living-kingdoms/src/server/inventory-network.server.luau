--!strict

--[[
	Blueprint v2.0 owner-only inventory network plus the live persistence lifecycle.

	Inventory identity is always derived from the invoking Player. This script also
	owns the application-scoped lease lifecycle required by InventoryLiveService:
	load/acquire on join, periodic renewal while connected, release on leave, and
	final release on shutdown. Character progression hydrates and commits through
	the same lease owner; no client mutation surface is introduced.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryLiveService = require(script.Parent.Systems.InventoryLiveService)
local CharacterProgressionService = require(script.Parent.Systems.CharacterProgressionService)
local OperativeLifeService = require(script.Parent.Systems.OperativeLifeService)

local LEASE_RENEW_INTERVAL_SECONDS = 30

assert(
	CharacterProgressionService.configurePersistence(
		function(playerId, progressionState, sourceId, attributionId, nowUnix)
			return InventoryLiveService.saveCharacterProgression(
				playerId,
				progressionState,
				sourceId,
				attributionId,
				nowUnix
			)
		end
	),
	"character progression persistence writer must bind"
)

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

local equipOwnedItem = Instance.new("RemoteFunction")
equipOwnedItem.Name = "EquipOwnedItem"
equipOwnedItem.Parent = network

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

local function reconcileEquipmentEffects(player: Player)
	OperativeLifeService.reconcileMaximumHealth(player)
	OperativeLifeService.reconcileMovementSpeed(player)
end

--[[
	A player whose leased persistence could not load must not keep playing. Their
	session would run against no durable record and whichever server holds the
	lease owns the truth they would be diverging from.
]]
local function loadPlayer(player: Player)
	local loaded = InventoryLiveService.loadPlayer(player.UserId, os.time())
	if loaded.Accepted ~= true then
		warn(string.format("[InventoryNetwork] persistence load rejected for %d: %s", player.UserId, loaded.ReasonId))
		if player.Parent == Players then
			player:Kick(
				"Your saved character is active on another server or could not be loaded safely. Please rejoin."
			)
		end
		return
	end
	if player.Parent ~= Players then
		InventoryLiveService.releasePlayer(player.UserId)
		return
	end
	local hydrated = CharacterProgressionService.hydratePlayer(player, loaded.ProgressionState)
	if hydrated.Accepted ~= true then
		InventoryLiveService.releasePlayer(player.UserId)
		if player.Parent == Players then
			player:Kick("Your character progression could not be loaded safely. Please rejoin.")
		end
		return
	end
	loadedPlayerIds[player.UserId] = true
	reconcileEquipmentEffects(player)
	pushTo(player)
end

local function releasePlayer(player: Player)
	loadedPlayerIds[player.UserId] = nil
	local released = InventoryLiveService.releasePlayer(player.UserId)
	if released.Accepted ~= true and released.ReasonId ~= "LeaseNotOwned" then
		warn(
			string.format(
				"[InventoryNetwork] persistence lease release rejected for %d: %s",
				player.UserId,
				released.ReasonId
			)
		)
	end
end

readOwnInventory.OnServerInvoke = function(player: Player, requestedOwnerId: any): any
	if requestedOwnerId ~= nil then
		return rejected("CrossPlayerInventoryAccess")
	end
	return readFor(player)
end

compareOwnedItem.OnServerInvoke = function(player: Player, candidateInstanceId: any): any
	if type(candidateInstanceId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidCandidateItem", Comparison = nil })
	end
	return InventoryLiveService.compareOwnedItem(player.UserId, player.UserId, candidateInstanceId)
end

-- The client names only an owned instance. Slot, definition and any combat
-- WeaponId are derived by server-owned inventory/config state.
equipOwnedItem.OnServerInvoke = function(player: Player, instanceId: any): any
	if type(instanceId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidEquipRequest" })
	end
	local outcome = InventoryLiveService.equipOwnedItem(player.UserId, player.UserId, instanceId, os.time())
	if outcome.Accepted == true then
		reconcileEquipmentEffects(player)
		pushTo(player)
	end
	return table.freeze({ Accepted = outcome.Accepted == true, ReasonId = outcome.ReasonId })
end

dismantleOwnedItem.OnServerInvoke = function(player: Player, instanceId: any, transactionId: any): any
	if type(instanceId) ~= "string" or type(transactionId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidDismantleRequest", Outcome = nil })
	end
	local outcome =
		InventoryLiveService.dismantleOwnedItem(player.UserId, player.UserId, instanceId, transactionId, os.time())
	if outcome.Accepted == true then
		reconcileEquipmentEffects(player)
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
						"[InventoryNetwork] persistence lease renewal rejected for %d: %s",
						player.UserId,
						renewed.ReasonId
					)
				)
				loadedPlayerIds[player.UserId] = nil
				InventoryLiveService.releasePlayer(player.UserId)
				if player.Parent == Players then
					player:Kick("Your saved-character session could no longer be protected. Please rejoin.")
				end
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

print("[Living Kingdoms] Inventory, progression, and lease lifecycle mounted")
