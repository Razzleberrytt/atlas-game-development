--!strict

-- BA-031 portal destination/eligibility contract fixture: validation, the
-- pure eligibility resolver, and the one authored `portal.expedition.primary`
-- definition tracking its expedition's party bounds. No network, teleport, or
-- server owner exists to exercise here -- this is contract/config-only.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "PortalDestinationContracts assertion failed", 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/World/PortalDestinationContracts.luau"), {
	debugName = "PortalDestinationContracts",
	injectGlobals = true,
})()

local DenialReasonIds = contracts.DenialReasonIds

local function definition(overrides: { [string]: any }?): any
	local base = {
		ContentId = "portal.expedition.primary",
		Version = "1.0.0",
		Destination = {
			ContentId = "portal.expedition.primary",
			LaunchAuthorityOwnerId = "ExpeditionLobbyService",
		},
		PartyConstraint = { MinimumPartySize = 1, MaximumPartySize = 4 },
		RequiresUnlockId = nil,
		RuntimeEnabled = true,
	}
	if overrides then
		for key, value in overrides do
			base[key] = value
		end
	end
	return base
end

-- ===========================================================================
-- validatePortalDestinationDefinition
-- ===========================================================================
check(contracts.validatePortalDestinationDefinition(definition()), "a well-formed definition must validate")
check(
	not contracts.validatePortalDestinationDefinition(definition({ ContentId = "" })),
	"an empty content ID must not validate"
)
check(
	not contracts.validatePortalDestinationDefinition(
		definition({ PartyConstraint = { MinimumPartySize = 4, MaximumPartySize = 1 } })
	),
	"inverted party bounds must not validate"
)
check(
	not contracts.validatePortalDestinationDefinition(definition({ extra = true })),
	"an unknown field must not validate"
)
check(
	not contracts.validatePortalDestinationDefinition(
		definition({ Destination = { ContentId = "portal.expedition.primary" } })
	),
	"a destination missing its launch authority owner must not validate"
)
check(
	contracts.validatePortalDestinationDefinition(definition({ RequiresUnlockId = "unlock.something" })),
	"a bounded unlock ID must validate"
)

-- ===========================================================================
-- evaluateEligibility
-- ===========================================================================
local disabled = definition({ RuntimeEnabled = false })
local disabledResult = contracts.evaluateEligibility(disabled, { PartySize = 1 })
check(disabledResult.Accepted == false, "a runtime-disabled definition must deny")
check(disabledResult.ReasonId == DenialReasonIds.RuntimeDisabled, "the reason must be RuntimeDisabled")

local enabled = definition()
local tooSmall = contracts.evaluateEligibility(enabled, { PartySize = 0 })
check(tooSmall.Accepted == false and tooSmall.ReasonId == DenialReasonIds.PartyTooSmall, "an empty party must deny")

local tooLarge = contracts.evaluateEligibility(enabled, { PartySize = 5 })
check(tooLarge.Accepted == false and tooLarge.ReasonId == DenialReasonIds.PartyTooLarge, "an oversized party must deny")

local accepted = contracts.evaluateEligibility(enabled, { PartySize = 2 })
check(accepted.Accepted == true and accepted.ReasonId == nil, "a party within bounds must be accepted")

local unlockGated = definition({ RequiresUnlockId = "unlock.something" })
local missingUnlock = contracts.evaluateEligibility(unlockGated, { PartySize = 1 })
check(
	missingUnlock.Accepted == false and missingUnlock.ReasonId == DenialReasonIds.UnlockRequired,
	"a missing required unlock must deny"
)
local withUnlock =
	contracts.evaluateEligibility(unlockGated, { PartySize = 1, UnlockedIds = { ["unlock.something"] = true } })
check(withUnlock.Accepted == true, "an unlocked party within bounds must be accepted")

-- ===========================================================================
-- The one authored definition tracks its expedition's party bounds exactly.
-- ===========================================================================
local EXPEDITION_CONFIG_TOKEN = {}
local expeditionContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionContracts.luau"), {
		debugName = "ExpeditionContracts",
		injectGlobals = true,
	})()
local expeditionConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/ExpeditionConfig.luau"), {
	debugName = "ExpeditionConfig",
	injectGlobals = true,
	environment = {
		script = { Parent = { Parent = { Expeditions = { ExpeditionContracts = EXPEDITION_CONFIG_TOKEN } } } },
		require = function(token: unknown)
			check(token == EXPEDITION_CONFIG_TOKEN, "unexpected ExpeditionConfig dependency")
			return expeditionContracts
		end,
	},
})()

local EXPEDITION_TOKEN = {}
local portalConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/PortalDestinationConfig.luau"), {
	debugName = "PortalDestinationConfig",
	injectGlobals = true,
	environment = {
		script = { Parent = { ExpeditionConfig = EXPEDITION_TOKEN } },
		require = function(token: unknown)
			check(token == EXPEDITION_TOKEN, "unexpected PortalDestinationConfig dependency")
			return expeditionConfig
		end,
	},
})()

local firstExpedition = expeditionConfig.Definitions.FirstExpedition
local primary = portalConfig.Definitions.ExpeditionPrimary
check(contracts.validatePortalDestinationDefinition(primary), "the authored definition must itself validate")
check(primary.ContentId == "portal.expedition.primary", "the authored definition must reuse the stable content ID")
check(
	primary.Destination.LaunchAuthorityOwnerId == "ExpeditionLobbyService",
	"the destination must delegate to the existing canonical launch authority"
)
check(
	primary.PartyConstraint.MinimumPartySize == firstExpedition.MinimumPlayers,
	"the portal's minimum party size must track the expedition it launches"
)
check(
	primary.PartyConstraint.MaximumPartySize == firstExpedition.MaximumPlayers,
	"the portal's maximum party size must track the expedition it launches"
)
check(primary.RuntimeEnabled == false, "the authored definition must remain unconsumed data, not an activation")

print("PortalDestinationContracts: BA-031 destination/eligibility contract and authored data passed")
