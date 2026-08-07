--!strict

-- Standalone LK-0402 contract/configuration/validator fixtures. Production
-- modules load without Roblox runtime or a server/client bootstrap.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local contractsPath = "games/living-kingdoms/src/shared/Perception/PerceptionContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/PerceptionConfig.luau"
local validatorPath = "games/living-kingdoms/src/shared/Perception/PerceptionContractsValidator.luau"

local function loadStandalone(path: string, debugName: string)
	local loader = luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})
	return loader()
end

local contracts = loadStandalone(contractsPath, "PerceptionContracts")
local config = loadStandalone(configPath, "PerceptionConfig")
local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local validatorLoader = luau.load(fs.readFile(validatorPath), {
	debugName = "PerceptionContractsValidator",
	environment = {
		script = {
			Parent = {
				PerceptionContracts = CONTRACTS_TOKEN,
				Parent = { Config = { PerceptionConfig = CONFIG_TOKEN } },
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

local function assertExactIds(actual: { [string]: string }, expected: { [string]: string }, context: string)
	local actualCount = 0
	for key, value in actual do
		actualCount += 1
		assert(expected[key] == value, context .. ": unexpected ID")
	end

	local expectedCount = 0
	for _ in expected do
		expectedCount += 1
	end
	assert(actualCount == expectedCount, context .. ": wrong ID count")
end

assertExactIds(contracts.PerceptionStateIds, {
	Unknown = "Unknown",
	Suspected = "Suspected",
	Observed = "Observed",
}, "perception states")
assertExactIds(contracts.DisclosureStateIds, {
	Hidden = "Hidden",
	Disclosed = "Disclosed",
}, "disclosure states")
assertExactIds(contracts.MemoryStateIds, {
	None = "None",
	Remembered = "Remembered",
}, "memory states")
assertExactIds(contracts.ObservationConfidenceIds, {
	Low = "Low",
	Medium = "Medium",
	High = "High",
}, "observation confidence")
assertExactIds(contracts.ObservationSourceIds, {
	DirectSight = "DirectSight",
	TeammateInformation = "TeammateInformation",
	AuthoredObjective = "AuthoredObjective",
}, "observation sources")
assertExactIds(contracts.PerceptionRejectionReasonIds, {
	InvalidRecord = "InvalidRecord",
	InvalidEntity = "InvalidEntity",
	InvalidSource = "InvalidSource",
	InvalidDisclosure = "InvalidDisclosure",
	InvalidPerception = "InvalidPerception",
	InvalidMemory = "InvalidMemory",
	InvalidConfidence = "InvalidConfidence",
	InvalidStateCombination = "InvalidStateCombination",
	InvalidTimestamp = "InvalidTimestamp",
	StaleObservation = "StaleObservation",
}, "rejection reasons")

assert(table.isfrozen(contracts), "contracts module must be frozen")
for _, tableName in
	{
		"PerceptionStateIds",
		"DisclosureStateIds",
		"MemoryStateIds",
		"ObservationConfidenceIds",
		"ObservationSourceIds",
		"PerceptionRejectionReasonIds",
	}
do
	assert(table.isfrozen(contracts[tableName]), tableName .. " must be frozen")
end
local vocabularyMutationSucceeded = pcall(function()
	contracts.PerceptionStateIds.Unknown = "Changed"
end)
assert(not vocabularyMutationSucceeded, "frozen vocabulary must reject mutation")

assert(table.isfrozen(config), "configuration must be frozen")
assert(table.isfrozen(config.SupportedPerceptionStateIds), "configured perception IDs must be frozen")
assert(table.isfrozen(config.SupportedObservationConfidenceIds), "configured confidence IDs must be frozen")
assert(config.MaximumRememberedObservationsPerOperative == 32, "remembered-observation bound changed")
assert(config.MaximumObservationAgeSeconds == 30, "observation-age bound changed")
assertExactIds(config.SupportedPerceptionStateIds, contracts.PerceptionStateIds, "configured perception states")
assertExactIds(config.SupportedObservationConfidenceIds, contracts.ObservationConfidenceIds, "configured confidence")

local function observation(sourceId: string)
	return {
		observedEntityId = "entity.hostile-alpha",
		observationSourceId = sourceId,
		disclosureStateId = "Disclosed",
		perceptionStateId = "Observed",
		memoryStateId = "None",
		confidenceId = "High",
		observedAtServerTimestamp = 100,
	}
end

local function assertAccepted(record: any, evaluationServerTimestamp: any)
	local result = validator.validate(record, evaluationServerTimestamp)
	assert(result.isValid == true, "observation should be accepted")
	assert(result.rejectionReasonId == nil, "accepted observation cannot have a rejection reason")
	assert(table.isfrozen(result), "evaluation must be frozen")
	return result
end

local function assertRejected(record: any, evaluationServerTimestamp: any, expectedReason: string)
	local result = validator.validate(record, evaluationServerTimestamp)
	assert(result.isValid == false, "observation should be rejected")
	assert(result.rejectionReasonId == expectedReason, "unexpected rejection reason")
	assert(table.isfrozen(result), "evaluation must be frozen")
	return result
end

local directSight = observation("DirectSight")
assertAccepted(directSight, 100)
assert(directSight.rendererState == nil, "direct sight cannot encode renderer authority")
assert(directSight.visibilityProfileId == nil, "direct sight cannot encode gameplay-light authority")
assert(directSight.gameplayLightCoverage == nil, "direct sight cannot encode light coverage")

local teammateInformation = observation("TeammateInformation")
teammateInformation.observedEntityId = "operative.bravo"
assertAccepted(teammateInformation, 110)
assert(teammateInformation.lineOfSight == nil, "teammate information cannot encode line-of-sight authority")
assert(teammateInformation.targetEligible == nil, "teammate information cannot encode targeting authority")

local authoredObjective = observation("AuthoredObjective")
authoredObjective.observedEntityId = "objective.generator-room"
assertAccepted(authoredObjective, 130)
assert(authoredObjective.hostileTargetEligible == nil, "authored objective cannot encode hostile targeting authority")
assert(authoredObjective.lineOfSight == nil, "authored objective cannot encode line-of-sight authority")

local direct = observation("DirectSight")
local firstResult = assertAccepted(direct, 120)
local secondResult = assertAccepted(direct, 120)
assert(firstResult.isValid == secondResult.isValid, "repeat validation changed acceptance")
assert(firstResult.rejectionReasonId == secondResult.rejectionReasonId, "repeat validation changed reason")
assert(direct.observedEntityId == "entity.hostile-alpha", "validator mutated record")
assert(direct.observedAtServerTimestamp == 100, "validator mutated timestamp")
assert(not table.isfrozen(direct), "validator must not freeze caller record")

local nestedSentinel = { marker = { value = "unchanged" } }
local recordWithNestedSentinel = observation("DirectSight")
recordWithNestedSentinel.callerMetadata = nestedSentinel
assertAccepted(recordWithNestedSentinel, 100)
assert(recordWithNestedSentinel.callerMetadata == nestedSentinel, "validator replaced nested caller data")
assert(nestedSentinel.marker.value == "unchanged", "validator mutated nested caller data")
assert(not table.isfrozen(nestedSentinel), "validator must not freeze nested caller data")
assert(not table.isfrozen(nestedSentinel.marker), "validator must not freeze nested descendants")

assertRejected(nil, 100, "InvalidRecord")
local invalid = observation("DirectSight")
invalid.observedEntityId = ""
assertRejected(invalid, 100, "InvalidEntity")
invalid = observation("Hearing")
assertRejected(invalid, 100, "InvalidSource")
invalid = observation("ApprovedGameplayLight")
assertRejected(invalid, 100, "InvalidSource")
invalid = observation("DirectSight")
invalid.disclosureStateId = "Partial"
assertRejected(invalid, 100, "InvalidDisclosure")
invalid = observation("DirectSight")
invalid.perceptionStateId = "Visible"
assertRejected(invalid, 100, "InvalidPerception")
invalid = observation("DirectSight")
invalid.memoryStateId = "Forgotten"
assertRejected(invalid, 100, "InvalidMemory")
invalid = observation("DirectSight")
invalid.confidenceId = "Certain"
assertRejected(invalid, 100, "InvalidConfidence")

invalid = observation("DirectSight")
invalid.perceptionStateId = "Unknown"
assertRejected(invalid, 100, "InvalidStateCombination")
invalid = observation("DirectSight")
invalid.perceptionStateId = "Unknown"
invalid.memoryStateId = "Remembered"
invalid.confidenceId = "Low"
assertRejected(invalid, 100, "InvalidStateCombination")

local rememberedSuspected = observation("TeammateInformation")
rememberedSuspected.perceptionStateId = "Suspected"
rememberedSuspected.memoryStateId = "Remembered"
rememberedSuspected.confidenceId = "Medium"
assertAccepted(rememberedSuspected, 100)

local hiddenRememberedSuspected = observation("TeammateInformation")
hiddenRememberedSuspected.disclosureStateId = "Hidden"
hiddenRememberedSuspected.perceptionStateId = "Suspected"
hiddenRememberedSuspected.memoryStateId = "Remembered"
hiddenRememberedSuspected.confidenceId = "Low"
assertAccepted(hiddenRememberedSuspected, 100)

local rememberedObserved = observation("DirectSight")
rememberedObserved.memoryStateId = "Remembered"
assertAccepted(rememberedObserved, 100)

invalid = observation("DirectSight")
invalid.perceptionStateId = "Unknown"
invalid.confidenceId = "Certain"
assertRejected(invalid, -1, "InvalidConfidence")
invalid.confidenceId = "High"
local firstCombinationResult = assertRejected(invalid, -1, "InvalidStateCombination")
local secondCombinationResult = assertRejected(invalid, -1, "InvalidStateCombination")
assert(firstCombinationResult.isValid == secondCombinationResult.isValid, "combination acceptance changed")
assert(
	firstCombinationResult.rejectionReasonId == secondCombinationResult.rejectionReasonId,
	"combination precedence changed"
)

for _, timestamp in { -1, 0 / 0, math.huge, -math.huge, "now" } do
	invalid = observation("DirectSight")
	invalid.observedAtServerTimestamp = timestamp
	assertRejected(invalid, 100, "InvalidTimestamp")
	assertRejected(observation("DirectSight"), timestamp, "InvalidTimestamp")
end
invalid = observation("DirectSight")
invalid.observedAtServerTimestamp = 101
assertRejected(invalid, 100, "InvalidTimestamp")

assertAccepted(observation("DirectSight"), 130)
assertRejected(observation("DirectSight"), 130.001, "StaleObservation")

invalid = observation("Hearing")
invalid.observedEntityId = ""
invalid.disclosureStateId = "Partial"
invalid.perceptionStateId = "Visible"
invalid.memoryStateId = "Forgotten"
invalid.confidenceId = "Certain"
invalid.observedAtServerTimestamp = -1
assertRejected(invalid, -1, "InvalidEntity")

local contractSource = fs.readFile(contractsPath)
local configSource = fs.readFile(configPath)
local validatorSource = fs.readFile(validatorPath)
local combinedSource = contractSource .. configSource .. validatorSource
for _, forbidden in
	{
		"Player",
		"Model",
		"Character",
		"Instance",
		"Humanoid",
		"RemoteEvent",
		"RemoteFunction",
		"Bootstrap",
		"Raycast",
		"LineOfSight",
	}
do
	assert(not string.find(combinedSource, forbidden, 1, true), "forbidden runtime concept: " .. forbidden)
end

print("PerceptionContracts: LK-0402 vocabulary, config, validation, boundaries, and immutability passed")
