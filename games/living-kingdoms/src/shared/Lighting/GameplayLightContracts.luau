--!strict

--[[
	Canonical shared declarations for server-known gameplay lighting. These
	descriptions contain no Roblox objects or renderer state. The server owns
	identity, source type, visibility profile, activation/expiry, and coverage.
	Clients may later request narrow intent, but never author these fields.
]]

local GameplayLightContracts = {}

export type VisibilityProfileId = "Dark" | "Dim" | "Lit"

export type GameplayLightSourceTypeId = "AuthoredEnvironmental" | "ApprovedPersonal" | "ApprovedTemporary"

export type GameplayLightActivationStateId = "Inactive" | "Active" | "Expired"

export type GameplayLightCoverageDescriptor =
	{
		kind: "Radius",
		radiusStuds: number,
	}
	| {
		kind: "ForwardCone",
		rangeStuds: number,
		angleDegrees: number,
	}
	| {
		kind: "AuthoredZone",
		authoredZoneProfileId: string,
	}

export type GameplayLightActivation = {
	stateId: GameplayLightActivationStateId,
	activatedAtServerTimestamp: number?,
	expiresAtServerTimestamp: number?,
}

export type GameplayLightDescriptor = {
	sourceId: string,
	sourceTypeId: GameplayLightSourceTypeId,
	visibilityProfileId: VisibilityProfileId,
	activation: GameplayLightActivation,
	coverage: GameplayLightCoverageDescriptor,
	ownerEntityId: string?,
}

export type GameplayLightRejectionReasonId =
	"InvalidDescriptor"
	| "InvalidSourceIdentity"
	| "InvalidSourceType"
	| "UnknownVisibilityProfile"
	| "InvalidActivationState"
	| "InvalidTimestamp"
	| "InvalidLifetime"
	| "InvalidCoverage"
	| "InvalidOwnerIdentity"
	| "BudgetExceeded"
	| "StaleTransition"

export type GameplayLightValidationResult = {
	isValid: boolean,
	rejectionReasonId: GameplayLightRejectionReasonId?,
}

GameplayLightContracts.VisibilityProfileIds = table.freeze({
	Dark = "Dark",
	Dim = "Dim",
	Lit = "Lit",
})

GameplayLightContracts.GameplayLightSourceTypeIds = table.freeze({
	AuthoredEnvironmental = "AuthoredEnvironmental",
	ApprovedPersonal = "ApprovedPersonal",
	ApprovedTemporary = "ApprovedTemporary",
})

GameplayLightContracts.GameplayLightActivationStateIds = table.freeze({
	Inactive = "Inactive",
	Active = "Active",
	Expired = "Expired",
})

GameplayLightContracts.GameplayLightCoverageKindIds = table.freeze({
	Radius = "Radius",
	ForwardCone = "ForwardCone",
	AuthoredZone = "AuthoredZone",
})

GameplayLightContracts.GameplayLightRejectionReasonIds = table.freeze({
	InvalidDescriptor = "InvalidDescriptor",
	InvalidSourceIdentity = "InvalidSourceIdentity",
	InvalidSourceType = "InvalidSourceType",
	UnknownVisibilityProfile = "UnknownVisibilityProfile",
	InvalidActivationState = "InvalidActivationState",
	InvalidTimestamp = "InvalidTimestamp",
	InvalidLifetime = "InvalidLifetime",
	InvalidCoverage = "InvalidCoverage",
	InvalidOwnerIdentity = "InvalidOwnerIdentity",
	BudgetExceeded = "BudgetExceeded",
	StaleTransition = "StaleTransition",
})

return table.freeze(GameplayLightContracts)
