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

local function occurrenceCount(source: string, token: string): number
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
local service = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/RunProgressionHUDController.luau")
local upgradeResolver = fs.readFile("games/living-kingdoms/src/shared/Progression/RunUpgradeResolver.luau")
local fireResolver = fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau")
local damageResolver = fs.readFile("games/living-kingdoms/src/server/Systems/DamageResolver.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assert(contains(service, "RunService.Heartbeat:Connect"), "progression must use one bounded server scan")
assert(contains(service, "folder:GetChildren()"), "progression must inspect the bounded enemy folder")
assert(
	contains(service, "EnemyPresentationContracts.AttributeNames.LifeStateId"),
	"death truth must come from server-authored life state"
)
assert(
	contains(service, "EnemyPresentationContracts.AttributeNames.HitSequence"),
	"first-seen corpses require a confirmed hit"
)
assert(contains(service, "stateRemote:FireAllClients"), "confirmed awards must publish a server snapshot")
assert(contains(service, "readStateRemote.OnServerInvoke"), "late clients require read-only state recovery")
assert(
	contains(service, "chooseUpgradeRemote.OnServerEvent:Connect(onChooseUpgrade)"),
	"one upgrade intent must reach server validation"
)
assert(
	contains(service, "RunUpgradeResolver.applyChoice"),
	"the server must validate offered IDs through the pure resolver"
)
assert(contains(service, "UpgradeRequestCooldownSeconds"), "upgrade selection must be server throttled")
assert(contains(service, 'select("#", ...) ~= 0'), "upgrade requests must reject extra client arguments")
assert(contains(service, "syncCombatModifierAttributes()"), "accepted choices must publish trusted combat modifiers")
assert(contains(service, "table.clear(upgradeStacks)"), "run upgrades must reset with the operation session")
assert(config.MaximumTrackedEnemyModels == 64, "the corpse-overlap tracking ceiling must stay bounded")
assert(config.UpgradeChoiceCount == 3 and #config.UpgradeDefinitions == 4, "the first pool must remain three-of-four")

for _, prohibited in
	{
		"GetAttributeChangedSignal",
		"Humanoid.Health",
		"DataStoreService",
		"task.delay",
		"task.spawn",
		"task.defer",
	}
do
	assert(not contains(service, prohibited), "server progression must remain bounded and run-only: " .. prohibited)
end

assert(contains(upgradeResolver, "UpgradeNotOffered"), "spoofed upgrade IDs require an explicit rejection")
assert(contains(upgradeResolver, "MaximumStacks"), "maxed upgrades must be excluded and rejected")
assert(contains(upgradeResolver, "MaximumAmmoConservationChance"), "ammo conservation must remain bounded")
assert(contains(upgradeResolver, "MaximumDamageMultiplier"), "damage upgrades must remain bounded")

assert(contains(controller, "readStateRemote:InvokeServer()"), "the HUD must recover its current safe snapshot")
assert(contains(controller, "stateRemote.OnClientEvent:Connect"), "the HUD must render server-published progression")
assert(
	contains(controller, "chooseUpgradeRemote:FireServer(upgradeId)"),
	"the HUD may submit only an offered upgrade ID"
)
assert(occurrenceCount(controller, ":FireServer(") == 1, "the progression HUD must expose exactly one mutation call")
assert(contains(controller, "button.Activated:Connect"), "touch and mouse must use fixed choice buttons")
for _, prohibited in { "OnServerEvent", "DataStoreService", "Humanoid.Health", "SetAttribute(" } do
	assert(
		not contains(controller, prohibited),
		"the HUD must not establish progression or combat truth: " .. prohibited
	)
end

assert(contains(fireResolver, "RunCadenceMultiplier"), "automatic fire must consume the trusted cadence modifier")
assert(contains(fireResolver, "RunAmmoConservationChance"), "automatic fire must consume bounded Echo Chamber state")
assert(contains(fireResolver, "stableUnitInterval"), "ammo conservation must be deterministic")
assert(contains(damageResolver, "RunDamageMultiplier"), "damage must consume trusted Overpressure state")
assert(contains(damageResolver, "RunCullDamageMultiplier"), "damage must consume trusted Cull Protocol state")
assert(contains(damageResolver, "configured * 3"), "damage must retain a hard server-side ceiling")

assert(contains(serverBootstrap, "ensureProgressionNetwork()"), "server bootstrap must create the progression network")
assert(
	contains(serverBootstrap, '"State", "ChooseUpgrade"'),
	"bootstrap must create exactly the progression event pair"
)
assert(contains(serverBootstrap, "RunProgressionService.start()"), "server bootstrap must start run progression")
local enemyStart = string.find(serverBootstrap, "EnemyDirectorService.start()", 1, true)
local progressionStart = string.find(serverBootstrap, "RunProgressionService.start()", 1, true)
local combatStart = string.find(serverBootstrap, "OperativeCombatRuntimeService.start()", 1, true)
assert(enemyStart ~= nil and progressionStart ~= nil and combatStart ~= nil)
assert(
	(enemyStart :: number) < (progressionStart :: number) and (progressionStart :: number) < (combatStart :: number),
	"modifier attributes must initialize after enemy ownership and before automatic combat"
)
assert(
	not contains(clientBootstrap, "RunProgressionHUDController.start()"),
	"the standalone progression HUD must not run alongside the unified combat HUD"
)
assert(
	contains(clientBootstrap, "HordeHUDController.start()"),
	"the unified combat HUD must own the single progression surface"
)

print(
	"RunProgressionSourceAudit: death awards, offered-ID validation, bounded modifiers, HUD surface, and bootstrap order passed"
)
