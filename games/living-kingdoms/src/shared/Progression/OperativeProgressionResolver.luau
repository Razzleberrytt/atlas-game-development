--!strict

-- Pure Patch 0.4 resolver for durable operative progression. It consumes the
-- inventory owner's already-persisted reward-grant ledger; it never writes
-- persistence, trusts client-authored progress, or treats temporary run XP as
-- account progression.

export type RankDefinition = {
	Rank: number,
	Id: string,
	DisplayName: string,
	RequiredCompletedExpeditions: number,
}

export type ProgressionConfig = {
	Version: string,
	DurableRewardGrantPrefix: string,
	CompletedExpeditionSourceId: string,
	Ranks: { RankDefinition },
}

export type ProgressionSnapshot = {
	Accepted: boolean,
	ReasonId: string,
	CompletedExpeditions: number,
	Rank: number?,
	RankId: string?,
	RankDisplayName: string?,
	CurrentRankRequiredCompletedExpeditions: number?,
	NextRank: number?,
	NextRankId: string?,
	NextRankDisplayName: string?,
	NextRankRequiredCompletedExpeditions: number?,
	CompletedExpeditionsToNextRank: number?,
	IsMaximumRank: boolean,
}

local Resolver = {}

local function rejected(reasonId: string): ProgressionSnapshot
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

local function isNonemptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function validConfig(config: unknown): boolean
	if type(config) ~= "table" then
		return false
	end
	local candidate: any = config
	if not isNonemptyString(candidate.Version) or not isNonemptyString(candidate.DurableRewardGrantPrefix) then
		return false
	end
	if not isNonemptyString(candidate.CompletedExpeditionSourceId) or type(candidate.Ranks) ~= "table" then
		return false
	end
	if #candidate.Ranks < 2 or #candidate.Ranks > 10 then
		return false
	end

	local previousThreshold = -1
	local seenIds = {}
	for index, rank in candidate.Ranks do
		if type(rank) ~= "table" then
			return false
		end
		if rank.Rank ~= index or not isNonemptyString(rank.Id) or not isNonemptyString(rank.DisplayName) then
			return false
		end
		if seenIds[rank.Id] then
			return false
		end
		seenIds[rank.Id] = true
		local threshold = rank.RequiredCompletedExpeditions
		if type(threshold) ~= "number" or threshold < 0 or threshold % 1 ~= 0 or threshold <= previousThreshold then
			return false
		end
		previousThreshold = threshold
	end
	return candidate.Ranks[1].RequiredCompletedExpeditions == 0
end

local function completedRunId(config: ProgressionConfig, grantId: string): string?
	local prefix = config.DurableRewardGrantPrefix
	local suffix = ":" .. config.CompletedExpeditionSourceId
	if string.sub(grantId, 1, #prefix) ~= prefix or string.sub(grantId, -#suffix) ~= suffix then
		return nil
	end
	local runId = string.sub(grantId, #prefix + 1, #grantId - #suffix)
	if runId == "" then
		return nil
	end
	return runId
end

function Resolver.resolve(config: ProgressionConfig, appliedRewardGrantIds: unknown): ProgressionSnapshot
	if not validConfig(config) then
		return rejected("InvalidConfig")
	end
	if type(appliedRewardGrantIds) ~= "table" then
		return rejected("InvalidGrantLedger")
	end

	local completedRunIds = {}
	for _, rawGrantId in appliedRewardGrantIds :: any do
		if type(rawGrantId) ~= "string" then
			return rejected("InvalidGrantLedger")
		end
		local runId = completedRunId(config, rawGrantId)
		if runId ~= nil then
			completedRunIds[runId] = true
		end
	end

	local completedExpeditions = 0
	for _ in completedRunIds do
		completedExpeditions += 1
	end

	local current = config.Ranks[1]
	local nextRank: RankDefinition? = nil
	for _, rank in config.Ranks do
		if completedExpeditions >= rank.RequiredCompletedExpeditions then
			current = rank
		else
			nextRank = rank
			break
		end
	end

	local isMaximumRank = nextRank == nil
	return table.freeze({
		Accepted = true,
		ReasonId = "ProgressionResolved",
		CompletedExpeditions = completedExpeditions,
		Rank = current.Rank,
		RankId = current.Id,
		RankDisplayName = current.DisplayName,
		CurrentRankRequiredCompletedExpeditions = current.RequiredCompletedExpeditions,
		NextRank = if nextRank ~= nil then nextRank.Rank else nil,
		NextRankId = if nextRank ~= nil then nextRank.Id else nil,
		NextRankDisplayName = if nextRank ~= nil then nextRank.DisplayName else nil,
		NextRankRequiredCompletedExpeditions = if nextRank ~= nil then nextRank.RequiredCompletedExpeditions else nil,
		CompletedExpeditionsToNextRank = if nextRank ~= nil
			then nextRank.RequiredCompletedExpeditions - completedExpeditions
			else nil,
		IsMaximumRank = isMaximumRank,
	})
end

return table.freeze(Resolver)
