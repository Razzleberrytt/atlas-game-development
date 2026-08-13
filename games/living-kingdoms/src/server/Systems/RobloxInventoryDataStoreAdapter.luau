--!strict

-- Production storage adapter for inventory records and atomic session leases.
-- Studio is intentionally isolated from the production DataStore even when
-- Studio Access to API Services is enabled: evidence/playtest sessions must not
-- acquire production leases or mutate/migrate live inventory records.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ResolutionPolicy = require(script.Parent.InventoryDataStoreResolutionPolicy)
local StorageResults = require(ReplicatedStorage.Shared.Persistence.StorageResultContracts)

export type ReadResult = StorageResults.ReadResult
export type WriteResult = StorageResults.WriteResult

export type Adapter = {
	read: (self: Adapter, key: string) -> ReadResult,
	write: (self: Adapter, key: string, value: any) -> WriteResult,
	commit: (self: Adapter, key: string, transform: (any) -> any) -> WriteResult,
	update: (self: Adapter, key: string, transform: (any) -> any) -> (boolean, any),
	storageMode: (self: Adapter) -> string,
}

export type Options = {
	DataStoreName: string?,
	KeyPrefix: string?,
	MaximumAttempts: number?,
	BaseRetryDelaySeconds: number?,
}

local Adapter = {}
Adapter.__index = Adapter

local function assertPositiveInteger(value: number, name: string)
	assert(value >= 1 and value % 1 == 0, name .. " must be a positive integer")
end

local function retryDelay(baseDelay: number, attempt: number): number
	return math.min(baseDelay * (2 ^ (attempt - 1)), 8)
end

--[[
	Store selection belongs to InventoryDataStoreResolutionPolicy, which is pure
	and directly testable. The Studio check must still happen before GetDataStore
	-- Studio API access may be needed for unrelated evidence tooling, but it
	must never opt inventory into the production AtlasPlayerInventoryV1 store or
	the atlas-prod lease namespace -- and the policy encodes that ordering.

	Note what the policy deliberately changed: a live server whose GetDataStore
	call fails no longer falls soft to a volatile store. Doing so let a published
	server run a whole session on storage that silently evaporates, which is the
	worst outcome a persistence layer can produce. It now gets a store that
	throws, so reads exhaust their retries, the write guard engages, and the load
	is refused rather than answered with fiction.
]]
local function resolveStore(dataStoreName: string): (any, boolean, string?)
	local resolution = ResolutionPolicy.resolve(RunService:IsStudio(), function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)

	if resolution.Mode == "StudioVolatile" then
		warn(
			string.format(
				"[AtlasPersistence] Studio session detected; using volatile in-memory storage instead of DataStore %s. "
					.. "Progress will not persist across Studio sessions.",
				dataStoreName
			)
		)
	elseif resolution.Mode == "LiveUnavailable" then
		warn(
			string.format(
				"[AtlasPersistence] DataStore %s is unavailable (%s); inventory reads and writes will fail closed.",
				dataStoreName,
				tostring(resolution.Reason)
			)
		)
	end

	return resolution.Store, resolution.Mode ~= "LiveDurable", resolution.Mode
end

function Adapter.new(options: Options?): Adapter
	local resolved = options or {}
	local dataStoreName = resolved.DataStoreName or "AtlasPlayerInventoryV1"
	local keyPrefix = resolved.KeyPrefix or "atlas"
	local maximumAttempts = resolved.MaximumAttempts or 4
	local baseRetryDelaySeconds = resolved.BaseRetryDelaySeconds or 0.5

	assert(type(dataStoreName) == "string" and #dataStoreName >= 3, "invalid DataStore name")
	assert(type(keyPrefix) == "string" and #keyPrefix >= 1, "invalid key prefix")
	assertPositiveInteger(maximumAttempts, "MaximumAttempts")
	assert(type(baseRetryDelaySeconds) == "number" and baseRetryDelaySeconds >= 0, "invalid retry delay")

	local store, isVolatile, storageMode = resolveStore(dataStoreName)

	return setmetatable({
		_store = store,
		_isVolatile = isVolatile,
		_storageMode = storageMode,
		_keyPrefix = keyPrefix,
		_maximumAttempts = maximumAttempts,
		_baseRetryDelaySeconds = baseRetryDelaySeconds,
		_failedLoadKeys = {},
	}, Adapter) :: any
end

function Adapter:_qualifiedKey(key: string): string
	assert(type(key) == "string" and #key >= 3 and #key <= 120, "invalid persistence key")
	return string.format("%s:%s", (self :: any)._keyPrefix, key)
end

function Adapter:storageMode(): string
	return (self :: any)._storageMode
end

--[[
	GetAsync returning nil successfully means the key is absent -- Missing.
	Exhausting retries means we do not know -- Failed. Collapsing both to a bare
	nil is what let an outage read as "new player" and overwrite a real record,
	so the two are separate statuses here and the uncertain key is remembered:
	writes stay refused until a later successful read reconciles durable state.
]]
function Adapter:read(key: string): ReadResult
	local selfAny = self :: any
	local qualifiedKey = self:_qualifiedKey(key)
	local lastError: any = nil
	for attempt = 1, selfAny._maximumAttempts do
		local success, value = pcall(function()
			return selfAny._store:GetAsync(qualifiedKey)
		end)
		if success then
			selfAny._failedLoadKeys[qualifiedKey] = nil
			if value == nil then
				return StorageResults.missing()
			end
			return StorageResults.found(value)
		end
		lastError = value
		if attempt < selfAny._maximumAttempts then
			task.wait(retryDelay(selfAny._baseRetryDelaySeconds, attempt))
		end
	end

	selfAny._failedLoadKeys[qualifiedKey] = true
	warn(string.format("[AtlasPersistence] read failed for %s: %s", qualifiedKey, tostring(lastError)))
	return StorageResults.readFailed(lastError)
end

function Adapter:update(key: string, transform: (any) -> any): (boolean, any)
	local selfAny = self :: any
	local qualifiedKey = self:_qualifiedKey(key)
	local lastError: any = nil
	for attempt = 1, selfAny._maximumAttempts do
		local success, value = pcall(function()
			return selfAny._store:UpdateAsync(qualifiedKey, transform)
		end)
		if success then
			return true, value
		end
		lastError = value
		if attempt < selfAny._maximumAttempts then
			task.wait(retryDelay(selfAny._baseRetryDelaySeconds, attempt))
		end
	end
	warn(string.format("[AtlasPersistence] update failed for %s: %s", qualifiedKey, tostring(lastError)))
	return false, nil
end

--[[
	Committed carries the value the store actually holds after the transform,
	not the value the caller offered, so a later comparison is made against
	committed identity rather than intent.
]]
function Adapter:commit(key: string, transform: (any) -> any): WriteResult
	local selfAny = self :: any
	local qualifiedKey = self:_qualifiedKey(key)
	if selfAny._failedLoadKeys[qualifiedKey] == true then
		warn(
			string.format(
				"[AtlasPersistence] refusing write for %s because its latest read exhausted retries; "
					.. "a successful read must reconcile durable state first",
				qualifiedKey
			)
		)
		return StorageResults.writeFailed("UnreconciledRead")
	end
	local ok, value = self:update(key, transform)
	if not ok then
		return StorageResults.writeFailed("StorageUpdateFailed")
	end
	return StorageResults.committed(value)
end

function Adapter:write(key: string, value: any): WriteResult
	return self:commit(key, function()
		return value
	end)
end

return table.freeze(Adapter)
