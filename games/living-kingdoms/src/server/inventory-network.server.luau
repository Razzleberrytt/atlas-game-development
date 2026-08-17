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

local EquipmentCombatAdapter = require(script.Parent.Systems.EquipmentCombatAdapter)
local InventoryLiveService = require(script.Parent.Systems.InventoryLiveService)
local OperativeLifeService = require(script.Parent.Systems.OperativeLifeService)

local LEASE_RENEW_INTERVAL_SECONDS = 30
local COMBAT_ACTIVATION_RETRY_INTERVAL_SECONDS = 0.25
local COMBAT_ACTIVATION_MAX_ATTEMPTS = 80

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

local unequipOwnedSlot = Instance.new("RemoteFunction")
unequipOwnedSlot.Name = "UnequipOwnedSlot"
unequipOwnedSlot.Parent = network

local dismantleOwnedItem = Instance.new("RemoteFunction")
dismantleOwnedItem.Name = "DismantleOwnedItem"
dismantleOwnedItem.Parent = network

local state = Instance.new("RemoteEvent")
state.Name = "State"
state.Parent = network

local loadedPlayerIds: { [number]: boolean } = {}
local weaponActivationGenerationByPlayerId: { [number]: number } = {}
local combatAllowedByPlayerId: { [number]: boolean } = {}
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

local function nextWeaponActivationGeneration(playerId: number): number
	local generation = (weaponActivationGenerationByPlayerId[playerId] or 0) + 1
	weaponActivationGenerationByPlayerId[playerId] = generation
	return generation
end

local function cancelWeaponActivation(playerId: number)
	weaponActivationGenerationByPlayerId[playerId] = nil
end

--[[
	Combat runtime startup may lag inventory by a fraction. That dependency gets a
	finite 20-second retry window: 80 attempts × 0.25 seconds. Combat eligibility
	is different: it is owned by OperativeLifeService and is reconciled from its
	state/roster notifications below instead of being polled forever. A newer
	equip/unequip increments the generation so an older delayed callback can never
	overwrite the newer durable choice.
]]
local function attemptWeaponActivation(player: Player, instanceId: string?, generation: number, attempt: number)
	if
		player.Parent ~= Players
		or loadedPlayerIds[player.UserId] ~= true
		or weaponActivationGenerationByPlayerId[player.UserId] ~= generation
	then
		return
	end

	local accepted: boolean
	local reasonId: string
	if instanceId == nil then
		accepted, reasonId = EquipmentCombatAdapter.activatePreferredOrDefault(player)
	else
		accepted, reasonId = EquipmentCombatAdapter.activateOwnedEquippedWeapon(player, instanceId)
	end
	if accepted then
		return
	end
	if reasonId == "CombatNotAllowed" then
		combatAllowedByPlayerId[player.UserId] = false
		return
	end
	if reasonId == "CombatRuntimeNotReady" and attempt < COMBAT_ACTIVATION_MAX_ATTEMPTS then
		task.delay(COMBAT_ACTIVATION_RETRY_INTERVAL_SECONDS, function()
			attemptWeaponActivation(player, instanceId, generation, attempt + 1)
		end)
		return
	end

	warn(
		string.format(
			"[InventoryNetwork] durable equipment combat activation stopped for %d after %d attempt(s): %s",
			player.UserId,
			attempt,
			reasonId
		)
	)
end

local function queueSpecificWeaponActivation(player: Player, instanceId: string)
	local generation = nextWeaponActivationGeneration(player.UserId)
	if not OperativeLifeService.isCombatAllowed(player) then
		combatAllowedByPlayerId[player.UserId] = false
		return
	end
	combatAllowedByPlayerId[player.UserId] = true
	attemptWeaponActivation(player, instanceId, generation, 1)
end

local function queuePreferredWeaponActivation(player: Player)
	local generation = nextWeaponActivationGeneration(player.UserId)
	if not OperativeLifeService.isCombatAllowed(player) then
		combatAllowedByPlayerId[player.UserId] = false
		return
	end
	combatAllowedByPlayerId[player.UserId] = true
	attemptWeaponActivation(player, nil, generation, 1)
end

