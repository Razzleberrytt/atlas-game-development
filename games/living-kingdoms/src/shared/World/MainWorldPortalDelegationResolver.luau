--!strict

-- Patch 0.5 pure delegation resolver for the authored Main World expedition
-- portal. This module does not invoke eligibility, create remotes, mutate lobby
-- state, teleport players, or activate the dedicated place. It only proves that
-- held presentation resolves to the same canonical intent/owner already used by
-- the live expedition terminal.

export type AnchorDefinition = {
	id: string,
	worldContentId: string,
	interactionIntentId: string,
	mutationOwnerId: string?,
	runtimeEnabled: boolean,
}

export type DestinationDefinition = {
	ContentId: string,
	Destination: {
		ContentId: string,
		LaunchAuthorityOwnerId: string,
	},
	RuntimeEnabled: boolean,
}

export type DelegationContract = {
	MainWorldAnchorId: string,
	CurrentBridgeAnchorId: string,
	PortalContentId: string,
	InteractionIntentId: string,
	CanonicalLaunchAuthorityOwnerId: string,
}

export type DelegationPlan = {
	status: "HeldCanonicalDelegation" | "Rejected",
	contentId: string?,
	interactionIntentId: string?,
	launchAuthorityOwnerId: string?,
	reasonId: string?,
	runtimeEnabled: boolean,
	transportAuthorityOwnedHere: boolean,
	eligibilityAuthorityOwnedHere: boolean,
	consequentialMutationOwnedHere: boolean,
}

local Resolver = {}

local function rejected(reasonId: string): DelegationPlan
	return table.freeze({
		status = "Rejected",
		contentId = nil,
		interactionIntentId = nil,
		launchAuthorityOwnerId = nil,
		reasonId = reasonId,
		runtimeEnabled = false,
		transportAuthorityOwnedHere = false,
		eligibilityAuthorityOwnedHere = false,
		consequentialMutationOwnedHere = false,
	})
end

function Resolver.resolve(
	anchor: AnchorDefinition,
	currentBridgeAnchor: AnchorDefinition,
	destination: DestinationDefinition,
	contract: DelegationContract
): DelegationPlan
	if anchor.runtimeEnabled or destination.RuntimeEnabled then
		return rejected("HeldInputsRequired")
	end
	if not currentBridgeAnchor.runtimeEnabled then
		return rejected("CurrentBridgeMustBeActive")
	end
	if anchor.id ~= contract.MainWorldAnchorId then
		return rejected("MainWorldAnchorIdentityMismatch")
	end
	if currentBridgeAnchor.id ~= contract.CurrentBridgeAnchorId then
		return rejected("CurrentBridgeAnchorIdentityMismatch")
	end
	if anchor.worldContentId ~= contract.PortalContentId then
		return rejected("MainWorldAnchorContentMismatch")
	end
	if currentBridgeAnchor.worldContentId ~= contract.PortalContentId then
		return rejected("CurrentBridgeContentMismatch")
	end
	if destination.ContentId ~= contract.PortalContentId then
		return rejected("AnchorDestinationContentMismatch")
	end
	if destination.Destination.ContentId ~= destination.ContentId then
		return rejected("DestinationContentMismatch")
	end
	if anchor.interactionIntentId ~= contract.InteractionIntentId then
		return rejected("MainWorldInteractionIntentMismatch")
	end
	if currentBridgeAnchor.interactionIntentId ~= contract.InteractionIntentId then
		return rejected("CurrentBridgeInteractionIntentMismatch")
	end
	if anchor.mutationOwnerId == nil or currentBridgeAnchor.mutationOwnerId == nil then
		return rejected("CanonicalOwnerMissing")
	end
	if anchor.mutationOwnerId ~= contract.CanonicalLaunchAuthorityOwnerId then
		return rejected("MainWorldCanonicalOwnerMismatch")
	end
	if currentBridgeAnchor.mutationOwnerId ~= contract.CanonicalLaunchAuthorityOwnerId then
		return rejected("CurrentBridgeCanonicalOwnerMismatch")
	end
	if destination.Destination.LaunchAuthorityOwnerId ~= contract.CanonicalLaunchAuthorityOwnerId then
		return rejected("DestinationCanonicalOwnerMismatch")
	end

	return table.freeze({
		status = "HeldCanonicalDelegation",
		contentId = anchor.worldContentId,
		interactionIntentId = anchor.interactionIntentId,
		launchAuthorityOwnerId = anchor.mutationOwnerId,
		reasonId = nil,
		runtimeEnabled = false,
		transportAuthorityOwnedHere = false,
		eligibilityAuthorityOwnedHere = false,
		consequentialMutationOwnedHere = false,
	})
end

return table.freeze(Resolver)
