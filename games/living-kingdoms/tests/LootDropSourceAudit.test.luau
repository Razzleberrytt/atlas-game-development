--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function contains(source: string, token: string): boolean
	return source:find(token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local total = 0
	local cursor = 1
	while true do
		local index = source:find(token, cursor, true)
		if index == nil then
			return total
		end
		total += 1
		cursor = index + #token
	end
end

local contracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Loot/LootDropContracts.luau"),
	{ debugName = "LootDropContracts", injectGlobals = true }
)()
local config = fs.readFile("games/living-kingdoms/src/shared/Config/LootDropConfig.luau")
local dropResolver = fs.readFile("games/living-kingdoms/src/server/Systems/LootDropResolver.luau")
local service = fs.readFile("games/living-kingdoms/src/server/Systems/LootDropService.luau")
local healingResolver = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeHealingResolver.luau")
local lifeService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local progressionService = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assert(table.isfrozen(contracts), "loot contracts must be immutable")
assert(contracts.LootKindIds.AmmunitionBundle == "loot.ammunition_bundle")
assert(contracts.LootKindIds.FieldDressing == "loot.field_dressing")
assert(contracts.LootKindIds.FieldIntel == "loot.field_intel")

for _, token in {
	"MaximumTrackedEnemyModels",
	"MaximumActiveDrops",
	"DropLifetimeSeconds",
	"PickupMaximumDistanceStuds",
} do
	assert(contains(config, token), "missing bounded loot config token: " .. token)
end
assert(
	contains(dropResolver, "fact.activeDropCount >= LootDropConfig.MaximumActiveDrops"),
	"the pure resolver must enforce the active-drop ceiling"
)
assert(
	contains(dropResolver, "fact.serverTimestamp + LootDropConfig.DropLifetimeSeconds"),
	"the pure resolver must author one bounded expiry timestamp"
)

for _, token in {
	"ProximityPromptService.PromptTriggered:Connect",
	"RunService.Heartbeat:Connect",
	"MaximumTrackedEnemyModels",
	"PickupMaximumDistanceStuds",
	"activeDropCount()",
	"serverTimestamp >= entry.expiresAtServerTimestamp",
	"LootDropResolver.resolve",
	"AmmunitionSupplyResolver.collect",
	"OperativeLifeService.applyAuthoritativeHealing",
	"RunProgressionService.awardFieldIntel",
	"processedEnemyEntityIds",
	"entry.claimed",
	"horizontalDistance(position, entry.worldPosition)",
} do
	assert(contains(service, token), "missing loot authority token: " .. token)
end
assert(count(service, ":Connect(") == 3, "loot runtime requires exactly heartbeat, global prompt, and player-removal connections")
assert(not contains(service, "prompt.Triggered:Connect"), "drops must not create per-prompt connections")
for _, prohibited in {
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"OnServerEvent",
	"DataStoreService",
	"Humanoid.Health",
	"task.delay",
	"task.spawn",
	"task.defer",
	"math.random",
} do
	assert(not contains(service, prohibited), "loot runtime must not contain " .. prohibited)
end

assert(
	contains(healingResolver, "operativeSnapshot.lifeStateId ~= AliveStateId"),
	"field dressings must reject non-Alive operatives"
)
assert(contains(healingResolver, "math.min("), "field dressing healing must clamp to maximum health")
for _, prohibited in {
	'GetService("Players")',
	'FindFirstChildOfClass("Humanoid")',
	"Humanoid:TakeDamage",
	"Humanoid.Health",
	".Health =",
} do
	assert(not contains(healingResolver, prohibited), "pure healing resolver must not use " .. prohibited)
end
assert(
	contains(lifeService, "OperativeHealingResolver.resolve"),
	"life service must route field dressings through the pure healing resolver"
)
assert(contains(lifeService, "allowHealthIncrease"), "only the healing commit path may permit health increases")
assert(
	contains(progressionService, "function RunProgressionService.awardFieldIntel"),
	"field intel requires a server-owned XP award function"
)
assert(
	contains(progressionService, "processedFieldIntelRewardIds"),
	"field intel rewards require bounded duplicate protection"
)
assert(contains(bootstrap, "LootDropService.start()"), "server bootstrap must start the loot runtime")

print("LootDropSourceAudit: deterministic death drops, one prompt connection, reward authority, and bounds passed")
