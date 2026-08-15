--!strict

-- Durable character progression sub-record owned by InventoryLiveService.
-- It uses the same DataStore adapter and the same per-player session lease as
-- inventory, so character XP never becomes a competing persistence authority.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CharacterProgressionConfig)
local Resolver = require(ReplicatedStorage.Shared.Progression.CharacterProgressionResolver)
local StorageResults = require(ReplicatedStorage.Shared.Persistence.StorageResultContracts)

export type Store = {
	read: (self: Store, key: string) -> any,
	write: (self: Store, key: string, value: any) -> any,
}

local Service = {}
Service.__index = Service

local SCHEMA_VERSION = 1

local DURABLE_GRANT_SOURCES = table.freeze({
	[Config.SourceIds.DungeonCompletion] = true,
	[Config.SourceIds.Quest] = true,
	[Config.SourceIds.Event] = true,
})

local function keyFor(playerId: number): string
	return string.format("player:%d:character-progression", playerId)
end

local function validPlayerId(playerId: any): boolean
	return type(playerId) == "number" and playerId % 1 == 0 and playerId > 0
end

local function canonicalState(rawState: any): any
	return Resolver.serializeState(Resolver.normalizeState(rawState, Config), Config)
end

local function newRecord(nowUnix: number): any
	return {
		SchemaVersion = SCHEMA_VERSION,
		State = canonicalState(nil),
		AppliedGrantIds = {},
		UpdatedAtUnix = nowUnix,
	}
end

local function normalizeRecord(raw: any, nowUnix: number): (any, boolean)
	if type(raw) ~= "table" then
		return newRecord(nowUnix), true
	end

	local migrated = raw.SchemaVersion ~= SCHEMA_VERSION
	local grants = {}
	if type(raw.AppliedGrantIds) == "table" then
		for grantId, applied in raw.AppliedGrantIds do
			if type(grantId) == "string" and grantId ~= "" and applied == true then
				grants[grantId] = true
			else
				migrated = true
			end
		end
	elseif raw.AppliedGrantIds ~= nil then
		migrated = true
	end

	return {
		SchemaVersion = SCHEMA_VERSION,
		State = canonicalState(raw.State or raw.CharacterProgression or raw),
		AppliedGrantIds = grants,
		UpdatedAtUnix = if type(raw.UpdatedAtUnix) == "number" and raw.UpdatedAtUnix >= 0 then raw.UpdatedAtUnix else nowUnix,
	}, migrated
end

local function freezeRecord(record: any): any
	return table.freeze({
		SchemaVersion = record.SchemaVersion,
		State = record.State,
		AppliedGrantIds = table.freeze(table.clone(record.AppliedGrantIds)),
		UpdatedAtUnix = record.UpdatedAtUnix,
	})
end

function Service.new(store: Store): any
	assert(type(store) == "table" and type(store.read) == "function" and type(store.write) == "function", "invalid store")
	return setmetatable({ _store = store, _records = {}, _destroyed = false }, Service)
end

function Service:loadPlayer(playerId: number, nowUnix: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", State = nil, Migrated = false })
	end
	if not validPlayerId(playerId) or type(nowUnix) ~= "number" or nowUnix < 0 then
		return table.freeze({ Accepted = false, ReasonId = "InvalidLoadRequest", State = nil, Migrated = false })
	end

	local read = selfAny._store:read(keyFor(playerId))
	if read.Status == StorageResults.ReadStatuses.Failed then
		return table.freeze({ Accepted = false, ReasonId = "ProgressionReadFailed", State = nil, Migrated = false })
	end

	local record, migrated = normalizeRecord(if read.Status == StorageResults.ReadStatuses.Found then read.Value else nil, nowUnix)
	if read.Status == StorageResults.ReadStatuses.Missing or migrated then
		local written = selfAny._store:write(keyFor(playerId), record)
		if written.Status ~= StorageResults.WriteStatuses.Committed then
			return table.freeze({ Accepted = false, ReasonId = "ProgressionSaveFailed", State = nil, Migrated = migrated })
		end
	end

	selfAny._records[playerId] = record
	return table.freeze({
		Accepted = true,
		ReasonId = if migrated then "ProgressionMigrated" else "ProgressionLoaded",
		State = record.State,
		Migrated = migrated,
	})
end

function Service:savePlayer(playerId: number, rawState: any, sourceId: any, attributionId: any, nowUnix: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", State = nil, AlreadyApplied = false })
	end
	local record = selfAny._records[playerId]
	if record == nil then
		return table.freeze({ Accepted = false, ReasonId = "ProgressionNotLoaded", State = nil, AlreadyApplied = false })
	end
	if type(nowUnix) ~= "number" or nowUnix < 0 then
		return table.freeze({ Accepted = false, ReasonId = "InvalidSaveRequest", State = record.State, AlreadyApplied = false })
	end

	local durableGrantId: string? = nil
	if DURABLE_GRANT_SOURCES[sourceId] == true then
		if type(attributionId) ~= "string" or attributionId == "" then
			return table.freeze({ Accepted = false, ReasonId = "DurableAttributionRequired", State = record.State, AlreadyApplied = false })
		end
		durableGrantId = tostring(sourceId) .. ":" .. attributionId
		if record.AppliedGrantIds[durableGrantId] == true then
			return table.freeze({ Accepted = true, ReasonId = "ProgressionGrantAlreadyApplied", State = record.State, AlreadyApplied = true })
		end
	end

	local nextRecord = {
		SchemaVersion = SCHEMA_VERSION,
		State = canonicalState(rawState),
		AppliedGrantIds = table.clone(record.AppliedGrantIds),
		UpdatedAtUnix = nowUnix,
	}
	if durableGrantId ~= nil then
		nextRecord.AppliedGrantIds[durableGrantId] = true
	end

	local written = selfAny._store:write(keyFor(playerId), nextRecord)
	if written.Status ~= StorageResults.WriteStatuses.Committed then
		return table.freeze({ Accepted = false, ReasonId = "ProgressionSaveFailed", State = record.State, AlreadyApplied = false })
	end
	selfAny._records[playerId] = nextRecord
	return table.freeze({ Accepted = true, ReasonId = "ProgressionSaved", State = nextRecord.State, AlreadyApplied = false })
end

function Service:getState(playerId: number): any
	local record = (self :: any)._records[playerId]
	return if record == nil then nil else record.State
end

function Service:releasePlayer(playerId: number)
	(self :: any)._records[playerId] = nil
end

function Service:destroy()
	local selfAny = self :: any
	table.clear(selfAny._records)
	selfAny._destroyed = true
end

return Service
