--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "inventory persistence assertion failed", 2)
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

local CONTRACTS_TOKEN = {}
local DISMANTLE_TOKEN = {}
local STORAGE_RESULTS_TOKEN = {}
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

local store = { data = {}, failSaves = false, failReads = false, saveCount = 0 }
function store:read(key: string): any
	if self.failReads then
		return storageResults.readFailed("simulated read outage")
	end
	local value = deepCopy(self.data[key])
	if value == nil then
		return storageResults.missing()
	end
	return storageResults.found(value)
end
function store:write(key: string, value: any): any
	if self.failSaves then
		return storageResults.writeFailed("simulated write failure")
	end
	self.saveCount += 1
	self.data[key] = deepCopy(value)
	return storageResults.committed(deepCopy(value))
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
	Affixes = {},
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
assert(#legacy.Record.InventoryByInstanceId.legacy_item.Affixes == 0, "legacy gear should normalize to no affixes")

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

for _, supported in contracts.SupportedSchemaVersions do
	assert(contracts.isSupportedSchemaVersion(supported), "each declared version must be supported")
end
assert(contracts.isSupportedSchemaVersion(contracts.CurrentSchemaVersion), "the current version must be supported")
assert(not contracts.isSupportedSchemaVersion(contracts.CurrentSchemaVersion + 1), "future versions are unknown")

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

local dismantled = upgraded:dismantle(303, "item_carry_guid", "txn-a", 1500, true, {})
assert(dismantled.Accepted and dismantled.ReasonId == "ItemDismantled", "a valid dismantle is accepted")
assert(dismantled.Outcome.SalvagedPower == 12, "the destroyed item's facts are reported")
assert(dismantled.Record.InventoryByInstanceId.item_carry_guid == nil, "the item is gone")
assert(dismantled.Record.AppliedDismantleTransactions["txn-a"] ~= nil, "the transaction is recorded")

local rejoined = serviceModule.new(store):loadPlayer(303, 1600)
assert(rejoined.Accepted, "the profile reloads after a dismantle")
assert(rejoined.Record.AppliedDismantleTransactions["txn-a"] ~= nil, "the dismantle ledger is durable")
assert(rejoined.Record.InventoryByInstanceId.item_carry_guid == nil, "the destroyed item does not return")

local replay = upgraded:dismantle(303, "item_carry_guid", "txn-a", 1700, true, {})
assert(replay.Accepted and replay.ReasonId == "TransactionAlreadyApplied", "a replay is accepted")
assert(replay.Outcome.InstanceId == "item_carry_guid", "the original outcome is returned")

local second = upgraded:dismantle(303, "item_carry_guid", "txn-b", 1800, true, {})
assert(not second.Accepted and second.ReasonId == "ItemNotOwned", "an item cannot be destroyed twice")

local unleased = upgraded:dismantle(303, "item_other", "txn-c", 1900, false, {})
assert(not unleased.Accepted and unleased.ReasonId == "SessionLeaseRequired", "dismantle requires the lease")

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

store.failSaves = true
local failedDismantle = keeper:dismantle(101, spare.InstanceId, "txn-fail", 2100, true, {})
assert(not failedDismantle.Accepted and failedDismantle.ReasonId == "SaveFailed", "a failed write is reported")
assert(keeper:getRecord(101).InventoryByInstanceId[spare.InstanceId] ~= nil, "a failed dismantle rolls back")
assert(keeper:getRecord(101).AppliedDismantleTransactions["txn-fail"] == nil, "a failed dismantle records nothing")
store.failSaves = false

local retried = keeper:dismantle(101, spare.InstanceId, "txn-fail", 2110, true, {})
assert(retried.Accepted and retried.ReasonId == "ItemDismantled", "a retry after a failed write succeeds")
assert(retried.Record.InventoryByInstanceId[spare.InstanceId] == nil, "the retry destroys the item")

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

--[[
	Patch 0.7 migration invariants. A record is durable across deploys, so the
	load path is the only place a schema mismatch can be caught. Two directions
	matter and neither may write: a record from a future deploy must fail closed
	rather than be silently rewritten at today's schema (which would destroy
	whatever the newer schema added), and another player's record must never be
	adopted under the requesting id.
]]
local function legacyRecordFor(playerId: number, schemaVersion: any): any
	return {
		SchemaVersion = schemaVersion,
		PlayerId = playerId,
		InventoryByInstanceId = {
			migration_item = {
				InstanceId = "migration_item",
				DefinitionId = "keeper-relic",
				DefinitionVersion = "1.0.0",
				DisplayName = "Keeper Relic",
				Slot = "Relic",
				Rarity = "Rare",
				Power = 18,
				SourceId = "Boss",
				RunId = "migration-run",
				Seed = 79,
			},
		},
		EquippedBySlot = {},
		AppliedRewardInstanceIds = { migration_item = true },
		UpdatedAtUnix = 900,
	}
end

