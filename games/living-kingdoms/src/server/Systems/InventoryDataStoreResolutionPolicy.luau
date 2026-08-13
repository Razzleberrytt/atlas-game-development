--!strict

export type ResolutionMode = "StudioVolatile" | "LiveDurable" | "LiveUnavailable"

export type Resolution = {
	Mode: ResolutionMode,
	Store: any,
	Reason: string?,
}

local Policy = {}

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

local function createUnavailableStore(reason: any)
	local message = tostring(reason)
	local store = {}

	function store:GetAsync(_key: string): any
		error("storage backend unavailable: " .. message, 0)
	end

	function store:UpdateAsync(_key: string, _transform: (any) -> any): any
		error("storage backend unavailable: " .. message, 0)
	end

	return store
end

function Policy.resolve(isStudio: boolean, openLiveStore: () -> any): Resolution
	assert(type(isStudio) == "boolean", "isStudio must be boolean")
	assert(type(openLiveStore) == "function", "openLiveStore must be a function")

	if isStudio then
		return table.freeze({
			Mode = "StudioVolatile",
			Store = createVolatileStore(),
			Reason = nil,
		})
	end

	local success, storeOrError = pcall(openLiveStore)
	if success then
		assert(storeOrError ~= nil, "live store opener returned nil")
		return table.freeze({
			Mode = "LiveDurable",
			Store = storeOrError,
			Reason = nil,
		})
	end

	return table.freeze({
		Mode = "LiveUnavailable",
		Store = createUnavailableStore(storeOrError),
		Reason = tostring(storeOrError),
	})
end

return table.freeze(Policy)
