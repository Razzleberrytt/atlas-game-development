--!strict

-- Server-only owner for inventory persistence and per-player session leases.

local HttpService = game:GetService("HttpService")
local RobloxInventoryDataStoreAdapter = require(script.Parent.RobloxInventoryDataStoreAdapter)
local PlayerInventoryPersistenceService = require(script.Parent.PlayerInventoryPersistenceService)
local InventorySessionLeaseService = require(script.Parent.InventorySessionLeaseService)

local store = RobloxInventoryDataStoreAdapter.new({
	DataStoreName = "AtlasPlayerInventoryV1",
	KeyPrefix = "atlas-prod",
	MaximumAttempts = 4,
	BaseRetryDelaySeconds = 0.5,
})

local ownerId = string.format("%s:%s", game.JobId ~= "" and game.JobId or "studio", HttpService:GenerateGUID(false))
local leases = InventorySessionLeaseService.new(store, ownerId, 90)
local persistence = PlayerInventoryPersistenceService.new(store)
local destroyed = false

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
