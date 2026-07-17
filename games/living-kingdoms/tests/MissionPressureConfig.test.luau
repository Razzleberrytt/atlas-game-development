--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0105 mission pressure config assertion failed", 2)
	end
end

local missionConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MissionConfig.luau"), {
	debugName = "MissionConfig",
	injectGlobals = true,
})()

local escalation = missionConfig.Escalation
assert(missionConfig.Version == "P5-0105-v1")
assert(type(escalation.MaximumConcurrentEnemies) == "number")
assert(escalation.MaximumConcurrentEnemies >= 3)
assert(escalation.MaximumConcurrentEnemies <= 24)
assert(escalation.MinimumSecondsBetweenWaves >= 0)
assert(escalation.MinimumSecondsBetweenWaves <= 60)
assert(escalation.RecoverySecondsAfterWave >= 0)
assert(escalation.RecoverySecondsAfterWave <= 60)
assert(#escalation.Waves == 3)
for _, wave in escalation.Waves do
	assert(#wave > 0)
	assert(#wave <= escalation.MaximumConcurrentEnemies)
end
assert(table.isfrozen(escalation))
assert(table.isfrozen(missionConfig))

print("Mission pressure config fixture passed")
