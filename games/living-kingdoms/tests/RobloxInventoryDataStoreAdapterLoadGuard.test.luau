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

local POLICY_TOKEN, RESULTS_TOKEN = {}, {}
local storageResults =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/StorageResultContracts.luau"), {
		debugName = "StorageResultContracts",
		injectGlobals = true,
	})()
local resolutionPolicy =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventoryDataStoreResolutionPolicy.luau"), {
		debugName = "InventoryDataStoreResolutionPolicy",
		injectGlobals = true,
	})()

local warnings = {}
local adapterModule =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/RobloxInventoryDataStoreAdapter.luau"), {
		debugName = "RobloxInventoryDataStoreAdapter",
		environment = {
			game = {
				GetService = function(_self: unknown, name: string): any
					if name == "DataStoreService" then
						return dataStoreService
					elseif name == "RunService" then
						return runService
					elseif name == "ReplicatedStorage" then
						return { Shared = { Persistence = { StorageResultContracts = RESULTS_TOKEN } } }
					end
					error("unexpected service: " .. name)
				end,
			},
			script = { Parent = { InventoryDataStoreResolutionPolicy = POLICY_TOKEN } },
			require = function(token: unknown): any
				if token == POLICY_TOKEN then
					return resolutionPolicy
				elseif token == RESULTS_TOKEN then
					return storageResults
				end
				error("unexpected adapter dependency")
			end,
			task = {
				wait = function(_seconds: number) end,
			},
			warn = function(message: string)
				table.insert(warnings, message)
			end,
		},
		injectGlobals = true,
	})()

local adapter = adapterModule.new({
	DataStoreName = "AtlasInventoryLoadGuardTest",
	KeyPrefix = "test",
	MaximumAttempts = 2,
	BaseRetryDelaySeconds = 0,
})
local key = "player:101:inventory"

local failedLoad = adapter:read(key)
assert(failedLoad.Status == "Failed", "an exhausted read must report Failed rather than a bare nil")
assert(failedLoad.Value == nil, "a failed read must disclose no value")
assert(fakeStore.getCalls == 2, "the load path must exhaust its configured retry budget")

local attemptedBlank = { Marker = "blank" }
local savesBeforeGuard = fakeStore.updateCalls
local guardedSave = adapter:write(key, attemptedBlank)
assert(guardedSave.Status == "Failed", "a write after an uncertain read must fail closed")
assert(guardedSave.Reason == "UnreconciledRead", "the refusal must name the unreconciled read")
assert(fakeStore.updateCalls == savesBeforeGuard, "the guarded save must not reach UpdateAsync")
assert(fakeStore.value.Marker == "durable", "the durable record must survive the read outage untouched")

fakeStore.failReads = false
local reconciled = adapter:read(key)
assert(reconciled.Status == "Found", "a successful reread of a present key must report Found")
assert(reconciled.Value.Marker == "durable", "a successful reread must recover durable truth")
local savedAfterReconcile = adapter:write(key, { Marker = "updated" })
assert(savedAfterReconcile.Status == "Committed", "a successful reread must clear the write guard")
assert(savedAfterReconcile.Value.Marker == "updated", "a committed write must carry the stored value")
assert(fakeStore.updateCalls == savesBeforeGuard + 1, "the reconciled save must reach UpdateAsync exactly once")
assert(fakeStore.value.Marker == "updated", "the reconciled save must persist the requested record")

fakeStore.value = nil
local missing = adapter:read("player:202:inventory")
assert(missing.Status == "Missing", "an absent key must read as Missing, never as Failed")
local created = adapter:write("player:202:inventory", { Marker = "new" })
assert(created.Status == "Committed", "a genuinely absent key must still allow first-record creation")
assert(fakeStore.value.Marker == "new", "first-record creation must persist after a successful missing-key read")
assert(#warnings >= 2, "the exhausted load and guarded save should remain observable")

print("RobloxInventoryDataStoreAdapterLoadGuard.test.luau passed")
