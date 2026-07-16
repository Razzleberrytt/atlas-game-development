--!strict

-- Standalone LK-0405 server-runtime fixtures. The service is intentionally
-- absent from bootstrap and has no client, renderer, or visibility route.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function loadSimple(path: string, debugName: string)
	local chunk = luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {},
		injectGlobals = true,
	})
	return chunk()
end

local config =
	loadSimple("games/living-kingdoms/src/shared/Config/GameplayLightingConfig.luau", "GameplayLightingConfig")
local contracts =
	loadSimple("games/living-kingdoms/src/shared/Lighting/GameplayLightContracts.luau", "GameplayLightContracts")

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local VALIDATOR_TOKEN = {}

local validatorLoader =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Lighting/GameplayLightDescriptorValidator.luau"), {
		debugName = "GameplayLightDescriptorValidator",
		environment = {
			script = {
				Parent = {
					GameplayLightContracts = CONTRACTS_TOKEN,
					Parent = { Config = { GameplayLightingConfig = CONFIG_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == CONTRACTS_TOKEN then
					return contracts
				elseif token == CONFIG_TOKEN then
					return config
				end
				error("unexpected validator dependency")
			end,
		},
		injectGlobals = true,
	})
local validator = validatorLoader()

local now = 0
local scheduled = {}
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
local replicatedStorage = {
	Shared = {
		Config = { GameplayLightingConfig = CONFIG_TOKEN },
		Lighting = {
			GameplayLightContracts = CONTRACTS_TOKEN,
			GameplayLightDescriptorValidator = VALIDATOR_TOKEN,
		},
	},
}

local serviceLoader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/GameplayLightingService.luau"), {
	debugName = "GameplayLightingService",
	environment = {
		game = {
			GetService = function(_self, name)
				return if name == "ReplicatedStorage" then replicatedStorage else workspace
			end,
		},
		require = function(token: unknown)
			if token == CONFIG_TOKEN then
				return config
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == VALIDATOR_TOKEN then
				return validator
			end
			error("unexpected service dependency")
		end,
		task = {
			delay = function(delaySeconds, callback)
				local handle = { delay = delaySeconds, callback = callback, cancelled = false }
				table.insert(scheduled, handle)
				return handle
			end,
			cancel = function(handle)
				handle.cancelled = true
			end,
		},
	},
	injectGlobals = true,
})
local service = serviceLoader()

local function descriptor(sourceId: string, sourceTypeId: string?)
	local actualSourceTypeId = sourceTypeId or "AuthoredEnvironmental"
	return {
		sourceId = sourceId,
		sourceTypeId = actualSourceTypeId,
		visibilityProfileId = "Lit",
		activation = {
			stateId = "Inactive",
			activatedAtServerTimestamp = nil,
			expiresAtServerTimestamp = nil,
		},
		coverage = { kind = "Radius", radiusStuds = 12 },
		ownerEntityId = if actualSourceTypeId == "AuthoredEnvironmental" then nil else "operative.owner",
	}
end

local function snapshot()
	local result = service.readSnapshot()
	assert(result ~= nil, "expected a running snapshot")
	return result
end

local function findRecord(lightId: string)
	for _, record in snapshot().records do
		if record.lightId == lightId then
			return record
		end
	end
	return nil
end

local function reset()
	service.stop()
	service.start()
	now = 0
	table.clear(scheduled)
end

local function activeTimerCount(): number
	local count = 0
	for _, handle in scheduled do
		if not handle.cancelled then
			count += 1
		end
	end
	return count
end

service.start()

-- Registration, duplicate IDs, malformed definitions, profile/source validation, and copied definitions.
local authored = descriptor("source.authored")
local registered = service.registerLight("light.authored", authored)
assert(registered.didChange and registered.revision == 1, "registration did not create one record")
local registeredRecord = findRecord("light.authored")
assert(registeredRecord ~= nil and registeredRecord.activationStateId == "Inactive", "registration state was wrong")
assert(registeredRecord.revision == 1, "registration revision was not deterministic")
assert(
	service.registerLight("light.authored", authored).rejectionReasonId == "DuplicateLightIdentity",
	"duplicate ID accepted"
)
assert(service.registerLight("", authored).rejectionReasonId == "InvalidLightIdentity", "invalid light ID accepted")
assert(
	service.registerLight("light.malformed", {}).rejectionReasonId == "InvalidDescriptor",
	"malformed record accepted"
)
local invalidProfile = descriptor("source.profile")
invalidProfile.visibilityProfileId = "Bright"
assert(
	service.registerLight("light.profile", invalidProfile).rejectionReasonId == "UnknownVisibilityProfile",
	"invalid profile accepted"
)
local invalidSource = descriptor("")
assert(
	service.registerLight("light.source", invalidSource).rejectionReasonId == "InvalidSourceIdentity",
	"invalid source ID accepted"
)
local initiallyActive = descriptor("source.active")
initiallyActive.activation = { stateId = "Active", activatedAtServerTimestamp = 0, expiresAtServerTimestamp = nil }
assert(
	service.registerLight("light.active", initiallyActive).rejectionReasonId == "InvalidActivationState",
	"active registration bypassed activation"
)
authored.sourceId = "source.forged"
authored.visibilityProfileId = "Dark"
assert(
	registeredRecord.sourceId == "source.authored" and registeredRecord.visibilityProfileId == "Lit",
	"caller mutated registration"
)

