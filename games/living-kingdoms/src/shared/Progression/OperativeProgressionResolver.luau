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

export type UnlockDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	RequiredRank: number,
}

export type ProgressionConfig = {
	Version: string,
	DurableRewardGrantPrefix: string,
	CompletedExpeditionSourceId: string,
	Ranks: { RankDefinition },
	Unlocks: { UnlockDefinition }?,
}

-- One resolved unlock. `IsEarned` is the single canonical answer to "does this
-- operative hold this unlock", so no consumer re-implements the rank comparison.
export type ResolvedUnlock = {
	Id: string,
	DisplayName: string,
	Description: string,
	RequiredRank: number,
	IsEarned: boolean,
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
	Unlocks: { ResolvedUnlock },
	EarnedUnlockCount: number,
	TotalUnlockCount: number,
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
		Unlocks = table.freeze({}),
		EarnedUnlockCount = 0,
		TotalUnlockCount = 0,
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
	if candidate.Ranks[1].RequiredCompletedExpeditions ~= 0 then
		return false
	end
	-- Unlocks are optional so a partial runtime or a narrow fixture can resolve
	-- rank alone, but a malformed unlock list fails the whole snapshot closed
	-- rather than silently disclosing a partial entitlement set.
	if candidate.Unlocks == nil then
		return true
	end
	if type(candidate.Unlocks) ~= "table" then
		return false
	end
	local seenUnlockIds = {}
	for _, unlock in candidate.Unlocks do
		if type(unlock) ~= "table" or not isNonemptyString(unlock.Id) or seenUnlockIds[unlock.Id] then
			return false
		end
		if not isNonemptyString(unlock.DisplayName) or not isNonemptyString(unlock.Description) then
			return false
		end
		local requiredRank = unlock.RequiredRank
		if
			type(requiredRank) ~= "number"
			or requiredRank ~= requiredRank
			or requiredRank % 1 ~= 0
			or requiredRank < 1
			or requiredRank > #candidate.Ranks
		then
			return false
		end
		seenUnlockIds[unlock.Id] = true
	end
	return true
end

--[[
	Projects the authored unlock list against the resolved rank. This is the only
	place the "rank at or above requirement" rule exists, so the server
	entitlement check and the progression-map presentation cannot drift apart.

	The order is deterministic — required rank, then unlock ID — so a disclosed
	snapshot renders the same list every time.
]]
local function resolveUnlocks(config: ProgressionConfig, currentRank: number): ({ ResolvedUnlock }, number)
	local authored = config.Unlocks
	if authored == nil then
		return table.freeze({}), 0
	end
	local resolved = {}
	for _, unlock in authored do
		table.insert(
			resolved,
			table.freeze({
				Id = unlock.Id,
				DisplayName = unlock.DisplayName,
				Description = unlock.Description,
				RequiredRank = unlock.RequiredRank,
				IsEarned = currentRank >= unlock.RequiredRank,
			})
		)
	end
	table.sort(resolved, function(first, second)
		if first.RequiredRank ~= second.RequiredRank then
			return first.RequiredRank < second.RequiredRank
		end
		return first.Id < second.Id
	end)
	local earnedCount = 0
	for _, unlock in resolved do
		if unlock.IsEarned then
			earnedCount += 1
		end
	end
	return table.freeze(resolved), earnedCount
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

	--[[
		The ledger is a set: PlayerInventoryContracts declares
		AppliedRewardGrantIds as { [string]: boolean }, and persistence stores
		grantId -> true. Iterating it for values yielded booleans, so every
		non-empty ledger was rejected as malformed and progression died for
		exactly the players who had earned something. An empty ledger iterates
		zero times, which is why a fresh account looked fine.

		Grant ids are the keys. Values are validated the same way persistence
		validates them on load, so the two owners agree on what a ledger is.
	]]
	--[[
		#70 cross-domain binding. Progression is a projection of the durable grant
		ledger, not a second record, so the only way it can be wrong is by being
		computed from a ledger that is not the one the caller thinks it holds.
		Deriving an identity from the source here lets a consumer detect a stale
		or mismatched projection instead of trusting a rank that was correct for
		some other ledger.
	]]
	local sourceGrantIds = {}
	local completedRunIds = {}
	for grantId, applied in appliedRewardGrantIds :: any do
		if type(grantId) ~= "string" or applied ~= true then
			return rejected("InvalidGrantLedger")
		end
		table.insert(sourceGrantIds, grantId)
		local runId = completedRunId(config, grantId)
		if runId ~= nil then
			completedRunIds[runId] = true
		end
	end
	table.sort(sourceGrantIds)

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
	local unlocks, earnedUnlockCount = resolveUnlocks(config, current.Rank)
	return table.freeze({
		Accepted = true,
		ReasonId = "ProgressionResolved",
		SourceLedgerIdentity = string.format(
			"%s|grants=%d|%s",
			config.Version,
			#sourceGrantIds,
			table.concat(sourceGrantIds, ";")
		),
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
		Unlocks = unlocks,
		EarnedUnlockCount = earnedUnlockCount,
		TotalUnlockCount = #unlocks,
	})
end

return table.freeze(Resolver)
