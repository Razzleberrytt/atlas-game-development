--!strict

-- One shared truth for the terminal fate of run equipment. Claimed rewards are
-- only durable after a completed expedition; failure or abandonment forfeits
-- them. In-progress runs remain unresolved and must never be treated as banked.

local ExpeditionContracts = require(script.Parent.ExpeditionContracts)

export type RewardDispositionId = "Pending" | "Banked" | "Forfeited"

local RewardDispositionIds = table.freeze({
	Pending = "Pending" :: RewardDispositionId,
	Banked = "Banked" :: RewardDispositionId,
	Forfeited = "Forfeited" :: RewardDispositionId,
})

local Resolver = {}

function Resolver.resolve(outcomeId: unknown): RewardDispositionId?
	if outcomeId == ExpeditionContracts.OutcomeIds.InProgress then
		return RewardDispositionIds.Pending
	end
	if outcomeId == ExpeditionContracts.OutcomeIds.Completed then
		return RewardDispositionIds.Banked
	end
	if outcomeId == ExpeditionContracts.OutcomeIds.Failed or outcomeId == ExpeditionContracts.OutcomeIds.Abandoned then
		return RewardDispositionIds.Forfeited
	end
	return nil
end

function Resolver.shouldPersist(outcomeId: unknown): boolean
	return Resolver.resolve(outcomeId) == RewardDispositionIds.Banked
end

Resolver.RewardDispositionIds = RewardDispositionIds

return table.freeze(Resolver)
