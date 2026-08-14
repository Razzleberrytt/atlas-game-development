--!strict

--[[
	Patch 0.7 disconnect, crash, and shutdown fault matrix.

	Every scenario here is a moment where a process stops between two steps that
	were supposed to happen together. The question each asks is the same one:
	after the interruption, does durable truth win over whatever a surviving
	process still believes?

	Faults are injected as one-shot counts rather than timers, so each run is
	deterministic and a fault that failed to fire fails the test.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

-- Shared durable store ------------------------------------------------------

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

--[[
	Batch 8/9 fault-injection store. Faults are armed as one-shot counts so every
	scenario is deterministic: no wall clock, no randomness, and a fault that did
	not fire is a test failure rather than a flake.
]]
local sharedStore = {
	data = {},
	failReads = 0,
	failCommits = 0,
	readCount = 0,
	commitCount = 0,
	mutateBetweenInvocations = nil :: any,
}

function sharedStore:update(key: string, transform: (any) -> any): (boolean, any)
	self.commitCount += 1
	if self.failCommits > 0 then
		self.failCommits -= 1
		return false, nil
	end
	--[[
		#83: UpdateAsync may re-run the transform when the key changes under
		contention, so a scenario can land a different record between invocations.
	]]
	if self.mutateBetweenInvocations ~= nil then
		transform(deepCopy(self.data[key]))
		self.data[key] = deepCopy(self.mutateBetweenInvocations)
		self.mutateBetweenInvocations = nil
	end
	local nextValue = transform(deepCopy(self.data[key]))
	self.data[key] = deepCopy(nextValue)
	return true, deepCopy(nextValue)
end

function sharedStore:read(key: string): any
	self.readCount += 1
	if self.failReads > 0 then
		self.failReads -= 1
		return storageResults.readFailed("injected read fault")
	end
	local value = deepCopy(self.data[key])
	if value == nil then
		return storageResults.missing()
	end
	return storageResults.found(value)
end

function sharedStore:write(key: string, value: any): any
	return self:commit(key, function()
		return value
	end)
end

function sharedStore:commit(key: string, transform: (any) -> any): any
	local ok, committed = self:update(key, transform)
	if not ok then
		return storageResults.writeFailed("injected commit fault")
	end
	return storageResults.committed(committed)
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

local SNAPSHOT_EQUIPMENT_TOKEN, SNAPSHOT_CONTRACTS_TOKEN = {}, {}
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

-- One live server -----------------------------------------------------------

local LEASE_SOURCE = fs.readFile("games/living-kingdoms/src/server/Systems/InventorySessionLeaseService.luau")
local PERSISTENCE_SOURCE =
	fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau")
local LIVE_SOURCE = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")

--[[
	InventoryLiveService builds its store, lease service, and persistence service
	at module scope, so one load is one server. Loading it twice with distinct
	JobIds over the same store is the whole point: the lease owner ids differ
	exactly as they would across two live servers.
]]
local function newServer(jobId: string): any
	local leaseService = luau.load(LEASE_SOURCE, {
		debugName = "InventorySessionLeaseService:" .. jobId,
		environment = {},
		injectGlobals = true,
	})()

	local CONTRACTS_TOKEN, DISMANTLE_TOKEN, STORAGE_RESULTS_TOKEN, DURABLE_MUTATION_TOKEN, MIGRATION_STEPS_TOKEN, RECOVERY_TOKEN =
		{}, {}, {}, {}, {}, {}
	local persistenceReplicatedStorage = {
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
	local persistenceService = luau.load(PERSISTENCE_SOURCE, {
		debugName = "PlayerInventoryPersistenceService:" .. jobId,
		environment = {
			game = {
				GetService = function(): any
					return persistenceReplicatedStorage
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
	local scriptParent = {
		RobloxInventoryDataStoreAdapter = token("RobloxInventoryDataStoreAdapter"),
		PlayerInventoryPersistenceService = token("PlayerInventoryPersistenceService"),
		InventorySessionLeaseService = token("InventorySessionLeaseService"),
	}
	local moduleByName: { [string]: any } = {
		EquipmentComparisonResolver = {
			compareAgainstEquipped = function(): any
				return table.freeze({ Accepted = true, ReasonId = "Compared", Comparison = {} })
			end,
		},
		InventoryDismantleResolver = dismantleResolver,
		PlayerInventorySnapshot = inventorySnapshot,
		EquipmentRewardConfig = { Definitions = {} },
		-- The adapter is the Studio/production storage decision. Substituting the
		-- shared store here is what makes two servers reach one durable record.
		RobloxInventoryDataStoreAdapter = {
			new = function(): any
				return sharedStore
			end,
		},
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
								return jobId .. "-guid-0123456789abcdef"
							end,
						}
					end
					error("unexpected service request: " .. name)
				end,
			},
			script = { Parent = scriptParent },
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

local PLAYER = 6161

local function gearReward(runId: string, instanceSuffix: string): any
	return {
		InstanceId = "item_" .. instanceSuffix .. "_guid",
		GrantId = string.format("reward:%s:Boss", runId),
		ContentSignature = "v1|keeper-relic|Rare|18|" .. runId,
		DefinitionId = "keeper-relic",
		DefinitionVersion = "1.0.0",
		DisplayName = "Keeper Relic",
		Slot = "Relic",
		Rarity = "Rare",
		Power = 18,
		Affixes = {},
		SourceId = "Boss",
		RunId = runId,
		Seed = 41,
	}
end

local function durableRecord(): any
	return sharedStore.data["player:6161:inventory"]
end

local alpha = newServer("job-alpha-00000000")
check(alpha.loadPlayer(PLAYER, 1000).Accepted, "the player loads on a healthy store")
check(alpha.applyReward(PLAYER, gearReward("run-base", "base"), 1010).Accepted, "a baseline item is earned")

-- #71: disconnect during a reward write ------------------------------------

sharedStore.failCommits = 1
local interruptedGrant = alpha.applyReward(PLAYER, gearReward("run-a", "a"), 1020)
check(not interruptedGrant.Accepted, "a reward write interrupted mid-flight must not report success")
check(sharedStore.failCommits == 0, "the injected commit fault must actually have fired")
check(durableRecord().InventoryByInstanceId.item_a_guid == nil, "an interrupted grant must not reach durable state")
check(
	alpha.getRecord(PLAYER).InventoryByInstanceId.item_a_guid == nil,
	"an interrupted grant must not reach memory either, or memory would outrun durable truth"
)

-- #76: the client never learned the outcome, so it retries the same grant.
local retried = alpha.applyReward(PLAYER, gearReward("run-a", "a"), 1030)
check(retried.Accepted, "a retry after an unknown outcome must succeed rather than stay stuck")
check(durableRecord().InventoryByInstanceId.item_a_guid ~= nil, "the retry must land durably")

-- A further retry, after the client still saw nothing, must not double-grant.
local doubleRetry = alpha.applyReward(PLAYER, gearReward("run-a", "a2"), 1040)
check(not doubleRetry.Accepted, "a retry of an already-applied grant must not apply twice")
check(doubleRetry.ReasonId == "RewardAlreadyApplied", "the second retry must read as a replay")

-- #72: disconnect during a dismantle write ----------------------------------

sharedStore.failCommits = 1
local interruptedDismantle = alpha.dismantleOwnedItem(PLAYER, PLAYER, "item_a_guid", "txn-fault-1", 1050)
check(not interruptedDismantle.Accepted, "a dismantle interrupted mid-write must not report success")
check(durableRecord().InventoryByInstanceId.item_a_guid ~= nil, "an interrupted dismantle must not destroy the item")
check(
	durableRecord().AppliedDismantleTransactions["txn-fault-1"] == nil,
	"an interrupted dismantle must record no transaction, or its retry would be answered as a replay"
)

local retriedDismantle = alpha.dismantleOwnedItem(PLAYER, PLAYER, "item_a_guid", "txn-fault-1", 1060)
check(retriedDismantle.Accepted, "the same dismantle transaction must succeed on retry")
check(durableRecord().InventoryByInstanceId.item_a_guid == nil, "the retried dismantle destroys the item")

-- #74/#75: crash before vs after the durable commit --------------------------

--[[
	The mutation order is durable-commit then memory. A crash before the commit
	leaves neither changed; a crash after it leaves durable ahead of a memory
	that no longer exists. Both must resolve to durable truth on the next load,
	which is the only thing a restarted process can trust.
]]
sharedStore.failCommits = 1
check(
	not alpha.applyReward(PLAYER, gearReward("run-crash", "crash"), 1070).Accepted,
	"a crash before the durable commit loses the mutation entirely"
)
check(durableRecord().InventoryByInstanceId.item_crash_guid == nil, "nothing is persisted by a pre-commit crash")

check(alpha.applyReward(PLAYER, gearReward("run-crash", "crash"), 1080).Accepted, "the post-commit case is set up")
-- The process dies here: durable holds the grant, this server's memory is gone.
alpha.destroy()

local restarted = newServer("job-restart-00000000")
check(restarted.loadPlayer(PLAYER, 1200).Accepted, "a restarted server loads the player")
check(
	restarted.getRecord(PLAYER).InventoryByInstanceId.item_crash_guid ~= nil,
	"work committed before the crash must survive it"
)
check(
	restarted.getRecord(PLAYER).InventoryByInstanceId.item_a_guid == nil,
	"work undone before the crash must stay undone"
)

-- #73: disconnect during a migration write ----------------------------------

sharedStore.data["player:6262:inventory"] = {
	SchemaVersion = 1,
	PlayerId = 6262,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	UpdatedAtUnix = 900,
}
sharedStore.failCommits = 1
local interruptedMigration = restarted.loadPlayer(6262, 1300)
check(not interruptedMigration.Accepted, "a migration interrupted mid-write must not report success")
check(sharedStore.data["player:6262:inventory"].SchemaVersion == 1, "the source record must survive the interruption")
check(restarted.getRecord(6262) == nil, "an interrupted migration must leave no resident record")

local retriedMigration = restarted.loadPlayer(6262, 1310)
check(retriedMigration.Accepted and retriedMigration.Migrated, "the migration succeeds on retry")
restarted.releasePlayer(6262)

-- #77: rapid server hop ------------------------------------------------------

restarted.releasePlayer(PLAYER)
local hopServers = {}
for index = 1, 5 do
	local server = newServer(string.format("job-hop-%08d", index))
	local loaded = server.loadPlayer(PLAYER, 1400 + index)
	check(loaded.Accepted, "hop " .. index .. " must acquire the lease and load")
	check(
		loaded.Record.InventoryByInstanceId.item_crash_guid ~= nil,
		"every hop must see the same durable truth, not a rebuilt blank record"
	)
	server.releasePlayer(PLAYER)
	table.insert(hopServers, server)
end

--[[
	A hop that released must not still believe it owns the player. Stale
	ownership across hops is how two servers end up writing one inventory.
]]
for index, server in hopServers do
	check(server.getRecord(PLAYER) == nil, "hop " .. index .. " must not retain the record after releasing")
	check(
		not server.applyReward(PLAYER, gearReward("run-stale", "stale" .. index), 1500).Accepted,
		"a released hop must not be able to write"
	)
end

-- #78/#79: shutdown, healthy and during a partial storage outage -------------

local shutdown = newServer("job-shutdown-000000")
for playerId = 7001, 7008 do
	check(shutdown.loadPlayer(playerId, 1600).Accepted, "resident player " .. playerId .. " loads")
end
local cleanShutdown = shutdown.destroy()
check(cleanShutdown.Requested == 8, "a healthy shutdown must account for every resident player")
check(cleanShutdown.Released == 8 and cleanShutdown.Unresolved == 0, "a healthy shutdown resolves every lease")

local outage = newServer("job-outage-0000000")
for playerId = 7101, 7104 do
	check(outage.loadPlayer(playerId, 1700).Accepted, "outage-case player " .. playerId .. " loads")
end

--[[
	Enough injected failures to exhaust one player's bounded retries, but not all
	of them: a partial outage must be reported as partial, not as total success
	and not as total failure.
]]
sharedStore.failCommits = 3
local partialShutdown = outage.destroy()
check(partialShutdown.Requested == 4, "a partial outage still accounts for every resident player")
check(partialShutdown.Unresolved >= 1, "a lease that could not be released must be reported")
check(partialShutdown.Released >= 1, "a partial outage must not abandon the leases that could still be released")
check(
	partialShutdown.Released + partialShutdown.Unresolved == partialShutdown.Requested,
	"every requested release must be accounted for as released or unresolved"
)
sharedStore.failCommits = 0

-- #80: durable truth wins over stale process memory --------------------------

local survivor = newServer("job-survivor-00000")
check(survivor.loadPlayer(PLAYER, 1800).Accepted, "the final server loads the player")
local finalRecord = survivor.getRecord(PLAYER)
check(finalRecord.InventoryByInstanceId.item_base_guid ~= nil, "the baseline item survived every fault")
check(finalRecord.InventoryByInstanceId.item_crash_guid ~= nil, "the committed grant survived every fault")
check(finalRecord.InventoryByInstanceId.item_a_guid == nil, "the dismantled item stayed destroyed")
check(finalRecord.InventoryByInstanceId.item_stale1_guid == nil, "no stale hop ever wrote")
check(
	finalRecord.AppliedRewardGrantIds["reward:run-a:Boss"] == true,
	"a destroyed reward's grant entry must persist so it cannot be granted again"
)
check(
	finalRecord.AppliedDismantleTransactions["txn-fault-1"] ~= nil,
	"the completed dismantle transaction must persist so its retry stays a replay"
)
check(finalRecord.SchemaVersion == contracts.CurrentSchemaVersion, "the surviving record is at the current schema")
survivor.releasePlayer(PLAYER)
survivor.destroy()
restarted.destroy()
for _, server in hopServers do
	server.destroy()
end

print("Inventory lifecycle fault matrix fixture passed")
