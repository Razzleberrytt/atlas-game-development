--!strict

--[[
	Patch 0.7 read-outage recovery, end to end.

	Three owners have to agree for a DataStore read outage to be survivable, and
	each is covered alone but the chain between them is not:

	  1. RobloxInventoryDataStoreAdapter remembers a key whose read exhausted its
	     retries and refuses to save it until a later read succeeds;
	  2. PlayerInventoryPersistenceService branches on the read status, so a
	     Failed read is refused as LoadFailed before a blank record is ever
	     built -- (1) remains the backstop if that check is ever bypassed;
	  3. InventoryLiveService must release the session lease it just acquired,
	     or a failed load would leave the player's lease squatting on this
	     server until it expired, locked out of every other server.

	The player-facing consequence of a rejected load is a kick
	(inventory-network.server.luau), which is the safe outcome: better to rejoin
	than to play a session whose inventory is blank and whose writes would
	contradict durable truth.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

-- Durable store, shared by both servers -------------------------------------

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

local durable: { [string]: any } = {}
local fakeStore = { failReads = false }
function fakeStore:GetAsync(key: string): any
	if self.failReads then
		error("simulated GetAsync outage")
	end
	return deepCopy(durable[key])
end
function fakeStore:UpdateAsync(key: string, transform: (any) -> any): any
	local nextValue = transform(deepCopy(durable[key]))
	durable[key] = deepCopy(nextValue)
	return deepCopy(nextValue)
end

-- Shared pure dependencies --------------------------------------------------

local EQUIPMENT_TOKEN, AFFIX_TOKEN = {}, {}
local equipmentContracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
	RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
	SourceIds = { Elite = "Elite", Boss = "Boss" },
}
local affixContracts = { EffectIds = { DamagePercent = "DamagePercent" } }

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
	debugName = "PlayerInventoryContracts",
	environment = {
		script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } } } },
		require = function(): any
			return equipmentContracts
		end,
	},
	injectGlobals = true,
})()

local RESOLVER_CONTRACTS_TOKEN, RESOLVER_EQUIPMENT_TOKEN = {}, {}
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
			require = function(token: unknown): any
				if token == RESOLVER_CONTRACTS_TOKEN then
					return contracts
				end
				return equipmentContracts
			end,
		},
		injectGlobals = true,
	})()

local SNAPSHOT_CONTRACTS_TOKEN, SNAPSHOT_EQUIPMENT_TOKEN = {}, {}
local inventorySnapshot =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventorySnapshot.luau"), {
		debugName = "PlayerInventorySnapshot",
		environment = {
			script = {
				Parent = {
					PlayerInventoryContracts = SNAPSHOT_CONTRACTS_TOKEN,
					Parent = { Equipment = { EquipmentRewardContracts = SNAPSHOT_EQUIPMENT_TOKEN } },
				},
			},
			require = function(token: unknown): any
				if token == SNAPSHOT_CONTRACTS_TOKEN then
					return contracts
				end
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
local capacityContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryCapacityContracts.luau"), {
		debugName = "InventoryCapacityContracts",
		injectGlobals = true,
	})()

local resolutionPolicy =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventoryDataStoreResolutionPolicy.luau"), {
		debugName = "InventoryDataStoreResolutionPolicy",
		injectGlobals = true,
	})()

local ADAPTER_SOURCE = fs.readFile("games/living-kingdoms/src/server/Systems/RobloxInventoryDataStoreAdapter.luau")
local LEASE_SOURCE = fs.readFile("games/living-kingdoms/src/server/Systems/InventorySessionLeaseService.luau")
local PERSISTENCE_SOURCE =
	fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau")
local LIVE_SOURCE = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")

