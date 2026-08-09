--!strict

--[[
	BA-031 authored portal destination/eligibility data for the one currently
	active portal, `portal.expedition.primary` (WorldContentConfig). Party
	bounds mirror ExpeditionConfig.Definitions.FirstExpedition exactly, since
	this portal ultimately gates entry into that same expedition. RuntimeEnabled
	stays false: nothing calls PortalDestinationContracts.evaluateEligibility
	yet, so this remains unconsumed data rather than an activation.
]]

local ExpeditionConfig = require(script.Parent.ExpeditionConfig)

local firstExpedition = ExpeditionConfig.Definitions.FirstExpedition

local PortalDestinationConfig = {
	Version = "BA-031-v1",
	Definitions = table.freeze({
		ExpeditionPrimary = table.freeze({
			ContentId = "portal.expedition.primary",
			Version = "1.0.0",
			Destination = table.freeze({
				ContentId = "portal.expedition.primary",
				LaunchAuthorityOwnerId = "ExpeditionLobbyService",
			}),
			PartyConstraint = table.freeze({
				MinimumPartySize = firstExpedition.MinimumPlayers,
				MaximumPartySize = firstExpedition.MaximumPlayers,
			}),
			RequiresUnlockId = nil,
			RuntimeEnabled = false,
		}),
	}),
}

assert(
	PortalDestinationConfig.Definitions.ExpeditionPrimary.PartyConstraint.MinimumPartySize
		== firstExpedition.MinimumPlayers,
	"portal party bounds must track the expedition it ultimately launches"
)
assert(
	PortalDestinationConfig.Definitions.ExpeditionPrimary.PartyConstraint.MaximumPartySize
		== firstExpedition.MaximumPlayers,
	"portal party bounds must track the expedition it ultimately launches"
)

return table.freeze(PortalDestinationConfig)
