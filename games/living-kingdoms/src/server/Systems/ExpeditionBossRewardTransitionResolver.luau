--!strict

--[[
	Pure bridge between the authoritative expedition phase transition and the
	existing run-build reward owner. This resolver does not grant a reward; it
	only derives one deterministic server-side event when the same expedition
	advances from Boss into Rewards and the authored decision is runtime-enabled.
]]

export type RewardEvent = {
	EventId: string,
	SourceId: string,
}

local Resolver = {}

function Resolver.resolve(previousSnapshot: any?, currentSnapshot: any?, decision: any?): RewardEvent?
	if type(previousSnapshot) ~= "table" or type(currentSnapshot) ~= "table" or type(decision) ~= "table" then
		return nil
	end
	if decision.RuntimeConsumptionEnabled ~= true then
		return nil
	end
	if previousSnapshot.PhaseId ~= "Boss" or currentSnapshot.PhaseId ~= "Rewards" then
		return nil
	end
	local runId = currentSnapshot.RunId
	if type(runId) ~= "string" or runId == "" or previousSnapshot.RunId ~= runId then
		return nil
	end
	local decisionId = decision.DecisionId
	local sourceId = decision.RunRewardSourceId
	if type(decisionId) ~= "string" or decisionId == "" or type(sourceId) ~= "string" or sourceId == "" then
		return nil
	end
	return table.freeze({
		EventId = decisionId .. ":" .. runId,
		SourceId = sourceId,
	})
end

return table.freeze(Resolver)
