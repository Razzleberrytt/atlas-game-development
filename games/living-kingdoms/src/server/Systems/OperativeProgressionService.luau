--!strict

-- Patch 0.4 read-only durable progression adapter. InventoryLiveService remains
-- the persistence/session owner; this service only derives a sanitized rank
-- snapshot and unlock eligibility from the owner's already-loaded durable
-- reward-grant ledger.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeProgressionConfig = require(ReplicatedStorage.Shared.Config.OperativeProgressionConfig)
local OperativeProgressionResolver = require(ReplicatedStorage.Shared.Progression.OperativeProgressionResolver)
local InventoryLiveService = require(script.Parent.InventoryLiveService)

local Service = {}

local function rejected(reasonId: string): any
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		CompletedExpeditions = 0,
		Rank = nil,
		RankId = nil,
		RankDisplayName = nil,
		CurrentRankRequiredCompletedExpeditions = nil,
		NextRank = nil,
		NextRankId = nil,
		NextRankDisplayName = nil,
		NextRankRequiredCompletedExpeditions = nil,
		CompletedExpeditionsToNextRank = nil,
		IsMaximumRank = false,
		Unlocks = table.freeze({}),
		EarnedUnlockCount = 0,
		TotalUnlockCount = 0,
	})
end

-- requesterId must come from the invoking Player. Keeping ownerId explicit makes
-- the cross-player disclosure guard testable instead of relying on every caller
-- to remember that progression is private account state.
function Service.readOwnedSnapshot(requesterId: number, ownerId: number): any
	if requesterId ~= ownerId then
		return rejected("CrossPlayerProgressionAccess")
	end

	local record = InventoryLiveService.getRecord(ownerId)
	if record == nil then
		return rejected("InventoryNotLoaded")
	end
	if type(record.AppliedRewardGrantIds) ~= "table" then
		return rejected("InvalidDurableGrantLedger")
	end

	return OperativeProgressionResolver.resolve(OperativeProgressionConfig, record.AppliedRewardGrantIds)
end

--[[
	Unlocks are never stored independently. They are a deterministic projection of
	the same durable rank snapshot, making future bounded unlocks cheap to add
	without creating a second persistence or progression authority.

	The entitlement rule itself lives once, inside OperativeProgressionResolver, so
	this server check and the disclosed progression-map presentation always answer
	from the same resolved list rather than two copies of the rank comparison.
]]
function Service.hasOwnedUnlock(requesterId: number, ownerId: number, unlockId: string): boolean
	if type(unlockId) ~= "string" or unlockId == "" then
		return false
	end

	local snapshot = Service.readOwnedSnapshot(requesterId, ownerId)
	if snapshot.Accepted ~= true or type(snapshot.Unlocks) ~= "table" then
		return false
	end
	for _, unlock in snapshot.Unlocks do
		if unlock.Id == unlockId then
			return unlock.IsEarned == true
		end
	end
	return false
end

return table.freeze(Service)
