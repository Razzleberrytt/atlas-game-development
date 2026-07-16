--!strict

--[[
	Selects at most one target from caller-provided, server-derived candidates.
	Every candidate is validated by TargetCandidateValidator; this module does
	not discover, cache, fire at, or mutate targets.

	Priority is active threat to this exact operative, then squared horizontal
	XZ distance, then lexical CombatEntityId. Distances use exact number
	comparisons without an epsilon so the ordering stays transitive.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local TargetCandidateValidator = require(script.Parent.TargetCandidateValidator)

type CombatEntityId = CombatContracts.CombatEntityId
type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type SelectedTargetState = CombatContracts.SelectedTargetState
type TargetCandidate = CombatContracts.TargetCandidate
type WeaponReadinessState = CombatContracts.WeaponReadinessState

export type OperativeTargetingState = {
	entityId: CombatEntityId,
	worldPosition: Vector3,
	combatStateId: OperativeCombatStateId,
	weaponReadiness: WeaponReadinessState,
}

type TargetCandidateSelector = {
	select: (operative: OperativeTargetingState, candidates: { TargetCandidate }) -> SelectedTargetState?,
}

local TargetCandidateSelector: TargetCandidateSelector = {} :: TargetCandidateSelector
local selectionReasons = CombatContracts.TargetSelectionReasonIds

local function horizontalDistanceSquared(first: Vector3, second: Vector3): number
	local deltaX = second.X - first.X
	local deltaZ = second.Z - first.Z
	return deltaX * deltaX + deltaZ * deltaZ
end

local function isBetterCandidate(
	candidate: TargetCandidate,
	candidateDistanceSquared: number,
	current: TargetCandidate?,
	currentDistanceSquared: number
): boolean
	if current == nil then
		return true
	end

	if candidateDistanceSquared < currentDistanceSquared then
		return true
	end

	if candidateDistanceSquared > currentDistanceSquared then
		return false
	end

	return candidate.entityId < current.entityId
end

function TargetCandidateSelector.select(
	operative: OperativeTargetingState,
	candidates: { TargetCandidate }
): SelectedTargetState?
	local closestValid: TargetCandidate? = nil
	local closestValidDistanceSquared = math.huge
	local closestThreat: TargetCandidate? = nil
	local closestThreatDistanceSquared = math.huge

	for _, candidate in candidates do
		local validation = TargetCandidateValidator.validate(operative, candidate)
		if validation.isValid then
			local distanceSquared = horizontalDistanceSquared(operative.worldPosition, candidate.worldPosition)
			if isBetterCandidate(candidate, distanceSquared, closestValid, closestValidDistanceSquared) then
				closestValid = candidate
				closestValidDistanceSquared = distanceSquared
			end

			if
				candidate.activelyThreateningOperativeEntityId == operative.entityId
				and isBetterCandidate(candidate, distanceSquared, closestThreat, closestThreatDistanceSquared)
			then
				closestThreat = candidate
				closestThreatDistanceSquared = distanceSquared
			end
		end
	end

	local selectedCandidate = closestThreat or closestValid
	if selectedCandidate == nil then
		return nil
	end

	return {
		operativeEntityId = operative.entityId,
		targetEntityId = selectedCandidate.entityId,
		isValid = true,
		selectionReasonId = if closestThreat ~= nil
			then selectionReasons.ThreateningClosest
			else selectionReasons.ValidClosest,
		selectedAtServerTimestamp = nil,
	}
end

return table.freeze(TargetCandidateSelector)
