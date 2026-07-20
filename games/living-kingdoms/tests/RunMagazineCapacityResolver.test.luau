--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/RunMagazineCapacityResolver.luau"),
	{ debugName = "RunMagazineCapacityResolver", injectGlobals = true }
)()

local baseline = {
	weaponId = "weapon.fixture",
	loadedRounds = 12,
	reserveRounds = 24,
	magazineCapacity = 12,
}
local expanded = resolver.resolve(baseline, 12, 48, 1.45)
assert(expanded.didApply)
assert(expanded.ammunitionAfter.magazineCapacity == 17, "12 * 1.45 must round to 17")
assert(expanded.ammunitionAfter.loadedRounds == 17 and expanded.ammunitionAfter.reserveRounds == 19)
assert(baseline.loadedRounds == 12 and baseline.reserveRounds == 24, "resolver mutated caller state")

local partial = resolver.resolve({
	weaponId = "weapon.fixture",
	loadedRounds = 4,
	reserveRounds = 2,
	magazineCapacity = 12,
}, 12, 48, 1.15)
assert(partial.ammunitionAfter.magazineCapacity == 14)
assert(partial.ammunitionAfter.loadedRounds == 6 and partial.ammunitionAfter.reserveRounds == 0)

local reconciled = resolver.resolve(expanded.ammunitionAfter, 12, 48, 1.45)
assert(reconciled.ammunitionAfter.loadedRounds == 17 and reconciled.ammunitionAfter.reserveRounds == 19)

local reduced = resolver.resolve(expanded.ammunitionAfter, 12, 48, 1)
assert(reduced.ammunitionAfter.magazineCapacity == 12)
assert(reduced.ammunitionAfter.loadedRounds == 12 and reduced.ammunitionAfter.reserveRounds == 24)

local invalid = resolver.resolve(baseline, 12, 48, 2)
assert(not invalid.didApply and invalid.ammunitionAfter.magazineCapacity == 12)

print("RunMagazineCapacityResolver: bounded capacity, conservation, reconciliation, and copies passed")
