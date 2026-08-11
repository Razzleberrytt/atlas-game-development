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
local destination = {
	ContentId = config.PortalContentId,
	Destination = {
		ContentId = config.PortalContentId,
		LaunchAuthorityOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	},
	RuntimeEnabled = false,
}

local plan = resolver.resolve(mainWorldAnchor, destination)
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
check(resolver.resolve(runtimeAnchor, destination).reasonId == "HeldInputsRequired")

local runtimeDestination = table.clone(destination)
runtimeDestination.RuntimeEnabled = true
check(resolver.resolve(mainWorldAnchor, runtimeDestination).reasonId == "HeldInputsRequired")

local contentMismatch = table.clone(mainWorldAnchor)
contentMismatch.worldContentId = "portal.other"
check(resolver.resolve(contentMismatch, destination).reasonId == "AnchorDestinationContentMismatch")

local destinationMismatch = {
	ContentId = config.PortalContentId,
	Destination = {
		ContentId = "portal.other",
		LaunchAuthorityOwnerId = config.CanonicalLaunchAuthorityOwnerId,
	},
	RuntimeEnabled = false,
}
check(resolver.resolve(mainWorldAnchor, destinationMismatch).reasonId == "DestinationContentMismatch")

local ownerMissing = table.clone(mainWorldAnchor)
ownerMissing.mutationOwnerId = nil
check(resolver.resolve(ownerMissing, destination).reasonId == "CanonicalOwnerMissing")

local ownerMismatch = table.clone(mainWorldAnchor)
ownerMismatch.mutationOwnerId = "OtherOwner"
check(resolver.resolve(ownerMismatch, destination).reasonId == "CanonicalOwnerMismatch")

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

for _, required in {
	config.MainWorldAnchorId,
	config.CurrentBridgeAnchorId,
	config.PortalContentId,
	config.InteractionIntentId,
	config.CanonicalLaunchAuthorityOwnerId,
} do
	check(string.find(hubSource, required, 1, true) ~= nil, "hub registry drift: " .. required)
end

for _, required in {
	config.PortalContentId,
	config.CanonicalLaunchAuthorityOwnerId,
	"RuntimeEnabled = false",
} do
	check(string.find(destinationSource, required, 1, true) ~= nil, "destination drift: " .. required)
end

check(string.find(bootstrapSource, config.CanonicalLaunchAuthorityOwnerId, 1, true) ~= nil)
check(string.find(bootstrapSource, "ConsequentialAuthorityAllowed = false", 1, true) ~= nil)
check(string.find(resolverSource, "TeleportService", 1, true) == nil)
check(string.find(resolverSource, "RemoteEvent", 1, true) == nil)
check(string.find(resolverSource, "RemoteFunction", 1, true) == nil)
check(string.find(resolverSource, "evaluateEligibility", 1, true) == nil)
check(string.find(resolverSource, "WaitForChild", 1, true) == nil)
