--!strict

-- Server-only owner for inventory persistence and per-player session leases.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentComparisonResolver = require(ReplicatedStorage.Shared.Equipment.EquipmentComparisonResolver)
local EquipmentContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)
local InventoryDismantleResolver = require(ReplicatedStorage.Shared.Persistence.InventoryDismantleResolver)
local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local PlayerInventorySnapshot = require(ReplicatedStorage.Shared.Persistence.PlayerInventorySnapshot)
local StorageResults = require(ReplicatedStorage.Shared.Persistence.StorageResultContracts)
local RobloxInventoryDataStoreAdapter = require(script.Parent.RobloxInventoryDataStoreAdapter)
local PlayerInventoryPersistenceService = require(script.Parent.PlayerInventoryPersistenceService)
local InventorySessionLeaseService = require(script.Parent.InventorySessionLeaseService)

local store = RobloxInventoryDataStoreAdapter.new({
	DataStoreName = "AtlasPlayerInventoryV1",
	KeyPrefix = "atlas-prod",
	MaximumAttempts = 4,
	BaseRetryDelaySeconds = 0.5,
})

local leaseOwnerId =
	string.format("%s:%s", game.JobId ~= "" and game.JobId or "studio", HttpService:GenerateGUID(false))
local leases = InventorySessionLeaseService.new(store, leaseOwnerId, 90)
local persistence = PlayerInventoryPersistenceService.new(store)
local destroyed = false

local recentDismantleRequests: { [number]: { number } } = {}

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function lookupEquipmentDefinition(definitionId: string): any
	return definitionsById[definitionId]
end

local function isKnownSlot(slotId: unknown): boolean
	for _, candidate in EquipmentContracts.SlotIds do
		if slotId == candidate then
			return true
		end
	end
	return false
end

local function inventoryKeyFor(playerId: number): string
	return string.format("player:%d:inventory", playerId)
end

local Service = {}

local function rejected(reasonId: string)
	return table.freeze({ Accepted = false, ReasonId = reasonId, Record = nil, Migrated = false })
end

function Service.loadPlayer(playerId: number, nowUnix: number): any
	if destroyed then
		return rejected("ServiceDestroyed")
	end
	local lease = leases:acquire(playerId, nowUnix)
	if lease.Accepted ~= true then
		return rejected(lease.ReasonId)
	end
	local loaded = persistence:loadPlayer(playerId, nowUnix)
	if loaded.Accepted ~= true then
		leases:release(playerId)
	end
	return loaded
end

function Service.renewPlayer(playerId: number, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed" })
	end
	return leases:renew(playerId, nowUnix)
end

function Service.releasePlayer(playerId: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed" })
	end
	recentDismantleRequests[playerId] = nil
	local released = leases:release(playerId)
	persistence:releasePlayer(playerId)
	return released
end

function Service.applyReward(playerId: number, reward: any, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Record = nil })
	end
	if not leases:hasLease(playerId, nowUnix) then
		return table.freeze({
			Accepted = false,
			ReasonId = "SessionLeaseRequired",
			Record = persistence:getRecord(playerId),
		})
	end
	return persistence:applyReward(playerId, reward, nowUnix)
end

function Service.getRecord(playerId: number): any
	if destroyed then
		return nil
	end
	return persistence:getRecord(playerId)
end

function Service.readOwnedSnapshot(requesterId: number, ownerId: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Snapshot = nil })
	end
	return PlayerInventorySnapshot.forOwner(requesterId, ownerId, persistence:getRecord(ownerId))
end

function Service.compareOwnedItem(requesterId: number, ownerId: number, candidateInstanceId: any): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Comparison = nil })
	end
	if requesterId ~= ownerId then
		return table.freeze({ Accepted = false, ReasonId = "CrossPlayerInventoryAccess", Comparison = nil })
	end
	if type(candidateInstanceId) ~= "string" or candidateInstanceId == "" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidCandidateItem", Comparison = nil })
	end

	local record = persistence:getRecord(ownerId)
	if record == nil then
		return table.freeze({ Accepted = false, ReasonId = "InventoryNotLoaded", Comparison = nil })
	end
	local candidate = record.InventoryByInstanceId[candidateInstanceId]
	if candidate == nil then
		return table.freeze({ Accepted = false, ReasonId = "ItemNotOwned", Comparison = nil })
	end

	return EquipmentComparisonResolver.compareAgainstEquipped(
		candidate,
		record.EquippedBySlot,
		record.InventoryByInstanceId,
		lookupEquipmentDefinition
	)
end

