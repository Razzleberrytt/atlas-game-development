--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local InventoryDataStoreResolutionPolicy = require(script.Parent.InventoryDataStoreResolutionPolicy)

export type ReadResult =
	{ Status: "Found", Value: any }
	| { Status: "Missing" }
	| { Status: "Failed", ReasonId: string }

export type UpdateResult =
	{ Status: "Committed", CommittedValue: any }
	| { Status: "Failed", ReasonId: string }

export type SaveResult =
	{ Status: "Saved", CommittedValue: any }
	| { Status: "Failed", ReasonId: string }

export type Adapter = {
	load: (self: Adapter, key: string) -> any,
	save: (self: Adapter, key: string, value: any) -> boolean,
	update: (self: Adapter, key: string, transform: (any) -> any) -> (boolean, any),
	read: (self: Adapter, key: string) -> ReadResult,
	updateResult: (self: Adapter, key: string, transform: (any) -> any) -> UpdateResult,
	saveResult: (self: Adapter, key: string, value: any) -> SaveResult,
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

local function resolveStore(dataStoreName: string): (any, boolean)
	local resolution = InventoryDataStoreResolutionPolicy.resolve(RunService:IsStudio(), function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)
	return resolution.Store, resolution.Mode == "StudioVolatile"
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
		_failedLoadKeys = {},
	}, Adapter) :: any
end

function Adapter:_qualifiedKey(key: string): string
	assert(type(key) == "string" and #key >= 3 and #key <= 120, "invalid persistence key")
	return string.format("%s:%s", (self :: any)._keyPrefix, key)
end

local function loadWithRetry(self: Adapter, qualifiedKey: string): (boolean, any)
	local selfAny = self :: any
	local lastError: any = nil
	for attempt = 1, selfAny._maximumAttempts do
		local success, value = pcall(function()
			return selfAny._store:GetAsync(qualifiedKey)
		end)
		if success then
			selfAny._failedLoadKeys[qualifiedKey] = nil
			return true, value
		end
		lastError = value
		if attempt < selfAny._maximumAttempts then
			task.wait(retryDelay(selfAny._baseRetryDelaySeconds, attempt))
		end
	end
	selfAny._failedLoadKeys[qualifiedKey] = true
	warn(string.format("[AtlasPersistence] read unavailable for %s: %s", qualifiedKey, tostring(lastError)))
	return false, nil
end

function Adapter:read(key: string): ReadResult
	local success, value = loadWithRetry(self, self:_qualifiedKey(key))
	if not success then
		return table.freeze({ Status = "Failed", ReasonId = "RetryExhausted" })
	end
	if value == nil then
		return table.freeze({ Status = "Missing" })
	end
	return table.freeze({ Status = "Found", Value = value })
end

function Adapter:load(key: string): any
	local outcome = self:read(key)
	return if outcome.Status == "Found" then outcome.Value else nil
end

local function updateWithRetry(self: Adapter, qualifiedKey: string, transform: (any) -> any): (boolean, any)
	local selfAny = self :: any
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
	warn(string.format("[AtlasPersistence] update unavailable for %s: %s", qualifiedKey, tostring(lastError)))
	return false, nil
end

function Adapter:updateResult(key: string, transform: (any) -> any): UpdateResult
	if type(transform) ~= "function" then
		return table.freeze({ Status = "Failed", ReasonId = "InvalidTransform" })
	end
	local success, value = updateWithRetry(self, self:_qualifiedKey(key), transform)
	if not success then
		return table.freeze({ Status = "Failed", ReasonId = "RetryExhausted" })
	end
	return table.freeze({ Status = "Committed", CommittedValue = value })
end

function Adapter:update(key: string, transform: (any) -> any): (boolean, any)
	local outcome = self:updateResult(key, transform)
	if outcome.Status == "Committed" then
		return true, outcome.CommittedValue
	end
	return false, nil
end

function Adapter:saveResult(key: string, value: any): SaveResult
	local selfAny = self :: any
	local qualifiedKey = self:_qualifiedKey(key)
	if selfAny._failedLoadKeys[qualifiedKey] == true then
		return table.freeze({ Status = "Failed", ReasonId = "ReadReconciliationRequired" })
	end
	local outcome = self:updateResult(key, function()
		return value
	end)
	if outcome.Status ~= "Committed" then
		return table.freeze({ Status = "Failed", ReasonId = outcome.ReasonId })
	end
	return table.freeze({ Status = "Saved", CommittedValue = outcome.CommittedValue })
end

function Adapter:save(key: string, value: any): boolean
	return self:saveResult(key, value).Status == "Saved"
end

return table.freeze(Adapter)
