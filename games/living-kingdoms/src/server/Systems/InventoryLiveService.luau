--!strict

--[[
	Server-only owner for the production inventory persistence instance.
	All trusted server systems share the same loaded-record cache and DataStore
	adapter. No remotes are created here.
]]

local RobloxInventoryDataStoreAdapter = require(script.Parent.RobloxInventoryDataStoreAdapter)
local PlayerInventoryPersistenceService = require(script.Parent.PlayerInventoryPersistenceService)

local store = RobloxInventoryDataStoreAdapter.new({
	DataStoreName = "AtlasPlayerInventoryV1",
	KeyPrefix = "atlas-prod",
	MaximumAttempts = 4,
	BaseRetryDelaySeconds = 0.5,
})

local persistence = PlayerInventoryPersistenceService.new(store)
local destroyed = false

local Service = {}

function Service.loadPlayer(playerId: number, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Record = nil, Migrated = false })
	end
	return persistence:loadPlayer(playerId, nowUnix)
end

function Service.applyReward(playerId: number, reward: any, nowUnix: number): any
	if destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Record = nil })
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
	destroyed = true
	persistence:destroy()
end

return table.freeze(Service)
