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

local function countOccurrences(source: string, token: string): number
	local count = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return count
		end
		count += 1
		startIndex = found + #token
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunUpgradeContracts.luau"), {
	debugName = "RunUpgradeContracts",
	injectGlobals = true,
})()
local service = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local xpController = fs.readFile("games/living-kingdoms/src/client/Controllers/RunProgressionHUDController.luau")
local choiceController = fs.readFile("games/living-kingdoms/src/client/Controllers/RunUpgradeChoiceController.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assert(table.isfrozen(contracts), "upgrade contracts must be immutable")
assert(#config.UpgradeOrder == 3, "the first offer must contain exactly three choices")
assert(config.MaximumTrackedEnemyModels == 64, "the corpse-overlap tracking ceiling must stay bounded")
assert(config.MaximumPendingUpgradeSelections <= 8, "queued level choices must remain bounded")

for _, token in {
	"RunService.Heartbeat:Connect",
	"folder:GetChildren()",
	"EnemyPresentationContracts.AttributeNames.LifeStateId",
	"EnemyPresentationContracts.AttributeNames.HitSequence",
	"stateRemote:FireAllClients",
	"readStateRemote.OnServerInvoke",
	"table.clear(trackedLifeStates)",
	"RunUpgradeContracts.validateSelectionIntent",
	"RunProgressionResolver.applyUpgradeSelection",
	"RunProgressionResolver.deriveCombatModifiers",
	"SelectionIntentCooldownSeconds",
	"pendingUpgradeSelections",
	"pendingUpgradeOffer",
} do
	assert(contains(service, token), "missing authoritative progression token: " .. token)
end
assert(countOccurrences(service, "OnServerEvent:Connect") == 1, "progression may expose only one selection input")

for _, prohibited in {
	"Humanoid.Health",
	"DataStoreService",
	"GetAttributeChangedSignal",
	"task.delay",
	"task.spawn",
	"task.defer",
} do
	assert(not contains(service, prohibited), "server progression must stay bounded: " .. prohibited)
end

assert(contains(xpController, "readStateRemote:InvokeServer()"), "the XP HUD must recover current safe state")
assert(contains(xpController, "stateRemote.OnClientEvent:Connect"), "the XP HUD renders server-published progression")
assert(contains(xpController, "RunService.RenderStepped:Connect"), "one client frame connection owns gain fading")
for _, prohibited in { "FireServer", "OnServerEvent", "DataStoreService", "Humanoid.Health" } do
	assert(not contains(xpController, prohibited), "the XP HUD must remain read-only: " .. prohibited)
end

for _, token in {
	"RunUpgradeContracts.validateOffer",
	"RunUpgradeContracts.validateStacks",
	"selectionIntentRemote:FireServer",
	"offerId = offer.offerId",
	"upgradeId = upgradeId",
	"First accepted squad selection locks",
} do
	assert(contains(choiceController, token), "missing safe choice-controller token: " .. token)
end
for _, prohibited in {
	"currentXP",
	"FieldXpPerConfirmedEnemyDeath",
	"damageBonus =",
	"cadenceMultiplier =",
	"reloadMultiplier =",
	"DataStoreService",
	"Humanoid.Health",
} do
	assert(not contains(choiceController, prohibited), "choice client may not author progression truth: " .. prohibited)
end

for _, token in {
	"RunProgressionService.readCombatModifiers()",
	"modifiers.damageBonus",
	"modifiers.cadenceMultiplier",
	"modifiers.reloadMultiplier",
} do
	assert(contains(runtime, token), "combat runtime must consume server-owned squad modifiers: " .. token)
end

assert(contains(serverBootstrap, "ensureProgressionNetwork()"), "server bootstrap must create progression networking")
assert(contains(serverBootstrap, 'selectionIntent.Name = "SelectionIntent"'), "progression network requires one choice intent")
assert(contains(serverBootstrap, "RunProgressionService.start()"), "server bootstrap must start Field XP")
local enemyStart = string.find(serverBootstrap, "EnemyDirectorService.start()", 1, true)
local progressionStart = string.find(serverBootstrap, "RunProgressionService.start()", 1, true)
local combatStart = string.find(serverBootstrap, "OperativeCombatRuntimeService.start()", 1, true)
assert(enemyStart ~= nil and progressionStart ~= nil and combatStart ~= nil)
assert(
	(enemyStart :: number) < (progressionStart :: number) and (progressionStart :: number) < (combatStart :: number),
	"death observation and modifiers must start after enemies and before combat"
)
assert(contains(clientBootstrap, "RunProgressionHUDController.start()"), "client bootstrap must start the XP HUD")
assert(contains(clientBootstrap, "RunUpgradeChoiceController.start()"), "client bootstrap must start squad choices")

print("RunProgressionSourceAudit: death XP, selection authority, client limits, and combat modifiers passed")