--[[
	A whole server: real adapter over the shared store, real lease service, real
	persistence service, real live service. Only the DataStore itself is faked,
	so the read-outage guard under test is the production one.
]]
local function newServer(jobId: string): any
	local POLICY_TOKEN, ADAPTER_RESULTS_TOKEN = {}, {}
	local adapterModule = luau.load(ADAPTER_SOURCE, {
		debugName = "RobloxInventoryDataStoreAdapter:" .. jobId,
		environment = {
			game = {
				GetService = function(_self: any, name: string): any
					if name == "DataStoreService" then
						return {
							GetDataStore = function(): any
								return fakeStore
							end,
						}
					elseif name == "ReplicatedStorage" then
						return {
							Shared = { Persistence = { StorageResultContracts = ADAPTER_RESULTS_TOKEN } },
						}
					end
					return {
						IsStudio = function(): boolean
							return false
						end,
					}
				end,
			},
			script = { Parent = { InventoryDataStoreResolutionPolicy = POLICY_TOKEN } },
			require = function(token: unknown): any
				if token == POLICY_TOKEN then
					return resolutionPolicy
				elseif token == ADAPTER_RESULTS_TOKEN then
					return storageResults
				end
				error("unexpected adapter dependency")
			end,
			task = { wait = function() end },
			warn = function() end,
		},
		injectGlobals = true,
	})()

	local leaseService = luau.load(LEASE_SOURCE, {
		debugName = "InventorySessionLeaseService:" .. jobId,
		environment = {},
		injectGlobals = true,
	})()

	local CONTRACTS_TOKEN, DISMANTLE_TOKEN, STORAGE_RESULTS_TOKEN, DURABLE_MUTATION_TOKEN, MIGRATION_STEPS_TOKEN, RECOVERY_TOKEN =
		{}, {}, {}, {}, {}, {}
	local persistenceService = luau.load(PERSISTENCE_SOURCE, {
		debugName = "PlayerInventoryPersistenceService:" .. jobId,
		environment = {
			game = {
				GetService = function(): any
					return {
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
							Equipment = {
								EquipmentRewardContracts = EQUIPMENT_TOKEN,
								EquipmentAffixContracts = AFFIX_TOKEN,
							},
						},
					}
				end,
			},
			require = function(token: unknown): any
				if token == CONTRACTS_TOKEN then
					return contracts
				elseif token == EQUIPMENT_TOKEN then
					return equipmentContracts
				elseif token == AFFIX_TOKEN then
					return affixContracts
				elseif token == DISMANTLE_TOKEN then
					return dismantleResolver
				elseif token == MIGRATION_STEPS_TOKEN then
					return migrationSteps
				elseif token == CAPACITY_TOKEN then
					return capacityContracts
				elseif token == RECOVERY_TOKEN then
					return recoveryContracts
				elseif token == DURABLE_MUTATION_TOKEN then
					return durableMutation
				elseif token == STORAGE_RESULTS_TOKEN then
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

	local tokens: { [any]: string } = {}
	local function token(name: string): any
		local value = {}
		tokens[value] = name
		return value
	end
	local liveReplicatedStorage = {
		Shared = {
			Equipment = { EquipmentComparisonResolver = token("EquipmentComparisonResolver") },
			Persistence = {
				InventoryDismantleResolver = token("InventoryDismantleResolver"),
				PlayerInventorySnapshot = token("PlayerInventorySnapshot"),
			},
			Config = { EquipmentRewardConfig = token("EquipmentRewardConfig") },
		},
	}
	local moduleByName: { [string]: any } = {
		EquipmentComparisonResolver = {
			compareAgainstEquipped = function(): any
				return nil
			end,
		},
		InventoryDismantleResolver = dismantleResolver,
		PlayerInventorySnapshot = inventorySnapshot,
		EquipmentRewardConfig = { Definitions = {} },
		RobloxInventoryDataStoreAdapter = adapterModule,
		PlayerInventoryPersistenceService = persistenceService,
		InventorySessionLeaseService = leaseService,
	}

	return luau.load(LIVE_SOURCE, {
		debugName = "InventoryLiveService:" .. jobId,
		environment = {
			game = {
				JobId = jobId,
				GetService = function(_self: any, name: string): any
					if name == "ReplicatedStorage" then
						return liveReplicatedStorage
					elseif name == "HttpService" then
						return {
							GenerateGUID = function(): string
								return jobId .. "-guid-0123456789ab"
							end,
						}
					end
					error("unexpected service request: " .. name)
				end,
			},
			script = {
				Parent = {
					RobloxInventoryDataStoreAdapter = token("RobloxInventoryDataStoreAdapter"),
					PlayerInventoryPersistenceService = token("PlayerInventoryPersistenceService"),
					InventorySessionLeaseService = token("InventorySessionLeaseService"),
				},
			},
			warn = function() end,
			require = function(value: any): any
				local name = tokens[value]
				if name == nil then
					error("unexpected live service dependency")
				end
				return moduleByName[name]
			end,
		},
		injectGlobals = true,
	})()
end

local PLAYER = 5150
local INVENTORY_KEY = "atlas-prod:player:5150:inventory"

local alpha = newServer("job-alpha-00000000")

-- 1. Establish durable truth on a healthy server -----------------------------

check(alpha.loadPlayer(PLAYER, 1000).Accepted, "the player loads while the store is healthy")
local reward = {
	InstanceId = "item_outage_guid",
	GrantId = "reward:run-700:Elite",
	ContentSignature = "v1|warden-rifle|1.0.0|Uncommon|12|Elite|700",
	DefinitionId = "warden-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Warden Rifle",
	Slot = "Primary",
	Rarity = "Uncommon",
	Power = 12,
	Affixes = {},
	SourceId = "Elite",
	RunId = "run-700",
	Seed = 700,
}
check(alpha.applyReward(PLAYER, reward, 1010).Accepted, "the player earns a durable item")
check(durable[INVENTORY_KEY].InventoryByInstanceId.item_outage_guid ~= nil, "the item reaches the durable record")
alpha.releasePlayer(PLAYER)

-- 2. The player rejoins during a read outage ---------------------------------

local bravo = newServer("job-bravo-00000000")
fakeStore.failReads = true

local outageLoad = bravo.loadPlayer(PLAYER, 1100)
check(not outageLoad.Accepted, "a read outage must refuse the load rather than invent a new player")
check(outageLoad.ReasonId == "LoadFailed", "a failed read must be named as such, not borrowed from the write path")
check(bravo.getRecord(PLAYER) == nil, "a refused load must leave no resident record to serve or write from")

--[[
	The whole point of the adapter guard: the blank record the persistence layer
	built from a nil read must never have reached the store.
]]
check(
	durable[INVENTORY_KEY].InventoryByInstanceId.item_outage_guid ~= nil,
	"the durable record must survive the outage untouched"
)

-- 3. The failed load must not leave the lease squatting ----------------------

local charlie = newServer("job-charlie-0000000")
fakeStore.failReads = false
local elsewhere = charlie.loadPlayer(PLAYER, 1110)
check(elsewhere.Accepted, "a server whose load failed must release the lease so another server can take the player")
check(
	elsewhere.Record.InventoryByInstanceId.item_outage_guid ~= nil,
	"the recovering server must load durable truth, not a blank record"
)
charlie.releasePlayer(PLAYER)

-- 4. The outage server recovers once reads succeed ---------------------------

local recovered = bravo.loadPlayer(PLAYER, 1120)
check(recovered.Accepted, "the same server must recover once its reads succeed")
check(
	recovered.Record.InventoryByInstanceId.item_outage_guid ~= nil,
	"recovery must restore durable truth on the server that saw the outage"
)

local followUp = table.clone(reward)
followUp.InstanceId = "item_after_outage_guid"
followUp.GrantId = "reward:run-701:Elite"
followUp.RunId = "run-701"
check(bravo.applyReward(PLAYER, followUp, 1130).Accepted, "writes must resume once the read guard clears")
check(
	durable[INVENTORY_KEY].InventoryByInstanceId.item_outage_guid ~= nil
		and durable[INVENTORY_KEY].InventoryByInstanceId.item_after_outage_guid ~= nil,
	"a post-recovery write must extend durable truth rather than replace it"
)

--[[
	Task #19: failure -> recovery -> safe mutation. Durable truth must win over
	the blank state the outage briefly made plausible, and the recovered record
	must accept new work without resurrecting it.
]]
local afterRecovery = bravo.getRecord(PLAYER)
check(afterRecovery ~= nil, "the recovered server holds a resident record")
check(afterRecovery.InventoryByInstanceId.item_outage_guid ~= nil, "recovery kept the pre-outage item")
check(afterRecovery.InventoryByInstanceId.item_after_outage_guid ~= nil, "recovery kept the post-outage grant")
check(
	afterRecovery.SchemaVersion == contracts.CurrentSchemaVersion,
	"a record recovered through an outage must still be at the current schema"
)

--[[
	Task #20: the uncertainty guard is per key. One player's outage must not
	quarantine another player's writes, or a single unlucky read would spread
	into a server-wide persistence stall.
]]
local OTHER_PLAYER = 5151
local OTHER_KEY = "atlas-prod:player:5151:inventory"
local delta = newServer("job-delta-00000000")

check(delta.loadPlayer(OTHER_PLAYER, 1200).Accepted, "the second player loads while the store is healthy")
fakeStore.failReads = true
local contaminated = delta.loadPlayer(PLAYER, 1210)
check(not contaminated.Accepted, "the first player's read fails during the outage")
fakeStore.failReads = false

local otherReward = table.clone(reward)
otherReward.InstanceId = "item_other_player_guid"
otherReward.GrantId = "reward:run-750:Elite"
otherReward.RunId = "run-750"
local otherWrite = delta.applyReward(OTHER_PLAYER, otherReward, 1220)
check(otherWrite.Accepted, "an unrelated player's write must not be blocked by another player's failed read")
check(
	durable[OTHER_KEY].InventoryByInstanceId.item_other_player_guid ~= nil,
	"the unrelated player's write must reach their own durable record"
)
check(
	durable[INVENTORY_KEY].InventoryByInstanceId.item_other_player_guid == nil,
	"one player's write must never land in another player's record"
)
delta.releasePlayer(OTHER_PLAYER)
delta.destroy()

bravo.releasePlayer(PLAYER)
alpha.destroy()
bravo.destroy()
charlie.destroy()

print("Inventory read outage recovery fixture passed")
