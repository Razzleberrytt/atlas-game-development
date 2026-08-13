--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "lease assertion failed", 2)
	end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventorySessionLeaseService.luau"), {
	debugName = "InventorySessionLeaseService",
	environment = {},
	injectGlobals = true,
})()

local store = { data = {}, fail = false }
function store:update(key: string, transform)
	if self.fail then
		return false, nil
	end
	local nextValue = transform(self.data[key])
	self.data[key] = nextValue
	return true, nextValue
end

local first = module.new(store, "server-owner-aaaaaaaa", 90)
local second = module.new(store, "server-owner-bbbbbbbb", 90)

local acquired = first:acquire(101, 1000)
assert(acquired.Accepted and acquired.ReasonId == "LeaseAcquired", "first server should acquire")
assert(first:hasLease(101, 1001), "first server should own active lease")

local blocked = second:acquire(101, 1010)
assert(not blocked.Accepted and blocked.ReasonId == "LeaseHeldByAnotherServer", "second server must be blocked")

local renewed = first:renew(101, 1030)
assert(renewed.Accepted and renewed.ExpiresAtUnix == 1120, "owner should renew")

local wrongRelease = second:release(101)
assert(not wrongRelease.Accepted and wrongRelease.ReasonId == "LeaseNotOwned", "wrong owner cannot release")
assert(first:hasLease(101, 1031), "wrong release must not affect owner")

local takeoverBlocked = second:acquire(101, 1119)
assert(not takeoverBlocked.Accepted, "takeover before expiry must fail")
local takeover = second:acquire(101, 1120)
assert(takeover.Accepted, "stale lease should be replaceable at expiry")

local lostRenewal = first:renew(101, 1121)
assert(not lostRenewal.Accepted and lostRenewal.ReasonId == "LeaseLost", "old owner must detect lease loss")

local released = second:release(101)
assert(released.Accepted and released.ReasonId == "LeaseReleased", "current owner should release")

store.fail = true
local failed = first:acquire(202, 1200)
assert(not failed.Accepted and failed.ReasonId == "LeaseStoreFailed", "store failures must fail closed")
store.fail = false

first:acquire(303, 1300)
first:acquire(404, 1300)
first:releaseAll()
assert(
	store.data["player:303:lease"] == nil and store.data["player:404:lease"] == nil,
	"releaseAll should clear owned leases"
)

--[[
	Patch 0.7 retried-transform contract. A single update may run the transform
	more than once: the store adapter retries a failed attempt with the same
	closure, and UpdateAsync re-runs the transform when the key changes under
	contention. Only the final invocation describes what was written.

	This store runs the transform twice, replacing the key's value in between, so
	the first invocation observes state that no longer applies.
]]
local contendedStore = { data = {}, firstPassValue = nil :: any }
function contendedStore:update(key: string, transform)
	transform(self.firstPassValue)
	local nextValue = transform(self.data[key])
	self.data[key] = nextValue
	return true, nextValue
end

local contended = module.new(contendedStore, "server-owner-cccccccc", 90)
local rival = { OwnerId = "server-owner-dddddddd", AcquiredAtUnix = 1000, RenewedAtUnix = 1000, ExpiresAtUnix = 9000 }

-- The discarded first invocation sees a live rival lease; the committed one sees
-- a free key. The acquisition must be reported, not the stale block.
contendedStore.firstPassValue = rival
contendedStore.data["player:505:lease"] = nil
local contendedAcquire = contended:acquire(505, 2000)
assert(contendedAcquire.Accepted, "a discarded blocked invocation must not veto a committed acquisition")
assert(contendedAcquire.ReasonId == "LeaseAcquired", "the committed acquisition must be reported")
assert(contended:hasLease(505, 2001), "a committed acquisition must be tracked so it can be released")

-- The reverse: the discarded invocation sees our own lease, the committed one
-- finds a rival. The owner check on the returned value already covers this
-- direction; the assertion holds it so a future refactor cannot make the flag
-- the only thing standing between this server and an inventory it lost.
contendedStore.firstPassValue = contendedStore.data["player:505:lease"]
contendedStore.data["player:505:lease"] = rival
local contendedRenew = contended:renew(505, 2010)
assert(not contendedRenew.Accepted, "a discarded successful invocation must not report a renewal that did not commit")
assert(contendedRenew.ReasonId == "LeaseLost", "losing the key to another server must be reported as a loss")
assert(not contended:hasLease(505, 2011), "a lost lease must not stay cached as owned")

contendedStore.firstPassValue = nil
contended:destroy()

first:destroy()
second:destroy()
print("InventorySessionLeaseService.test.luau passed")
