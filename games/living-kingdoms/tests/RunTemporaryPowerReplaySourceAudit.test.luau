--!strict

local fs = require("@lune/fs")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local lifecycle = fs.readFile("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local runBuild = fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildService.luau")

assert(contains(lifecycle, "RunBuildService.resetOperation()"), "replay must clear temporary relics and upgrade stacks")
assert(contains(lifecycle, "RunProgressionService.resetOperation()"), "replay must clear Field XP and run progression")
local buildResetStart = assert(string.find(lifecycle, "RunBuildService.resetOperation()", 1, true))
local progressionResetStart = assert(string.find(lifecycle, "RunProgressionService.resetOperation()", 1, true))
assert(
	buildResetStart < progressionResetStart,
	"run build must reset before progression resynchronizes derived combat modifiers"
)

assert(contains(runBuild, "store:startOperation()"), "run build reset must begin a fresh operation generation")
local resetStart = assert(string.find(progression, "function RunProgressionService.resetOperation(): boolean", 1, true))
local nextFunctionStart = assert(string.find(progression, "function RunProgressionService.start()", resetStart, true))
local resetSource = string.sub(progression, resetStart, nextFunctionStart - 1)
for _, temporaryState in
	{
		"level = 1",
		"xp = 0",
		"totalXp = 0",
		"squadKills = 0",
		"eliteKillsSinceReward = 0",
		"unclaimedUpgradeChoices = 0",
		"table.clear(pendingChoiceIds)",
		"table.clear(processedFieldIntelRewardIds)",
	}
do
	assert(contains(resetSource, temporaryState), "run progression reset is missing temporary state: " .. temporaryState)
end
assert(
	contains(resetSource, "syncCombatModifierAttributes()") and contains(resetSource, "publishAll()"),
	"replay reset must republish neutral run modifiers and a fresh visible progression snapshot"
)
for _, monotonicTransportCounter in
	{
		"revision = 0",
		"lastGainSequence = 0",
		"selectionSequence = 0",
	}
do
	assert(
		not contains(resetSource, monotonicTransportCounter),
		"replay must not roll back long-lived HUD transport counter: " .. monotonicTransportCounter
	)
end

for _, durableOwner in
	{
		"InventoryLiveService",
		"PlayerInventoryPersistenceService",
		"DiscoveryMemoryService",
		"Achievement",
	}
do
	assert(
		not contains(lifecycle, durableOwner),
		"temporary-power replay reset must not erase durable state: " .. durableOwner
	)
end

print("RunTemporaryPowerReplaySourceAudit: replay clears temporary run build/progression without durable rollback")
