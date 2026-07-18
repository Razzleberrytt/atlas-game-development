--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "HROI-0105 run progression source audit failed", 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()
local service = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/RunProgressionHUDController.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assert(contains(service, "RunService.Heartbeat:Connect"), "progression must use one bounded server scan")
assert(contains(service, "folder:GetChildren()"), "progression must inspect the bounded enemy folder")
assert(contains(service, "EnemyPresentationContracts.AttributeNames.LifeStateId"), "death truth must come from server-authored life state")
assert(contains(service, "EnemyPresentationContracts.AttributeNames.HitSequence"), "first-seen corpses require a confirmed hit")
assert(contains(service, "stateRemote:FireAllClients"), "confirmed awards must publish a server snapshot")
assert(contains(service, "readStateRemote.OnServerInvoke"), "late clients require read-only state recovery")
assert(contains(service, "table.clear(trackedLifeStates)"), "run progression must reset and clean tracked death state")
assert(config.MaximumTrackedEnemyModels == 64, "the cosmetic corpse-overlap tracking ceiling must stay bounded")

for _, prohibited in {
	"OnServerEvent",
	"FireServer",
	"GetAttributeChangedSignal",
	"Humanoid.Health",
	"DataStoreService",
	"ChooseUpgrade",
	"task.delay",
	"task.spawn",
	"task.defer",
} do
	assert(not contains(service, prohibited), "server Field XP must not widen authority or scheduling: " .. prohibited)
end

assert(contains(controller, "readStateRemote:InvokeServer()"), "the HUD may request only its current safe snapshot")
assert(contains(controller, "stateRemote.OnClientEvent:Connect"), "the HUD must render server-published progression")
assert(contains(controller, "RunService.RenderStepped:Connect"), "one client frame connection owns bounded gain fading")
for _, prohibited in { "FireServer", "OnServerEvent", "DataStoreService", "Humanoid.Health" } do
	assert(not contains(controller, prohibited), "the HUD must remain read-only: " .. prohibited)
end

assert(contains(serverBootstrap, "ensureProgressionNetwork()"), "server bootstrap must create the safe progression network")
assert(contains(serverBootstrap, "RunProgressionService.start()"), "server bootstrap must start Field XP")
local enemyStart = string.find(serverBootstrap, "EnemyDirectorService.start()", 1, true)
local progressionStart = string.find(serverBootstrap, "RunProgressionService.start()", 1, true)
local combatStart = string.find(serverBootstrap, "OperativeCombatRuntimeService.start()", 1, true)
assert(enemyStart ~= nil and progressionStart ~= nil and combatStart ~= nil)
assert(
	(enemyStart :: number) < (progressionStart :: number) and (progressionStart :: number) < (combatStart :: number),
	"death observation must start after enemy ownership and before automatic combat"
)
assert(contains(clientBootstrap, "RunProgressionHUDController.start()"), "client bootstrap must start the Field XP HUD")

print("RunProgressionSourceAudit: server-only death awards, read-only HUD, bounded scans, and bootstrap order passed")
