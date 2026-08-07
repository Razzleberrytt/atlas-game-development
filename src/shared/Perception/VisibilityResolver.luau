--!strict

-- Pure server-domain visibility resolution. The caller supplies every
-- authoritative fact, including region, light coverage, and consequential LOS.
local GameplayLightContracts = require(script.Parent.Parent.Lighting.GameplayLightContracts)
local PerceptionContracts = require(script.Parent.PerceptionContracts)
local PerceptionConfig = require(script.Parent.Parent.Config.PerceptionConfig)
local VisibilityContracts = require(script.Parent.VisibilityContracts)

local VisibilityResolver = {}

local UNKNOWN = PerceptionContracts.PerceptionStateIds.Unknown
local SUSPECTED = PerceptionContracts.PerceptionStateIds.Suspected
local OBSERVED = PerceptionContracts.PerceptionStateIds.Observed
local LOW = PerceptionContracts.ObservationConfidenceIds.Low
local MEDIUM = PerceptionContracts.ObservationConfidenceIds.Medium
local HIGH = PerceptionContracts.ObservationConfidenceIds.High

local function isNonemptyString(value: unknown): boolean
	return typeof(value) == "string" and #value > 0
end

local function isKnownValue(values: { [string]: string }, value: unknown): boolean
	return typeof(value) == "string" and values[value] == value
end

local function isBoolean(value: unknown): boolean
	return typeof(value) == "boolean"
end

local function isFiniteNonnegativeNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function rejected(rejectionReasonId: string)
	return table.freeze({
		isValid = false,
		isGameplayVisible = false,
		perceptionStateId = UNKNOWN,
		confidenceId = LOW,
		canCreateDirectSightObservation = false,
		isTargetingVisible = false,
		rejectionReasonId = rejectionReasonId,
		decisionReasonId = nil,
	})
end

local function decided(
	decisionReasonId: string,
	perceptionStateId: string,
	confidenceId: string,
	isGameplayVisible: boolean,
	canCreateDirectSightObservation: boolean,
	isTargetingVisible: boolean
)
	return table.freeze({
		isValid = true,
		isGameplayVisible = isGameplayVisible,
		perceptionStateId = perceptionStateId,
		confidenceId = confidenceId,
		canCreateDirectSightObservation = canCreateDirectSightObservation,
		isTargetingVisible = isTargetingVisible,
		rejectionReasonId = nil,
		decisionReasonId = decisionReasonId,
	})
end

local function maximumDistanceSquared(visibilityProfileId: string): number
	local distanceStuds = PerceptionConfig.PrototypeForwardVisibilityRangeStuds[visibilityProfileId]
	return distanceStuds * distanceStuds
end

local function observedConfidence(visibilityProfileId: string): string
	if visibilityProfileId == GameplayLightContracts.VisibilityProfileIds.Dim then
		return MEDIUM
	end

	return HIGH
end

