--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "inventory persistence assertion failed", 2)
	end
end

local EQUIPMENT_TOKEN = {}
local equipmentContracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
	RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
	SourceIds = { Elite = "Elite", Boss = "Boss" },
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

local CONTRACTS_TOKEN = {}
local DISMANTLE_TOKEN = {}
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
		Persistence = { PlayerInventoryContracts = CONTRACTS_TOKEN, InventoryDismantleResolver = DISMANTLE_TOKEN },
		Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN },
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
				if token == DISMANTLE_TOKEN then
					return dismantleResolver
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
function store:load(key: string)
	return deepCopy(self.data[key])
end
function store:save(key: string, value: any): boolean
	if self.failSaves then
		return false
	end
	self.data[key] = deepCopy(value)
	return true
end

local reward = {
	InstanceId = "item_first_guid",
	GrantId = "reward:run-123:Elite",
	ContentSignature = "v1|warden-rifle|1.0.0|Uncommon|12|Elite|77",
	DefinitionId = "warden-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Warden Rifle",
	Slot = "Primary",
	Rarity = "Uncommon",
	Power = 12,
	SourceId = "Elite",
	RunId = "run-123",
	Seed = 77,
}

local service = serviceModule.new(store)
local loadResult = service:loadPlayer(101, 1000)
assert(loadResult.Accepted and loadResult.Migrated, "new record should persist")
assert(loadResult.Record.SchemaVersion == contracts.CurrentSchemaVersion, "new records should use the current schema")

local applied = service:applyReward(101, reward, 1001)
assert(applied.Accepted, "reward should apply once")
assert(applied.Record.AppliedRewardGrantIds[reward.GrantId] == true, "grant id must be indexed")

local duplicateInstance = service:applyReward(101, reward, 1002)
assert(
	not duplicateInstance.Accepted and duplicateInstance.ReasonId == "RewardAlreadyApplied",
	"same instance must reject"
)

local replayedReward = table.clone(reward)
replayedReward.InstanceId = "item_different_guid"
local replayed = service:applyReward(101, replayedReward, 1003)
assert(not replayed.Accepted and replayed.ReasonId == "RewardAlreadyApplied", "same grant with a new GUID must reject")
assert(
	replayed.Record.InventoryByInstanceId[replayedReward.InstanceId] == nil,
	"replayed GUID must not enter inventory"
)

local equipped = service:equip(101, "Primary", reward.InstanceId, 1004)
assert(equipped.Accepted, "owned item should equip")

local reloaded = serviceModule.new(store)
local reloadResult = reloaded:loadPlayer(101, 1100)
assert(reloadResult.Accepted and not reloadResult.Migrated, "a current-schema record reloads without migrating")
assert(reloadResult.Record.AppliedRewardGrantIds[reward.GrantId] == true, "grant index must survive reload")
local replayAfterReload = reloaded:applyReward(101, replayedReward, 1101)
assert(
	not replayAfterReload.Accepted and replayAfterReload.ReasonId == "RewardAlreadyApplied",
	"replay after reload must reject"
)

store.data["player:202:inventory"] = {
	SchemaVersion = 1,
	PlayerId = 202,
	InventoryByInstanceId = {
		legacy_item = {
			InstanceId = "legacy_item",
			DefinitionId = "keeper-relic",
			DefinitionVersion = "1.0.0",
			DisplayName = "Keeper Relic",
			Slot = "Relic",
			Rarity = "Rare",
			Power = 18,
			SourceId = "Boss",
			RunId = "legacy-run",
			Seed = 78,
		},
	},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = { legacy_item = true },
	UpdatedAtUnix = 900,
}
local legacy = serviceModule.new(store):loadPlayer(202, 1200)
assert(legacy.Accepted and legacy.Migrated, "schema one should migrate")
assert(legacy.Record.AppliedRewardGrantIds["reward:legacy-run:Boss"] == true, "migration must rebuild grant index")

store.failSaves = true
local failedReward = table.clone(reward)
failedReward.InstanceId = "item_failed_guid"
failedReward.GrantId = "reward:run-124:Boss"
failedReward.SourceId = "Boss"
failedReward.RunId = "run-124"
local failed = service:applyReward(101, failedReward, 1300)
assert(not failed.Accepted and failed.ReasonId == "SaveFailed", "failed writes must not mutate memory")
assert(service:getRecord(101).AppliedRewardGrantIds[failedReward.GrantId] == nil, "failed grant must roll back")
store.failSaves = false

--[[
	Schema 3 added the dismantle ledger. Every previously supported version must
	still load, or a live inventory is stranded.
]]
for _, supported in contracts.SupportedSchemaVersions do
	assert(contracts.isSupportedSchemaVersion(supported), "each declared version must be supported")
end
assert(contracts.isSupportedSchemaVersion(contracts.CurrentSchemaVersion), "the current version must be supported")
assert(not contracts.isSupportedSchemaVersion(contracts.CurrentSchemaVersion + 1), "future versions are unknown")

