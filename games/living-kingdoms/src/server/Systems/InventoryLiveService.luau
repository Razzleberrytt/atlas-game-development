--!strict

-- Server-only owner for inventory persistence and per-player session leases.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentComparisonResolver = require(ReplicatedStorage.Shared.Equipment.EquipmentComparisonResolver)
local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local PlayerInventorySnapshot = require(ReplicatedStorage.Shared.Persistence.PlayerInventorySnapshot)
local RobloxInventoryDataStoreAdapter = require(script.Parent.RobloxInventoryDataStoreAdapter)
local PlayerInventoryPersistenceService = require(script.Parent.PlayerInventoryPersistenceService)
local InventorySessionLeaseService = require(script.Parent.InventorySessionLeaseService)

local store = RobloxInventoryDataStoreAdapter.new({
	DataStoreName = "AtlasPlayerInventoryV1",
	KeyPrefix = "atlas-prod",
	MaximumAttempts = 4,
	BaseRetryDelaySeconds = 0.5,
})

-- Identifies this server instance as the holder of a session lease. Distinct
-- from a player's inventory owner id, which is always a Roblox user id.
local leaseOwnerId =
	string.format("%s:%s", game.JobId ~= "" and game.JobId or "studio", HttpService:GenerateGUID(false))
local leases = InventorySessionLeaseService.new(store, leaseOwnerId, 90)
local persistence = PlayerInventoryPersistenceService.new(store)
local destroyed = false

-- Authored definitions are static, so the tag lookup comparison needs is indexed
-- once rather than scanned per request.
local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function lookupEquipmentDefinition(definitionId: string): any
	return definitionsById[definitionId]
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
	return leases:release(playerId)
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

--[[
	The only inventory read a client is ever served. `requesterId` must be derived
	from the connection by the caller; this service never accepts an owner
	identity from a payload. A rejected read discloses no record at all.
]]
function Service.readOwnedSnapshot(requesterId: number, ownerId: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Snapshot = nil })
	end
	return PlayerInventorySnapshot.forOwner(requesterId, ownerId, persistence:getRecord(ownerId))
end

--[[
	Compares one item the owner holds against whatever occupies its slot. The
	candidate is named by instance id and must already be owned, so a client
	cannot ask the server to evaluate an item it invented.
]]
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

function Service.destroy()
	if destroyed then
		return
	end
	leases:releaseAll()
	persistence:destroy()
	leases:destroy()
	destroyed = true
end

return table.freeze(Service)
