--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "character progression persistence assertion failed", 2)
	end
end

local EQUIPMENT_TOKEN = {}
local AFFIX_TOKEN = {}
local equipmentContracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
	RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
	SourceIds = { Elite = "Elite", Boss = "Boss" },
}
local affixContracts = {
	EffectIds = {
		DamagePercent = "DamagePercent",
		ReloadSpeedPercent = "ReloadSpeedPercent",
		MaxHealthPercent = "MaxHealthPercent",
		MoveSpeedPercent = "MoveSpeedPercent",
		AbilityHastePercent = "AbilityHastePercent",
		AbilityPowerPercent = "AbilityPowerPercent",
	},
}

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
	debugName = "PlayerInventoryContracts",
	environment = {
		script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } } } },
		require = function(token: unknown)
			assert(token == EQUIPMENT_TOKEN, "unexpected contracts dependency")
			return equipmentContracts
		end,
	},
	injectGlobals = true,
})()

local storageResults =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/StorageResultContracts.luau"), {
		debugName = "StorageResultContracts",
		injectGlobals = true,
	})()
local durableMutation =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/DurableMutationContracts.luau"), {
		debugName = "DurableMutationContracts",
		injectGlobals = true,
	})()
local recoveryContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryRecoveryContracts.luau"), {
		debugName = "InventoryRecoveryContracts",
		injectGlobals = true,
	})()
local capacityContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryCapacityContracts.luau"), {
		debugName = "InventoryCapacityContracts",
		injectGlobals = true,
	})()

local MIGRATION_CONTRACTS_TOKEN = {}
local migrationSteps =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryMigrationSteps.luau"), {
		debugName = "InventoryMigrationSteps",
		environment = {
			script = { Parent = { PlayerInventoryContracts = MIGRATION_CONTRACTS_TOKEN } },
			require = function(): any
				return contracts
			end,
		},
		injectGlobals = true,
	})()

local CONTRACTS_TOKEN = {}
local DISMANTLE_TOKEN = {}
local STORAGE_RESULTS_TOKEN = {}
local DURABLE_MUTATION_TOKEN = {}
local MIGRATION_STEPS_TOKEN = {}
local RECOVERY_TOKEN = {}
local CAPACITY_TOKEN = {}
local RESOLVER_CONTRACTS_TOKEN = {}
local RESOLVER_EQUIPMENT_TOKEN = {}

local dismantleResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryDismantleResolver.luau"), {
		debugName = "InventoryDismantleResolver",
		environment = {
			script = {
				Parent = {
					PlayerInventoryContracts = RESOLVER_CONTRACTS_TOKEN,
					Parent = { Equipment = { EquipmentRewardContracts = RESOLVER_EQUIPMENT_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == RESOLVER_CONTRACTS_TOKEN then
					return contracts
				end
				if token == RESOLVER_EQUIPMENT_TOKEN then
					return equipmentContracts
				end
				error("unexpected dismantle resolver dependency")
			end,
		},
		injectGlobals = true,
	})()

local replicatedStorage = {
	Shared = {
		Persistence = {
			PlayerInventoryContracts = CONTRACTS_TOKEN,
			InventoryDismantleResolver = DISMANTLE_TOKEN,
			StorageResultContracts = STORAGE_RESULTS_TOKEN,
			DurableMutationContracts = DURABLE_MUTATION_TOKEN,
			InventoryMigrationSteps = MIGRATION_STEPS_TOKEN,
			InventoryRecoveryContracts = RECOVERY_TOKEN,
			InventoryCapacityContracts = CAPACITY_TOKEN,
		},
		Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN, EquipmentAffixContracts = AFFIX_TOKEN },
	},
}

local serviceModule =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau"), {
		debugName = "PlayerInventoryPersistenceService",
		environment = {
			game = {
				GetService = function(_self: unknown, name: string)
					assert(name == "ReplicatedStorage")
					return replicatedStorage
				end,
			},
			require = function(token: unknown)
				if token == CONTRACTS_TOKEN then
					return contracts
				end
				if token == EQUIPMENT_TOKEN then
					return equipmentContracts
				end
				if token == AFFIX_TOKEN then
					return affixContracts
				end
				if token == DISMANTLE_TOKEN then
					return dismantleResolver
				end
				if token == STORAGE_RESULTS_TOKEN then
					return storageResults
				end
				if token == DURABLE_MUTATION_TOKEN then
					return durableMutation
				end
				if token == MIGRATION_STEPS_TOKEN then
					return migrationSteps
				end
				if token == RECOVERY_TOKEN then
					return recoveryContracts
				end
				if token == CAPACITY_TOKEN then
					return capacityContracts
				end
				error("unexpected persistence dependency")
			end,
		},
		injectGlobals = true,
	})()

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local store = { data = {}, failSaves = false }
function store:read(key: string): any
	local value = deepCopy(self.data[key])
	return if value == nil then storageResults.missing() else storageResults.found(value)