function Service.equipOwnedItem(requesterId: number, ownerId: number, instanceId: any, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Record = nil })
	end
	if requesterId ~= ownerId then
		return table.freeze({ Accepted = false, ReasonId = "CrossPlayerInventoryAccess", Record = nil })
	end
	if type(instanceId) ~= "string" or instanceId == "" or type(nowUnix) ~= "number" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidEquipRequest", Record = nil })
	end
	if not leases:hasLease(ownerId, nowUnix) then
		return table.freeze({
			Accepted = false,
			ReasonId = "SessionLeaseRequired",
			Record = persistence:getRecord(ownerId),
		})
	end
	local record = persistence:getRecord(ownerId)
	if record == nil then
		return table.freeze({ Accepted = false, ReasonId = "InventoryNotLoaded", Record = nil })
	end
	local item = record.InventoryByInstanceId[instanceId]
	if item == nil then
		return table.freeze({ Accepted = false, ReasonId = "ItemNotOwned", Record = record })
	end
	return persistence:equip(ownerId, item.Slot, instanceId, nowUnix)
end

function Service.unequipOwnedSlot(requesterId: number, ownerId: number, slotId: any, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Record = nil })
	end
	if requesterId ~= ownerId then
		return table.freeze({ Accepted = false, ReasonId = "CrossPlayerInventoryAccess", Record = nil })
	end
	if not isKnownSlot(slotId) or type(nowUnix) ~= "number" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidUnequipRequest", Record = nil })
	end
	if not leases:hasLease(ownerId, nowUnix) then
		return table.freeze({
			Accepted = false,
			ReasonId = "SessionLeaseRequired",
			Record = persistence:getRecord(ownerId),
		})
	end
	local record = persistence:getRecord(ownerId)
	if record == nil then
		return table.freeze({ Accepted = false, ReasonId = "InventoryNotLoaded", Record = nil })
	end
	if nowUnix < record.UpdatedAtUnix then
		return table.freeze({ Accepted = false, ReasonId = "InvalidUnequipRequest", Record = record })
	end
	if record.EquippedBySlot[slotId] == nil then
		return table.freeze({ Accepted = true, ReasonId = "SlotAlreadyUnequipped", Record = record })
	end

	local nextRecord = {
		SchemaVersion = record.SchemaVersion,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.clone(record.InventoryByInstanceId),
		EquippedBySlot = table.clone(record.EquippedBySlot),
		AppliedRewardInstanceIds = table.clone(record.AppliedRewardInstanceIds),
		AppliedRewardGrantIds = table.clone(record.AppliedRewardGrantIds),
		AppliedDismantleTransactions = table.clone(record.AppliedDismantleTransactions),
		AppliedRewardContentSignatures = table.clone(record.AppliedRewardContentSignatures),
		UpdatedAtUnix = nowUnix,
	}
	nextRecord.EquippedBySlot[slotId] = nil
	local write = store:write(inventoryKeyFor(ownerId), nextRecord)
	if write.Status ~= StorageResults.WriteStatuses.Committed then
		return table.freeze({ Accepted = false, ReasonId = "SaveFailed", Record = record })
	end

	local persistenceState = persistence :: any
	assert(type(persistenceState._records) == "table", "inventory persistence resident cache unavailable")
	persistenceState._records[ownerId] = nextRecord
	return table.freeze({ Accepted = true, ReasonId = "ItemUnequipped", Record = persistence:getRecord(ownerId) })
end

function Service.dismantleOwnedItem(
	requesterId: number,
	ownerId: number,
	instanceId: any,
	transactionId: any,
	nowUnix: number
): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Outcome = nil })
	end
	if requesterId ~= ownerId then
		return table.freeze({ Accepted = false, ReasonId = "CrossPlayerInventoryAccess", Outcome = nil })
	end
	if type(instanceId) ~= "string" or type(transactionId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidDismantleRequest", Outcome = nil })
	end

	local timestamps = recentDismantleRequests[ownerId]
	if timestamps == nil then
		timestamps = {}
		recentDismantleRequests[ownerId] = timestamps
	end

	local outcome = persistence:dismantle(
		ownerId,
		instanceId,
		transactionId,
		nowUnix,
		leases:hasLease(ownerId, nowUnix),
		timestamps
	)

	if outcome.Accepted == true and outcome.ReasonId == "ItemDismantled" then
		table.insert(timestamps, nowUnix)
		while #timestamps > InventoryDismantleResolver.MaximumRequestsPerWindow do
			table.remove(timestamps, 1)
		end
	end
	return outcome
end

function Service.destroy(): any
	if destroyed then
		return table.freeze({ Requested = 0, Released = 0, Unresolved = 0, UnresolvedPlayerIds = table.freeze({}) })
	end
	local summary = leases:releaseAll()
	persistence:destroy()
	leases:destroy()
	destroyed = true
	return summary
end

return table.freeze(Service)
