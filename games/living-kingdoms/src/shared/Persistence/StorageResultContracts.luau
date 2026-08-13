--!strict

--[[
	Patch 0.7 explicit storage outcome vocabulary.

	A bare `nil` read cannot distinguish "this player has no saved record" from
	"the read failed and we have no idea", and those two demand opposite
	responses: the first should create a new record, the second must never write
	anything. A bare boolean write result is the same problem one layer over --
	it says a write did not happen without saying whether the value was rejected
	or the backend was unreachable.

	Callers are expected to branch on Status. Value is only meaningful on Found
	and Committed; Reason only carries diagnostic text on Failed.
]]

export type ReadStatus = "Found" | "Missing" | "Failed"
export type WriteStatus = "Committed" | "Failed"

export type ReadResult = {
	Status: ReadStatus,
	Value: any?,
	Reason: string?,
}

export type WriteResult = {
	Status: WriteStatus,
	Value: any?,
	Reason: string?,
}

local StorageResultContracts = {}

StorageResultContracts.ReadStatuses = table.freeze({
	Found = "Found" :: ReadStatus,
	Missing = "Missing" :: ReadStatus,
	Failed = "Failed" :: ReadStatus,
})

StorageResultContracts.WriteStatuses = table.freeze({
	Committed = "Committed" :: WriteStatus,
	Failed = "Failed" :: WriteStatus,
})

function StorageResultContracts.found(value: any): ReadResult
	assert(value ~= nil, "a Found read must carry a value; absence is Missing")
	return table.freeze({ Status = "Found" :: ReadStatus, Value = value, Reason = nil })
end

function StorageResultContracts.missing(): ReadResult
	return table.freeze({ Status = "Missing" :: ReadStatus, Value = nil, Reason = nil })
end

function StorageResultContracts.readFailed(reason: any): ReadResult
	return table.freeze({ Status = "Failed" :: ReadStatus, Value = nil, Reason = tostring(reason) })
end

--[[
	Committed carries the value the store actually holds, not the value the
	caller asked to write. An UpdateAsync transform can return something other
	than its input, so the committed identity is what any later comparison has
	to be made against.
]]
function StorageResultContracts.committed(value: any): WriteResult
	return table.freeze({ Status = "Committed" :: WriteStatus, Value = value, Reason = nil })
end

function StorageResultContracts.writeFailed(reason: any): WriteResult
	return table.freeze({ Status = "Failed" :: WriteStatus, Value = nil, Reason = tostring(reason) })
end

function StorageResultContracts.isRead(value: any): boolean
	return type(value) == "table" and StorageResultContracts.ReadStatuses[value.Status] ~= nil
end

function StorageResultContracts.isWrite(value: any): boolean
	return type(value) == "table" and StorageResultContracts.WriteStatuses[value.Status] ~= nil
end

return table.freeze(StorageResultContracts)
