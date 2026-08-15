--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local persistence = fs.readFile("games/living-kingdoms/src/server/Systems/CharacterProgressionPersistenceService.luau")
local inventoryOwner = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")
local lifecycle = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/CharacterProgressionService.luau")
local rewards = fs.readFile("games/living-kingdoms/src/server/Systems/CharacterProgressionGameplayRewardService.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/CharacterProgressionConfig.luau")

assert(contains(inventoryOwner, 'DataStoreName = "AtlasPlayerInventoryV1"'), "progression must remain under the existing datastore owner")
assert(contains(inventoryOwner, "CharacterProgressionPersistenceService.new(store)"), "progression persistence must reuse the existing store adapter")
assert(contains(inventoryOwner, "leases:hasLease(playerId, nowUnix)"), "progression writes must require the existing session lease")
assert(contains(inventoryOwner, "saveCharacterProgression"), "lease owner must expose the progression persistence seam")
assert(contains(lifecycle, "CharacterProgressionService.hydratePlayer"), "join lifecycle must hydrate durable progression")
assert(contains(lifecycle, "CharacterProgressionService.configurePersistence"), "award service must bind to the leased persistence owner")

assert(contains(persistence, "Resolver.normalizeState"), "saved and legacy progression must normalize through the canonical resolver")
assert(contains(persistence, "AppliedGrantIds"), "durable one-time progression rewards need a replay ledger")
assert(contains(persistence, "ProgressionGrantAlreadyApplied"), "durable replay must resolve idempotently")
assert(contains(persistence, "DungeonCompletion"), "dungeon completion must use durable attribution")
assert(contains(persistence, "Quest"), "quest completion must be ready for durable attribution")
assert(contains(persistence, "Event"), "event completion must be ready for durable attribution")

assert(contains(progression, "persistenceWriter"), "XP owner must persist before publishing live state")
assert(contains(progression, "ProgressionPersistenceUnavailable"), "XP must fail closed when persistence is unavailable")
assert(contains(progression, "XPAlreadyAwarded"), "durable replay must not add XP twice")

assert(contains(rewards, "confirmedHit(model)"), "enemy XP must require server-confirmed damage")
assert(contains(rewards, "ExpeditionLiveRuntimeService.readSnapshot"), "dungeon XP must observe the authoritative expedition runtime")
assert(contains(rewards, "ExpeditionRunRosterService.read"), "dungeon XP must use the launch-time participant roster")
assert(contains(rewards, "ExpeditionRewardDispositionResolver.shouldPersist"), "failed/non-rewarding runs must not grant completion XP")
assert(contains(rewards, "Config.RewardXP.EnemyKill"), "enemy XP amount must be configured")
assert(contains(rewards, "Config.RewardXP.DungeonCompletion"), "dungeon XP amount must be configured")

assert(contains(config, "EnemyKill = 20"), "enemy XP default must be explicit and rebalanceable")
assert(contains(config, "Assist = 10"), "assist XP default must be reserved for future contributor attribution")
assert(contains(config, "DungeonCompletion = 250"), "dungeon XP default must be explicit and rebalanceable")

for _, source in { persistence, inventoryOwner, progression, rewards } do
	assert(not contains(source, "DataStoreService:GetDataStore"), "progression must not create a second datastore authority")
	assert(not contains(source, "OnServerEvent"), "progression mutation must not accept client-authored reward events")
end

print("CharacterProgressionPersistenceSourceAudit: lease ownership, durable replay, hydration, and gameplay reward boundaries passed")
