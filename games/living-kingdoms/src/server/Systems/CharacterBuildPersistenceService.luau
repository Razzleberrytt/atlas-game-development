--!strict

-- Compact persistence for player-selected build allocations. InventoryLiveService
-- supplies the same datastore adapter and session lease used by account state,
-- so this service does not create a second runtime persistence authority.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CharacterStatConfig)
local BuildResolver = require(ReplicatedStorage.Shared.Progression.CharacterBuildResolver)
local StorageResults = require(ReplicatedStorage.Shared.Persistence.StorageResultContracts)

local Service = {}
Service.__index = Service

local RECORD_VERSION = "CHARACTER-BUILD-RECORD-v1"
local MAX_DURABLE_REQUEST_IDS = 128

local function isInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

local function keyFor(playerId: number): string
	return string.format("player:%d:character-build", playerId)
end

local function exportState(state: any): any
	local allocations = {}
	for attributeId, points in state.AllocatedAttributes do
		allocations[attributeId] = points
	end
	return table.freeze({ Version = Config.Version, AllocatedAttributes = table.freeze(allocations) })
end

local function newRecord(nowUnix: number): any
	local state = BuildResolver.defaultState(Config)
	return {
		Version = RECORD_VERSION,
		BuildState = exportState(state),
		AppliedRequestIds = {},
		UpdatedAtUnix = nowUnix,
	}
end

local function normalizeRecord(raw: any, nowUnix: number): any?
	if raw == nil then
		return newRecord(nowUnix)
	end
	if type(raw) ~= "table" or (raw.Version ~= nil and raw.Version ~= RECORD_VERSION) then
		return nil
	end
	if type(raw.AppliedRequestIds or {}) ~= "table" then
		return nil
	end
	local state = BuildResolver.normalizeState(raw.BuildState, Config)
	if state == nil then
		return nil
	end
	local requestIds = {}
	for requestId, timestamp in raw.AppliedRequestIds or {} do
		if type(requestId) ~= "string" or #requestId < 8 or #requestId > 128 or not isInteger(timestamp) or timestamp < 0 then
			return nil
		end
		requestIds[requestId] = timestamp
	end
	return {
		Version = RECORD_VERSION,
		BuildState = exportState(state),
		AppliedRequestIds = requestIds,
		UpdatedAtUnix = if isInteger(raw.UpdatedAtUnix) and raw.UpdatedAtUnix >= 0 then raw.UpdatedAtUnix else nowUnix,
	}
end

local function pruneRequestIds(requestIds: { [string]: number })
	local count = 0
	for _ in requestIds do
		count += 1
	end
	while count > MAX_DURABLE_REQUEST_IDS do
		local oldestId: string? = nil
		local oldestTime = math.huge
		for requestId, timestamp in requestIds do
			if timestamp < oldestTime or (timestamp == oldestTime and (oldestId == nil or requestId < oldestId)) then
				oldestId = requestId
				oldestTime = timestamp
			end
		end
		if oldestId == nil then
			break
		end
		requestIds[oldestId] = nil
		count -= 1
	end
end

function Service.new(store: any): any
	assert(type(store) == "table" and type(store.read) == "function" and type(store.commit) == "function", "invalid build store")
	return setmetatable({ _store = store, _records = {}, _destroyed = false }, Service)
end

function Service:loadPlayer(playerId: number, nowUnix: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", State = nil })
	end
	if not isInteger(playerId) or playerId <= 0 or not isInteger(nowUnix) or nowUnix < 0 then
		return table.freeze({ Accepted = false, ReasonId = "InvalidBuildLoadRequest", State = nil })
	end
	local read = selfAny._store:read(keyFor(playerId))
	if read.Status == StorageResults.ReadStatuses.Failed then
		return table.freeze({ Accepted = false, ReasonId = "BuildLoadFailed", State = nil })
	end
	local normalized = normalizeRecord(read.Value, nowUnix)
	if normalized == nil then
		return table.freeze({ Accepted = false, ReasonId = "InvalidSavedBuildRecord", State = nil })
	end
	selfAny._records[playerId] = normalized
	return table.freeze({ Accepted = true, ReasonId = if read.Value == nil then "CreatedBuildState" else "BuildLoaded", State = normalized.BuildState })
end

function Service:savePlayer(playerId: number, buildState: any, requestId: string, nowUnix: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", State = nil, AlreadyApplied = false })
	end
	if not isInteger(playerId)
		or playerId <= 0
		or type(requestId) ~= "string"
		or #requestId < 8
		or #requestId > 128
		or not isInteger(nowUnix)
		or nowUnix < 0
	then
		return table.freeze({ Accepted = false, ReasonId = "InvalidBuildSaveRequest", State = nil, AlreadyApplied = false })
	end
	if selfAny._records[playerId] == nil then
		return table.freeze({ Accepted = false, ReasonId = "BuildNotLoaded", State = nil, AlreadyApplied = false })
	end
	local candidate = BuildResolver.normalizeState(buildState, Config)
	if candidate == nil or candidate.RecoveredState == true then
		return table.freeze({ Accepted = false, ReasonId = "InvalidBuildState", State = nil, AlreadyApplied = false })
	end

	local alreadyApplied = false
	local acceptedTransform = false
	local write = selfAny._store:commit(keyFor(playerId), function(current: any): any
		local normalized = normalizeRecord(current, nowUnix)
		if normalized == nil then
			return current
		end
		if normalized.AppliedRequestIds[requestId] ~= nil then
			alreadyApplied = true
			acceptedTransform = true
			return normalized
		end
		local requestIds = table.clone(normalized.AppliedRequestIds)
		requestIds[requestId] = nowUnix
		pruneRequestIds(requestIds)
		acceptedTransform = true
		return {
			Version = RECORD_VERSION,
			BuildState = exportState(candidate),
			AppliedRequestIds = requestIds,
			UpdatedAtUnix = math.max(normalized.UpdatedAtUnix, nowUnix),
		}
	end)
	if write.Status ~= StorageResults.WriteStatuses.Committed or not acceptedTransform then
		return table.freeze({ Accepted = false, ReasonId = "BuildSaveFailed", State = nil, AlreadyApplied = false })
	end
	local committed = normalizeRecord(write.Value, nowUnix)
	if committed == nil then
		return table.freeze({ Accepted = false, ReasonId = "BuildCommitInvalid", State = nil, AlreadyApplied = false })
	end
	selfAny._records[playerId] = committed
	return table.freeze({
		Accepted = true,
		ReasonId = if alreadyApplied then "BuildRequestAlreadyApplied" else "BuildSaved",
		State = committed.BuildState,
		AlreadyApplied = alreadyApplied,
	})
end

function Service:getState(playerId: number): any
	local record = (self :: any)._records[playerId]
	return if record ~= nil then record.BuildState else nil
end

function Service:releasePlayer(playerId: number)
	(self :: any)._records[playerId] = nil
end

function Service:destroy()
	local selfAny = self :: any
	selfAny._destroyed = true
	selfAny._records = {}
end

return table.freeze(Service)
