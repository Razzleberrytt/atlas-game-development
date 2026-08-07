--!strict

--[[
	Blueprint v2.0 queue item 1 — owner-only inventory snapshot fixture.

	Proves the disclosure boundary: only the owner is served, server-only
	bookkeeping never leaves, ordering is deterministic, and a rejected read
	discloses nothing.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "inventory snapshot assertion failed", 2)
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
				assert(token == EQUIPMENT_TOKEN, "unexpected PlayerInventoryContracts dependency")
				return equipmentContracts
			end,
		},
		injectGlobals = true,
	})()

local SNAPSHOT_CONTRACTS_TOKEN = {}
local SNAPSHOT_EQUIPMENT_TOKEN = {}
local Snapshot = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventorySnapshot.luau"), {
	debugName = "PlayerInventorySnapshot",
	environment = {
		script = {
			Parent = {
				PlayerInventoryContracts = SNAPSHOT_CONTRACTS_TOKEN,
				Parent = { Equipment = { EquipmentRewardContracts = SNAPSHOT_EQUIPMENT_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == SNAPSHOT_CONTRACTS_TOKEN then
				return inventoryContracts
			end
			if token == SNAPSHOT_EQUIPMENT_TOKEN then
				return equipmentContracts
			end
			error("unexpected PlayerInventorySnapshot dependency")
		end,
	},
	injectGlobals = true,
})()

local OWNER_ID = 5150
local OTHER_ID = 9001

local function reward(instanceId: string, slot: string, power: number): any
	return {
		InstanceId = instanceId,
		GrantId = "reward:run-owner-001:" .. instanceId,
		ContentSignature = "v1|" .. instanceId,
		DefinitionId = "def-" .. instanceId,
		DefinitionVersion = "1.0.0",
		DisplayName = "Item " .. instanceId,
		Slot = slot,
		Rarity = "Rare",
		Power = power,
		SourceId = "Elite",
		RunId = "run-owner-001",
		Seed = 4242,
	}
end

local function record(playerId: number): any
	return {
		SchemaVersion = inventoryContracts.CurrentSchemaVersion,
		PlayerId = playerId,
		InventoryByInstanceId = {
			["item_ccc"] = reward("item_ccc", "Primary", 30),
			["item_aaa"] = reward("item_aaa", "Primary", 12),
			["item_bbb"] = reward("item_bbb", "Armor", 21),
		},
		EquippedBySlot = { Primary = "item_aaa" },
		AppliedRewardInstanceIds = { ["item_aaa"] = true, ["item_bbb"] = true, ["item_ccc"] = true },
		AppliedRewardGrantIds = { ["reward:run-owner-001:item_aaa"] = true },
		UpdatedAtUnix = 1_700_000_000,
	}
end

-- The owner is served their own inventory.
local owned = Snapshot.forOwner(OWNER_ID, OWNER_ID, record(OWNER_ID))
assert(owned.Accepted == true and owned.ReasonId == "InventoryDisclosed", "the owner must be served")
local snapshot = owned.Snapshot
assert(snapshot.OwnerId == OWNER_ID, "the snapshot names its owner")
assert(snapshot.ItemCount == 3 and #snapshot.Items == 3, "every owned item is disclosed")
assert(snapshot.UpdatedAtUnix == 1_700_000_000, "the snapshot carries the record version marker")

-- Ordering is deterministic so snapshots can be compared and diffed.
assert(
	snapshot.Items[1].InstanceId == "item_aaa"
		and snapshot.Items[2].InstanceId == "item_bbb"
		and snapshot.Items[3].InstanceId == "item_ccc",
	"items must be disclosed in a stable instance-id order"
)

-- Equipped state is derived from the record, never from the item itself.
assert(snapshot.Items[1].Equipped == true, "the equipped primary is marked equipped")
assert(snapshot.Items[3].Equipped == false, "an unequipped item in the same slot is not marked equipped")
assert(snapshot.EquippedBySlot.Primary == "item_aaa", "the equipped map is disclosed")

-- Server-only bookkeeping must never reach a client.
assert(rawget(snapshot :: any, "AppliedRewardInstanceIds") == nil, "the instance ledger must not be disclosed")
assert(rawget(snapshot :: any, "AppliedRewardGrantIds") == nil, "the grant ledger must not be disclosed")
for _, item in snapshot.Items do
	assert(rawget(item :: any, "GrantId") == nil, "grant ids are idempotency keys and must not be disclosed")
	assert(rawget(item :: any, "RunId") == nil, "run provenance must not be disclosed")
	assert(rawget(item :: any, "Seed") == nil, "reward seeds must not be disclosed")
end

-- The disclosed structure is frozen, so a consumer cannot mutate shared state.
assert(table.isfrozen(snapshot :: any), "the snapshot must be frozen")
assert(table.isfrozen(snapshot.Items :: any), "the item list must be frozen")
assert(table.isfrozen(snapshot.Items[1] :: any), "each item must be frozen")
assert(table.isfrozen(snapshot.EquippedBySlot :: any), "the equipped map must be frozen")

-- Cross-player reads are rejected and disclose nothing at all.
local crossPlayer = Snapshot.forOwner(OTHER_ID, OWNER_ID, record(OWNER_ID))
assert(crossPlayer.Accepted == false, "a non-owner must be rejected")
assert(crossPlayer.ReasonId == "CrossPlayerInventoryAccess", "cross-player reads have a distinct reason")
assert(crossPlayer.Snapshot == nil, "a rejected read discloses no snapshot")

-- A record loaded under the wrong identity fails closed rather than leaking.
local mismatched = Snapshot.forOwner(OWNER_ID, OWNER_ID, record(OTHER_ID))
assert(mismatched.Accepted == false and mismatched.ReasonId == "InventoryOwnerMismatch", "ownership must be verified")
assert(mismatched.Snapshot == nil, "a mismatched record discloses no snapshot")

-- An unloaded inventory is a rejection, not an empty snapshot that a client
-- could mistake for a wiped inventory.
local unloaded = Snapshot.forOwner(OWNER_ID, OWNER_ID, nil)
assert(unloaded.Accepted == false and unloaded.ReasonId == "InventoryNotLoaded", "an unloaded inventory is rejected")
assert(unloaded.Snapshot == nil, "an unloaded inventory discloses no snapshot")

-- Malformed identities are rejected before any record is touched.
for _, invalid in { 0, -1, 1.5, "5150" } do
	local badRequester = Snapshot.forOwner(invalid :: any, OWNER_ID, record(OWNER_ID))
	assert(badRequester.Accepted == false, "an invalid requester identity must be rejected")
	assert(badRequester.ReasonId == "InvalidPlayerIdentity", "invalid identities have a distinct reason")
	local badOwner = Snapshot.forOwner(OWNER_ID, invalid :: any, record(OWNER_ID))
	assert(badOwner.Accepted == false and badOwner.ReasonId == "InvalidPlayerIdentity", "invalid owners are rejected")
end

-- An empty inventory is a valid disclosure, distinct from a rejection.
local emptyRecord = record(OWNER_ID)
emptyRecord.InventoryByInstanceId = {}
emptyRecord.EquippedBySlot = {}
local empty = Snapshot.forOwner(OWNER_ID, OWNER_ID, emptyRecord)
assert(empty.Accepted == true and empty.Snapshot.ItemCount == 0, "an empty inventory is disclosed as empty")

print("PlayerInventorySnapshot fixture passed")
