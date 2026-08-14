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

local durableMutation =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/DurableMutationContracts.luau"), {
		debugName = "DurableMutationContracts",
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
local recoveryContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryRecoveryContracts.luau"), {
		debugName = "InventoryRecoveryContracts",
		injectGlobals = true,
	})()

local CONTRACTS_TOKEN = {}
local DISMANTLE_TOKEN = {}
local STORAGE_RESULTS_TOKEN = {}
local DURABLE_MUTATION_TOKEN = {}
local MIGRATION_STEPS_TOKEN = {}
local RECOVERY_TOKEN = {}
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

function store:commit(key: string, transform: (any) -> any): any
	local nextValue = transform(deepCopy(self.data[key]))
	self.data[key] = deepCopy(nextValue)
	return storageResults.committed(deepCopy(nextValue))
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
--[[
	Quarantine copies the damaged payload to a derived key, so a write does
	happen -- just never to the source. That distinction is the invariant.
]]
assert(store.saveCount > savesBeforeFuture, "an unrecoverable record must be quarantined for diagnosis")
assert(store.data["player:606:inventory"].SchemaVersion == futureSchema, "the durable record must survive untouched")
local quarantinedFuture = nil
for key, value in store.data do
	if string.find(key, "quarantine:player:606:inventory", 1, true) == 1 then
		quarantinedFuture = value
	end
end
assert(quarantinedFuture ~= nil, "the damaged record must be copied to a derived quarantine key")
assert(quarantinedFuture.SourceKey == "player:606:inventory", "the quarantine envelope must name its source")
assert(quarantinedFuture.ReasonId == "UnsupportedSchemaVersion", "the quarantine envelope must record why")
assert(quarantinedFuture.Classification == "Corrupt", "an unsupported schema is not a transient failure")
assert(quarantinedFuture.Payload.SchemaVersion == futureSchema, "the quarantined payload must be the damaged record")

store.data["player:607:inventory"] = legacyRecordFor(608, contracts.CurrentSchemaVersion)
local savesBeforeMismatch = store.saveCount
local mismatched = serviceModule.new(store):loadPlayer(607, 2300)
assert(not mismatched.Accepted and mismatched.ReasonId == "PlayerIdMismatch", "another player's record is not adopted")
assert(
	store.data["player:607:inventory"].PlayerId == 608,
	"a mismatched record must not be rewritten under the requesting id"
)

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

--[[
	Patch 0.7 Batch 4. A repeat of a grant id is either a retry of the same grant
	or a different grant wearing a used id. The ledger used to record only that an
	id had been used, so the second case was answered as the first and the
	differing reward was discarded with no signal.
]]
local mutation = serviceModule.new(store)
local MUT_PLAYER = 7070
assert(mutation:loadPlayer(MUT_PLAYER, 5000).Accepted, "the mutation player loads")

local function grant(instanceSuffix: string, signature: string): any
	return {
		InstanceId = "item_" .. instanceSuffix .. "_guid",
		GrantId = "reward:expedition:mut:Boss",
		ContentSignature = signature,
		DefinitionId = "keeper-relic",
		DefinitionVersion = "1.0.0",
		DisplayName = "Keeper Relic",
		Slot = "Relic",
		Rarity = "Rare",
		Power = 18,
		Affixes = {},
		SourceId = "Boss",
		RunId = "expedition:mut",
		Seed = 41,
	}
end

local firstGrant = mutation:applyReward(MUT_PLAYER, grant("first", "v1|keeper-relic|Rare|18"), 5010)
assert(firstGrant.Accepted, "the first grant is applied")
assert(
	firstGrant.Record.AppliedRewardContentSignatures["reward:expedition:mut:Boss"] == "v1|keeper-relic|Rare|18",
	"an applied grant must record the content it was applied for"
)

-- #36: a retry of the same grant, with a fresh instance GUID, is still a retry.
local retry = mutation:applyReward(MUT_PLAYER, grant("second", "v1|keeper-relic|Rare|18"), 5020)
assert(not retry.Accepted, "a retried grant must not apply twice")
assert(retry.ReasonId == "RewardAlreadyApplied", "an identical retry must read as a replay")
assert(retry.Record.InventoryByInstanceId.item_second_guid == nil, "a retry must not add a second copy")

-- #37: the same grant id carrying different content is a conflict, not a replay.
local conflict = mutation:applyReward(MUT_PLAYER, grant("third", "v2|keeper-relic|Legendary|99"), 5030)
assert(not conflict.Accepted, "a conflicting grant must not apply")
assert(conflict.ReasonId == "RewardGrantConflict", "differing content under a used grant id must be named a conflict")
assert(conflict.Record.InventoryByInstanceId.item_third_guid == nil, "a conflicting grant must not be stored")

