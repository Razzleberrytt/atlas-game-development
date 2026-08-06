--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "VS-0109 persistence assertion failed", 2) end
end

local EQUIPMENT_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
	debugName = "PlayerInventoryContracts",
	environment = {
		script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } } } },
		require = function(token: unknown)
			assert(token == EQUIPMENT_TOKEN, "unexpected contracts dependency")
			return {
				SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
				RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
				SourceIds = { Elite = "Elite", Boss = "Boss" },
			}
		end,
	},
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Persistence = { PlayerInventoryContracts = CONTRACTS_TOKEN },
		Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN },
	},
}

local equipmentContracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
	RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
	SourceIds = { Elite = "Elite", Boss = "Boss" },
}

local serviceModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau"), {
	debugName = "PlayerInventoryPersistenceService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
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
function store:load(key: string)
	return deepCopy(self.data[key])
end
function store:save(key: string, value: any): boolean
	if self.failSaves then return false end
	self.data[key] = deepCopy(value)
	return true
end

local reward = {
	InstanceId = "run-123:Elite:1",
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
assert(loadResult.Accepted and loadResult.Migrated, "new players should receive and persist a migrated record")
assert(loadResult.Record.SchemaVersion == 1, "new records should use current schema")

local applied = service:applyReward(101, reward, 1001)
assert(applied.Accepted and applied.ReasonId == "RewardApplied", "reward should apply once")
assert(applied.Record.InventoryByInstanceId[reward.InstanceId] ~= nil, "reward should enter inventory")

local duplicate = service:applyReward(101, reward, 1002)
assert(not duplicate.Accepted and duplicate.ReasonId == "RewardAlreadyApplied", "duplicate reward must be idempotently rejected")

local equipped = service:equip(101, "Primary", reward.InstanceId, 1003)
assert(equipped.Accepted and equipped.Record.EquippedBySlot.Primary == reward.InstanceId, "owned item should equip")

local wrongSlot = service:equip(101, "Armor", reward.InstanceId, 1004)
assert(not wrongSlot.Accepted and wrongSlot.ReasonId == "SlotMismatch", "slot mismatch should fail")

local reloaded = serviceModule.new(store)
local reloadResult = reloaded:loadPlayer(101, 1100)
assert(reloadResult.Accepted and not reloadResult.Migrated, "saved current-schema records should load without migration")
assert(reloadResult.Record.EquippedBySlot.Primary == reward.InstanceId, "equipped state should persist")
assert(reloadResult.Record.AppliedRewardInstanceIds[reward.InstanceId] == true, "idempotency index should persist")

store.data["player:202:inventory"] = {
	PlayerId = 202,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
}
local legacy = serviceModule.new(store):loadPlayer(202, 1200)
assert(legacy.Accepted and legacy.Migrated, "legacy pre-schema record should migrate")

store.data["player:303:inventory"] = {
	SchemaVersion = 99,
	PlayerId = 303,
	InventoryByInstanceId = {},
	EquippedBySlot = {},
	AppliedRewardInstanceIds = {},
	UpdatedAtUnix = 0,
}
local unsupported = serviceModule.new(store):loadPlayer(303, 1200)
assert(not unsupported.Accepted and unsupported.ReasonId == "UnsupportedSchemaVersion", "future schemas must be rejected")

store.failSaves = true
local failed = service:applyReward(101, {
	InstanceId = "run-124:Boss:1",
	DefinitionId = "keeper-relic",
	DefinitionVersion = "1.0.0",
	DisplayName = "Keeper Relic",
	Slot = "Relic",
	Rarity = "Rare",
	Power = 18,
	SourceId = "Boss",
	RunId = "run-124",
	Seed = 78,
}, 1300)
assert(not failed.Accepted and failed.ReasonId == "SaveFailed", "failed writes must not mutate authoritative memory")
assert(service:getRecord(101).InventoryByInstanceId["run-124:Boss:1"] == nil, "failed reward save must roll back")
store.failSaves = false

service:destroy()
assert(service:getRecord(101) == nil, "destroyed service should disclose no cached record")

print("PlayerInventoryPersistenceService.test.luau passed")