end
function store:write(key: string, value: any): any
	if self.failSaves then
		return storageResults.writeFailed("simulated write failure")
	end
	self.data[key] = deepCopy(value)
	return storageResults.committed(deepCopy(value))
end
function store:commit(key: string, transform: (any) -> any): any
	local value = transform(deepCopy(self.data[key]))
	self.data[key] = deepCopy(value)
	return storageResults.committed(deepCopy(value))
end

assert(contracts.CurrentSchemaVersion == 5, "character progression should ship in account schema five")
local validChain, chainReason = migrationSteps.validateChain()
assert(validChain, chainReason)

local service = serviceModule.new(store)
local loaded = service:loadPlayer(7001, 1000)
assert(loaded.Accepted and loaded.Record.CharacterProgression.TotalXP == 0, "new accounts should begin at zero XP")

local first = service:applyCharacterProgression(
	7001,
	{ Version = "CHARACTER-XP-v1", TotalXP = 350 },
	"DungeonCompletion:run-1",
	1001
)
assert(first.Accepted, "first durable XP grant should commit")
assert(first.Record.CharacterProgression.TotalXP == 350, "committed XP should be visible in the account record")
assert(first.Record.AppliedCharacterProgressionGrantIds["DungeonCompletion:run-1"] == true, "grant id must persist")

local reloaded = serviceModule.new(store):loadPlayer(7001, 1100)
assert(reloaded.Accepted and reloaded.Record.CharacterProgression.TotalXP == 350, "XP must survive a rejoin")
assert(
	reloaded.Record.AppliedCharacterProgressionGrantIds["DungeonCompletion:run-1"] == true,
	"replay ledger must survive a rejoin"
)

local duplicate = service:applyCharacterProgression(
	7001,
	{ Version = "CHARACTER-XP-v1", TotalXP = 600 },
	"DungeonCompletion:run-1",
	1002
)
assert(
	not duplicate.Accepted and duplicate.ReasonId == "CharacterProgressionGrantAlreadyApplied",
	"same durable grant must not double-award"
)
assert(duplicate.Record.CharacterProgression.TotalXP == 350, "duplicate grants cannot advance XP")

local rollback = service:applyCharacterProgression(7001, { Version = "CHARACTER-XP-v1", TotalXP = 349 }, nil, 1003)
assert(
	not rollback.Accepted and rollback.ReasonId == "CharacterProgressionRollbackRejected",
	"persistence must reject XP rollback"
)

store.failSaves = true
local failed = service:applyCharacterProgression(
	7001,
	{ Version = "CHARACTER-XP-v1", TotalXP = 500 },
	"DungeonCompletion:run-2",
	1004
)
assert(not failed.Accepted and failed.ReasonId == "SaveFailed", "failed writes must fail closed")
assert(service:getRecord(7001).CharacterProgression.TotalXP == 350, "failed writes cannot mutate resident XP")
store.failSaves = false

store.data["player:7002:inventory"] = {
	SchemaVersion = 4,
	PlayerId = 7002,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	AppliedRewardGrantIds = {},
	AppliedDismantleTransactions = {},
	AppliedRewardContentSignatures = {},
	XP = 725,
	UpdatedAtUnix = 900,
}
local legacy = serviceModule.new(store):loadPlayer(7002, 1200)
assert(legacy.Accepted and legacy.Migrated, "schema four should migrate to schema five")
assert(legacy.Record.CharacterProgression.TotalXP == 725, "legacy root XP should migrate without loss")
assert(
	type(legacy.Record.AppliedCharacterProgressionGrantIds) == "table",
	"migration must create progression replay ledger"
)

store.data["player:7003:inventory"] = {
	SchemaVersion = 4,
	PlayerId = 7003,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	AppliedRewardGrantIds = {},
	AppliedDismantleTransactions = {},
	AppliedRewardContentSignatures = {},
	CharacterProgression = { TotalXP = "corrupt" },
	UpdatedAtUnix = 900,
}
local malformed = serviceModule.new(store):loadPlayer(7003, 1200)
assert(malformed.Accepted and malformed.Record.CharacterProgression.TotalXP == 0, "malformed XP should recover safely")

local capXP = 344397924
local capped = service:applyCharacterProgression(
	7001,
	{ Version = "CHARACTER-XP-v1", TotalXP = capXP },
	"DungeonCompletion:cap-test",
	1005
)
assert(capped.Accepted and capped.Record.CharacterProgression.TotalXP == capXP, "canonical cap XP must persist exactly")
local capReload = serviceModule.new(store):loadPlayer(7001, 1300)
assert(capReload.Record.CharacterProgression.TotalXP == capXP, "cap XP must round-trip exactly")

print("Character progression persistence tests passed")
