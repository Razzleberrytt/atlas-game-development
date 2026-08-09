--!strict

-- BA-062 C4 pure arbitration contract. This module decides whether a numbered
-- choice input has exactly one eligible presentation owner. It does not listen
-- for input, create UI, send remotes, or mutate gameplay state.

export type Resolution = {
	ResolutionId: string,
	DispatchAllowed: boolean,
	OwnerId: string?,
	ActiveOwnerIds: { string },
}

local ResolutionIds = table.freeze({
	NoneActive = "NoneActive",
	SingleActive = "SingleActive",
	Conflict = "Conflict",
	InvalidInput = "InvalidInput",
})

local Resolver = {
	ResolutionIds = ResolutionIds,
}

local function frozenIds(ids: { string }): { string }
	return table.freeze(ids)
end

local function resolution(
	resolutionId: string,
	dispatchAllowed: boolean,
	ownerId: string?,
	activeOwnerIds: { string }
): Resolution
	return table.freeze({
		ResolutionId = resolutionId,
		DispatchAllowed = dispatchAllowed,
		OwnerId = ownerId,
		ActiveOwnerIds = frozenIds(activeOwnerIds),
	})
end

function Resolver.resolve(activeOwnerIds: { string }): Resolution
	local normalized = {}
	local seen = {}
	for index = 1, #activeOwnerIds do
		local ownerId = activeOwnerIds[index]
		if type(ownerId) ~= "string" or ownerId == "" or seen[ownerId] then
			return resolution(ResolutionIds.InvalidInput, false, nil, {})
		end
		seen[ownerId] = true
		table.insert(normalized, ownerId)
	end
	table.sort(normalized)

	if #normalized == 0 then
		return resolution(ResolutionIds.NoneActive, false, nil, normalized)
	end
	if #normalized == 1 then
		return resolution(ResolutionIds.SingleActive, true, normalized[1], normalized)
	end
	return resolution(ResolutionIds.Conflict, false, nil, normalized)
end

return table.freeze(Resolver)