local futureSchema = contracts.CurrentSchemaVersion + 1
store.data["player:606:inventory"] = legacyRecordFor(606, futureSchema)
local savesBeforeFuture = store.saveCount
local futureLoad = serviceModule.new(store):loadPlayer(606, 2300)
assert(not futureLoad.Accepted, "a record from a newer deploy must fail closed")
assert(futureLoad.ReasonId == "UnsupportedSchemaVersion", "an unsupported schema must be named")
assert(store.saveCount == savesBeforeFuture, "an unsupported schema must never be rewritten at today's schema")
assert(store.data["player:606:inventory"].SchemaVersion == futureSchema, "the durable record must survive untouched")

store.data["player:607:inventory"] = legacyRecordFor(608, contracts.CurrentSchemaVersion)
local savesBeforeMismatch = store.saveCount
local mismatched = serviceModule.new(store):loadPlayer(607, 2300)
assert(not mismatched.Accepted and mismatched.ReasonId == "PlayerIdMismatch", "another player's record is not adopted")
assert(store.saveCount == savesBeforeMismatch, "a mismatched record must not be rewritten under the requesting id")

-- Every supported version must migrate forward to exactly one shape, and the
-- migration must be idempotent: the write-back has to leave the durable record
-- at the current schema so a rejoin does not migrate a second time.
for _, supported in contracts.SupportedSchemaVersions do
	local playerId = 6100 + supported
	local key = string.format("player:%d:inventory", playerId)
	store.data[key] = legacyRecordFor(playerId, supported)

	local migrating = serviceModule.new(store)
	local firstLoad = migrating:loadPlayer(playerId, 2400)
	assert(firstLoad.Accepted, "every supported schema must load: " .. tostring(supported))
	assert(
		firstLoad.Record.SchemaVersion == contracts.CurrentSchemaVersion,
		"every supported schema must migrate forward: " .. tostring(supported)
	)
	assert(
		firstLoad.Migrated == (supported ~= contracts.CurrentSchemaVersion),
		"only an older schema may report a migration: " .. tostring(supported)
	)
	assert(
		firstLoad.Record.InventoryByInstanceId.migration_item ~= nil,
		"migration must preserve owned items: " .. tostring(supported)
	)
	assert(
		store.data[key].SchemaVersion == contracts.CurrentSchemaVersion,
		"a migration write-back must leave the durable record current: " .. tostring(supported)
	)

	local secondLoad = serviceModule.new(store):loadPlayer(playerId, 2500)
	assert(secondLoad.Accepted and not secondLoad.Migrated, "migration must be idempotent: " .. tostring(supported))
end

-- Patch 0.7 session lifecycle: load is wired to PlayerAdded, so a departing
-- player's record must be released or every joiner stays resident for the life
-- of the server and remains readable long after their lease is gone.
local lifecycle = serviceModule.new(store)
local lifecycleLoad = lifecycle:loadPlayer(101, 3000)
assert(lifecycleLoad.Accepted, "the lifecycle player loads")
assert(lifecycle:getRecord(101) ~= nil, "a loaded player is resident")

local savesBeforeRelease = store.saveCount
local releasedRecord = lifecycle:releasePlayer(101)
assert(releasedRecord.Accepted and releasedRecord.Released == true, "releasing a resident player is accepted")
assert(releasedRecord.ReasonId == "RecordReleased", "releasing a resident player reports the release")
assert(lifecycle:getRecord(101) == nil, "a released player must not stay resident")
assert(store.saveCount == savesBeforeRelease, "releasing a record must not write to the store")

local releasedAgain = lifecycle:releasePlayer(101)
assert(releasedAgain.Accepted and releasedAgain.Released == false, "a repeated release is accepted and writes nothing")
assert(releasedAgain.ReasonId == "NoRecordHeld", "a repeated release reports that no record was held")

local releaseUnknown = lifecycle:releasePlayer(999)
assert(releaseUnknown.Accepted and releaseUnknown.Released == false, "releasing an unknown player is safe")

for _, invalid in { 0, -1, 1.5, "101" } do
	local rejected = lifecycle:releasePlayer(invalid :: any)
	assert(not rejected.Accepted and rejected.ReasonId == "InvalidReleaseRequest", "a malformed release fails closed")
end

-- A released player must not be mutable until they load again, and the reload
-- must come from the store rather than from a stale resident copy.
local staleMutation = lifecycle:applyReward(101, spare, 3100)
assert(not staleMutation.Accepted and staleMutation.ReasonId == "PlayerNotLoaded", "a released player is not mutable")

local rejoinedAfterRelease = lifecycle:loadPlayer(101, 3200)
assert(rejoinedAfterRelease.Accepted, "a released player can rejoin")
assert(
	rejoinedAfterRelease.Record.InventoryByInstanceId[spare.InstanceId] == nil,
	"a rejoin must reload durable truth rather than a stale resident record"
)
assert(lifecycle:getRecord(101) ~= nil, "a rejoined player is resident again")
lifecycle:destroy()

local destroyedRelease = lifecycle:releasePlayer(101)
assert(not destroyedRelease.Accepted and destroyedRelease.ReasonId == "ServiceDestroyed", "a destroyed service refuses")

service:destroy()
assert(service:getRecord(101) == nil, "destroyed service should disclose no record")

print("PlayerInventoryPersistenceService.test.luau passed")
