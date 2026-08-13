--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "inventory datastore adapter load-guard assertion failed", 2)
	end
end

local fakeStore = {
	value = { Marker = "durable" },
	failReads = true,
	getCalls = 0,
	updateCalls = 0,
}

function fakeStore:GetAsync(_key: string): any
	self.getCalls += 1
	if self.failReads then
		error("simulated GetAsync outage")
	end
	return self.value
end

function fakeStore:UpdateAsync(_key: string, transform: (any) -> any): any
	self.updateCalls += 1
	self.value = transform(self.value)
	return self.value
end

local dataStoreService = {}
function dataStoreService:GetDataStore(name: string): any
	assert(name == "AtlasInventoryLoadGuardTest", "unexpected datastore name")
	return fakeStore
end

local runService = {}
function runService:IsStudio(): boolean
	return false
end

local warnings = {}
local adapterModule = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/RobloxInventoryDataStoreAdapter.luau"),
	{
		debugName = "RobloxInventoryDataStoreAdapter",
		environment = {
			game = {
				GetService = function(_self: unknown, name: string): any
					if name == "DataStoreService" then
						return dataStoreService
					elseif name == "RunService" then
						return runService
					end
					error("unexpected service: " .. name)
				end,
			},
			task = {
				wait = function(_seconds: number) end,
			},
			warn = function(message: string)
				table.insert(warnings, message)
			end,
		},
		injectGlobals = true,
	}
)()

local adapter = adapterModule.new({
	DataStoreName = "AtlasInventoryLoadGuardTest",
	KeyPrefix = "test",
	MaximumAttempts = 2,
	BaseRetryDelaySeconds = 0,
})
local key = "player:101:inventory"

local failedLoad = adapter:load(key)
assert(failedLoad == nil, "an exhausted read still returns nil to the legacy load caller")
assert(fakeStore.getCalls == 2, "the load path must exhaust its configured retry budget")

local attemptedBlank = { Marker = "blank" }
local savesBeforeGuard = fakeStore.updateCalls
local guardedSave = adapter:save(key, attemptedBlank)
assert(not guardedSave, "a save after an uncertain load must fail closed")
assert(fakeStore.updateCalls == savesBeforeGuard, "the guarded save must not reach UpdateAsync")
assert(fakeStore.value.Marker == "durable", "the durable record must survive the read outage untouched")

fakeStore.failReads = false
local reconciled = adapter:load(key)
assert(reconciled.Marker == "durable", "a successful reread must recover durable truth")
local savedAfterReconcile = adapter:save(key, { Marker = "updated" })
assert(savedAfterReconcile, "a successful reread must clear the write guard")
assert(fakeStore.updateCalls == savesBeforeGuard + 1, "the reconciled save must reach UpdateAsync exactly once")
assert(fakeStore.value.Marker == "updated", "the reconciled save must persist the requested record")

fakeStore.value = nil
local missing = adapter:load("player:202:inventory")
assert(missing == nil, "a successful read of an absent key must remain distinguishable by the cleared guard")
local created = adapter:save("player:202:inventory", { Marker = "new" })
assert(created, "a genuinely absent key must still allow first-record creation")
assert(fakeStore.value.Marker == "new", "first-record creation must persist after a successful missing-key read")
assert(#warnings >= 2, "the exhausted load and guarded save should remain observable")

print("RobloxInventoryDataStoreAdapterLoadGuard.test.luau passed")
