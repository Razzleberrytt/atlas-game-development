--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldPortalDelegationResolver assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local resolver = loadModule(
	"games/living-kingdoms/src/shared/World/MainWorldPortalDelegationResolver.luau",
	"MainWorldPortalDelegationResolver"
)
local config = loadModule(
	"games/living-kingdoms/src/shared/Config/MainWorldPortalDelegationConfig.luau",
	"MainWorldPortalDelegationConfig"
)

local mainWorldAnchor = {
	id = config.MainWorldAnchorId,
	worldContentId = config.PortalContentId,
	interactionIntentId = config.InteractionIntentId,
	mutationOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	runtimeEnabled = false,
}
local currentBridgeAnchor = {
	id = config.CurrentBridgeAnchorId,
	worldContentId = config.PortalContentId,
	interactionIntentId = config.InteractionIntentId,
	mutationOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	runtimeEnabled = true,
}
local destination = {
	ContentId = config.PortalContentId,
	Destination = {
		ContentId = config.PortalContentId,
		LaunchAuthorityOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	},
	RuntimeEnabled = false,
}

local function resolve(anchor, bridge, target)
	return resolver.resolve(anchor, bridge, target, config)
end

local plan = resolve(mainWorldAnchor, currentBridgeAnchor, destination)
check(plan.status == "HeldCanonicalDelegation")
check(plan.contentId == config.PortalContentId)
check(plan.interactionIntentId == config.InteractionIntentId)
check(plan.launchAuthorityOwnerId == config.CanonicalLaunchAuthorityOwnerId)
check(plan.reasonId == nil)
check(plan.runtimeEnabled == false)
check(plan.transportAuthorityOwnedHere == false)
check(plan.eligibilityAuthorityOwnedHere == false)
check(plan.consequentialMutationOwnedHere == false)

local runtimeAnchor = table.clone(mainWorldAnchor)
runtimeAnchor.runtimeEnabled = true
check(resolve(runtimeAnchor, currentBridgeAnchor, destination).reasonId == "HeldInputsRequired")

local runtimeDestination = table.clone(destination)
runtimeDestination.RuntimeEnabled = true
check(resolve(mainWorldAnchor, currentBridgeAnchor, runtimeDestination).reasonId == "HeldInputsRequired")

local heldBridge = table.clone(currentBridgeAnchor)
heldBridge.runtimeEnabled = false
check(resolve(mainWorldAnchor, heldBridge, destination).reasonId == "CurrentBridgeMustBeActive")

local mainWorldIdentityMismatch = table.clone(mainWorldAnchor)
mainWorldIdentityMismatch.id = "hub.anchor.other"
check(
	resolve(mainWorldIdentityMismatch, currentBridgeAnchor, destination).reasonId == "MainWorldAnchorIdentityMismatch"
)

local bridgeIdentityMismatch = table.clone(currentBridgeAnchor)
bridgeIdentityMismatch.id = "hub.anchor.other"
check(resolve(mainWorldAnchor, bridgeIdentityMismatch, destination).reasonId == "CurrentBridgeAnchorIdentityMismatch")

local mainWorldContentMismatch = table.clone(mainWorldAnchor)
mainWorldContentMismatch.worldContentId = "portal.other"
check(resolve(mainWorldContentMismatch, currentBridgeAnchor, destination).reasonId == "MainWorldAnchorContentMismatch")

local bridgeContentMismatch = table.clone(currentBridgeAnchor)
bridgeContentMismatch.worldContentId = "portal.other"
check(resolve(mainWorldAnchor, bridgeContentMismatch, destination).reasonId == "CurrentBridgeContentMismatch")

local destinationContentMismatch = {
	ContentId = "portal.other",
	Destination = {
		ContentId = "portal.other",
		LaunchAuthorityOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	},
	RuntimeEnabled = false,
}
check(
	resolve(mainWorldAnchor, currentBridgeAnchor, destinationContentMismatch).reasonId
		== "AnchorDestinationContentMismatch"
)

local destinationDefinitionMismatch = {
	ContentId = config.PortalContentId,
	Destination = {
		ContentId = "portal.other",
		LaunchAuthorityOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	},
	RuntimeEnabled = false,
}
check(
	resolve(mainWorldAnchor, currentBridgeAnchor, destinationDefinitionMismatch).reasonId
		== "DestinationContentMismatch"
)

local mainWorldIntentMismatch = table.clone(mainWorldAnchor)
mainWorldIntentMismatch.interactionIntentId = "hub.intent.other"
check(
	resolve(mainWorldIntentMismatch, currentBridgeAnchor, destination).reasonId == "MainWorldInteractionIntentMismatch"
)

