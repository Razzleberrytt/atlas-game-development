--!strict

--[[
	Pure server-side primary-target selector for weapon patterns. Threatening
	hostiles remain an absolute priority cohort. Within that cohort, cone and
	line-pierce weapons prefer the valid primary that exposes the greatest number
	of secondary impacts according to the existing WeaponPatternResolver.

	When the current primary remains valid in the same threat cohort and offers
	the same pattern utility as the newly ranked best target, it may be retained
	inside a small distance allowance. This prevents needless target/facing churn
	between equivalent cluster or lineup choices without delaying a better pattern
	opportunity, an active threat, or invalidation.

	Single-target weapons, invalid patterns, and pattern weapons with no secondary
	opportunity delegate exactly to TargetCandidateSelector. This module performs
	no discovery, raycasts, firing, ammunition mutation, damage, commits, remotes,
	or presentation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local WeaponPatternConfig = require(ReplicatedStorage.Shared.Config.WeaponPatternConfig)
local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)
local TargetCandidateValidator = require(script.Parent.TargetCandidateValidator)
local WeaponPatternResolver = require(script.Parent.WeaponPatternResolver)

export type OperativeTargetingState = TargetCandidateSelector.OperativeTargetingState

type CombatEntityId = CombatContracts.CombatEntityId
type TargetCandidate = CombatContracts.TargetCandidate
type SelectedTargetState = CombatContracts.SelectedTargetState

type RankedPrimary = {
	candidate: TargetCandidate,
	utilityCount: number,
	distanceSquared: number,
}

local WeaponTargetSelector = {}
local selectionReasons = CombatContracts.TargetSelectionReasonIds
local patternModes = WeaponPatternConfig.ModeIds

local EQUIVALENT_PATTERN_UTILITY_DISTANCE_ALLOWANCE_STUDS = 6
assert(
	EQUIVALENT_PATTERN_UTILITY_DISTANCE_ALLOWANCE_STUDS >= 2
		and EQUIVALENT_PATTERN_UTILITY_DISTANCE_ALLOWANCE_STUDS <= 10,
	"equivalent pattern-target retention allowance must stay small and bounded"
)

local function horizontalDistanceSquared(first: Vector3, second: Vector3): number
	local deltaX = second.X - first.X
	local deltaZ = second.Z - first.Z
	return deltaX * deltaX + deltaZ * deltaZ
end

local function isThreatening(operative: OperativeTargetingState, candidate: TargetCandidate): boolean
	return candidate.activelyThreateningOperativeEntityId == operative.entityId
end

local function toPatternFacts(candidates: { TargetCandidate }): { WeaponPatternResolver.PatternTargetFact }
	local facts = table.create(#candidates)
	for _, candidate in candidates do
		table.insert(facts, {
			entityId = candidate.entityId,
			worldPosition = candidate.worldPosition,
			isAlive = candidate.isAlive,
			isTargetable = candidate.isTargetable
				and candidate.entityKindId == CombatContracts.CombatEntityKindIds.Hostile
				and candidate.relationshipId == CombatContracts.TeamRelationshipIds.Hostile,
			isVisible = candidate.isVisible,
			hasLineOfSight = candidate.hasLineOfSight,
		})
	end
	return facts
end

local function isBetterPrimary(candidate: RankedPrimary, current: RankedPrimary?): boolean
	if current == nil then
		return true
	end
	if candidate.utilityCount ~= current.utilityCount then
		return candidate.utilityCount > current.utilityCount
	end
	if candidate.distanceSquared ~= current.distanceSquared then
		return candidate.distanceSquared < current.distanceSquared
	end
	return candidate.candidate.entityId < current.candidate.entityId
end

local function retainedOrBest(best: RankedPrimary, current: RankedPrimary?): RankedPrimary
	if current == nil or current.utilityCount ~= best.utilityCount then
		return best
	end
	local maximumRetainedDistance = math.sqrt(best.distanceSquared)
		+ EQUIVALENT_PATTERN_UTILITY_DISTANCE_ALLOWANCE_STUDS
	if current.distanceSquared > maximumRetainedDistance * maximumRetainedDistance then
		return best
	end
	return current
end

function WeaponTargetSelector.select(
	operative: OperativeTargetingState,
	candidates: { TargetCandidate },
	currentTargetEntityId: CombatEntityId?
): SelectedTargetState?
	local definition = WeaponPatternConfig.get(operative.weaponReadiness.weaponId)
	if
		definition == nil
		or definition.ModeId == patternModes.SingleTarget
		or definition.MaximumSecondaryTargets <= 0
	then
		return TargetCandidateSelector.select(operative, candidates)
	end

	local validPrimaries = {}
	local hasThreateningPrimary = false
	for _, candidate in candidates do
		if TargetCandidateValidator.validate(operative, candidate).isValid then
			table.insert(validPrimaries, candidate)
			hasThreateningPrimary = hasThreateningPrimary or isThreatening(operative, candidate)
		end
	end
	if #validPrimaries == 0 then
		return nil
	end

	local patternFacts = toPatternFacts(candidates)
	local best: RankedPrimary? = nil
	local current: RankedPrimary? = nil
	for _, candidate in validPrimaries do
		if hasThreateningPrimary and not isThreatening(operative, candidate) then
			continue
		end
		local impacts = WeaponPatternResolver.resolve(
			operative.weaponReadiness.weaponId,
			operative.worldPosition,
			candidate.entityId,
			patternFacts
		)
		local ranked = {
			candidate = candidate,
			utilityCount = #impacts,
			distanceSquared = horizontalDistanceSquared(operative.worldPosition, candidate.worldPosition),
		}
		if isBetterPrimary(ranked, best) then
			best = ranked
		end
		if currentTargetEntityId ~= nil and candidate.entityId == currentTargetEntityId then
			current = ranked
		end
	end

	if best == nil or best.utilityCount <= 0 then
		return TargetCandidateSelector.select(operative, candidates)
	end

	local selected = retainedOrBest(best, current)
	return {
		operativeEntityId = operative.entityId,
		targetEntityId = selected.candidate.entityId,
		isValid = true,
		selectionReasonId = if hasThreateningPrimary
			then selectionReasons.ThreateningPatternUtility
			else selectionReasons.ValidPatternUtility,
		selectedAtServerTimestamp = nil,
	}
end

return table.freeze(WeaponTargetSelector)
