--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local scheduler = luau.load(fs.readFile("games/living-kingdoms/src/server/Domain/EnemyNavigationScheduler.luau"), {
	debugName = "EnemyNavigationScheduler",
	injectGlobals = true,
})()

local function joined(values: { string }): string
	return table.concat(values, ",")
end

local first = scheduler.resolveRoundRobinGrants({ "enemy-c", "enemy-a", "enemy-b" }, nil, 2)
assert(joined(first.GrantedEntityIds) == "enemy-a,enemy-b", "first grants must be deterministic and bounded")
assert(first.CursorEntityId == "enemy-b", "cursor must advance to the last granted enemy")

local second = scheduler.resolveRoundRobinGrants({ "enemy-a", "enemy-b", "enemy-c" }, first.CursorEntityId, 2)
assert(joined(second.GrantedEntityIds) == "enemy-c,enemy-a", "round robin must wrap after the cursor")
assert(second.CursorEntityId == "enemy-a", "wrapped grants must advance the cursor")

local third = scheduler.resolveRoundRobinGrants({ "enemy-b", "enemy-c", "enemy-d" }, second.CursorEntityId, 2)
assert(
	joined(third.GrantedEntityIds) == "enemy-b,enemy-c",
	"missing cursor membership must fall back deterministically"
)

local all = scheduler.resolveRoundRobinGrants({ "enemy-c", "enemy-a", "enemy-b" }, "enemy-a", 99)
assert(#all.GrantedEntityIds == 3, "grant count must never exceed eligible enemy count")
assert(
	joined(all.GrantedEntityIds) == "enemy-b,enemy-c,enemy-a",
	"grant-all case must still preserve round-robin order"
)

local zero = scheduler.resolveRoundRobinGrants({ "enemy-a", "enemy-b" }, "enemy-a", 0)
assert(#zero.GrantedEntityIds == 0, "zero budget must grant no path computations")
assert(zero.CursorEntityId == "enemy-a", "zero budget must not consume fairness cursor")

local negative = scheduler.resolveRoundRobinGrants({ "enemy-a", "enemy-b" }, "enemy-b", -3)
assert(#negative.GrantedEntityIds == 0, "negative budget must clamp to zero grants")

local duplicate = scheduler.resolveRoundRobinGrants({ "enemy-b", "enemy-a", "enemy-a", "" }, nil, 4)
assert(joined(duplicate.GrantedEntityIds) == "enemy-a,enemy-b", "duplicate/empty ids must not consume budget")

local empty = scheduler.resolveRoundRobinGrants({}, "enemy-b", 4)
assert(#empty.GrantedEntityIds == 0 and empty.CursorEntityId == "enemy-b", "empty population must preserve cursor")

print("EnemyNavigationScheduler: bounded deterministic round-robin fairness passed")
