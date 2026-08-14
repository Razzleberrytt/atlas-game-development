--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "finite lease time assertion failed", 2)
	end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventorySessionLeaseService.luau"), {
	debugName = "InventorySessionLeaseService",
	injectGlobals = true,
})()

local store = { data = {}, updateCalls = 0 }
function store:update(key: string, transform)
	self.updateCalls += 1
	local nextValue = transform(self.data[key])
	self.data[key] = nextValue
	return true, nextValue
end

local service = module.new(store, "server-owner-finite-time", 90)

for _, invalidNow in { 0 / 0, math.huge, -math.huge } do
	local callsBefore = store.updateCalls
	local outcome = service:acquire(101, invalidNow)
	assert(
		not outcome.Accepted and outcome.ReasonId == "InvalidAcquireRequest",
		"non-finite acquire time must be rejected"
	)
	assert(store.updateCalls == callsBefore, "invalid acquire must not touch durable storage")
	assert(store.data["player:101:lease"] == nil, "invalid acquire must not write a lease")
end

assert(service:acquire(101, 1000).Accepted, "finite acquire should still succeed")
local durableLease = store.data["player:101:lease"]

for _, invalidNow in { 0 / 0, math.huge, -math.huge } do
	local callsBefore = store.updateCalls
	local outcome = service:renew(101, invalidNow)
	assert(not outcome.Accepted and outcome.ReasonId == "InvalidRenewRequest", "non-finite renew time must be rejected")
	assert(store.updateCalls == callsBefore, "invalid renew must not touch durable storage")
	assert(store.data["player:101:lease"] == durableLease, "invalid renew must leave the durable lease unchanged")
end

local rival = module.new(store, "server-owner-rival-time", 90)
for _, field in { "ExpiresAtUnix", "AcquiredAtUnix", "RenewedAtUnix" } do
	store.data["player:202:lease"] = {
		OwnerId = "server-owner-foreign-time",
		AcquiredAtUnix = 900,
		RenewedAtUnix = 950,
		ExpiresAtUnix = 2000,
	}
	store.data["player:202:lease"][field] = math.huge
	local outcome = rival:acquire(202, 1000)
	assert(
		not outcome.Accepted and outcome.ReasonId == "LeaseRecordMalformed",
		"infinite persisted lease fields must fail closed: " .. field
	)
	assert(
		store.data["player:202:lease"][field] == math.huge,
		"malformed persisted lease must not be rewritten: " .. field
	)
end

service:destroy()
rival:destroy()

print("InventorySessionLeaseFiniteTime.test.luau passed")