-- Durable equipment may load before OperativeLifeService has registered the
-- player, and an operative can later return from a non-combat life state. Only a
-- false->true eligibility edge reapplies the preferred durable weapon, so health
-- changes while already Alive never reset ammunition or weapon state.
local function reconcileCombatEligibility(player: Player)
	local playerId = player.UserId
	if loadedPlayerIds[playerId] ~= true then
		return
	end
	local allowed = OperativeLifeService.isCombatAllowed(player)
	local wasAllowed = combatAllowedByPlayerId[playerId] == true
	if not allowed then
		combatAllowedByPlayerId[playerId] = false
		cancelWeaponActivation(playerId)
		return
	end
	combatAllowedByPlayerId[playerId] = true
	if not wasAllowed then
		queuePreferredWeaponActivation(player)
	end
end

--[[
	A player whose inventory could not be leased must not keep playing. Their
	session would run against no durable record: rewards would be refused, and
	whichever server does hold the lease owns the truth they would be diverging
	from. Kicking is the safe outcome, and it is the policy the retired
	ExpeditionFoundationBootstrap lifecycle enforced before this script became
	the single owner.
]]
local function loadPlayer(player: Player)
	local loaded = InventoryLiveService.loadPlayer(player.UserId, os.time())
	if loaded.Accepted ~= true then
		warn(string.format("[InventoryNetwork] inventory load rejected for %d: %s", player.UserId, loaded.ReasonId))
		if player.Parent == Players then
			player:Kick("Your inventory is active on another server or could not be loaded safely. Please rejoin.")
		end
		return
	end
	if player.Parent ~= Players then
		InventoryLiveService.releasePlayer(player.UserId)
		return
	end
	loadedPlayerIds[player.UserId] = true
	combatAllowedByPlayerId[player.UserId] = false
	reconcileEquipmentEffects(player)
	reconcileCombatEligibility(player)
	pushTo(player)
end

local function releasePlayer(player: Player)
	loadedPlayerIds[player.UserId] = nil
	combatAllowedByPlayerId[player.UserId] = nil
	cancelWeaponActivation(player.UserId)
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
		local record = outcome.Record
		local item = if type(record) == "table" then record.InventoryByInstanceId[instanceId] else nil
		if type(item) == "table" and EquipmentCombatAdapter.isWeaponSlot(item.Slot) then
			queueSpecificWeaponActivation(player, instanceId)
		end
		pushTo(player)
	end
	return table.freeze({ Accepted = outcome.Accepted == true, ReasonId = outcome.ReasonId })
end

-- Unequip accepts only a known slot intent. Owner identity is always the invoking
-- player; the live service validates the slot and lease before the persistence
-- owner changes durable state.
unequipOwnedSlot.OnServerInvoke = function(player: Player, slotId: any): any
	if type(slotId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidUnequipRequest" })
	end
	local outcome = InventoryLiveService.unequipOwnedSlot(player.UserId, player.UserId, slotId, os.time())
	if outcome.Accepted == true then
		reconcileEquipmentEffects(player)
		if EquipmentCombatAdapter.isWeaponSlot(slotId) then
			queuePreferredWeaponActivation(player)
		end
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

local lifeStateConnection = OperativeLifeService.subscribe(function(player)
	reconcileCombatEligibility(player)
end)
local lifeRosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
	if eventName ~= "Registered" then
		return
	end
	local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
	if player ~= nil then
		reconcileCombatEligibility(player)
	end
end)
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
		--[[
			Only loaded players are renewed. A player who never loaded has no
			lease to renew, so renewing everyone present would report LeaseNotOwned
			for them and -- under the kick policy below -- eject a player for a
			lease they were never granted.
		]]
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
				--[[
					A lost lease means another server now owns this inventory.
					Continuing would let this session mutate a record it no
					longer holds, so the session ends here.
				]]
				loadedPlayerIds[player.UserId] = nil
				combatAllowedByPlayerId[player.UserId] = nil
				cancelWeaponActivation(player.UserId)
				InventoryLiveService.releasePlayer(player.UserId)
				if player.Parent == Players then
					player:Kick("Your inventory session could no longer be protected. Please rejoin.")
				end
			end
		end
	end
end)

game:BindToClose(function()
	heartbeatConnection:Disconnect()
	lifeStateConnection:Disconnect()
	lifeRosterConnection:Disconnect()
	playerAddedConnection:Disconnect()
	playerRemovingConnection:Disconnect()
	table.clear(loadedPlayerIds)
	table.clear(weaponActivationGenerationByPlayerId)
	table.clear(combatAllowedByPlayerId)
	InventoryLiveService.destroy()
end)

print("[Living Kingdoms] Inventory network and lease lifecycle mounted")
