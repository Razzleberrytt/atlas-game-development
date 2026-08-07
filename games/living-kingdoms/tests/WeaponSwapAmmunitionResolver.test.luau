--!strict

--[[
	Blueprint v2.0 queue item 2 — weapon swap ammunition fixture.

	The governing property is conservation: a swap may move or lose rounds, but
	it may never create one. That is what closes the mid-combat refill exploit.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "weapon swap ammunition assertion failed", 2)
	end
end

local Resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/WeaponSwapAmmunitionResolver.luau"),
	{ debugName = "WeaponSwapAmmunitionResolver", injectGlobals = true }
)()

local function carried(loadedRounds: number, reserveRounds: number): any
	return { loadedRounds = loadedRounds, reserveRounds = reserveRounds }
end

local function capacity(magazineCapacity: number, maximumReserveRounds: number): any
	return { magazineCapacity = magazineCapacity, maximumReserveRounds = maximumReserveRounds }
end

-- The exploit case: an almost-dry weapon swapped for another must not arrive
-- with a full magazine.
local nearlyDry = Resolver.resolve(carried(1, 0), capacity(30, 90))
assert(nearlyDry.Accepted == true and nearlyDry.ReasonId == "AmmunitionCarried", "a valid swap resolves")
assert(nearlyDry.LoadedRounds == 1, "a swap must not refill the magazine")
assert(nearlyDry.ReserveRounds == 0, "a swap must not conjure reserve rounds")
assert(nearlyDry.DiscardedRounds == 0, "nothing was lost")

-- Fully dry stays fully dry, so repeated swapping yields nothing.
local dry = Resolver.resolve(carried(0, 0), capacity(30, 90))
assert(dry.LoadedRounds == 0 and dry.ReserveRounds == 0, "an empty operative gains nothing from a swap")

-- Conservation: total rounds are preserved whenever the incoming weapon can
-- hold them. This is the property that closes the exploit.
local cases = {
	{ carried(12, 24), capacity(30, 90) },
	{ carried(30, 0), capacity(8, 40) },
	{ carried(5, 5), capacity(10, 10) },
	{ carried(0, 48), capacity(12, 48) },
	{ carried(7, 13), capacity(20, 0) },
}
for _, case in cases do
	local before = case[1]
	local result = Resolver.resolve(before, case[2])
	assert(result.Accepted == true, "each case must resolve")
	local totalBefore = before.loadedRounds + before.reserveRounds
	local totalAfter = result.LoadedRounds + result.ReserveRounds + result.DiscardedRounds
	assert(totalAfter == totalBefore, "a swap must neither create nor silently destroy rounds")
	assert(result.LoadedRounds + result.ReserveRounds <= totalBefore, "a swap can never increase carried rounds")
end

-- The magazine fills first so a swap leaves the operative able to fire.
local plenty = Resolver.resolve(carried(0, 50), capacity(30, 90))
assert(plenty.LoadedRounds == 30, "the incoming magazine is filled first")
assert(plenty.ReserveRounds == 20, "the remainder goes to reserve")
assert(plenty.DiscardedRounds == 0, "nothing is lost when it all fits")

-- Caps are respected, and the overflow is reported rather than hidden.
local overflow = Resolver.resolve(carried(30, 90), capacity(8, 16))
assert(overflow.LoadedRounds == 8, "loaded rounds are clamped to the incoming magazine")
assert(overflow.ReserveRounds == 16, "reserve is clamped to the incoming maximum")
assert(overflow.DiscardedRounds == 96, "rounds that do not fit are reported as discarded")
assert(overflow.LoadedRounds + overflow.ReserveRounds + overflow.DiscardedRounds == 120, "conservation holds")

-- A weapon with no reserve capacity keeps only a magazine.
local noReserve = Resolver.resolve(carried(10, 10), capacity(6, 0))
assert(noReserve.LoadedRounds == 6 and noReserve.ReserveRounds == 0, "zero reserve capacity holds only a magazine")
assert(noReserve.DiscardedRounds == 14, "the rest is discarded")

-- Swapping to the same capacities is a no-op, so alternating between two
-- identical weapons yields nothing.
local roundTrip = Resolver.resolve(carried(9, 21), capacity(30, 90))
assert(roundTrip.LoadedRounds == 30 and roundTrip.ReserveRounds == 0, "the magazine fills from the same total")
local back = Resolver.resolve(carried(roundTrip.LoadedRounds, roundTrip.ReserveRounds), capacity(30, 90))
assert(back.LoadedRounds + back.ReserveRounds == 30, "repeated swaps cannot grow the total")

-- Malformed input is rejected and grants nothing.
local invalidCarried: { any } = {
	{},
	{ loadedRounds = -1, reserveRounds = 0 },
	{ loadedRounds = 1.5, reserveRounds = 0 },
	{ loadedRounds = 0, reserveRounds = "5" },
}
assert(#invalidCarried == 4, "every malformed carried case must run")
for _, invalid in invalidCarried do
	local bad = Resolver.resolve(invalid, capacity(30, 90))
	assert(bad.Accepted == false and bad.ReasonId == "InvalidCarriedAmmunition", "malformed ammunition is rejected")
	assert(bad.LoadedRounds == 0 and bad.ReserveRounds == 0, "a rejected swap grants nothing")
end

local invalidCapacities: { any } = {
	{},
	{ magazineCapacity = 0, maximumReserveRounds = 10 },
	{ magazineCapacity = -5, maximumReserveRounds = 10 },
	{ magazineCapacity = 10, maximumReserveRounds = -1 },
}
assert(#invalidCapacities == 4, "every malformed capacity case must run")
for _, invalid in invalidCapacities do
	local bad = Resolver.resolve(carried(5, 5), invalid)
	assert(bad.Accepted == false and bad.ReasonId == "InvalidWeaponCapacity", "a malformed weapon is rejected")
	assert(bad.LoadedRounds == 0 and bad.ReserveRounds == 0, "a rejected swap grants nothing")
end

-- The result is frozen, and inputs are never mutated.
local input = carried(4, 6)
local frozenResult = Resolver.resolve(input, capacity(10, 10))
assert(table.isfrozen(frozenResult :: any), "the result is frozen")
assert(input.loadedRounds == 4 and input.reserveRounds == 6, "the resolver does not mutate its input")

print("WeaponSwapAmmunitionResolver fixture passed")
