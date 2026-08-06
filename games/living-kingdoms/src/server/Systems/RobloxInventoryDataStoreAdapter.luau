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

	return setmetatable({
		_store = DataStoreService:GetDataStore(dataStoreName),
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
		if success then return value end
		lastError = value
		if attempt < selfAny._maximumAttempts then task.wait(retryDelay(selfAny._baseRetryDelaySeconds, attempt)) end
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
		if success then return true, value end
		lastError = value
		if attempt < selfAny._maximumAttempts then task.wait(retryDelay(selfAny._baseRetryDelaySeconds, attempt)) end
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
