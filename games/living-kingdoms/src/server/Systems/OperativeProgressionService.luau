--!strict

-- Patch 0.4 read-only durable progression adapter. InventoryLiveService remains
-- the persistence/session owner; this service only derives a sanitized rank
-- snapshot from the owner's already-loaded durable reward-grant ledger.

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

return table.freeze(Service)
