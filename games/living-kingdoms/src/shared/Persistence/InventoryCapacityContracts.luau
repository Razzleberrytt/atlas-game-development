--!strict

--[[
	Patch 0.7 durable record size budget.

	A DataStore value has a hard ceiling, and a record that crosses it does not
	save a truncated version -- it does not save at all. Every later mutation
	fails the same way, so the player keeps playing while nothing they do
	survives. The failure surfaces far from its cause, which is what makes it
	worth catching before submission rather than after.

	The estimator is deliberately deterministic and slightly pessimistic. It is
	not a JSON encoder; it is a bound. Being a little over is harmless, being
	under is the only outcome that matters, so every ambiguous case rounds up.
]]

local InventoryCapacityContracts = {}

--[[
	Roblox's documented per-key limit is 4,194,304 bytes. The safe ceiling sits
	well under it: the estimate is approximate, and a record that only fails at
	the true limit leaves no room to notice or act.
]]
InventoryCapacityContracts.DataStoreValueByteLimit = 4_194_304
InventoryCapacityContracts.SafeRecordByteLimit = 1_048_576
InventoryCapacityContracts.WarningRecordByteLimit = 786_432

export type SizeClassification = "Within" | "Approaching" | "Exceeded"

InventoryCapacityContracts.SizeClassifications = table.freeze({
	Within = "Within" :: SizeClassification,
	Approaching = "Approaching" :: SizeClassification,
	Exceeded = "Exceeded" :: SizeClassification,
})

--[[
	Per-value overhead covers the punctuation a serializer adds around each entry
	-- quotes, colons, commas, braces. Counting it per key and per value keeps the
	estimate above the real encoding rather than below it.
]]
local VALUE_OVERHEAD_BYTES = 4
local BOOLEAN_BYTES = 5
local NUMBER_BYTES = 20

local function estimate(value: any, depth: number): number
	if depth > 32 then
		--[[
			A structure deeper than any record shape should be is treated as
			expensive rather than followed. Refusing to recurse forever is the
			point; the number only has to be large enough to fail closed.
		]]
		return InventoryCapacityContracts.SafeRecordByteLimit
	end

	local valueType = type(value)
	if value == nil then
		return 0
	elseif valueType == "boolean" then
		return BOOLEAN_BYTES
	elseif valueType == "number" then
		return NUMBER_BYTES
	elseif valueType == "string" then
		return #value + VALUE_OVERHEAD_BYTES
	elseif valueType ~= "table" then
		return NUMBER_BYTES
	end

	local total = 2
	for key, child in value do
		total += estimate(key, depth + 1)
		total += estimate(child, depth + 1)
		total += VALUE_OVERHEAD_BYTES
	end
	return total
end

function InventoryCapacityContracts.estimateBytes(value: any): number
	return estimate(value, 0)
end

function InventoryCapacityContracts.classify(value: any): (SizeClassification, number)
	local bytes = InventoryCapacityContracts.estimateBytes(value)
	if bytes > InventoryCapacityContracts.SafeRecordByteLimit then
		return InventoryCapacityContracts.SizeClassifications.Exceeded, bytes
	elseif bytes >= InventoryCapacityContracts.WarningRecordByteLimit then
		return InventoryCapacityContracts.SizeClassifications.Approaching, bytes
	end
	return InventoryCapacityContracts.SizeClassifications.Within, bytes
end

function InventoryCapacityContracts.exceedsSafeLimit(value: any): boolean
	local classification = InventoryCapacityContracts.classify(value)
	return classification == InventoryCapacityContracts.SizeClassifications.Exceeded
end

--[[
	Retention, stated rather than implemented as pruning.

	A replay ledger cannot be compacted by deleting entries: every entry removed
	is a mutation that becomes replayable again, which is the one failure the
	ledger exists to prevent. So retention here means bounding growth and moving
	*detail* elsewhere while keeping the minimal set that can still answer a
	replay -- never dropping the answer itself.

	Archival is therefore copy-then-retain, not delete. The key that proves a
	transaction happened stays; only the payload a replay would disclose may move
	to an archive key, at the cost of one extra read on that rare path.
]]
function InventoryCapacityContracts.archivalKeyFor(sourceKey: string, generation: number): string
	assert(type(sourceKey) == "string" and sourceKey ~= "", "archival requires a source key")
	assert(type(generation) == "number" and generation % 1 == 0 and generation >= 0, "archival requires a generation")
	return string.format("archive:%s:%d", sourceKey, generation)
end

--[[
	A ledger entry is safe to archive only when the record still proves the
	transaction happened without it. Dropping the proof is never archival.
]]
function InventoryCapacityContracts.isArchivable(retainedProof: any, archivedDetail: any): boolean
	return retainedProof ~= nil and archivedDetail ~= nil
end

return table.freeze(InventoryCapacityContracts)
