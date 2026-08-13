--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "lease assertion failed", 2)
	end
end

local warnings: { string } = {}
local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventorySessionLeaseService.luau"), {
	debugName = "InventorySessionLeaseService",
	environment = {
		warn = function(message: string)
			table.insert(warnings, message)
		end,
	},
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

--[[
	#26: a server that has lost the lease must not be able to release it. Doing so
	would delete the new owner's record and hand the player to whoever asked next.
]]
local releaseAfterLoss = first:release(101)
assert(not releaseAfterLoss.Accepted, "a server that lost the lease must not release it")
assert(releaseAfterLoss.ReasonId == "LeaseNotOwned", "the refusal must name the lost ownership")
assert(store.data["player:101:lease"] ~= nil, "a refused release must leave the new owner's lease intact")
assert(store.data["player:101:lease"].OwnerId == "server-owner-bbbbbbbb", "the new owner must still hold the key")

--[[
	#27: the expiry boundary in all three directions. Before expiry the lease
	holds; at expiry it is takeable; after expiry it stays takeable. hasLease must
	agree with the store on each side.
]]
assert(second:hasLease(101, 1209), "the holder's cached lease is live before expiry")
assert(not second:hasLease(101, 1210), "a cached lease must expire exactly at its expiry, not after")
assert(not second:hasLease(101, 1211), "a cached lease must stay expired past its expiry")

local released = second:release(101)
assert(released.Accepted and released.ReasonId == "LeaseReleased", "current owner should release")

local function boundaryTakeoverAt(nowUnix: number): boolean
	store.data["player:606:lease"] = nil
	local holder = module.new(store, "server-owner-cccccccc", 90)
	local rival = module.new(store, "server-owner-dddddddd", 90)
	assert(holder:acquire(606, 5000).Accepted, "the boundary lease is acquired at 5000, expiring at 5090")
	local takeover = rival:acquire(606, nowUnix).Accepted
	holder:destroy()
	rival:destroy()
	store.data["player:606:lease"] = nil
	return takeover
end

assert(not boundaryTakeoverAt(5089), "a rival must be blocked one second before expiry")
assert(boundaryTakeoverAt(5090), "a rival may take the key exactly at expiry")
assert(boundaryTakeoverAt(5091), "a rival may take the key after expiry")

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
--[[
	Batch 3 #21/#22: a lease record that exists but cannot be parsed must be
	honoured, not replaced. The old guard required every field to be well typed
	AND the owner to differ AND the expiry to be in the future, so a rival lease
	with a malformed field failed the condition and fell through to the
	overwrite -- leaving two servers both believing they owned the player.
]]
local malformedStore = { data = {} }
function malformedStore:update(key: string, transform)
	local nextValue = transform(self.data[key])
	self.data[key] = nextValue
	return true, nextValue
end

local guard = module.new(malformedStore, "server-owner-eeeeeeee", 90)
local rivalRecords = {
	{ OwnerId = "server-owner-ffffffff", AcquiredAtUnix = 1, RenewedAtUnix = 1, ExpiresAtUnix = "soon" },
	{ OwnerId = "server-owner-ffffffff", AcquiredAtUnix = 1, RenewedAtUnix = 1 },
	{ OwnerId = "", AcquiredAtUnix = 1, RenewedAtUnix = 1, ExpiresAtUnix = 9000 },
	{ AcquiredAtUnix = 1, RenewedAtUnix = 1, ExpiresAtUnix = 9000 },
	{ OwnerId = "server-owner-ffffffff", ExpiresAtUnix = 9000 },
	{ OwnerId = "server-owner-ffffffff", AcquiredAtUnix = 1, RenewedAtUnix = 1, ExpiresAtUnix = 0 / 0 },
	"not-a-table",
}

for index, record in rivalRecords do
	malformedStore.data["player:707:lease"] = record
	local outcome = guard:acquire(707, 1000)
	assert(not outcome.Accepted, "a malformed lease record must not be acquirable: case " .. index)
	assert(outcome.ReasonId == "LeaseRecordMalformed", "a malformed record must be named as such: case " .. index)
	assert(
		malformedStore.data["player:707:lease"] == record,
		"a malformed record must survive untouched: case " .. index
	)
	assert(not guard:hasLease(707, 1001), "a refused acquire must not cache a lease: case " .. index)
end

