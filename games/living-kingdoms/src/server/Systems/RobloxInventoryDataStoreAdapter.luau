--!strict

-- Production storage adapter for inventory records and atomic session leases.
-- Studio is intentionally isolated from the production DataStore even when
-- Studio Access to API Services is enabled: evidence/playtest sessions must not
-- acquire production leases or mutate/migrate live inventory records.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

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
	-- This check must happen before GetDataStore. Studio API access may be needed
	-- for unrelated evidence tooling, but it must never opt inventory into the
	-- production AtlasPlayerInventoryV1 store or atlas-prod lease namespace.
	if RunService:IsStudio() then
		warn(
			string.format(
				"[AtlasPersistence] Studio session detected; using volatile in-memory storage instead of DataStore %s. "
					.. "Progress will not persist across Studio sessions.",
				dataStoreName
			)
		)
		return createVolatileStore(), true
	end

	-- Live servers use the real store. Keep the existing fail-soft construction
	-- fallback for unpublished/nonstandard environments where GetDataStore itself
	-- is unavailable, but never use it as the Studio isolation mechanism.
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
