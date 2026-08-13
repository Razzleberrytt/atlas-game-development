--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "inventory store resolution assertion failed", 2)
	end
end

local policy =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventoryDataStoreResolutionPolicy.luau"), {
		debugName = "InventoryDataStoreResolutionPolicy",
		injectGlobals = true,
	})()

-- Studio must never even attempt to open the live store.
local studioOpenCalls = 0
local studio = policy.resolve(true, function()
	studioOpenCalls += 1
	error("studio must not open the live store")
end)
assert(studio.Mode == "StudioVolatile", "Studio must select isolated volatile storage")
assert(studioOpenCalls == 0, "Studio must not call the live store opener")
assert(studio.Reason == nil, "Studio resolution should not report an error reason")
assert(studio.Store:GetAsync("a") == nil, "a new volatile store starts empty")
local studioValue = studio.Store:UpdateAsync("a", function(current)
	assert(current == nil, "the first volatile transform sees no value")
	return { Marker = "studio" }
end)
assert(studioValue.Marker == "studio", "volatile UpdateAsync returns the committed value")
assert(studio.Store:GetAsync("a").Marker == "studio", "volatile state is readable inside the same session")

local secondStudio = policy.resolve(true, function()
	error("studio must not open the live store")
end)
assert(secondStudio.Store:GetAsync("a") == nil, "separate Studio resolutions must not share volatile state")

-- A healthy live environment must return the exact durable store supplied by
-- the opener and must not wrap or replace it with process-local state.
local durableValues: { [string]: any } = { existing = { Marker = "durable" } }
local durableStore = {}
function durableStore:GetAsync(key: string): any
	return durableValues[key]
end
function durableStore:UpdateAsync(key: string, transform: (any) -> any): any
	local updated = transform(durableValues[key])
	durableValues[key] = updated
	return updated
end
local liveOpenCalls = 0
local live = policy.resolve(false, function()
	liveOpenCalls += 1
	return durableStore
end)
assert(live.Mode == "LiveDurable", "a healthy live environment must select the durable store")
assert(liveOpenCalls == 1, "the live store opener should run exactly once")
assert(live.Store == durableStore, "the healthy live resolution must preserve the exact durable store")
assert(live.Store:GetAsync("existing").Marker == "durable", "healthy live reads must use durable truth")
live.Store:UpdateAsync("existing", function(current)
	assert(current.Marker == "durable", "the live transform must receive durable state")
	return { Marker = "updated" }
end)
assert(durableValues.existing.Marker == "updated", "healthy live updates must persist through the supplied store")

-- A live opener failure must produce a deliberately unavailable store. It must
-- not create a writable in-memory substitute that could pretend valuable state
-- was safely persisted.
local unavailable = policy.resolve(false, function()
	error("simulated open failure")
end)
assert(unavailable.Mode == "LiveUnavailable", "a failed live opener must select unavailable mode")
assert(type(unavailable.Reason) == "string", "unavailable mode must preserve an observable reason")
assert(
	string.find(unavailable.Reason, "simulated open failure", 1, true) ~= nil,
	"the failure reason must remain diagnosable"
)

local readOk = pcall(function()
	unavailable.Store:GetAsync("player:101:inventory")
end)
assert(not readOk, "an unavailable live store must reject reads")

local transformCalls = 0
local updateOk = pcall(function()
	unavailable.Store:UpdateAsync("player:101:inventory", function()
		transformCalls += 1
		return { Marker = "must-not-write" }
	end)
end)
assert(not updateOk, "an unavailable live store must reject updates")
assert(transformCalls == 0, "an unavailable live store must not run the caller transform")

local nilStoreOk = pcall(function()
	policy.resolve(false, function()
		return nil
	end)
end)
assert(not nilStoreOk, "a live opener that returns nil is invalid rather than a missing durable store")

local invalidStudioOk = pcall(function()
	policy.resolve("yes" :: any, function()
		return durableStore
	end)
end)
assert(not invalidStudioOk, "the environment mode must be an explicit boolean")

local invalidOpenerOk = pcall(function()
	policy.resolve(false, nil :: any)
end)
assert(not invalidOpenerOk, "the live store opener must be a function")

print("InventoryDataStoreResolutionPolicy.test.luau passed")