-- Activation, duplicate activation, manual deactivation, reactivation, and activation revisions.
local activated = service.activateLight("light.authored", 1, nil)
assert(activated.didChange and activated.revision == 2, "permanent activation failed")
local activeRecord = findRecord("light.authored")
assert(
	activeRecord.activationStateId == "Active" and activeRecord.activatedAtServerTimestamp == 1,
	"active state was wrong"
)
assert(
	activeRecord.expiresAtServerTimestamp == nil and activeRecord.revision == 2,
	"permanent activation metadata was wrong"
)
assert(not service.activateLight("light.authored", 1, nil).didChange, "duplicate activation was not silent")
assert(
	service.activateLight("light.authored", 0, nil).rejectionReasonId == "StaleTransition",
	"stale activation accepted"
)
local deactivated = service.deactivateLight("light.authored", 2)
assert(
	deactivated.didChange and findRecord("light.authored").activationStateId == "Inactive",
	"manual deactivation failed"
)
local revisionAfterDeactivation = findRecord("light.authored").revision
assert(not service.deactivateLight("light.authored", 3).didChange, "duplicate deactivation was not silent")
assert(findRecord("light.authored").revision == revisionAfterDeactivation, "silent deactivation advanced revision")
assert(service.activateLight("light.authored", 4, nil).didChange, "reactivation failed")
assert(findRecord("light.authored").revision == revisionAfterDeactivation + 1, "reactivation revision was wrong")

