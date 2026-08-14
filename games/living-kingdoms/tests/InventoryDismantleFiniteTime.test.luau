--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "dismantle finite-time assertion failed", 2)
	end
end

local equipmentContracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"),
	{ debugName = "EquipmentRewardContracts", injectGlobals = true }
)()

local EQUIPMENT_TOKEN = {}
local inventoryContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
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
local RESOLVER_EQUIPMENT_TOKEN = {}
local Resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryDismantleResolver.luau"), {
		debugName = "InventoryDismantleResolver",
		environment = {
			script = {
				Parent = {
					PlayerInventoryContracts = CONTRACTS_TOKEN,
					Parent = { Equipment = { EquipmentRewardContracts = RESOLVER_EQUIPMENT_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == CONTRACTS_TOKEN then
					return inventoryContracts
				end
				if token == RESOLVER_EQUIPMENT_TOKEN then
					return equipmentContracts
				end
				error("unexpected resolver dependency")
			end,
		},
		injectGlobals = true,
	})()

local reward = table.freeze({
	InstanceId = "item_spare",
	GrantId = "reward:finite-time:item_spare",
	ContentSignature = "v1|item_spare",
	DefinitionId = "frontier-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Frontier Rifle",
	Slot = "Primary",
	Rarity = "Rare",
	Power = 11,
	SourceId = "Elite",
	RunId = "run-finite-time",
	Seed = 99,
})

local record = {
	SchemaVersion = inventoryContracts.CurrentSchemaVersion,
	PlayerId = 4242,
	InventoryByInstanceId = { item_spare = reward },
	EquippedBySlot = {},
	AppliedRewardInstanceIds = { item_spare = true },
	AppliedRewardGrantIds = { [reward.GrantId] = true },
	AppliedDismantleTransactions = {},
	AppliedRewardContentSignatures = { [reward.GrantId] = reward.ContentSignature },
	UpdatedAtUnix = 1_700_000_000,
}

local valid = Resolver.resolve({
	RequesterId = 4242,
	OwnerId = 4242,
	InstanceId = "item_spare",
	TransactionId = "txn-signature-ledger",
	NowUnix = 1_700_000_100,
}, {
	Record = record,
	HasSessionLease = true,
	AppliedTransactions = {},
	RecentRequestTimestamps = {},
})
assert(valid.Accepted and valid.NextRecord ~= nil, "finite dismantle should produce a next record")
assert(
	valid.NextRecord.AppliedRewardContentSignatures[reward.GrantId] == reward.ContentSignature,
	"dismantle must preserve reward content signatures"
)

for _, invalidNow in { 0 / 0, math.huge, -math.huge } do
	local outcome = Resolver.resolve({
		RequesterId = 4242,
		OwnerId = 4242,
		InstanceId = "item_spare",
		TransactionId = "txn-finite-time",
		NowUnix = invalidNow,
	}, {
		Record = record,
		HasSessionLease = true,
		AppliedTransactions = {},
		RecentRequestTimestamps = {},
	})
	assert(not outcome.Accepted, "non-finite dismantle time must be rejected")
	assert(outcome.ReasonId == "InvalidDismantleRequest", "non-finite time must use the invalid-request reason")
	assert(outcome.NextRecord == nil, "non-finite time must not produce a record to persist")
end

print("InventoryDismantleFiniteTime.test.luau passed")
