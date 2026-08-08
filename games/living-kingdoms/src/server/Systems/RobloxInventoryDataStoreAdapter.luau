--!strict

-- Production storage adapter for inventory records and atomic session leases.

local DataStoreService = game:GetService("DataStoreService")

export type Adapter = {
	load: (self: Adapter, key: string) -> any,
	save: (self: Adapter, key: string, value: any) -> boolean,
	update: (self: Adapter, key: string, transform: (any) -> any) -> (boolean, any),
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

-- An unpublished place has no DataStore access, so `GetDataStore` throws at
-- construction time. Every read/write below is already retried under pcall, but
-- a throw here loads-errors this module and takes the whole inventory,
-- expedition-reward and expedition-result chain down with it. Fall back to a
-- process-local store so Studio sessions stay bootable; a live server always
-- reaches the real DataStore and never takes this path.
local function createVolatileStore()
	local values: { [string]: any } = {}
	local store = {}

	function store:GetAsync(key: string): any
		return values[key]
	end

	function store:UpdateAsync(key: string, transform: (any) -> any): any
		local updated = transform(values[key])
		values[key] = updated
		return updated
	end

	return store
end

local function resolveStore(dataStoreName: string): (any, boolean)
	local success, storeOrError = pcall(function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)
	if success then
		return storeOrError, false
	end
	warn(
		string.format(
			"[AtlasPersistence] DataStore %s is unavailable (%s); using a volatile in-memory store. "
				.. "Progress will not persist across sessions.",
			dataStoreName,
			tostring(storeOrError)
		)
	)
	return createVolatileStore(), true
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

	local store, isVolatile = resolveStore(dataStoreName)

	return setmetatable({
		_store = store,
		_isVolatile = isVolatile,
		_keyPrefix = keyPrefix,
		_maximumAttempts = maximumAttempts,
		_baseRetryDelaySeconds = baseRetryDelaySeconds,
	}, Adapter) :: any
end

function Adapter:_qualifiedKey(key: string): string
	assert(type(key) == "string" and #key >= 3 and #key <= 120, "invalid persistence key")
	return string.format("%s:%s", (self :: any)._keyPrefix, key)
end

function Adapter:load(key: string): any
	local selfAny = self :: any
	local qualifiedKey = self:_qualifiedKey(key)
	local lastError: any = nil
	for attempt = 1, selfAny._maximumAttempts do
		local success, value = pcall(function()
			return selfAny._store:GetAsync(qualifiedKey)
		end)
		if success then
			return value
		end
		lastError = value
		if attempt < selfAny._maximumAttempts then
			task.wait(retryDelay(selfAny._baseRetryDelaySeconds, attempt))
		end
	end
	warn(string.format("[AtlasPersistence] load failed for %s: %s", qualifiedKey, tostring(lastError)))
	return nil
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

function Adapter:save(key: string, value: any): boolean
	local success = self:update(key, function()
		return value
	end)
	return success
end

return table.freeze(Adapter)
