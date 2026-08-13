--!strict

--[[
	Patch 0.7 Batch 2 storage-contract audit.

	Two invariants worth pinning statically, because both regress silently:

	  1. store selection has one owner. The adapter used to carry its own Studio
	     branch and its own volatile-store constructor; a copy drifting back in
	     would reintroduce the fail-soft live fallback that let a published
	     server run a whole session on storage that evaporates.
	  2. persistence reads go through explicit statuses. A reintroduced bare
	     `nil` read cannot distinguish an absent record from a failed one, which
	     is the exact ambiguity that turned an outage into a blank overwrite.
]]

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local adapterSource = fs.readFile("games/living-kingdoms/src/server/Systems/RobloxInventoryDataStoreAdapter.luau")
local persistenceSource = fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau")

local function adapterHas(needle: string): boolean
	return string.find(adapterSource, needle, 1, true) ~= nil
end

local function persistenceHas(needle: string): boolean
	return string.find(persistenceSource, needle, 1, true) ~= nil
end

-- 1. Canonical store resolution ---------------------------------------------

check(
	adapterHas("require(script.Parent.InventoryDataStoreResolutionPolicy)"),
	"the live inventory adapter must consume the canonical storage resolution policy"
)
check(
	adapterHas("ResolutionPolicy.resolve(RunService:IsStudio()"),
	"storage resolution must be delegated with the Studio decision, not re-derived"
)
check(
	not adapterHas("local function createVolatileStore"),
	"the adapter must not keep its own volatile store constructor beside the policy"
)
check(
	not adapterHas("using a volatile in-memory store"),
	"a live DataStore failure must fail closed, not fall soft to volatile storage"
)

-- 2. Explicit storage outcomes ----------------------------------------------

check(adapterHas("StorageResults.missing()"), "an absent key must read as Missing")
check(adapterHas("StorageResults.found(value)"), "a present key must read as Found")
check(adapterHas("StorageResults.readFailed(lastError)"), "an exhausted read must report Failed, never a bare nil")
check(adapterHas("StorageResults.committed(value)"), "a committed write must carry the value the store holds")
check(adapterHas("StorageResults.writeFailed("), "a refused or failed write must say which it was")

check(
	persistenceHas('ReasonId = "LoadFailed"'),
	"a failed read must surface as LoadFailed rather than borrowing a write reason"
)
check(
	persistenceHas("readResult.Status == StorageResults.ReadStatuses.Failed"),
	"persistence must branch on read status before normalizing a record"
)
check(not persistenceHas("_store:load("), "persistence must not read through the ambiguous bare-nil load surface")
check(not persistenceHas("_store:save("), "persistence must not write through the bare-boolean save surface")

--[[
	Ordering matters as much as presence: the read status has to be checked
	before normalizeRecord runs, or a failed read still builds a blank record and
	only a downstream write guard stops it from being persisted.
]]
local statusCheckAt = string.find(persistenceSource, "readResult.Status == StorageResults.ReadStatuses.Failed", 1, true)
local normalizeAt = string.find(persistenceSource, "local normalized, migrated, reasonId = normalizeRecord", 1, true)
check(statusCheckAt ~= nil and normalizeAt ~= nil, "expected both the read-status check and the normalize call")
check(
	(statusCheckAt :: number) < (normalizeAt :: number),
	"the read-status check must precede normalization, not clean up after it"
)

print("InventoryStorageContractSourceAudit: canonical resolution and explicit storage outcomes passed")
