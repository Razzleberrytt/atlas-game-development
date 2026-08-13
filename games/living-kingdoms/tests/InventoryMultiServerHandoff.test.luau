--!strict

--[[
	Patch 0.7 multi-server handoff harness.

	Studio cannot answer any of this. RobloxInventoryDataStoreAdapter deliberately
	swaps in a volatile in-memory store when RunService:IsStudio() is true (pinned
	by StudioInventoryPersistenceIsolation), so a Studio session has exactly one
	server and a store nobody else can reach -- leases never contend there.

	So this loads the real InventoryLiveService twice over one shared store. Each
	load is a separate server with its own JobId, its own lease owner id, and its
	own resident records, exactly as two live servers would be. Everything below
	runs against the production code path on both sides.
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

local sharedStore = { data = {}, updateCount = 0, readCount = 0 }
function sharedStore:update(key: string, transform: (any) -> any): (boolean, any)
	self.updateCount += 1
	local nextValue = transform(deepCopy(self.data[key]))
	self.data[key] = deepCopy(nextValue)
	return true, deepCopy(nextValue)
end
function sharedStore:read(key: string): any
	self.readCount += 1
	local value = deepCopy(self.data[key])
	if value == nil then
		return storageResults.missing()
	end
	return storageResults.found(value)
end
function sharedStore:write(key: string, value: any): any
	local _, committed = self:update(key, function()
		return value
	end)
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

	local CONTRACTS_TOKEN, DISMANTLE_TOKEN, STORAGE_RESULTS_TOKEN = {}, {}, {}
	local persistenceReplicatedStorage = {
		Shared = {
			Persistence = {
				PlayerInventoryContracts = CONTRACTS_TOKEN,
				InventoryDismantleResolver = DISMANTLE_TOKEN,
				StorageResultContracts = STORAGE_RESULTS_TOKEN,
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
				elseif token == STORAGE_RESULTS_TOKEN then
					return storageResults
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

local alpha = newServer("job-alpha-00000000")
local bravo = newServer("job-bravo-00000000")

local PLAYER = 4242
--[[
	The expiry boundary below is the safety property, so the duration has to match
	the one the live service actually configures. Read it back rather than
	trusting a copy: if the service changes it, this fails here with a reason
	instead of failing cryptically at a boundary assertion.
]]
local LEASE_SECONDS = 90
check(
	string.find(
		LIVE_SOURCE,
		string.format("InventorySessionLeaseService.new(store, leaseOwnerId, %d)", LEASE_SECONDS),
		1,
		true
	) ~= nil,
	string.format(
		"this fixture assumes a %d second lease; InventoryLiveService no longer configures one",
		LEASE_SECONDS
	)
)

local reward = {
	InstanceId = "item_handoff_guid",
	GrantId = "reward:run-900:Elite",
	ContentSignature = "v1|warden-rifle|1.0.0|Uncommon|12|Elite|900",
	DefinitionId = "warden-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Warden Rifle",
	Slot = "Primary",
	Rarity = "Uncommon",
	Power = 12,
	Affixes = {},
	SourceId = "Elite",
	RunId = "run-900",
	Seed = 900,
}

-- 1. Alpha takes the player and earns an item ------------------------------

local alphaLoad = alpha.loadPlayer(PLAYER, 1000)
check(alphaLoad.Accepted, "the first server must load the player")

local granted = alpha.applyReward(PLAYER, reward, 1010)
check(granted.Accepted and granted.ReasonId == "RewardApplied", "the lease holder must be able to grant a reward")

-- 2. Bravo cannot touch a player Alpha holds --------------------------------

local bravoBlocked = bravo.loadPlayer(PLAYER, 1020)
check(not bravoBlocked.Accepted, "a second server must not load a player under a live lease")
check(bravoBlocked.ReasonId == "LeaseHeldByAnotherServer", "the refusal must name the held lease")

local bravoReward = table.clone(reward)
bravoReward.InstanceId = "item_stolen_guid"
bravoReward.GrantId = "reward:run-901:Elite"
bravoReward.RunId = "run-901"
local bravoMutation = bravo.applyReward(PLAYER, bravoReward, 1030)
check(not bravoMutation.Accepted, "a server without the lease must not mutate")
check(bravoMutation.ReasonId == "SessionLeaseRequired", "the refusal must name the missing lease")
check(
	sharedStore.data["player:4242:inventory"].InventoryByInstanceId.item_stolen_guid == nil,
	"a refused mutation must not reach the durable record"
)

-- 3. Clean handoff: the player leaves Alpha and joins Bravo ------------------

alpha.releasePlayer(PLAYER)
check(alpha.getRecord(PLAYER) == nil, "releasing must drop the resident record on the losing server")

local bravoLoad = bravo.loadPlayer(PLAYER, 1040)
check(bravoLoad.Accepted, "the next server must load the player once the lease is free")
check(
	bravoLoad.Record.InventoryByInstanceId.item_handoff_guid ~= nil,
	"the item earned on the first server must survive the handoff"
)

local bravoSnapshot = bravo.readOwnedSnapshot(PLAYER, PLAYER)
check(bravoSnapshot.Accepted, "the new server must disclose the owner's inventory")
check(bravoSnapshot.Snapshot.ItemCount == 1, "the disclosed inventory must carry the earned item")

-- 4. The stale server must not keep writing ---------------------------------

local staleMutation = alpha.applyReward(PLAYER, bravoReward, 1050)
check(not staleMutation.Accepted, "the server that released the player must not mutate afterwards")
check(staleMutation.ReasonId == "SessionLeaseRequired", "a released server holds no lease")

-- 5. Crash handoff: Alpha takes the player back, then dies without releasing --

bravo.releasePlayer(PLAYER)
check(alpha.loadPlayer(PLAYER, 1100).Accepted, "the player returns to the first server")

local crashedReward = table.clone(reward)
crashedReward.InstanceId = "item_crash_guid"
crashedReward.GrantId = "reward:run-902:Elite"
crashedReward.RunId = "run-902"
check(alpha.applyReward(PLAYER, crashedReward, 1110).Accepted, "the returning server may grant while leased")

-- Alpha is gone. It never released, so the lease can only expire.
local beforeExpiry = 1100 + LEASE_SECONDS - 1
check(not bravo.loadPlayer(PLAYER, beforeExpiry).Accepted, "a crashed server's lease must hold until it expires")

local atExpiry = 1100 + LEASE_SECONDS
local recovered = bravo.loadPlayer(PLAYER, atExpiry)
check(recovered.Accepted, "an expired lease must be recoverable by the next server")
check(
	recovered.Record.InventoryByInstanceId.item_crash_guid ~= nil,
	"work committed before the crash must survive recovery"
)

--[[
	The safety property the whole design rests on: the windows never overlap. The
	crashed server's cached lease expires at exactly the moment the next server
	may take it, so there is no instant where both believe they may write.
]]
local staleAfterExpiry = alpha.applyReward(PLAYER, bravoReward, atExpiry)
check(not staleAfterExpiry.Accepted, "a crashed server must not mutate once its lease has expired")
check(staleAfterExpiry.ReasonId == "SessionLeaseRequired", "the expired holder must be refused for want of a lease")

local alphaRenew = alpha.renewPlayer(PLAYER, atExpiry + 1)
check(not alphaRenew.Accepted, "a server that lost the lease must fail its renewal")
check(alphaRenew.ReasonId == "LeaseLost", "losing the key to another server must be reported as a loss")

-- 6. The recovered holder still owns the record -----------------------------

local finalReward = table.clone(reward)
finalReward.InstanceId = "item_final_guid"
finalReward.GrantId = "reward:run-903:Elite"
finalReward.RunId = "run-903"
check(bravo.applyReward(PLAYER, finalReward, atExpiry + 2).Accepted, "the recovered holder may grant")

local durable = sharedStore.data["player:4242:inventory"]
check(durable.InventoryByInstanceId.item_handoff_guid ~= nil, "durable record keeps the first server's item")
check(durable.InventoryByInstanceId.item_crash_guid ~= nil, "durable record keeps the pre-crash item")
check(durable.InventoryByInstanceId.item_final_guid ~= nil, "durable record keeps the recovered server's item")
check(durable.InventoryByInstanceId.item_stolen_guid == nil, "no unleased write ever reached the durable record")

bravo.releasePlayer(PLAYER)
alpha.destroy()
bravo.destroy()

print("Inventory multi-server handoff fixture passed")