-- #33: equip is naturally idempotent under exact replay -- the same slot and
-- instance twice leaves one binding and no ledger movement.
local equipFirst = mutation:equip(MUT_PLAYER, "Relic", "item_first_guid", 5040)
assert(equipFirst.Accepted, "the item equips")
local equipReplay = mutation:equip(MUT_PLAYER, "Relic", "item_first_guid", 5050)
assert(equipReplay.Accepted, "an exact equip replay stays accepted")
assert(equipReplay.Record.EquippedBySlot.Relic == "item_first_guid", "an equip replay leaves the same binding")
assert(
	equipReplay.Record.AppliedRewardContentSignatures["reward:expedition:mut:Boss"] == "v1|keeper-relic|Rare|18",
	"equipping must not disturb reward replay protection"
)

-- #38/#40: destroying an item must not erase the record that its grant was
-- already applied, or the same reward could be granted again after a dismantle.
local dismantled = mutation:dismantle(MUT_PLAYER, "item_first_guid", "txn-mut-1", 5060, true, {})
assert(not dismantled.Accepted and dismantled.ReasonId == "ItemEquipped", "an equipped item is protected")

local spareGrant = {
	InstanceId = "item_spare_mut_guid",
	GrantId = "reward:expedition:mut2:Elite",
	ContentSignature = "v1|warden-rifle|Uncommon|12",
	DefinitionId = "warden-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Warden Rifle",
	Slot = "Primary",
	Rarity = "Uncommon",
	Power = 12,
	Affixes = {},
	SourceId = "Elite",
	RunId = "expedition:mut2",
	Seed = 42,
}
assert(mutation:applyReward(MUT_PLAYER, spareGrant, 5070).Accepted, "the spare grant applies")
local spareDismantle = mutation:dismantle(MUT_PLAYER, "item_spare_mut_guid", "txn-mut-2", 5080, true, {})
assert(spareDismantle.Accepted and spareDismantle.ReasonId == "ItemDismantled", "the spare item is destroyed")
assert(
	spareDismantle.Record.AppliedRewardGrantIds["reward:expedition:mut2:Elite"] == true,
	"a dismantle must not erase the grant ledger entry that prevents a re-grant"
)
assert(
	spareDismantle.Record.AppliedRewardContentSignatures["reward:expedition:mut2:Elite"] ~= nil,
	"a dismantle must not erase the content identity that distinguishes replay from conflict"
)

local regrant = mutation:applyReward(MUT_PLAYER, spareGrant, 5090)
assert(not regrant.Accepted, "a destroyed reward must not be grantable again")
assert(regrant.ReasonId == "RewardAlreadyApplied", "the re-grant must still read as a replay after a dismantle")

-- #38: the dismantle replay survives a release and rejoin.
mutation:releasePlayer(MUT_PLAYER)
local rejoinedMutation = serviceModule.new(store)
assert(rejoinedMutation:loadPlayer(MUT_PLAYER, 5100).Accepted, "the player rejoins")
local replayedDismantle = rejoinedMutation:dismantle(MUT_PLAYER, "item_spare_mut_guid", "txn-mut-2", 5110, true, {})
assert(replayedDismantle.Accepted, "a replayed dismantle is accepted after a rejoin")
assert(replayedDismantle.ReasonId == "TransactionAlreadyApplied", "the replay must be recognised across a rejoin")
assert(replayedDismantle.Outcome.InstanceId == "item_spare_mut_guid", "the original outcome answers the replay")

-- #35: a signature ledger entry without its grant id is incoherent and fails closed.
store.data["player:7171:inventory"] = {
	SchemaVersion = contracts.CurrentSchemaVersion,
	PlayerId = 7171,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	AppliedRewardGrantIds = {},
	AppliedDismantleTransactions = {},
	AppliedRewardContentSignatures = { ["reward:orphan:Boss"] = "v1|orphan" },
	UpdatedAtUnix = 900,
}
local orphanSignature = serviceModule.new(store):loadPlayer(7171, 5200)
assert(not orphanSignature.Accepted, "a signature without its grant must fail closed")
assert(orphanSignature.ReasonId == "InvalidRewardSignatureLedger", "the orphaned signature reason must be stable")

-- #39: the ledger bound is enforced where it can still be reported, rather than
-- at the DataStore size limit where the whole record stops saving.
assert(durableMutation.MaximumLedgerEntries >= 1_024, "the ledger bound must leave room for a long-lived account")
assert(durableMutation.exceedsBound({}) == false, "an empty ledger is within bound")
local overBound = {}
for index = 1, durableMutation.MaximumLedgerEntries + 1 do
	overBound["grant:" .. tostring(index)] = true