-- An absent key is not malformed; first acquisition must still work.
malformedStore.data["player:707:lease"] = nil
local firstAcquire = guard:acquire(707, 1000)
assert(firstAcquire.Accepted, "an absent lease key must remain acquirable")
assert(
	malformedStore.data["player:707:lease"].OwnerGeneration ~= nil,
	"a written lease must carry its owner generation"
)

-- #23: two services sharing an owner id stay distinguishable in the record.
local twin = module.new(malformedStore, "server-owner-eeeeeeee", 90)
assert(
	(twin :: any)._ownerGeneration ~= (guard :: any)._ownerGeneration,
	"two lease services must not share an owner generation"
)

-- A malformed record also cannot be renewed into a repaired one.
malformedStore.data["player:707:lease"] = { OwnerId = "server-owner-eeeeeeee", ExpiresAtUnix = "soon" }
local malformedRenew = guard:renew(707, 1010)
assert(not malformedRenew.Accepted and malformedRenew.ReasonId == "LeaseLost", "a malformed record must not be renewed")
assert(
	malformedStore.data["player:707:lease"].ExpiresAtUnix == "soon",
	"a refused renewal must leave the unparseable record alone"
)

--[[
	#28/#29: shutdown release used to discard every result, so a store failure
	left a durable lease behind with nothing recording it and the player locked
	out until it expired -- indistinguishable from a clean shutdown.
]]
local shutdownStore = { data = {}, failUpdates = false, updateCalls = 0 }
function shutdownStore:update(key: string, transform)
	self.updateCalls += 1
	if self.failUpdates then
		return false, nil
	end
	local nextValue = transform(self.data[key])
	self.data[key] = nextValue
	return true, nextValue
end

local shutdown = module.new(shutdownStore, "server-owner-99999999", 90)
assert(shutdown:acquire(801, 2000).Accepted and shutdown:acquire(802, 2000).Accepted, "both players lease cleanly")

local cleanSummary = shutdown:releaseAll()
assert(cleanSummary.Requested == 2, "the summary must count every lease it attempted")
assert(cleanSummary.Released == 2 and cleanSummary.Unresolved == 0, "a healthy shutdown resolves every lease")

local stubborn = module.new(shutdownStore, "server-owner-88888888", 90)
assert(stubborn:acquire(803, 2100).Accepted, "the stubborn-store player leases cleanly")
shutdownStore.failUpdates = true
local callsBefore = shutdownStore.updateCalls
local failedSummary = stubborn:releaseAll()
assert(failedSummary.Requested == 1, "a failing shutdown still reports what it attempted")
assert(failedSummary.Released == 0 and failedSummary.Unresolved == 1, "an unreleasable lease must be reported")
assert(failedSummary.UnresolvedPlayerIds[1] == 803, "the unresolved lease must name its player")
local attempts = shutdownStore.updateCalls - callsBefore
assert(attempts > 1, "a store failure must be retried rather than abandoned on the first attempt")
assert(attempts <= 3, "shutdown retries must stay bounded: " .. tostring(attempts))
assert(#warnings > 0, "an unresolved shutdown lease must be observable in operator diagnostics")
assert(
	string.find(warnings[#warnings], "803", 1, true) ~= nil,
	"the shutdown diagnostic must name the lease that survived"
)
shutdownStore.failUpdates = false

--[[
	#30: leases are per key. One player's contention or failure must not affect
	another player's key on the same server.
]]
local isolationStore = { data = {} }
function isolationStore:update(key: string, transform)
	local nextValue = transform(self.data[key])
	self.data[key] = nextValue
	return true, nextValue
end

local holder = module.new(isolationStore, "server-owner-77777777", 90)
local rival = module.new(isolationStore, "server-owner-66666666", 90)
for playerId = 900, 909 do
	assert(holder:acquire(playerId, 3000).Accepted, "each player must lease independently: " .. playerId)
end
-- The rival takes exactly one key; every other key must be unaffected.
isolationStore.data["player:905:lease"] = nil
assert(rival:acquire(905, 3010).Accepted, "a freed key must be acquirable by another server")
for playerId = 900, 909 do
	local expected = playerId ~= 905
	assert(
		(isolationStore.data[string.format("player:%d:lease", playerId)].OwnerId == "server-owner-77777777") == expected,
		"one key changing owner must not move any other key: " .. playerId
	)
end
assert(not rival:acquire(904, 3020).Accepted, "a key still held must stay blocked while a sibling key moved")
holder:destroy()
rival:destroy()
guard:destroy()
twin:destroy()
shutdown:destroy()
stubborn:destroy()

print("InventorySessionLeaseService.test.luau passed")