local bridgeIntentMismatch = table.clone(currentBridgeAnchor)
bridgeIntentMismatch.interactionIntentId = "hub.intent.other"
check(resolve(mainWorldAnchor, bridgeIntentMismatch, destination).reasonId == "CurrentBridgeInteractionIntentMismatch")

local ownerMissing = table.clone(mainWorldAnchor)
ownerMissing.mutationOwnerId = nil
check(resolve(ownerMissing, currentBridgeAnchor, destination).reasonId == "CanonicalOwnerMissing")

local bridgeOwnerMissing = table.clone(currentBridgeAnchor)
bridgeOwnerMissing.mutationOwnerId = nil
check(resolve(mainWorldAnchor, bridgeOwnerMissing, destination).reasonId == "CanonicalOwnerMissing")

local mainWorldOwnerMismatch = table.clone(mainWorldAnchor)
mainWorldOwnerMismatch.mutationOwnerId = "OtherOwner"
check(resolve(mainWorldOwnerMismatch, currentBridgeAnchor, destination).reasonId == "MainWorldCanonicalOwnerMismatch")

local bridgeOwnerMismatch = table.clone(currentBridgeAnchor)
bridgeOwnerMismatch.mutationOwnerId = "OtherOwner"
check(resolve(mainWorldAnchor, bridgeOwnerMismatch, destination).reasonId == "CurrentBridgeCanonicalOwnerMismatch")

local destinationOwnerMismatch = {
	ContentId = config.PortalContentId,
	Destination = {
		ContentId = config.PortalContentId,
		LaunchAuthorityOwnerId = "OtherOwner",
	},
	RuntimeEnabled = false,
}
check(
	resolve(mainWorldAnchor, currentBridgeAnchor, destinationOwnerMismatch).reasonId
		== "DestinationCanonicalOwnerMismatch"
)

check(config.RuntimeEnabled == false)
check(config.Rules.MainWorldSurfaceOwnsConsequentialMutation == false)
check(config.Rules.MainWorldSurfaceOwnsEligibility == false)
check(config.Rules.MainWorldSurfaceOwnsTransport == false)
check(config.Rules.ClientMayGrantJoinReadyOrLaunch == false)
check(config.Rules.InterPlaceTransportDefined == false)
check(config.Rules.PublishedPlaceIdsRequiredBeforeTransport == true)
check(config.Rules.RecoveredPromptInferenceAllowed == false)
check(config.Rules.StreamOutMayCompleteInteraction == false)
check(config.Rules.DelegationMustMatchCurrentBridgeIntent == true)
check(config.Rules.DelegationMustMatchCanonicalLaunchOwner == true)

local hubSource = fs.readFile("games/living-kingdoms/src/shared/Config/HubInteractionConfig.luau")
local destinationSource = fs.readFile("games/living-kingdoms/src/shared/Config/PortalDestinationConfig.luau")
local bootstrapSource = fs.readFile("games/living-kingdoms/src/shared/Config/MainWorldBootstrapAllowlistConfig.luau")
local resolverSource = fs.readFile("games/living-kingdoms/src/shared/World/MainWorldPortalDelegationResolver.luau")

for _, required in
	{
		config.MainWorldAnchorId,
		config.CurrentBridgeAnchorId,
		config.PortalContentId,
		config.InteractionIntentId,
		config.CanonicalLaunchAuthorityOwnerId,
	}
do
	check(string.find(hubSource, required, 1, true) ~= nil, "hub registry drift: " .. required)
end

for _, required in
	{
		config.PortalContentId,
		config.CanonicalLaunchAuthorityOwnerId,
		"RuntimeEnabled = false",
	}
do
	check(string.find(destinationSource, required, 1, true) ~= nil, "destination drift: " .. required)
end

check(string.find(bootstrapSource, config.CanonicalLaunchAuthorityOwnerId, 1, true) ~= nil)
check(string.find(bootstrapSource, "ConsequentialAuthorityAllowed = false", 1, true) ~= nil)
check(string.find(resolverSource, "TeleportService", 1, true) == nil)
check(string.find(resolverSource, "RemoteEvent", 1, true) == nil)
check(string.find(resolverSource, "RemoteFunction", 1, true) == nil)
check(string.find(resolverSource, "evaluateEligibility", 1, true) == nil)
check(string.find(resolverSource, "WaitForChild", 1, true) == nil)