-- Stable input first-failure order: facts, observer identity, candidate identity,
-- self, observer state, candidate state, relationship/category, profile,
-- spatial container, region, illumination, spatial distance, LOS, disclosure.
function VisibilityResolver.resolve(facts: unknown)
	if typeof(facts) ~= "table" then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidFacts)
	end
	if not isNonemptyString(facts.observerEntityId) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidObserverIdentity)
	end
	if not isNonemptyString(facts.candidateEntityId) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidCandidateIdentity)
	end
	if facts.observerEntityId == facts.candidateEntityId then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.SelfEvaluation)
	end
	if facts.observerCanPerceive ~= true then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.ObserverStateInvalid)
	end
	if
		facts.candidateIsGameplayPresent ~= true
		or facts.candidateIsAlive ~= true
		or not isBoolean(facts.candidateIsTargetable)
	then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.CandidateStateInvalid)
	end
	if
		not isKnownValue(VisibilityContracts.VisibilityEntityCategoryIds, facts.candidateCategoryId)
		or not isKnownValue(VisibilityContracts.VisibilityRelationshipIds, facts.relationshipId)
	then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidRelationshipOrCategory)
	end
	if
		typeof(facts.illuminationFacts) ~= "table"
		or not isKnownValue(GameplayLightContracts.VisibilityProfileIds, facts.illuminationFacts.visibilityProfileId)
	then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidVisibilityProfile)
	end
	if typeof(facts.spatialFacts) ~= "table" then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidSpatialFact)
	end
	if not isKnownValue(VisibilityContracts.PerceptualRegionIds, facts.spatialFacts.perceptualRegionId) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidPerceptualRegion)
	end
	if not isBoolean(facts.illuminationFacts.hasQualifyingLocalLightCoverage) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidIlluminationFact)
	end
	if not isFiniteNonnegativeNumber(facts.spatialFacts.distanceSquaredStuds) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidSpatialFact)
	end
	if not isBoolean(facts.spatialFacts.hasConsequentialLineOfSight) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidLineOfSightFact)
	end
	if not isKnownValue(PerceptionContracts.DisclosureStateIds, facts.disclosureStateId) then
		return rejected(VisibilityContracts.VisibilityRejectionReasonIds.InvalidDisclosureFact)
	end

	if facts.spatialFacts.perceptualRegionId == VisibilityContracts.PerceptualRegionIds.Outside then
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.OutsidePerceptualRegion,
			UNKNOWN,
			LOW,
			false,
			false,
			false
		)
	end
	if
		facts.spatialFacts.distanceSquaredStuds > maximumDistanceSquared(facts.illuminationFacts.visibilityProfileId)
	then
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.OutsideVisibilityRange,
			UNKNOWN,
			LOW,
			false,
			false,
			false
		)
	end
	if
		facts.illuminationFacts.visibilityProfileId == GameplayLightContracts.VisibilityProfileIds.Dark
		and not facts.illuminationFacts.hasQualifyingLocalLightCoverage
	then
		if facts.spatialFacts.perceptualRegionId == VisibilityContracts.PerceptualRegionIds.Peripheral then
			return decided(
				VisibilityContracts.VisibilityDecisionReasonIds.PeripheralOnly,
				SUSPECTED,
				LOW,
				false,
				false,
				false
			)
		end
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.InsufficientIllumination,
			UNKNOWN,
			LOW,
			false,
			false,
			false
		)
	end
	if facts.spatialFacts.perceptualRegionId == VisibilityContracts.PerceptualRegionIds.Peripheral then
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.PeripheralOnly,
			SUSPECTED,
			LOW,
			false,
			false,
			false
		)
	end
	if not facts.spatialFacts.hasConsequentialLineOfSight then
		return decided(VisibilityContracts.VisibilityDecisionReasonIds.NoLineOfSight, UNKNOWN, LOW, false, false, false)
	end

	local confidenceId = observedConfidence(facts.illuminationFacts.visibilityProfileId)
	if facts.disclosureStateId ~= PerceptionContracts.DisclosureStateIds.Disclosed then
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.NotDisclosedForTargeting,
			OBSERVED,
			confidenceId,
			true,
			true,
			false
		)
	end
	if
		facts.candidateCategoryId ~= VisibilityContracts.VisibilityEntityCategoryIds.Hostile
		or facts.relationshipId ~= VisibilityContracts.VisibilityRelationshipIds.Hostile
	then
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.RelationshipNotHostile,
			OBSERVED,
			confidenceId,
			true,
			true,
			false
		)
	end
	if facts.candidateIsTargetable ~= true then
		return decided(
			VisibilityContracts.VisibilityDecisionReasonIds.CandidateUntargetable,
			OBSERVED,
			confidenceId,
			true,
			true,
			false
		)
	end

	return decided(
		VisibilityContracts.VisibilityDecisionReasonIds.ObservedTargetingVisible,
		OBSERVED,
		confidenceId,
		true,
		true,
		true
	)
end

return table.freeze(VisibilityResolver)
