--!strict

-- Stable declarations for one authoritative observer/candidate visibility
-- evaluation. These records contain normalized server facts only.
local VisibilityContracts = {}

export type VisibilityEntityCategoryId = "Operative" | "Hostile" | "Objective"
export type VisibilityRelationshipId = "Friendly" | "Hostile" | "Neutral"
export type PerceptualRegionId = "Forward" | "Peripheral" | "Outside"

export type VisibilityIlluminationFacts = {
	visibilityProfileId: "Dark" | "Dim" | "Lit",
	hasQualifyingLocalLightCoverage: boolean,
}

export type VisibilitySpatialFacts = {
	distanceSquaredStuds: number,
	perceptualRegionId: PerceptualRegionId,
	hasConsequentialLineOfSight: boolean,
}

export type VisibilityEvaluationFacts = {
	observerEntityId: string,
	candidateEntityId: string,
	observerCanPerceive: boolean,
	candidateCategoryId: VisibilityEntityCategoryId,
	candidateIsGameplayPresent: boolean,
	candidateIsAlive: boolean,
	candidateIsTargetable: boolean,
	relationshipId: VisibilityRelationshipId,
	illuminationFacts: VisibilityIlluminationFacts,
	spatialFacts: VisibilitySpatialFacts,
	disclosureStateId: "Hidden" | "Disclosed",
}

export type VisibilityRejectionReasonId =
	"InvalidFacts"
	| "InvalidObserverIdentity"
	| "InvalidCandidateIdentity"
	| "SelfEvaluation"
	| "ObserverStateInvalid"
	| "CandidateStateInvalid"
	| "InvalidRelationshipOrCategory"
	| "InvalidVisibilityProfile"
	| "InvalidPerceptualRegion"
	| "InvalidIlluminationFact"
	| "InvalidSpatialFact"
	| "InvalidLineOfSightFact"
	| "InvalidDisclosureFact"

export type VisibilityDecisionReasonId =
	"OutsidePerceptualRegion"
	| "OutsideVisibilityRange"
	| "InsufficientIllumination"
	| "NoLineOfSight"
	| "PeripheralOnly"
	| "NotDisclosedForTargeting"
	| "RelationshipNotHostile"
	| "CandidateUntargetable"
	| "ObservedTargetingVisible"

export type VisibilityResolution = {
	isValid: boolean,
	isGameplayVisible: boolean,
	perceptionStateId: "Unknown" | "Suspected" | "Observed",
	confidenceId: "Low" | "Medium" | "High",
	canCreateDirectSightObservation: boolean,
	isTargetingVisible: boolean,
	rejectionReasonId: VisibilityRejectionReasonId?,
	decisionReasonId: VisibilityDecisionReasonId?,
}

VisibilityContracts.VisibilityEntityCategoryIds = table.freeze({
	Operative = "Operative",
	Hostile = "Hostile",
	Objective = "Objective",
})

VisibilityContracts.VisibilityRelationshipIds = table.freeze({
	Friendly = "Friendly",
	Hostile = "Hostile",
	Neutral = "Neutral",
})

VisibilityContracts.PerceptualRegionIds = table.freeze({
	Forward = "Forward",
	Peripheral = "Peripheral",
	Outside = "Outside",
})

VisibilityContracts.VisibilityRejectionReasonIds = table.freeze({
	InvalidFacts = "InvalidFacts",
	InvalidObserverIdentity = "InvalidObserverIdentity",
	InvalidCandidateIdentity = "InvalidCandidateIdentity",
	SelfEvaluation = "SelfEvaluation",
	ObserverStateInvalid = "ObserverStateInvalid",
	CandidateStateInvalid = "CandidateStateInvalid",
	InvalidRelationshipOrCategory = "InvalidRelationshipOrCategory",
	InvalidVisibilityProfile = "InvalidVisibilityProfile",
	InvalidPerceptualRegion = "InvalidPerceptualRegion",
	InvalidIlluminationFact = "InvalidIlluminationFact",
	InvalidSpatialFact = "InvalidSpatialFact",
	InvalidLineOfSightFact = "InvalidLineOfSightFact",
	InvalidDisclosureFact = "InvalidDisclosureFact",
})

VisibilityContracts.VisibilityDecisionReasonIds = table.freeze({
	OutsidePerceptualRegion = "OutsidePerceptualRegion",
	OutsideVisibilityRange = "OutsideVisibilityRange",
	InsufficientIllumination = "InsufficientIllumination",
	NoLineOfSight = "NoLineOfSight",
	PeripheralOnly = "PeripheralOnly",
	NotDisclosedForTargeting = "NotDisclosedForTargeting",
	RelationshipNotHostile = "RelationshipNotHostile",
	CandidateUntargetable = "CandidateUntargetable",
	ObservedTargetingVisible = "ObservedTargetingVisible",
})

return table.freeze(VisibilityContracts)
