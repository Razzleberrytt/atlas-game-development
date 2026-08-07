--!strict

--[[
	Blueprint v2.0 queue item 3 — dismantle transaction fixture (v1.9 Ticket 143).

	Covers the required request matrix: locked (no session lease), equipped,
	unknown, foreign, valid, replayed, and rate-limited.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "dismantle assertion failed", 2)
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
				error("unexpected dismantle resolver dependency")
			end,
		},
		injectGlobals = true,
	})()

local OWNER_ID = 4242
local OTHER_ID = 7777

local function reward(instanceId: string, slot: string, power: number): any
	return {
		InstanceId = instanceId,
		GrantId = "reward:run-dismantle:" .. instanceId,
		ContentSignature = "v1|" .. instanceId,
		DefinitionId = "frontier-rifle",
		DefinitionVersion = "1.0.0",
		DisplayName = "Frontier Rifle",
		Slot = slot,
		Rarity = "Rare",
		Power = power,
		SourceId = "Elite",
		RunId = "run-dismantle",
		Seed = 99,
	}
end

local function record(playerId: number): any
	return {
		SchemaVersion = inventoryContracts.CurrentSchemaVersion,
		PlayerId = playerId,
		InventoryByInstanceId = {
			["item_spare"] = reward("item_spare", "Primary", 11),
			["item_worn"] = reward("item_worn", "Primary", 9),
		},
		EquippedBySlot = { Primary = "item_worn" },
		AppliedRewardInstanceIds = { ["item_spare"] = true, ["item_worn"] = true },
		AppliedRewardGrantIds = { ["reward:run-dismantle:item_spare"] = true },
		UpdatedAtUnix = 1_700_000_000,
	}
end

