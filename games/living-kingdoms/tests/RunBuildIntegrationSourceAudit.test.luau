--!strict

local fs = require("@lune/fs")

local store = fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildStateStore.luau")
local service = fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildService.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

assert(contains(store, "operationGeneration += 1"), "operation reset must advance generation")
assert(contains(store, "maximumTrackedOperativesPerOperation"), "operative state must remain population-bounded")
assert(contains(store, "maximumProcessedRequestIdsPerOperative"), "replay history must remain bounded")
assert(contains(store, "disconnectOperative"), "disconnect ownership is missing")
assert(contains(store, "pendingRewards = {}"), "future reward state must have one canonical empty owner")
assert(contains(store, "chargeCount = 0"), "future relic charges must have one canonical empty owner")
assert(contains(store, "cooldownEndServerTimestamp = nil"), "future cooldown state must have one canonical empty owner")
assert(contains(store, "counterValue = 0"), "future relic counters must have one canonical empty owner")

assert(contains(service, "Players.PlayerAdded:Connect"), "operative registration must follow the server roster")
assert(contains(service, "Players.PlayerRemoving:Connect"), "disconnect must release the live association")
assert(contains(progression, "require(script.Parent.RunBuildService)"), "Field Upgrades must use the run-build owner")
assert(
	contains(progression, "RunBuildService.commitSquadUpgradeStacks"),
	"accepted Field Upgrades must commit through the run-build owner"
)
assert(
	not contains(progression, "local upgradeStacks:"),
	"RunProgressionService must not retain a parallel upgrade-stack owner"
)

local buildStart = string.find(bootstrap, "RunBuildService.start()", 1, true)
local progressionStart = string.find(bootstrap, "RunProgressionService.start()", 1, true)
assert(
	buildStart ~= nil and progressionStart ~= nil and buildStart < progressionStart,
	"run-build owner must start first"
)

print("RunBuildIntegrationSourceAudit: one bounded run-build owner is integrated before progression")