-- Temporary expiration, refresh/replacement, stale callbacks, and centralized scheduling.
reset()
service.registerLight("light.temporary", descriptor("source.temporary", "ApprovedTemporary"))
assert(
	service.activateLight("light.temporary", 10, nil).rejectionReasonId == "InvalidLifetime",
	"permanent temporary light accepted"
)
assert(
	service.activateLight("light.temporary", -1, 10).rejectionReasonId == "InvalidTimestamp",
	"invalid timestamp accepted"
)
assert(
	service.activateLight("light.temporary", 10, 10).rejectionReasonId == "InvalidLifetime",
	"expired activation accepted"
)
local temporaryActivated = service.activateLight("light.temporary", 10, 20)
assert(temporaryActivated.didChange and activeTimerCount() == 1, "temporary activation did not schedule centrally")
local staleTimer = scheduled[#scheduled]
local revisionBeforeRefresh = findRecord("light.temporary").revision
local refreshed = service.activateLight("light.temporary", 12, 22)
assert(
	refreshed.didChange and findRecord("light.temporary").revision == revisionBeforeRefresh + 1,
	"refresh did not replace activation"
)
assert(activeTimerCount() == 1, "refresh created more than one active expiry timer")
now = 20
staleTimer.callback()
assert(findRecord("light.temporary").activationStateId == "Active", "old callback expired refreshed light")
service.evaluateExpiriesAt(21.999)
assert(findRecord("light.temporary").activationStateId == "Active", "light expired before deadline")
local expired = service.evaluateExpiriesAt(22)
assert(expired.didChange and findRecord("light.temporary").activationStateId == "Expired", "timed expiration failed")
assert(findRecord("light.temporary").activatedAtServerTimestamp == nil, "expired activation retained timestamps")
assert(not service.evaluateExpiriesAt(23).didChange, "expired cleanup was not idempotent")
assert(service.activateLight("light.temporary", 24, 34).didChange, "expired light did not reactivate")

-- Budget enforcement is exact, deterministic, and has no overflow.
reset()
for index = 1, config.MaximumActiveGameplayLocalizedLightsPerClientView + 1 do
	local lightId = string.format("light.budget.%02d", index)
	service.registerLight(lightId, descriptor("source." .. lightId))
	local result = service.activateLight(lightId, index, nil)
	if index <= config.MaximumActiveGameplayLocalizedLightsPerClientView then
		assert(result.didChange, "in-budget light was rejected")
	else
		assert(result.rejectionReasonId == "BudgetExceeded", "overflow was not deterministically rejected")
	end
end
local activeCount = 0
for _, record in snapshot().records do
	if record.activationStateId == "Active" then
		activeCount += 1
	end
end
assert(activeCount == config.MaximumActiveGameplayLocalizedLightsPerClientView, "budget overflow changed authority")

-- Immutable reads, subscriber notifications, and subscriber mutation protection.
reset()
local notifications = {}
local subscriberMutationRejected = false
local connection = service.subscribe(function(change)
	change = change
	local ok = pcall(function()
		change.changedRecords[1].sourceId = "source.forged"
	end)
	subscriberMutationRejected = not ok
	table.insert(notifications, change)
end)
assert(connection ~= nil, "subscription failed")
service.registerLight("light.notify", descriptor("source.notify"))
service.activateLight("light.notify", 1, nil)
assert(#notifications == 2 and subscriberMutationRejected, "subscriber did not receive protected changes")
assert(findRecord("light.notify").sourceId == "source.notify", "subscriber mutated authority")
local read = snapshot()
local readMutationSucceeded = pcall(function()
	read.records[1].activationStateId = "Expired"
end)
assert(not readMutationSucceeded, "snapshot was mutable")
assert(findRecord("light.notify").activationStateId == "Active", "read mutated authority")
connection:Disconnect()
service.deactivateLight("light.notify", 2)
assert(#notifications == 2, "disconnected subscriber was notified")

-- Removal, duplicate removal, replacement registration, stop cleanup, and restart.
local removed = service.removeLight("light.notify")
assert(removed.didChange and findRecord("light.notify") == nil, "removal failed")
assert(service.removeLight("light.notify").rejectionReasonId == "UnknownLight", "duplicate removal changed state")
local replacement = descriptor("source.replacement")
assert(service.registerLight("light.notify", replacement).didChange, "removed identity could not be replaced")
assert(findRecord("light.notify").sourceId == "source.replacement", "replacement retained old definition")
local timerBeforeStop = scheduled[#scheduled]
service.stop()
assert(service.readSnapshot() == nil, "stop retained readable state")
assert(service.activateLight("light.notify", 3, nil).rejectionReasonId == "ServiceStopped", "stopped service mutated")
if timerBeforeStop ~= nil then
	now = 100
	timerBeforeStop.callback()
end
service.start()
assert(snapshot().revision == 0 and #snapshot().records == 0, "restart retained state or revisions")

-- Stable replay and same-expiry/light-ID tie ordering are insertion independent.
local function replay(order: { string }): string
	reset()
	local changes = {}
	service.subscribe(function(change)
		if #change.changedRecords > 1 then
			local ids = {}
			for _, record in change.changedRecords do
				table.insert(ids, record.lightId)
			end
			table.insert(changes, table.concat(ids, ","))
		end
	end)
	for _, lightId in order do
		service.registerLight(lightId, descriptor("source." .. lightId, "ApprovedTemporary"))
		service.activateLight(lightId, 1, 10)
	end
	assert(activeTimerCount() == 1, "tie scheduling created multiple timers")
	service.evaluateExpiriesAt(10)
	local states = {}
	for _, record in snapshot().records do
		table.insert(states, string.format("%s:%s:%d", record.lightId, record.activationStateId, record.revision))
	end
	return table.concat(states, "|") .. ";" .. changes[#changes]
end

local forwardReplay = replay({ "light.tie.a", "light.tie.b" })
local reverseReplay = replay({ "light.tie.b", "light.tie.a" })
assert(forwardReplay == reverseReplay, "equivalent replay or tie breaking changed results")
assert(string.find(forwardReplay, "light.tie.a,light.tie.b", 1, true), "expiry tie did not use stable light ID order")

-- Bootstrap, remote-authority, renderer, raycast, visibility, discovery, and runtime-object audits.
local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/GameplayLightingService.luau")
local bootstrapSource = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local projectSource = fs.readFile("games/living-kingdoms/default.project.json")
assert(not string.find(bootstrapSource, "GameplayLightingService", 1, true), "runtime was bootstrapped")
assert(not string.find(projectSource, "GameplayLight", 1, true), "project added a gameplay-light remote")
for _, forbidden in
	{
		"OnServerEvent",
		"RemoteEvent",
		"RemoteFunction",
		"Instance.new",
		"BasePart",
		"Attachment",
		"PointLight",
		"SpotLight",
		"SurfaceLight",
		"Color3",
		"Brightness",
		"Shadows",
		"Raycast",
		"GetParts",
		"VisibilityResolver",
		"DiscoveryMemoryService",
		"TargetCandidateSelector",
		"ParticleEmitter",
	}
do
	assert(not string.find(serviceSource, forbidden, 1, true), "service added excluded runtime concern: " .. forbidden)
end
assert(string.find(serviceSource, "task.cancel", 1, true), "central expiry timer was not cancellable")
assert(string.find(serviceSource, "timerGeneration", 1, true), "stale timer generation guard missing")

service.stop()
assert(activeTimerCount() == 0, "stop leaked an active expiry timer")

print("GameplayLightingService: LK-0405 ownership, lifecycle, budget, replay, security, and scope fixtures passed")