-- A schema 2 record predates dismantle and migrates to an empty ledger.
store.data["player:303:inventory"] = {
	SchemaVersion = 2,
	PlayerId = 303,
	InventoryByInstanceId = { item_carry_guid = table.clone(reward) },
	EquippedBySlot = {},
	AppliedRewardInstanceIds = { item_carry_guid = true },
	AppliedRewardGrantIds = { ["reward:run-123:Elite"] = true },
	UpdatedAtUnix = 900,
}
store.data["player:303:inventory"].InventoryByInstanceId.item_carry_guid.InstanceId = "item_carry_guid"
local upgraded = serviceModule.new(store)
local upgradedLoad = upgraded:loadPlayer(303, 1400)
assert(upgradedLoad.Accepted and upgradedLoad.Migrated, "a schema two record must migrate forward")
assert(upgradedLoad.Record.SchemaVersion == contracts.CurrentSchemaVersion, "migration reaches the current schema")
assert(type(upgradedLoad.Record.AppliedDismantleTransactions) == "table", "migration creates the ledger")
assert(next(upgradedLoad.Record.AppliedDismantleTransactions) == nil, "a pre-dismantle record has no transactions")
assert(upgradedLoad.Record.InventoryByInstanceId.item_carry_guid ~= nil, "migration preserves owned items")

-- Dismantle destroys the item once and records the transaction durably.
local dismantled = upgraded:dismantle(303, "item_carry_guid", "txn-a", 1500, true, {})
assert(dismantled.Accepted and dismantled.ReasonId == "ItemDismantled", "a valid dismantle is accepted")
assert(dismantled.Outcome.SalvagedPower == 12, "the destroyed item's facts are reported")
assert(dismantled.Record.InventoryByInstanceId.item_carry_guid == nil, "the item is gone")
assert(dismantled.Record.AppliedDismantleTransactions["txn-a"] ~= nil, "the transaction is recorded")

-- The ledger survives a reload, so a replay is answered after a rejoin.
local rejoined = serviceModule.new(store):loadPlayer(303, 1600)
assert(rejoined.Accepted, "the profile reloads after a dismantle")
assert(rejoined.Record.AppliedDismantleTransactions["txn-a"] ~= nil, "the dismantle ledger is durable")
assert(rejoined.Record.InventoryByInstanceId.item_carry_guid == nil, "the destroyed item does not return")

-- Replaying the same transaction returns the original outcome and writes nothing.
local replay = upgraded:dismantle(303, "item_carry_guid", "txn-a", 1700, true, {})
assert(replay.Accepted and replay.ReasonId == "TransactionAlreadyApplied", "a replay is accepted")
assert(replay.Outcome.InstanceId == "item_carry_guid", "the original outcome is returned")

-- A new transaction naming the destroyed item is rejected.
local second = upgraded:dismantle(303, "item_carry_guid", "txn-b", 1800, true, {})
assert(not second.Accepted and second.ReasonId == "ItemNotOwned", "an item cannot be destroyed twice")

-- Without the session lease the destructive write is refused.
local unleased = upgraded:dismantle(303, "item_other", "txn-c", 1900, false, {})
assert(not unleased.Accepted and unleased.ReasonId == "SessionLeaseRequired", "dismantle requires the lease")

-- The equipped item is protected, so a spare is needed for the failure case.
local keeper = serviceModule.new(store)
keeper:loadPlayer(101, 2000)
assert(keeper:getRecord(101).EquippedBySlot.Primary == reward.InstanceId, "the first item is equipped")
local equippedAttempt = keeper:dismantle(101, reward.InstanceId, "txn-equipped", 2010, true, {})
assert(not equippedAttempt.Accepted and equippedAttempt.ReasonId == "ItemEquipped", "equipped items are protected")

local spare = table.clone(reward)
spare.InstanceId = "item_spare_guid"
spare.GrantId = "reward:run-125:Elite"
spare.RunId = "run-125"
local spareGranted = keeper:applyReward(101, spare, 2020)
assert(spareGranted.Accepted, "the spare item is granted")
assert(spareGranted.Record.AppliedDismantleTransactions ~= nil, "a reward grant preserves the dismantle ledger")

-- A failed save must not remove the item from memory.
store.failSaves = true
local failedDismantle = keeper:dismantle(101, spare.InstanceId, "txn-fail", 2100, true, {})
assert(not failedDismantle.Accepted and failedDismantle.ReasonId == "SaveFailed", "a failed write is reported")
assert(keeper:getRecord(101).InventoryByInstanceId[spare.InstanceId] ~= nil, "a failed dismantle rolls back")
assert(keeper:getRecord(101).AppliedDismantleTransactions["txn-fail"] == nil, "a failed dismantle records nothing")
store.failSaves = false

-- Retrying the same transaction after the failure now succeeds, because the
-- failed attempt recorded nothing.
local retried = keeper:dismantle(101, spare.InstanceId, "txn-fail", 2110, true, {})
assert(retried.Accepted and retried.ReasonId == "ItemDismantled", "a retry after a failed write succeeds")
assert(retried.Record.InventoryByInstanceId[spare.InstanceId] == nil, "the retry destroys the item")

-- A malformed ledger entry is rejected rather than dropped, because discarding
-- it would let an applied dismantle replay into a second destruction.
store.data["player:404:inventory"] = {
	SchemaVersion = contracts.CurrentSchemaVersion,
	PlayerId = 404,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	AppliedRewardGrantIds = {},
	AppliedDismantleTransactions = { ["txn-bad"] = { InstanceId = 7 } },
	UpdatedAtUnix = 900,
}
local corrupt = serviceModule.new(store):loadPlayer(404, 2200)
assert(not corrupt.Accepted and corrupt.ReasonId == "InvalidDismantleLedger", "a malformed ledger fails closed")

service:destroy()
assert(service:getRecord(101) == nil, "destroyed service should disclose no record")

print("PlayerInventoryPersistenceService.test.luau passed")
