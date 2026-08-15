--!strict

--[[
	Pure scheduling/progress helper for the production enemy director.
	Keeps expensive path grants deterministic and independent of Lua table
	iteration order, while making stuck detection testable without Roblox
	services or a second runtime loop.
]]

local Scheduler = {}

export type WorldPosition = {
	x: number,
	y: number,
	z: number,
}

export type RoundRobinResolution = {
	grantedEntityIds: { [string]: boolean },
	nextCursorEntityId: string?,
	grantCount: number,
}

export type ProgressResolution = {
	didRecover: boolean,
	progressAnchor: WorldPosition,
	progressAnchorServerTimestamp: number,
	nextRecoveryServerTimestamp: number,
}

local function copyPosition(position: WorldPosition): WorldPosition
	return { x = position.x, y = position.y, z = position.z }
end

function Scheduler.resolveRoundRobin(
	candidateEntityIds: { string },
	previousCursorEntityId: string?,
	maximumGrants: number
): RoundRobinResolution
	assert(type(candidateEntityIds) == "table", "navigation candidates must be a table")
	assert(maximumGrants > 0 and maximumGrants % 1 == 0, "navigation grant limit must be a positive integer")

	local sortedIds = table.clone(candidateEntityIds)
	table.sort(sortedIds)
	local count = #sortedIds
	if count == 0 then
		return {
			grantedEntityIds = {},
			nextCursorEntityId = previousCursorEntityId,
			grantCount = 0,
		}
	end

	local startIndex = 1
	if previousCursorEntityId ~= nil then
		local foundSuccessor = false
		for index, entityId in sortedIds do
			if entityId > previousCursorEntityId then
				startIndex = index
				foundSuccessor = true
				break
			end
		end
		if not foundSuccessor then
			startIndex = 1
		end
	end

	local grants: { [string]: boolean } = {}
	local grantCount = math.min(maximumGrants, count)
	local lastGrantedEntityId: string? = nil
	for offset = 0, grantCount - 1 do
		local index = ((startIndex + offset - 1) % count) + 1
		local entityId = sortedIds[index]
		grants[entityId] = true
		lastGrantedEntityId = entityId
	end

	return {
		grantedEntityIds = grants,
		nextCursorEntityId = lastGrantedEntityId,
		grantCount = grantCount,
	}
end

function Scheduler.resolveProgress(
	currentPosition: WorldPosition,
	progressAnchor: WorldPosition,
	progressAnchorServerTimestamp: number,
	nextRecoveryServerTimestamp: number,
	serverTimestamp: number,
	minimumProgressStuds: number,
	progressWindowSeconds: number,
	recoveryCooldownSeconds: number
): ProgressResolution
	assert(minimumProgressStuds > 0, "minimum navigation progress must be positive")
	assert(progressWindowSeconds > 0, "navigation progress window must be positive")
	assert(recoveryCooldownSeconds >= progressWindowSeconds, "navigation recovery cooldown must cover the progress window")

	local dx = currentPosition.x - progressAnchor.x
	local dz = currentPosition.z - progressAnchor.z
	local progressed = dx * dx + dz * dz >= minimumProgressStuds * minimumProgressStuds
	if progressed then
		return {
			didRecover = false,
			progressAnchor = copyPosition(currentPosition),
			progressAnchorServerTimestamp = serverTimestamp,
			nextRecoveryServerTimestamp = nextRecoveryServerTimestamp,
		}
	end

	local windowElapsed = serverTimestamp - progressAnchorServerTimestamp >= progressWindowSeconds
	if windowElapsed and serverTimestamp >= nextRecoveryServerTimestamp then
		return {
			didRecover = true,
			progressAnchor = copyPosition(currentPosition),
			progressAnchorServerTimestamp = serverTimestamp,
			nextRecoveryServerTimestamp = serverTimestamp + recoveryCooldownSeconds,
		}
	end

	return {
		didRecover = false,
		progressAnchor = copyPosition(progressAnchor),
		progressAnchorServerTimestamp = progressAnchorServerTimestamp,
		nextRecoveryServerTimestamp = nextRecoveryServerTimestamp,
	}
end

return table.freeze(Scheduler)
