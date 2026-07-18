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

for _, token in {
	"ProximityPromptService.PromptTriggered:Connect",
	"RunService.Heartbeat:Connect",
	"MaximumTrackedEnemyModels",
	"DropLifetimeSeconds",
	"PickupMaximumDistanceStuds",
	"activeDropCount()",
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

assert(contains(healingResolver, "operativeSnapshot.lifeStateId ~= AliveStateId"))
assert(contains(healingResolver, "math.min("))
assert(not contains(healingResolver, "Humanoid"))
assert(contains(lifeService, "OperativeHealingResolver.resolve"))
assert(contains(lifeService, "allowHealthIncrease"))
assert(contains(progressionService, "function RunProgressionService.awardFieldIntel"))
assert(contains(progressionService, "processedFieldIntelRewardIds"))
assert(contains(bootstrap, "LootDropService.start()"))

print("LootDropSourceAudit: deterministic death drops, one prompt connection, reward authority, and bounds passed")
