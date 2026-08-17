--!strict

export type BudgetResolution = {
	GrantedEntityIds: { string },
	CursorEntityId: string?,
}

local Scheduler = {}

local function orderedUniqueEntityIds(entityIds: { string }): { string }
	local seen: { [string]: boolean } = {}
	local ordered: { string } = {}
	for _, entityId in entityIds do
		if type(entityId) == "string" and entityId ~= "" and seen[entityId] ~= true then
			seen[entityId] = true
			table.insert(ordered, entityId)
		end
	end
	table.sort(ordered)
	return ordered
end

function Scheduler.resolveRoundRobinGrants(
	entityIds: { string },
	cursorEntityId: string?,
	maximumGrants: number
): BudgetResolution
	local ordered = orderedUniqueEntityIds(entityIds)
	local count = #ordered
	local grantCount = math.min(math.max(0, math.floor(maximumGrants)), count)
	if count == 0 or grantCount == 0 then
		return table.freeze({
			GrantedEntityIds = table.freeze({}),
			CursorEntityId = cursorEntityId,
		})
	end

	local startIndex = 1
	if cursorEntityId ~= nil then
		-- Resume at the first surviving id after the cursor, even if the cursor's
		-- enemy despawned between evaluations. Falling back to index 1 whenever a
		-- cursor disappears would repeatedly favor low sorted ids under spawn/death
		-- churn and weaken the fairness guarantee this scheduler exists to provide.
		local foundSuccessor = false
		for index, entityId in ordered do
			if entityId > cursorEntityId then
				startIndex = index
				foundSuccessor = true
				break
			end
		end
		if not foundSuccessor then
			startIndex = 1
		end
	end

	local granted: { string } = {}
	for offset = 0, grantCount - 1 do
		local index = ((startIndex + offset - 2) % count) + 1
		table.insert(granted, ordered[index])
	end

	return table.freeze({
		GrantedEntityIds = table.freeze(granted),
		CursorEntityId = granted[#granted],
	})
end

return table.freeze(Scheduler)