end
assert(durableMutation.exceedsBound(overBound), "a ledger past the bound must be detectable")

--[[
	Batch 5 #48/#49. A record from a newer deploy carries state this build cannot
	describe. It must be refused and preserved, never rewritten at today's schema
	-- a downgrade write would discard exactly the fields this build could not
	see.
]]
local futureWithExtras = {
	SchemaVersion = contracts.CurrentSchemaVersion + 1,
	PlayerId = 8181,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	AppliedRewardGrantIds = {},
	AppliedDismantleTransactions = {},
	AppliedRewardContentSignatures = {},
	SeasonalCurrencyBalances = { embers = 12 },
	FutureOnlyLedger = { ["txn-future"] = true },
	UpdatedAtUnix = 900,
}
store.data["player:8181:inventory"] = futureWithExtras
local futureLoad = serviceModule.new(store):loadPlayer(8181, 6000)
assert(not futureLoad.Accepted, "a newer-deploy record must be refused")
assert(futureLoad.ReasonId == "UnsupportedSchemaVersion", "the refusal must name the schema")
assert(futureLoad.Classification == "Corrupt", "an unreadable newer record is not a transient failure")
local stillThere = store.data["player:8181:inventory"]
assert(stillThere.SchemaVersion == contracts.CurrentSchemaVersion + 1, "the source schema must be untouched")
assert(stillThere.SeasonalCurrencyBalances.embers == 12, "unknown newer fields must survive the refusal")
assert(stillThere.FutureOnlyLedger["txn-future"] == true, "every unknown newer ledger must survive the refusal")

-- Migration step identity is reported so an operator can tell 1 -> 4 from 3 -> 4.
store.data["player:8282:inventory"] = {
	SchemaVersion = 1,
	PlayerId = 8282,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	UpdatedAtUnix = 900,
}
local steppedLoad = serviceModule.new(store):loadPlayer(8282, 6100)
assert(steppedLoad.Accepted and steppedLoad.Migrated, "a schema-one record migrates")
assert(steppedLoad.MigrationStepIds ~= nil, "a migration must report which steps it took")
assert(
	#steppedLoad.MigrationStepIds == contracts.CurrentSchemaVersion - 1,
	"a schema-one record must cross every intermediate version"
)
assert(steppedLoad.MigrationStepIds[1] == "inventory-1-to-2-grant-index", "steps must be reported in order")

--[[
	#47: the migration write-back must not clobber a record that changed since
	the read. A newer record wins rather than being overwritten by one derived
	from a stale read.
]]
local raceStore = { data = {}, saveCount = 0 }
function raceStore:read(key: string): any
	local value = deepCopy(self.data[key])
	if value == nil then
		return storageResults.missing()
	end
	return storageResults.found(value)
end
function raceStore:write(key: string, value: any): any
	self.data[key] = deepCopy(value)
	return storageResults.committed(deepCopy(value))
end
function raceStore:commit(key: string, transform: (any) -> any): any
	-- Another server lands a newer record between this read and this commit.
	if key == "player:8383:inventory" and not self.raced then
		self.raced = true
		self.data[key] = {
			SchemaVersion = contracts.CurrentSchemaVersion,
			PlayerId = 8383,
			InventoryByInstanceId = {},
			EquippedBySlot = {},
			AppliedRewardInstanceIds = {},
			AppliedRewardGrantIds = {},
			AppliedDismantleTransactions = {},
			AppliedRewardContentSignatures = {},
			UpdatedAtUnix = 9999,
		}
	end
	local nextValue = transform(deepCopy(self.data[key]))
	self.data[key] = deepCopy(nextValue)
	return storageResults.committed(deepCopy(nextValue))
end

raceStore.data["player:8383:inventory"] = {
	SchemaVersion = 2,
	PlayerId = 8383,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	AppliedRewardGrantIds = {},
	UpdatedAtUnix = 900,
}
local raced = serviceModule.new(raceStore):loadPlayer(8383, 6200)
assert(not raced.Accepted, "a migration that lost a race must not report success")
assert(raced.ReasonId == "MigrationRaceDetected", "the race must be named")
assert(raceStore.data["player:8383:inventory"].UpdatedAtUnix == 9999, "the newer record must survive the race")
assert(
	raceStore.data["player:8383:inventory"].SchemaVersion == contracts.CurrentSchemaVersion,
	"the newer record must keep its own schema, not the migrating server's rewrite"
)

print("PlayerInventoryPersistenceService.test.luau passed")