local function state(overrides: any?): any
	local base = {
		Record = record(OWNER_ID),
		HasSessionLease = true,
		AppliedTransactions = {},
		RecentRequestTimestamps = {},
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function request(overrides: any?): any
	local base = {
		RequesterId = OWNER_ID,
		OwnerId = OWNER_ID,
		InstanceId = "item_spare",
		TransactionId = "txn-0001",
		NowUnix = 1_700_000_100,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

-- Valid: the unequipped item is destroyed exactly once.
local valid = Resolver.resolve(request(), state())
assert(valid.Accepted == true and valid.ReasonId == "ItemDismantled", "a valid dismantle is accepted")
assert(valid.Replayed == false, "a first application is not a replay")
assert(valid.Outcome.InstanceId == "item_spare", "the destroyed item is named")
assert(valid.Outcome.SalvagedPower == 11 and valid.Outcome.SalvagedRarity == "Rare", "salvage facts are reported")
assert(valid.Outcome.SalvagedDefinitionId == "frontier-rifle", "the definition is reported for later pricing")
assert(valid.NextRecord.InventoryByInstanceId["item_spare"] == nil, "the item is removed")
assert(valid.NextRecord.InventoryByInstanceId["item_worn"] ~= nil, "other items are untouched")
assert(valid.NextRecord.EquippedBySlot.Primary == "item_worn", "the equipped item stays equipped")
assert(valid.NextRecord.UpdatedAtUnix == 1_700_000_100, "the record version marker advances")
assert(table.isfrozen(valid.NextRecord :: any), "the next record is frozen")

-- Grant replay protection must survive a dismantle, or re-running the original
-- grant transaction would recreate the destroyed item.
assert(valid.NextRecord.AppliedRewardInstanceIds["item_spare"] == true, "the instance ledger is preserved")
assert(
	valid.NextRecord.AppliedRewardGrantIds["reward:run-dismantle:item_spare"] == true,
	"the grant ledger is preserved"
)

-- The input record is never mutated.
local untouched = state()
Resolver.resolve(request(), untouched)
assert(untouched.Record.InventoryByInstanceId["item_spare"] ~= nil, "the resolver does not mutate its input")

-- Replayed: the same transaction returns the original outcome and is accepted,
-- so a client that retried after a dropped response is not told the item remains.
local replayed = Resolver.resolve(
	request(),
	state({ AppliedTransactions = { ["txn-0001"] = valid.Outcome }, Record = valid.NextRecord })
)
assert(replayed.Accepted == true, "a replayed transaction is accepted, not rejected")
assert(replayed.ReasonId == "TransactionAlreadyApplied", "a replay is reported as such")
assert(replayed.Replayed == true and replayed.Outcome.InstanceId == "item_spare", "the original outcome is returned")
assert(replayed.NextRecord == nil, "a replay writes nothing")

-- A replay is answered even once the lease has lapsed.
local replayedNoLease = Resolver.resolve(
	request(),
	state({ AppliedTransactions = { ["txn-0001"] = valid.Outcome }, HasSessionLease = false })
)
assert(replayedNoLease.Accepted == true, "a replay does not require a live lease")

-- A distinct transaction naming the already-destroyed item is rejected.
local secondAttempt = Resolver.resolve(request({ TransactionId = "txn-0002" }), state({ Record = valid.NextRecord }))
assert(
	secondAttempt.Accepted == false and secondAttempt.ReasonId == "ItemNotOwned",
	"an item cannot be destroyed twice"
)

-- Equipped items are protected.
local equipped = Resolver.resolve(request({ InstanceId = "item_worn" }), state())
assert(equipped.Accepted == false and equipped.ReasonId == "ItemEquipped", "an equipped item cannot be dismantled")
assert(equipped.NextRecord == nil, "a rejected dismantle writes nothing")

-- Unknown and foreign instance ids are indistinguishable rejections.
local unknown = Resolver.resolve(request({ InstanceId = "item_nonexistent" }), state())
assert(unknown.Accepted == false and unknown.ReasonId == "ItemNotOwned", "an unknown item is rejected")
local foreign = Resolver.resolve(request({ InstanceId = "item_someone_elses" }), state())
assert(foreign.ReasonId == unknown.ReasonId, "a foreign item is indistinguishable from an unknown one")

-- Cross-player requests are rejected before the record is read.
local crossPlayer = Resolver.resolve(request({ RequesterId = OTHER_ID }), state())
assert(crossPlayer.Accepted == false, "a non-owner cannot dismantle")
assert(crossPlayer.ReasonId == "CrossPlayerInventoryAccess", "cross-player access has a distinct reason")

-- A record loaded under another identity fails closed.
local mismatched = Resolver.resolve(request(), state({ Record = record(OTHER_ID) }))
assert(mismatched.Accepted == false and mismatched.ReasonId == "InventoryOwnerMismatch", "ownership is verified")

-- Locked: without the session lease another server may own this profile.
local noLease = Resolver.resolve(request(), state({ HasSessionLease = false }))
assert(noLease.Accepted == false and noLease.ReasonId == "SessionLeaseRequired", "a destructive write needs the lease")

-- Rate limited: a burst beyond the bound is refused.
local burst = {}
for index = 1, Resolver.MaximumRequestsPerWindow do
	burst[index] = 1_700_000_099
end
local limited = Resolver.resolve(request(), state({ RecentRequestTimestamps = burst }))
assert(limited.Accepted == false and limited.ReasonId == "RateLimited", "a request burst is bounded")

-- Timestamps outside the window do not count toward the bound.
local stale = {}
for index = 1, Resolver.MaximumRequestsPerWindow do
	stale[index] = 1_700_000_100 - Resolver.RateWindowSeconds - 1
end
local afterWindow = Resolver.resolve(request(), state({ RecentRequestTimestamps = stale }))
assert(afterWindow.Accepted == true, "the rate window expires")

-- An unloaded inventory and a stale clock are rejected.
-- Built directly: a nil override cannot clear a field through the helper.
local unloadedState = state()
unloadedState.Record = nil
local unloaded = Resolver.resolve(request(), unloadedState)
assert(unloaded.Accepted == false and unloaded.ReasonId == "InventoryNotLoaded", "an unloaded inventory is rejected")
local backwards = Resolver.resolve(request({ NowUnix = 1_699_999_999 }), state())
assert(backwards.Accepted == false and backwards.ReasonId == "StaleDismantleRequest", "a stale clock is rejected")

-- Malformed requests are rejected and destroy nothing.
local malformed: { any } = {
	request({ InstanceId = "" }),
	request({ TransactionId = "" }),
	request({ InstanceId = 7 }),
	request({ NowUnix = -1 }),
	request({ NowUnix = "now" }),
}
assert(#malformed == 5, "every malformed request case must run")
for _, invalid in malformed do
	local bad = Resolver.resolve(invalid, state())
	assert(bad.Accepted == false, "a malformed request is rejected")
	assert(bad.ReasonId == "InvalidDismantleRequest", "malformed requests share one reason")
	assert(bad.NextRecord == nil, "a rejected request writes nothing")
end

local badIdentity = Resolver.resolve(request({ RequesterId = 0, OwnerId = 0 }), state())
assert(badIdentity.Accepted == false and badIdentity.ReasonId == "InvalidPlayerIdentity", "identities are validated")

print("InventoryDismantleResolver fixture passed")
