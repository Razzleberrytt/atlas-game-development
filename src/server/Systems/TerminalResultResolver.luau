--!strict

--[[
	P10-0102 the one authoritative terminal-result decision. Pure, deterministic,
	side-effect free: given the server-owned operation facts, it returns the single
	first-commit-wins terminal result — or a reason the operation is not yet
	terminal — with a fixed precedence so simultaneous conditions can never produce
	two results.

	Every terminal cause converges here: a committed squad wipe, authoritative
	abandonment, and the boss-defeat extraction. Precedence is fixed: a dead squad
	cannot extract, so a committed wipe outranks a pending extraction; abandonment
	outranks extraction for the same reason. Per the plan, objectives are
	non-terminal and there is no timeout cause. The runtime owner (P10-0103) reads
	the facts, calls this resolver, and commits at most once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)

type TerminalDecision = MatchResultContracts.TerminalDecision

local CauseIds = MatchResultContracts.MissionResultCauseIds
local RejectionReasonIds = MatchResultContracts.TerminalDecisionRejectionReasonIds
local OutcomeByCauseId = MatchResultContracts.OutcomeByCauseId

-- Server-owned facts for one terminal decision. `resolvedCauseId` is the already
-- committed result (nil while the operation is unresolved); the booleans are the
-- current terminal conditions.
export type TerminalFacts = {
	resolvedCauseId: string?,
	squadWiped: boolean,
	isAbandoned: boolean,
	extractionArrived: boolean,
	serverTimestamp: number,
}

local TerminalResultResolver = {}

local function decision(
	shouldCommit: boolean,
	causeId: string?,
	outcomeId: string?,
	rejectionReasonId: string?
): TerminalDecision
	return table.freeze({
		shouldCommit = shouldCommit,
		causeId = causeId,
		outcomeId = outcomeId,
		rejectionReasonId = rejectionReasonId,
	}) :: TerminalDecision
end

local function commit(causeId: string): TerminalDecision
	return decision(true, causeId, OutcomeByCauseId[causeId], nil)
end

function TerminalResultResolver.resolve(facts: TerminalFacts): TerminalDecision
	if
		type(facts) ~= "table"
		or type(facts.squadWiped) ~= "boolean"
		or type(facts.isAbandoned) ~= "boolean"
		or type(facts.extractionArrived) ~= "boolean"
		or (facts.resolvedCauseId ~= nil and CauseIds[facts.resolvedCauseId] == nil)
	then
		return decision(false, nil, nil, RejectionReasonIds.InvalidFacts)
	end
	local serverTimestamp = facts.serverTimestamp
	if
		type(serverTimestamp) ~= "number"
		or serverTimestamp ~= serverTimestamp
		or serverTimestamp == math.huge
		or serverTimestamp == -math.huge
		or serverTimestamp < 0
	then
		return decision(false, nil, nil, RejectionReasonIds.InvalidTimestamp)
	end

	-- First-commit-wins: a resolved operation never resolves again.
	if facts.resolvedCauseId ~= nil then
		return decision(false, nil, nil, RejectionReasonIds.AlreadyResolved)
	end

	-- Fixed precedence: wipe, then abandonment, then extraction.
	if facts.squadWiped then
		return commit(CauseIds.SquadWipe)
	end
	if facts.isAbandoned then
		return commit(CauseIds.Abandoned)
	end
	if facts.extractionArrived then
		return commit(CauseIds.Extracted)
	end
	return decision(false, nil, nil, RejectionReasonIds.NotTerminal)
end

return table.freeze(TerminalResultResolver)
