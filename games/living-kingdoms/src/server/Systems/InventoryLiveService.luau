--!strict

-- Server-only owner for account persistence and per-player session leases.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentComparisonResolver = require(ReplicatedStorage.Shared.Equipment.EquipmentComparisonResolver)
local InventoryDismantleResolver = require(ReplicatedStorage.Shared.Persistence.InventoryDismantleResolver)
local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local CharacterProgressionConfig = require(ReplicatedStorage.Shared.Config.CharacterProgressionConfig)
local PlayerInventorySnapshot = require(ReplicatedStorage.Shared.Persistence.PlayerInventorySnapshot)
local RobloxInventoryDataStoreAdapter = require(script.Parent.RobloxInventoryDataStoreAdapter)
local PlayerInventoryPersistenceService = require(script.Parent.PlayerInventoryPersistenceService)
local CharacterBuildPersistenceService = require(script.Parent.CharacterBuildPersistenceService)
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
local buildPersistence = CharacterBuildPersistenceService.new(store)
local destroyed = false

local recentDismantleRequests: { [number]: { number } } = {}

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function lookupEquipmentDefinition(definitionId: string): any
	return definitionsById[definitionId]
end

local Service = {}

local DURABLE_PROGRESSION_SOURCES = table.freeze({
	[CharacterProgressionConfig.SourceIds.DungeonCompletion] = true,
	[CharacterProgressionConfig.SourceIds.Quest] = true,
	[CharacterProgressionConfig.SourceIds.Event] = true,
})

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
		return loaded
	end
	local buildLoaded = buildPersistence:loadPlayer(playerId, nowUnix)
	if buildLoaded.Accepted ~= true then
		persistence:releasePlayer(playerId)
		leases:release(playerId)
		return rejected(buildLoaded.ReasonId)
	end
	local record = loaded.Record
	return table.freeze({
		Accepted = true,
		ReasonId = loaded.ReasonId,
		Record = record,
		Migrated = loaded.Migrated == true,
		ProgressionState = if record ~= nil then record.CharacterProgression else nil,
		ProgressionMigrated = loaded.Migrated == true,
		BuildState = buildLoaded.State,
	})
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
	buildPersistence:releasePlayer(playerId)
	local released = leases:release(playerId)
	persistence:releasePlayer(playerId)
	return released
end

-- Character XP is committed through the same leased account record as equipment.
-- Only low-frequency, naturally idempotent sources consume durable grant-ledger
-- entries; kill/assist attribution can remain encounter-scoped once combat owns
-- a trusted contributor ledger.
function Service.saveCharacterProgression(
	playerId: number,
	state: any,
	sourceId: any,
	attributionId: any,
	nowUnix: number
): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", State = nil, AlreadyApplied = false })
	end
	if not leases:hasLease(playerId, nowUnix) then
		local record = persistence:getRecord(playerId)
		return table.freeze({
			Accepted = false,
			ReasonId = "SessionLeaseRequired",
			State = if record ~= nil then record.CharacterProgression else nil,
			AlreadyApplied = false,
		})
	end

	local grantId: string? = nil
	if DURABLE_PROGRESSION_SOURCES[sourceId] == true then
		if type(attributionId) ~= "string" or attributionId == "" then
			local record = persistence:getRecord(playerId)
			return table.freeze({
				Accepted = false,
				ReasonId = "DurableAttributionRequired",
				State = if record ~= nil then record.CharacterProgression else nil,
				AlreadyApplied = false,
			})
		end
		grantId = tostring(sourceId) .. ":" .. attributionId
	end

	local saved = persistence:applyCharacterProgression(playerId, state, grantId, nowUnix)
	local record = saved.Record
	local storedState = if record ~= nil then record.CharacterProgression else nil
	if saved.ReasonId == "CharacterProgressionGrantAlreadyApplied" then
		return table.freeze({
			Accepted = true,
			ReasonId = saved.ReasonId,
			State = storedState,
			AlreadyApplied = true,
		})
	end
	return table.freeze({
		Accepted = saved.Accepted == true,
		ReasonId = saved.ReasonId,
		State = storedState,
		AlreadyApplied = false,
	})
end

function Service.getCharacterProgression(playerId: number): any
	if destroyed then
		return nil
	end
	local record = persistence:getRecord(playerId)
	return if record ~= nil then record.CharacterProgression else nil
end

function Service.saveCharacterBuild(playerId: number, state: any, requestId: any, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", State = nil, AlreadyApplied = false })
	end
	if type(requestId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidBuildRequestId", State = nil, AlreadyApplied = false })
	end
	if not leases:hasLease(playerId, nowUnix) then
		return table.freeze({
			Accepted = false,
			ReasonId = "SessionLeaseRequired",
			State = buildPersistence:getState(playerId),
			AlreadyApplied = false,
		})
	end
	return buildPersistence:savePlayer(playerId, state, requestId, nowUnix)
end

function Service.getCharacterBuild(playerId: number): any
	if destroyed then
		return nil
	end
	return buildPersistence:getState(playerId)
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
	buildPersistence:destroy()
	persistence:destroy()
	leases:destroy()
	destroyed = true
	return summary
end

return table.freeze(Service)
