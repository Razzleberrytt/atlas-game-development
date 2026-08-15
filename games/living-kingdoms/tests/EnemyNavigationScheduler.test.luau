--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Scheduler = luau.load(fs.readFile("games/living-kingdoms/src/server/Domain/EnemyNavigationScheduler.luau"), {
	debugName = "EnemyNavigationScheduler",
	injectGlobals = true,
})()

local candidates = {}
for index = 1, 24 do
	table.insert(candidates, string.format("enemy.%02d", index))
end

local cursor: string? = nil
local totalGrants: { [string]: number } = {}
for _ = 1, 6 do
	local resolution = Scheduler.resolveRoundRobin(candidates, cursor, 4)
	assert(resolution.grantCount == 4, "24-enemy pass must stay inside the four-path budget")
	local passCount = 0
	for entityId in resolution.grantedEntityIds do
		passCount += 1
		totalGrants[entityId] = (totalGrants[entityId] or 0) + 1
	end
	assert(passCount == 4, "each pass must grant exactly four unique enemies")
	cursor = resolution.nextCursorEntityId
end

for _, entityId in candidates do
	assert(totalGrants[entityId] == 1, entityId .. " must receive exactly one grant across one full rotation")
end

local reordered = { "enemy.05", "enemy.02", "enemy.04", "enemy.01", "enemy.03" }
local first = Scheduler.resolveRoundRobin(reordered, nil, 2)
assert(
	first.grantedEntityIds["enemy.01"] and first.grantedEntityIds["enemy.02"],
	"grant order must be lexical, not table order"
)
local second = Scheduler.resolveRoundRobin(reordered, first.nextCursorEntityId, 2)
assert(second.grantedEntityIds["enemy.03"] and second.grantedEntityIds["enemy.04"], "cursor must advance fairly")
local third = Scheduler.resolveRoundRobin(reordered, second.nextCursorEntityId, 2)
assert(third.grantedEntityIds["enemy.05"] and third.grantedEntityIds["enemy.01"], "cursor must wrap without starvation")

local anchor = { x = 0, y = 0, z = 0 }
local moving = Scheduler.resolveProgress({ x = 2, y = 0, z = 0 }, anchor, 0, 0, 0.5, 1.5, 1.25, 1.5)
assert(not moving.didRecover, "real movement must never trigger stuck recovery")
assert(
	moving.progressAnchor.x == 2 and moving.progressAnchorServerTimestamp == 0.5,
	"movement must reset the progress anchor"
)

local waiting = Scheduler.resolveProgress(
	{ x = 2.4, y = 0, z = 0 },
	moving.progressAnchor,
	0.5,
	0,
	1.4,
	1.5,
	1.25,
	1.5
)
assert(not waiting.didRecover, "sub-threshold movement before the window must remain ordinary pursuit")

local stuck = Scheduler.resolveProgress(
	{ x = 2.4, y = 0, z = 0 },
	waiting.progressAnchor,
	waiting.progressAnchorServerTimestamp,
	0,
	1.8,
	1.5,
	1.25,
	1.5
)
assert(stuck.didRecover, "a full no-progress window must trigger bounded recovery")
assert(
	math.abs(stuck.nextRecoveryServerTimestamp - 3.3) < 0.0001,
	"recovery must publish a deterministic cooldown"
)

local coolingDown = Scheduler.resolveProgress(
	{ x = 2.4, y = 0, z = 0 },
	stuck.progressAnchor,
	stuck.progressAnchorServerTimestamp,
	stuck.nextRecoveryServerTimestamp,
	3.1,
	1.5,
	1.25,
	1.5
)
assert(not coolingDown.didRecover, "recovery cooldown must prevent repath thrash")

local recoveredAgain = Scheduler.resolveProgress(
	{ x = 2.4, y = 0, z = 0 },
	coolingDown.progressAnchor,
	coolingDown.progressAnchorServerTimestamp,
	coolingDown.nextRecoveryServerTimestamp,
	3.4,
	1.5,
	1.25,
	1.5
)
assert(recoveredAgain.didRecover, "persistent obstruction may recover again after the cooldown")

print("EnemyNavigationScheduler: 24-enemy round-robin fairness + bounded stuck recovery validated")
