--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "inventory persistence assertion failed", 2) end
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
local replicatedStorage = { Shared = { Persistence = { PlayerInventoryContracts = CONTRACTS_TOKEN }, Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } } }
local serviceModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau"), {
	debugName = "PlayerInventoryPersistenceService",
	environment = {
		game = { GetService = function(_self: unknown, name: string) assert(name == "ReplicatedStorage"); return replicatedStorage end },
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then return contracts end
			if token == EQUIPMENT_TOKEN then return equipmentContracts end
			error("unexpected persistence dependency")
		end,
	},
	injectGlobals = true,
})()

local function deepCopy(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in value do copy[key] = deepCopy(child) end
	return copy
end

local store = { data = {}, failSaves = false }
function store:load(key: string) return deepCopy(self.data[key]) end
function store:save(key: string, value: any): boolean
	if self.failSaves then return false end
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
assert(loadResult.Record.SchemaVersion == 2, "new records should use schema two")

local applied = service:applyReward(101, reward, 1001)
assert(applied.Accepted, "reward should apply once")
assert(applied.Record.AppliedRewardGrantIds[reward.GrantId] == true, "grant id must be indexed")

local duplicateInstance = service:applyReward(101, reward, 1002)
assert(not duplicateInstance.Accepted and duplicateInstance.ReasonId == "RewardAlreadyApplied", "same instance must reject")

local replayedReward = table.clone(reward)
replayedReward.InstanceId = "item_different_guid"
local replayed = service:applyReward(101, replayedReward, 1003)
assert(not replayed.Accepted and replayed.ReasonId == "RewardAlreadyApplied", "same grant with a new GUID must reject")
assert(replayed.Record.InventoryByInstanceId[replayedReward.InstanceId] == nil, "replayed GUID must not enter inventory")

local equipped = service:equip(101, "Primary", reward.InstanceId, 1004)
assert(equipped.Accepted, "owned item should equip")

local reloaded = serviceModule.new(store)
local reloadResult = reloaded:loadPlayer(101, 1100)
assert(reloadResult.Accepted and not reloadResult.Migrated, "schema two should reload directly")
assert(reloadResult.Record.AppliedRewardGrantIds[reward.GrantId] == true, "grant index must survive reload")
local replayAfterReload = reloaded:applyReward(101, replayedReward, 1101)
assert(not replayAfterReload.Accepted and replayAfterReload.ReasonId == "RewardAlreadyApplied", "replay after reload must reject")

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

service:destroy()
assert(service:getRecord(101) == nil, "destroyed service should disclose no record")

print("PlayerInventoryPersistenceService.test.luau passed")
