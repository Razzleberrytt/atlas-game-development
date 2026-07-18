--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyLootConfig.luau"), {
	debugName = "EnemyLootConfig",
	injectGlobals = true,
})()
local service = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyLootService.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/AmmunitionScarcityContracts.luau")
local supplyResolver = fs.readFile("games/living-kingdoms/src/server/Domain/AmmunitionSupplyResolver.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assertThat(config.MaximumTrackedEnemyModels == 64, "enemy loot death observation ceiling drifted")
assertThat(config.MaximumActiveDrops == 16, "enemy loot active pickup ceiling drifted")
assertThat(config.PickupRadiusStuds <= 8, "enemy loot collection radius must remain local")
assertThat(config.Definitions.Common.Rounds == 8, "common enemy loot grant drifted")
assertThat(config.Definitions.Rare.Rounds == 20, "rare enemy loot grant drifted")

assertThat(contains(service, "RunService.Heartbeat:Connect"), "enemy loot must use one bounded server pass")
assertThat(contains(service, "folder:GetChildren()"), "enemy loot must observe the bounded enemy folder")
assertThat(
	contains(service, "EnemyPresentationContracts.AttributeNames.LifeStateId"),
	"enemy loot death truth must use server-authored life state"
)
assertThat(
	contains(service, "EnemyPresentationContracts.AttributeNames.HitSequence"),
	"first-seen corpses must require a confirmed server hit"
)
assertThat(contains(service, "Players:GetPlayers()"), "automatic pickup must derive server player identity")
assertThat(contains(service, "OperativeLifeService.isCombatAllowed"), "only living operatives may collect")
assertThat(contains(service, "AmmunitionSupplyResolver.collect"), "loot must use the existing ammunition resolver")
assertThat(
	contains(service, "OperativeCombatRuntimeService.commitReviveCombatState"),
	"loot must commit through the authoritative combat owner"
)
assertThat(contains(service, 'Instance.new("PointLight")'), "world loot requires readable glow")
assertThat(contains(service, 'Instance.new("BillboardGui")'), "world loot requires readable ammunition disclosure")
assertThat(contains(service, "serverTimestamp >= record.expiresAtServerTimestamp"), "loot must expire in the bounded pass")
assertThat(contains(service, "activeDropCount = math.max(0, activeDropCount - 1)"), "loot cleanup must release cap budget")

for _, prohibited in {
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"OnServerEvent",
	"ProximityPrompt",
	".Touched",
	"TouchEnded",
	"task.delay",
	"task.spawn",
	"task.defer",
	"DataStoreService",
	"Humanoid.Health",
} do
	assertThat(not contains(service, prohibited), "enemy loot must not widen authority or scheduling: " .. prohibited)
end

assertThat(contains(contracts, 'EnemyLoot = "EnemyLoot"'), "enemy loot requires an explicit supply source")
assertThat(contains(supplyResolver, "candidate.sourceId == SourceIds.EnemyLoot"), "supply resolver must whitelist enemy loot")
assertThat(contains(bootstrap, "EnemyLootService.start()"), "server bootstrap must start enemy loot")
local combatStart = string.find(bootstrap, "OperativeCombatRuntimeService.start()", 1, true)
local lootStart = string.find(bootstrap, "EnemyLootService.start()", 1, true)
assertThat(combatStart ~= nil and lootStart ~= nil and combatStart < lootStart, "combat authority must start before loot collection")

print("EnemyLootSourceAudit: server-only death rolls, automatic collection, visual disclosure, expiry, and caps passed")
