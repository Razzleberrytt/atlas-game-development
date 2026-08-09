--!strict

-- BA-031 contract-only portal destination/eligibility shape. No teleport
-- mechanism, network remote, or server owner is bound to this module.
-- `evaluateEligibility` is a pure resolver a future portal-facing owner may
-- call before deferring to the existing launch authority named on the
-- definition; nothing in the live game invokes it yet.

local Contracts = {}

Contracts.DenialReasonIds = table.freeze({
	RuntimeDisabled = "RuntimeDisabled",
	PartyTooSmall = "PartyTooSmall",
	PartyTooLarge = "PartyTooLarge",
	UnlockRequired = "UnlockRequired",
	PermissionDenied = "PermissionDenied",
	PlayerNotInLobby = "PlayerNotInLobby",
	InvalidRequest = "InvalidRequest",
})

-- The destination is named by reference to the existing stable world-content
-- ID and the service that already owns launch authority for it
-- (WorldContentConfig / CANONICAL-RUNTIME.md); this contract invents neither.
export type PortalDestinationRef = {
	ContentId: string,
	LaunchAuthorityOwnerId: string,
}

export type PortalPartyConstraint = {
	MinimumPartySize: number,
	MaximumPartySize: number,
}

export type PortalDestinationDefinition = {
	ContentId: string,
	Version: string,
	Destination: PortalDestinationRef,
	PartyConstraint: PortalPartyConstraint,
	-- nil means no unlock is required today; no unlock system exists yet.
	RequiresUnlockId: string?,
	-- Whether evaluateEligibility is wired into any live consumer. False for
	-- every currently authored definition: this contract is unconsumed data.
	RuntimeEnabled: boolean,
}

export type PortalEligibilityContext = {
	PartySize: number,
	UnlockedIds: { [string]: boolean }?,
}

export type PortalEligibilityResult = {
	Accepted: boolean,
	ReasonId: string?,
}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 1 and (value :: number) % 1 == 0
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

function Contracts.validatePortalDestinationDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			ContentId = true,
			Version = true,
			Destination = true,
			PartyConstraint = true,
			RequiresUnlockId = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(definition.ContentId, 64) or not isNonEmptyBoundedString(definition.Version, 16) then
		return false
	end
	local destination = definition.Destination
	if
		type(destination) ~= "table"
		or not isNonEmptyBoundedString(destination.ContentId, 64)
		or not isNonEmptyBoundedString(destination.LaunchAuthorityOwnerId, 64)
	then
		return false
	end
	local constraint = definition.PartyConstraint
	if
		type(constraint) ~= "table"
		or not isPositiveInteger(constraint.MinimumPartySize)
		or not isPositiveInteger(constraint.MaximumPartySize)
		or (constraint.MinimumPartySize :: number) > (constraint.MaximumPartySize :: number)
	then
		return false
	end
	if definition.RequiresUnlockId ~= nil and not isNonEmptyBoundedString(definition.RequiresUnlockId, 64) then
		return false
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

function Contracts.evaluateEligibility(
	definition: PortalDestinationDefinition,
	context: PortalEligibilityContext
): PortalEligibilityResult
	if not definition.RuntimeEnabled then
		return table.freeze({ Accepted = false, ReasonId = Contracts.DenialReasonIds.RuntimeDisabled })
	end
	if context.PartySize < definition.PartyConstraint.MinimumPartySize then
		return table.freeze({ Accepted = false, ReasonId = Contracts.DenialReasonIds.PartyTooSmall })
	end
	if context.PartySize > definition.PartyConstraint.MaximumPartySize then
		return table.freeze({ Accepted = false, ReasonId = Contracts.DenialReasonIds.PartyTooLarge })
	end
	if definition.RequiresUnlockId ~= nil then
		local unlocked = context.UnlockedIds ~= nil and context.UnlockedIds[definition.RequiresUnlockId] == true
		if not unlocked then
			return table.freeze({ Accepted = false, ReasonId = Contracts.DenialReasonIds.UnlockRequired })
		end
	end
	return table.freeze({ Accepted = true, ReasonId = nil })
end

return table.freeze(Contracts)
