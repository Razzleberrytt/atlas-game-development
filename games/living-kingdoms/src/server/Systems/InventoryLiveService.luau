--!strict

-- Server-only owner for inventory persistence and per-player session leases.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentComparisonResolver = require(ReplicatedStorage.Shared.Equipment.EquipmentComparisonResolver)
local InventoryDismantleResolver = require(ReplicatedStorage.Shared.Persistence.InventoryDismantleResolver)
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

-- Accepted dismantle timestamps per owner, for the rate bound only.
local recentDismantleRequests: { [number]: { number } } = {}

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
	recentDismantleRequests[playerId] = nil
	local released = leases:release(playerId)
	--[[
		The lease and the resident record have to fall together. Releasing only
		the lease left the departed player's inventory resident for the life of
		the server and still readable through getRecord. Order matters: the lease
		goes first so no mutation can be authorized against a record that is
		about to be dropped.
	]]
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

--[[
	Equips one item the owner already holds. The client names only the instance;
	the server resolves its slot from the durable record and requires the live
	session lease before persistence can change. No client-authored slot, item
	definition, power, or weapon id crosses this boundary.
]]
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

--[[
	Destroys one owned item under a client-supplied transaction id. The id is the
	only client-authored value accepted here, and it can do nothing but make a
	retry idempotent — it never names an item, an owner, or a value.

	Accepted request timestamps are tracked per owner for the rate bound. They
	are intentionally in-memory: a rejoin is far slower than the window, so
	persisting them would buy nothing.
]]
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

	-- Only accepted, non-replayed work counts toward the bound, so a client
	-- cannot exhaust its own budget with rejected probes and then claim to be
	-- rate limited, and a retry storm of one transaction is not penalised.
	if outcome.Accepted == true and outcome.ReasonId == "ItemDismantled" then
		table.insert(timestamps, nowUnix)
		while #timestamps > InventoryDismantleResolver.MaximumRequestsPerWindow do
			table.remove(timestamps, 1)
		end
	end
	return outcome
end

--[[
	Returns what shutdown actually achieved. The lease service reports which
	leases survived release, and discarding that here would put the observability
	one layer out of reach of the only caller that runs at shutdown -- leaving a
	partial outage indistinguishable from a clean close.
]]
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
