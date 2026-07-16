--!strict

-- Standalone LK-0404 server-runtime fixtures. The production service remains
-- unbootstrapped and exposes no client request or replication boundary.
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

local perceptionContracts =
	loadSimple("games/living-kingdoms/src/shared/Perception/PerceptionContracts.luau", "PerceptionContracts")
local visibilityContracts =
	loadSimple("games/living-kingdoms/src/shared/Perception/VisibilityContracts.luau", "VisibilityContracts")
local lightContracts =
	loadSimple("games/living-kingdoms/src/shared/Lighting/GameplayLightContracts.luau", "GameplayLightContracts")
local perceptionConfig = loadSimple("games/living-kingdoms/src/shared/Config/PerceptionConfig.luau", "PerceptionConfig")

local PERCEPTION_TOKEN = {}
local VISIBILITY_TOKEN = {}
local LIGHT_TOKEN = {}
local CONFIG_TOKEN = {}
local VALIDATOR_TOKEN = {}
local RESOLVER_TOKEN = {}

local validatorLoader =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Perception/PerceptionContractsValidator.luau"), {
		debugName = "PerceptionContractsValidator",
		environment = {
			script = {
				Parent = {
					PerceptionContracts = PERCEPTION_TOKEN,
					Parent = { Config = { PerceptionConfig = CONFIG_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == PERCEPTION_TOKEN then
					return perceptionContracts
				elseif token == CONFIG_TOKEN then
					return perceptionConfig
				end
				error("unexpected validator dependency")
			end,
		},
		injectGlobals = true,
	})
local validator = validatorLoader()

local resolverLoader = luau.load(fs.readFile("games/living-kingdoms/src/shared/Perception/VisibilityResolver.luau"), {
	debugName = "VisibilityResolver",
	environment = {
		script = {
			Parent = {
				PerceptionContracts = PERCEPTION_TOKEN,
				VisibilityContracts = VISIBILITY_TOKEN,
				Parent = {
					Lighting = { GameplayLightContracts = LIGHT_TOKEN },
					Config = { PerceptionConfig = CONFIG_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			if token == PERCEPTION_TOKEN then
				return perceptionContracts
			elseif token == VISIBILITY_TOKEN then
				return visibilityContracts
			elseif token == LIGHT_TOKEN then
				return lightContracts
			elseif token == CONFIG_TOKEN then
				return perceptionConfig
			end
			error("unexpected resolver dependency")
		end,
	},
	injectGlobals = true,
})
local resolver = resolverLoader()

local now = 0
local scheduled = {}
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
local replicatedStorage = {
	Shared = {
		Config = { PerceptionConfig = CONFIG_TOKEN },
		Perception = {
			PerceptionContracts = PERCEPTION_TOKEN,
			PerceptionContractsValidator = VALIDATOR_TOKEN,
			VisibilityResolver = RESOLVER_TOKEN,
		},
	},
}

local serviceLoader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/DiscoveryMemoryService.luau"), {
	debugName = "DiscoveryMemoryService",
	environment = {
		game = {
			GetService = function(_self, name)
				return if name == "ReplicatedStorage" then replicatedStorage else workspace
			end,
		},
		require = function(token: unknown)
			if token == PERCEPTION_TOKEN then
				return perceptionContracts
			elseif token == CONFIG_TOKEN then
				return perceptionConfig
			elseif token == VALIDATOR_TOKEN then
				return validator
			elseif token == RESOLVER_TOKEN then
				return resolver
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

local function facts(recipientId: string, candidateId: string)
	return {
		observerEntityId = recipientId,
		candidateEntityId = candidateId,
		observerCanPerceive = true,
		candidateCategoryId = "Hostile",
		candidateIsGameplayPresent = true,
		candidateIsAlive = true,
		candidateIsTargetable = true,
		relationshipId = "Hostile",
		illuminationFacts = {
			visibilityProfileId = "Lit",
			hasQualifyingLocalLightCoverage = false,
		},
		spatialFacts = {
			distanceSquaredStuds = 100,
			perceptualRegionId = "Forward",
			hasConsequentialLineOfSight = true,
		},
		disclosureStateId = "Disclosed",
	}
end

local function apply(recipientId: string, candidateId: string, candidateFacts: any, timestamp: number)
	local resolution = resolver.resolve(candidateFacts)
	return service.applyVisibilityResolution(recipientId, candidateId, candidateFacts, resolution, timestamp)
end

local function observe(recipientId: string, candidateId: string, timestamp: number)
	return apply(recipientId, candidateId, facts(recipientId, candidateId), timestamp)
end

local function lose(recipientId: string, candidateId: string, timestamp: number)
	local candidateFacts = facts(recipientId, candidateId)
	candidateFacts.spatialFacts.perceptualRegionId = "Outside"
	return apply(recipientId, candidateId, candidateFacts, timestamp)
end

local function snapshot(recipientId: string)
	local result = service.readRecipientSnapshot(recipientId)
	assert(result ~= nil, "expected registered recipient snapshot")
	return result
end

local function findRecord(recipientId: string, candidateId: string)
	for _, record in snapshot(recipientId).records do
		if record.observedEntityId == candidateId then
			return record
		end
	end
	return nil
end

local function reset(recipientIds: { string })
	service.stop()
	service.start()
	now = 0
	for _, recipientId in recipientIds do
		local registered = service.registerRecipient(recipientId)
		assert(registered.didChange and registered.snapshot ~= nil, "recipient registration failed")
	end
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

-- 1–6: registration, copied reads, deterministic duplicate registration, and isolation.
local registered = service.registerRecipient("operative.alpha")
assert(registered.snapshot.revision == 0 and #registered.snapshot.records == 0, "registration was not empty")
registered.snapshot.records[1] = { observedEntityId = "forged" }
assert(#snapshot("operative.alpha").records == 0, "copied registration read mutated authority")
local duplicateRegistration = service.registerRecipient("operative.alpha")
assert(
	not duplicateRegistration.didChange and duplicateRegistration.revision == 0,
	"duplicate registration changed state"
)
local unknown = observe("operative.unknown", "hostile.a", 0)
assert(unknown.rejectionReasonId == "UnknownRecipient", "unknown recipient operation did not reject")
service.registerRecipient("operative.beta")
observe("operative.alpha", "hostile.a", 0)
assert(service.unregisterRecipient("operative.alpha"), "registered recipient did not unregister")
assert(
	snapshot("operative.beta") ~= nil and service.readRecipientSnapshot("operative.alpha") == nil,
	"wrong recipient cleared"
)
service.registerRecipient("operative.late")
assert(#snapshot("operative.late").records == 0, "late registration inherited hidden knowledge")

-- 7–19: canonical current observations and fail-closed resolver correlation.
reset({ "operative.alpha" })
local notifications = {}
local connection = service.subscribeRecipient("operative.alpha", function(change)
	table.insert(notifications, change)
	if #change.changedRecords > 0 then
		change.changedRecords[1].confidenceId = "Low"
	end
end)
assert(connection ~= nil, "known recipient subscription failed")
local hiddenFacts = facts("operative.alpha", "hostile.current")
hiddenFacts.disclosureStateId = "Hidden"
local created = apply("operative.alpha", "hostile.current", hiddenFacts, 10)
local current = findRecord("operative.alpha", "hostile.current")
assert(created.didChange and current ~= nil, "accepted DirectSight did not create current disclosure")
assert(current.disclosureStateId == "Disclosed" and current.perceptionStateId == "Observed", "current state incorrect")
assert(
	current.memoryStateId == "None" and current.observationSourceId == "DirectSight",
	"current source/memory incorrect"
)
assert(current.confidenceId == "High" and current.observedAtServerTimestamp == 10, "confidence/timestamp incorrect")
assert(findRecord("operative.alpha", "hostile.current").confidenceId == "High", "subscriber mutated authority")
current.confidenceId = "Low"
assert(findRecord("operative.alpha", "hostile.current").confidenceId == "High", "copied read mutated authority")
assert(
	#notifications == 1 and #notifications[1].changedRecords == 1 and #notifications[1].removedObservedEntityIds == 0,
	"subscriber did not receive only the changed copied record"
)
local revisionAfterCreate = snapshot("operative.alpha").revision
local repeated = apply("operative.alpha", "hostile.current", hiddenFacts, 10)
assert(not repeated.didChange and #notifications == 1, "equivalent observation duplicated a change")
local newerFacts = facts("operative.alpha", "hostile.current")
newerFacts.illuminationFacts.visibilityProfileId = "Dim"
local newer = apply("operative.alpha", "hostile.current", newerFacts, 11)
assert(
	newer.didChange and findRecord("operative.alpha", "hostile.current").confidenceId == "Medium",
	"newer state lost"
)
local stale = apply("operative.alpha", "hostile.current", hiddenFacts, 10)
assert(stale.rejectionReasonId == "StaleObservation", "older observation replaced newer state")
assert(snapshot("operative.alpha").revision == revisionAfterCreate + 1, "rejection changed revision")
local mismatchRecipientFacts = facts("operative.beta", "hostile.current")
local mismatchRecipient = service.applyVisibilityResolution(
	"operative.alpha",
	"hostile.current",
	mismatchRecipientFacts,
	resolver.resolve(mismatchRecipientFacts),
	12
)
assert(mismatchRecipient.rejectionReasonId == "RecipientMismatch", "recipient mismatch accepted")
local mismatchCandidateFacts = facts("operative.alpha", "hostile.facts")
local mismatchCandidate = service.applyVisibilityResolution(
	"operative.alpha",
	"hostile.argument",
	mismatchCandidateFacts,
	resolver.resolve(mismatchCandidateFacts),
	12
)
assert(mismatchCandidate.rejectionReasonId == "CandidateMismatch", "candidate mismatch accepted")
local lightOnlyFacts = facts("operative.alpha", "hostile.light")
lightOnlyFacts.illuminationFacts.visibilityProfileId = "Dark"
lightOnlyFacts.illuminationFacts.hasQualifyingLocalLightCoverage = true
lightOnlyFacts.spatialFacts.hasConsequentialLineOfSight = false
assert(not apply("operative.alpha", "hostile.light", lightOnlyFacts, 12).didChange, "light coverage created discovery")
local outsideFacts = facts("operative.alpha", "hostile.outside")
outsideFacts.spatialFacts.perceptualRegionId = "Outside"
local forgedTargetResolution = table.clone(resolver.resolve(outsideFacts))
forgedTargetResolution.isTargetingVisible = true
local targetOnly =
	service.applyVisibilityResolution("operative.alpha", "hostile.outside", outsideFacts, forgedTargetResolution, 12)
assert(targetOnly.rejectionReasonId == "InvalidVisibilityResolution", "target-visible alone created discovery")
local peripheralFacts = facts("operative.alpha", "hostile.peripheral")
peripheralFacts.spatialFacts.perceptualRegionId = "Peripheral"
assert(
	not apply("operative.alpha", "hostile.peripheral", peripheralFacts, 12).didChange,
	"peripheral identity disclosed"
)
assert(findRecord("operative.alpha", "hostile.peripheral") == nil, "anonymous suspicion became exact identity")
local forgedPeripheralResolution = table.clone(resolver.resolve(peripheralFacts))
forgedPeripheralResolution.isGameplayVisible = true
forgedPeripheralResolution.perceptionStateId = "Observed"
forgedPeripheralResolution.canCreateDirectSightObservation = true
assert(
	service.applyVisibilityResolution(
		"operative.alpha",
		"hostile.peripheral",
		peripheralFacts,
		forgedPeripheralResolution,
		12
	).rejectionReasonId == "InvalidVisibilityResolution",
	"peripheral-only result was upgraded to DirectSight"
)
assert(not apply("operative.alpha", "hostile.outside", outsideFacts, 12).didChange, "Unknown result stored disclosure")

-- Invalid input/result operations leave authority unchanged and inputs untouched.
local beforeInvalid = snapshot("operative.alpha")
local malformed = service.applyVisibilityResolution("operative.alpha", "hostile.bad", {}, {}, -1)
assert(malformed.rejectionReasonId == "InvalidTimestamp", "invalid timestamp precedence changed")
assert(snapshot("operative.alpha").revision == beforeInvalid.revision, "malformed input mutated authority")
local immutableFacts = facts("operative.alpha", "hostile.immutable")
local immutableResolution = resolver.resolve(immutableFacts)
service.applyVisibilityResolution("operative.alpha", "hostile.immutable", immutableFacts, immutableResolution, 13)
assert(immutableFacts.disclosureStateId == "Disclosed" and immutableResolution.isValid, "service mutated caller input")

-- 20–28: current-to-stale memory, exact boundary, refresh, stale callbacks, and idempotent expiry.
reset({ "operative.alpha" })
observe("operative.alpha", "hostile.memory", 0)
local changedToMemory = lose("operative.alpha", "hostile.memory", 1)
local remembered = findRecord("operative.alpha", "hostile.memory")
assert(changedToMemory.didChange and remembered.memoryStateId == "Remembered", "loss did not transition to memory")
assert(
	remembered.perceptionStateId == "Observed" and remembered.expiresAtServerTimestamp == 30,
	"memory not explicitly stale"
)
assert(remembered.isTargetingVisible == nil and remembered.isTargetable == nil, "memory exposed target eligibility")
assert(not lose("operative.alpha", "hostile.memory", 5).didChange, "non-visible result refreshed memory")
assert(findRecord("operative.alpha", "hostile.memory").expiresAtServerTimestamp == 30, "memory expiry was refreshed")
service.evaluateExpiriesAt(30)
assert(findRecord("operative.alpha", "hostile.memory") ~= nil, "exact age boundary expired early")
local beforeExpiryRevision = snapshot("operative.alpha").revision
local expired = service.evaluateExpiriesAt(30.001)
assert(expired.didChange and findRecord("operative.alpha", "hostile.memory") == nil, "memory survived age boundary")
assert(snapshot("operative.alpha").revision == beforeExpiryRevision + 1, "expiry did not increment once")
assert(not service.evaluateExpiriesAt(31).didChange, "repeated cleanup was not idempotent")

reset({ "operative.alpha" })
observe("operative.alpha", "hostile.refresh", 0)
lose("operative.alpha", "hostile.refresh", 1)
local staleTimer = scheduled[#scheduled]
local refreshed = observe("operative.alpha", "hostile.refresh", 2)
assert(
	refreshed.didChange and findRecord("operative.alpha", "hostile.refresh").memoryStateId == "None",
	"sight did not refresh memory"
)
now = 31
staleTimer.callback()
assert(findRecord("operative.alpha", "hostile.refresh") ~= nil, "stale expiry deleted refreshed observation")

-- 29–35: age-first, oldest-first, stable-ID bounded eviction and one active timer.
local function boundedResult(insertionOrder: { string }): { string }
	reset({ "operative.bound" })
	observe("operative.bound", "hostile.current.keep", 0)
	for _, candidateId in insertionOrder do
		observe("operative.bound", candidateId, 0)
	end
	for _, candidateId in insertionOrder do
		lose("operative.bound", candidateId, 1)
	end
	local result = {}
	local rememberedCount = 0
	for _, record in snapshot("operative.bound").records do
		if record.memoryStateId == "Remembered" then
			rememberedCount += 1
			table.insert(result, record.observedEntityId)
		end
	end
	assert(rememberedCount == 32, "remembered table exceeded canonical maximum")
	assert(
		findRecord("operative.bound", "hostile.current.keep").memoryStateId == "None",
		"current sight evicted for memory"
	)
	assert(activeTimerCount() == 1, "runtime created more than one active expiry timer")
	return result
end

local ascending = {}
for index = 1, 33 do
	table.insert(ascending, string.format("hostile.tie.%02d", index))
end
local descending = table.clone(ascending)
table.sort(descending, function(left, right)
	return left > right
end)
local ascendingResult = boundedResult(ascending)
local descendingResult = boundedResult(descending)
assert(ascendingResult[1] == "hostile.tie.02", "stable entity-ID tie break evicted wrong record")
assert(table.concat(ascendingResult, ",") == table.concat(descendingResult, ","), "insertion order changed eviction")

reset({ "operative.oldest" })
observe("operative.oldest", "hostile.oldest", 0)
for index = 1, 32 do
	observe("operative.oldest", string.format("hostile.new.%02d", index), 1)
end
lose("operative.oldest", "hostile.oldest", 2)
for index = 1, 32 do
	lose("operative.oldest", string.format("hostile.new.%02d", index), 2)
end
assert(findRecord("operative.oldest", "hostile.oldest") == nil, "oldest memory was not evicted first")

reset({ "operative.expired" })
observe("operative.expired", "hostile.expired", 0)
lose("operative.expired", "hostile.expired", 1)
for index = 1, 32 do
	observe("operative.expired", string.format("hostile.live.%02d", index), 31)
	lose("operative.expired", string.format("hostile.live.%02d", index), 32)
end
assert(findRecord("operative.expired", "hostile.expired") == nil, "expired memory was not removed before capacity")

-- 36–44: recipient isolation, entity cleanup, teardown, and copied changed disclosures.
reset({ "operative.a", "operative.b" })
local changesA = {}
local changesB = {}
service.subscribeRecipient("operative.a", function(change)
	table.insert(changesA, change)
	change.removedObservedEntityIds[1] = "forged"
end)
service.subscribeRecipient("operative.b", function(change)
	table.insert(changesB, change)
end)
observe("operative.a", "hostile.shared", 0)
assert(findRecord("operative.b", "hostile.shared") == nil, "A disclosed hostile to B")
observe("operative.b", "hostile.other", 1)
lose("operative.a", "hostile.shared", 1)
service.evaluateExpiriesAt(30.001)
assert(findRecord("operative.b", "hostile.other") ~= nil, "A expiry altered B")
observe("operative.a", "hostile.remove", 31)
observe("operative.b", "hostile.remove", 31)
assert(service.removeObservedEntity("hostile.remove"), "entity removal reported no change")
assert(
	findRecord("operative.a", "hostile.remove") == nil and findRecord("operative.b", "hostile.remove") == nil,
	"entity removal was not global"
)
assert(not service.removeObservedEntity("hostile.remove"), "duplicate entity removal changed state")
assert(#changesA > 0 and #changesB > 0, "recipient subscribers missed changes")
assert(changesA[1].recipientEntityId == "operative.a", "subscriber received another recipient")
for _, record in snapshot("operative.a").records do
	assert(record.disclosureStateId ~= "Hidden", "hidden record appeared in snapshot")
end
service.stop()
assert(service.readRecipientSnapshot("operative.a") == nil, "teardown retained recipient state")
assert(
	service.applyVisibilityResolution("operative.a", "hostile.after", {}, {}, 32).rejectionReasonId == "ServiceStopped",
	"stopped commit accepted"
)
local revisionBeforeStaleCallback = #changesA
now = 100
staleTimer.callback()
assert(#changesA == revisionBeforeStaleCallback, "stopped stale callback notified subscriber")

-- 45–60: contract compatibility and source/security/scope audits.
reset({ "operative.audit" })
observe("operative.audit", "hostile.audit.current", 10)
observe("operative.audit", "hostile.audit.memory", 10)
lose("operative.audit", "hostile.audit.memory", 11)
for _, record in snapshot("operative.audit").records do
	local evaluationTimestamp = record.expiresAtServerTimestamp or record.observedAtServerTimestamp
	assert(validator.validate(record, evaluationTimestamp).isValid, "stored combination failed LK-0402 validation")
	assert(record.observationSourceId == "DirectSight", "non-DirectSight source entered runtime")
	assert(record.observationSourceId ~= "ApprovedGameplayLight", "gameplay light became observation source")
	assert(record.isTargetingVisible == nil and record.candidateIsTargetable == nil, "record granted targeting")
end

local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/DiscoveryMemoryService.luau")
local bootstrapSource = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local projectSource = fs.readFile("games/living-kingdoms/default.project.json")
assert(not string.find(serviceSource, "OnServerEvent", 1, true), "service added client mutation handler")
assert(not string.find(serviceSource, "RemoteEvent", 1, true), "service added replication/client request remote")
assert(not string.find(serviceSource, "RemoteFunction", 1, true), "service added client function route")
assert(not string.find(serviceSource, "Raycast", 1, true), "service added raycast")
assert(not string.find(serviceSource, "GetParts", 1, true), "service added spatial renderer query")
assert(not string.find(serviceSource, "Lighting", 1, true), "service added lighting runtime")
assert(not string.find(serviceSource, "Vector3", 1, true), "service invented exact spatial memory")
assert(not string.find(serviceSource, "Enemy", 1, true), "service added enemy AI")
assert(not string.find(bootstrapSource, "DiscoveryMemoryService", 1, true), "service was production-bootstrapped")
assert(not string.find(projectSource, "Discovery", 1, true), "project added discovery remote")
assert(not string.find(serviceSource, "TeammateInformation", 1, true), "teammate information gained runtime sight")
assert(not string.find(serviceSource, "AuthoredObjective", 1, true), "objective information gained hostile sight")
assert(string.find(serviceSource, "task.cancel", 1, true), "central timer was not cancellable")
assert(string.find(serviceSource, "timerGeneration", 1, true), "stale timer generation guard missing")
assert(activeTimerCount() == 1, "bootstrap/runtime audit found duplicate active timer")

local resolverSourceAfter = fs.readFile("games/living-kingdoms/src/shared/Perception/VisibilityResolver.luau")
assert(string.find(resolverSourceAfter, "VisibilityResolver.resolve", 1, true), "LK-0403 resolver changed unexpectedly")
assert(not string.find(serviceSource, "TargetCandidateSelector", 1, true), "P2 target flow was coupled to discovery")
assert(not string.find(serviceSource, "OperativeLifeRuntimeService", 1, true), "P3 runtime was coupled to discovery")

local repeatedFacts = facts("operative.audit", "hostile.repeat")
local repeatedResolution = resolver.resolve(repeatedFacts)
local firstRepeat =
	service.applyVisibilityResolution("operative.audit", "hostile.repeat", repeatedFacts, repeatedResolution, 12)
local secondRepeat =
	service.applyVisibilityResolution("operative.audit", "hostile.repeat", repeatedFacts, repeatedResolution, 12)
assert(firstRepeat.didChange and not secondRepeat.didChange, "repeated calls were not deterministic")

service.stop()
assert(activeTimerCount() == 0, "service teardown leaked active timer")

print("DiscoveryMemoryService: LK-0404 ownership, memory, isolation, replay, security, and scope fixtures passed")
