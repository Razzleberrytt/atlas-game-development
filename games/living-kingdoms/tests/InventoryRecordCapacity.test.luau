--!strict

--[[
	Patch 0.7 durable record size budget.

	A DataStore value has a hard ceiling, and a record that crosses it does not
	save a truncated version -- it does not save at all. Every later mutation
	fails the same way while the player keeps playing, so the loss surfaces far
	from its cause. This locks the estimator's direction of error and the
	below/at/above behaviour of the budget.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local capacity =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryCapacityContracts.luau"), {
		debugName = "InventoryCapacityContracts",
		injectGlobals = true,
	})()

-- The budget must leave real headroom under the platform ceiling.
check(
	capacity.SafeRecordByteLimit < capacity.DataStoreValueByteLimit,
	"the safe budget must sit under the platform limit, not on it"
)
check(
	capacity.WarningRecordByteLimit < capacity.SafeRecordByteLimit,
	"the warning threshold must come before the refusal threshold"
)

--[[
	The estimator is a bound, not an encoder. Being a little over is harmless;
	being under is the only outcome that matters, so it must never report fewer
	bytes than the payload's own raw content.
]]
local payload = { Marker = string.rep("x", 1_000) }
check(capacity.estimateBytes(payload) > 1_000, "the estimate must exceed the raw string it contains")

check(capacity.estimateBytes(nil) == 0, "nothing costs nothing")
check(capacity.estimateBytes({}) > 0, "even an empty table costs its own punctuation")
check(capacity.estimateBytes({ a = 1, b = 2 }) > capacity.estimateBytes({ a = 1 }), "more entries must estimate larger")

-- Deterministic: the same payload must always price the same.
check(capacity.estimateBytes(payload) == capacity.estimateBytes(payload), "the estimator must be deterministic")

--[[
	A cyclic or absurdly deep structure must fail closed rather than recurse
	forever. The depth guard prices it as expensive, which refuses the write.
]]
local deep: any = {}
local cursor = deep
for _ = 1, 64 do
	cursor.Next = {}
	cursor = cursor.Next
end
check(capacity.exceedsSafeLimit(deep), "a structure deeper than any record shape must fail closed")

-- Below / at / above the threshold ------------------------------------------

local function recordOfApproximately(targetBytes: number): any
	local record = { Items = {} }
	local index = 0
	while capacity.estimateBytes(record) < targetBytes do
		index += 1
		record.Items["item_" .. tostring(index)] = string.rep("y", 512)
	end
	return record
end

local below = { Small = "record" }
local belowClassification, belowBytes = capacity.classify(below)
check(belowClassification == "Within", "a small record is within budget")
check(belowBytes > 0, "a real record must cost something")
check(not capacity.exceedsSafeLimit(below), "a small record must not be refused")

local approaching = recordOfApproximately(capacity.WarningRecordByteLimit)
check(capacity.classify(approaching) == "Approaching", "a record past the warning threshold must be flagged")
check(not capacity.exceedsSafeLimit(approaching), "a warned record must still be writable")

local above = recordOfApproximately(capacity.SafeRecordByteLimit + 1)
check(capacity.classify(above) == "Exceeded", "a record past the budget must be refused")
check(capacity.exceedsSafeLimit(above), "a record past the budget must be refused")

--[[
	Retention. A replay ledger cannot be compacted by deleting entries: every
	entry removed is a mutation that becomes replayable again, which is the one
	failure the ledger exists to prevent. Archival is therefore copy-then-retain
	-- the proof that a transaction happened stays, only the detail moves.
]]
check(
	capacity.archivalKeyFor("player:1:inventory", 1) ~= "player:1:inventory",
	"an archive key must never collide with the record it preserves"
)
check(
	capacity.archivalKeyFor("player:1:inventory", 1) ~= capacity.archivalKeyFor("player:1:inventory", 2),
	"each archival generation must be distinct"
)
check(capacity.isArchivable(true, { Detail = "outcome" }), "detail may move when the proof is retained")
check(not capacity.isArchivable(nil, { Detail = "outcome" }), "dropping the proof is never archival")
check(not capacity.isArchivable(true, nil), "archiving nothing is not archival")

print("InventoryRecordCapacity: budget headroom, estimator direction, below/at/above, and retention semantics")
