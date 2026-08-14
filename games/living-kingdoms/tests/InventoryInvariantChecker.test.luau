--!strict

--[[
	Patch 0.7 #89. Every guard in the persistence layer prevents one bad
	transition. This asks a different question: given a record that already
	exists, is it self-consistent right now? That is what catches damage no
	guard covered -- a partial write, a hand-edited key, a bug in a future
	migration step.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local checker = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryInvariantChecker.luau"), {
	debugName = "InventoryInvariantChecker",
	injectGlobals = true,
})()

local function item(instanceId: string, slot: string, grantId: string): any
	return {
		InstanceId = instanceId,
		GrantId = grantId,
		ContentSignature = "v1|" .. instanceId,
		DefinitionId = "keeper-relic",
		Slot = slot,
		Rarity = "Rare",
		Power = 18,
		SourceId = "Boss",
	}
end

local function healthyRecord(): any
	return {
		SchemaVersion = 4,
		PlayerId = 1,
		InventoryByInstanceId = { item_a = item("item_a", "Relic", "reward:run-1:Boss") },
		EquippedBySlot = { Relic = "item_a" },
		AppliedRewardInstanceIds = { item_a = true },
		AppliedRewardGrantIds = { ["reward:run-1:Boss"] = true },
		AppliedRewardContentSignatures = { ["reward:run-1:Boss"] = "v1|item_a" },
		AppliedDismantleTransactions = {},
		UpdatedAtUnix = 100,
	}
end

local function codesOf(report: any): { [string]: boolean }
	local codes = {}
	for _, entry in report.Violations do
		codes[entry.Code] = true
	end
	return codes
end

local healthy = checker.check(healthyRecord())
check(healthy.Healthy, "a well-formed record must report healthy")
check(#healthy.Violations == 0, "a healthy record has no violations")
check(healthy.ItemCount == 1 and healthy.EquippedCount == 1, "the report must count what it examined")

check(not checker.check(nil).Healthy, "a missing record is not healthy")
check(not checker.check("record").Healthy, "a non-table record is not healthy")

local missingLedger = healthyRecord()
missingLedger.AppliedRewardGrantIds = nil
check(codesOf(checker.check(missingLedger)).MissingLedger, "a missing ledger must be reported")

--[[
	An owned item whose grant is not in the ledger could be granted a second
	time, because the ledger is the only thing that refuses a repeat.
]]
local orphanGrant = healthyRecord()
orphanGrant.AppliedRewardGrantIds = {}
check(codesOf(checker.check(orphanGrant)).OwnedItemMissingGrant, "an owned item without its grant must be reported")

local orphanInstance = healthyRecord()
orphanInstance.AppliedRewardInstanceIds = {}
check(
	codesOf(checker.check(orphanInstance)).OwnedItemMissingInstanceLedger,
	"an owned item missing from the instance ledger must be reported"
)

-- Ownership drift: the binding outlived the item.
local drifted = healthyRecord()
drifted.InventoryByInstanceId = {}
drifted.AppliedRewardInstanceIds = {}
local driftedCodes = codesOf(checker.check(drifted))
check(driftedCodes.EquippedItemNotOwned, "an equipped slot naming an unowned item must be reported")

local wrongSlot = healthyRecord()
wrongSlot.EquippedBySlot = { Primary = "item_a" }
check(codesOf(checker.check(wrongSlot)).EquippedSlotMismatch, "an item equipped into the wrong slot must be reported")

local keyMismatch = healthyRecord()
keyMismatch.InventoryByInstanceId = { item_a = item("item_b", "Relic", "reward:run-1:Boss") }
check(codesOf(checker.check(keyMismatch)).ItemKeyMismatch, "an item stored under the wrong key must be reported")

local signatureOrphan = healthyRecord()
signatureOrphan.AppliedRewardContentSignatures = { ["reward:nobody:Boss"] = "v1|nobody" }
check(codesOf(checker.check(signatureOrphan)).SignatureWithoutGrant, "a signature without its grant must be reported")

--[[
	A dismantle outcome must stay answerable after the item is gone, so an
	incomplete outcome is damage even though nothing references it.
]]
local badOutcome = healthyRecord()
badOutcome.AppliedDismantleTransactions = { ["txn-a"] = { InstanceId = 7 } }
check(codesOf(checker.check(badOutcome)).IncompleteDismantleOutcome, "an unanswerable dismantle outcome is damage")

--[[
	The checker is a pure reader. Finding a broken record is not licence to
	repair it: a repair that guessed would destroy the evidence needed to do the
	repair properly.
]]
local inspected = healthyRecord()
local before = inspected.EquippedBySlot.Relic
checker.check(inspected)
check(inspected.EquippedBySlot.Relic == before, "the checker must not mutate the record it inspects")
check(inspected.AppliedRewardGrantIds["reward:run-1:Boss"] == true, "the checker must not touch the ledgers")

print("InventoryInvariantChecker: duplicate items, missing ledgers, invalid equips, and ownership drift")
