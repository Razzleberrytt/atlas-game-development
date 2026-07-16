--!strict

-- Standalone LK-0401 contract/configuration/validator fixtures. Production
-- modules load without Roblox runtime or a server/client bootstrap.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local contractsPath = "games/living-kingdoms/src/shared/Lighting/GameplayLightContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/GameplayLightingConfig.luau"
local validatorPath = "games/living-kingdoms/src/shared/Lighting/GameplayLightDescriptorValidator.luau"

local function loadStandalone(path: string, debugName: string)
	local loader = luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})
	return loader()
end

local contracts = loadStandalone(contractsPath, "GameplayLightContracts")
local config = loadStandalone(configPath, "GameplayLightingConfig")
local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local validatorLoader = luau.load(fs.readFile(validatorPath), {
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

assertExactIds(contracts.VisibilityProfileIds, {
	Dark = "Dark",
	Dim = "Dim",
	Lit = "Lit",
}, "visibility profiles")
assertExactIds(contracts.GameplayLightSourceTypeIds, {
	AuthoredEnvironmental = "AuthoredEnvironmental",
	ApprovedPersonal = "ApprovedPersonal",
	ApprovedTemporary = "ApprovedTemporary",
}, "source types")
assertExactIds(contracts.GameplayLightActivationStateIds, {
	Inactive = "Inactive",
	Active = "Active",
	Expired = "Expired",
}, "activation states")
assertExactIds(contracts.GameplayLightCoverageKindIds, {
	Radius = "Radius",
	ForwardCone = "ForwardCone",
	AuthoredZone = "AuthoredZone",
}, "coverage kinds")
assertExactIds(contracts.GameplayLightRejectionReasonIds, {
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
}, "rejection reasons")

assert(table.isfrozen(contracts), "contracts module must be frozen")
for _, tableName in
	{
		"VisibilityProfileIds",
		"GameplayLightSourceTypeIds",
		"GameplayLightActivationStateIds",
		"GameplayLightCoverageKindIds",
		"GameplayLightRejectionReasonIds",
	}
do
	assert(table.isfrozen(contracts[tableName]), tableName .. " must be frozen")
end
local vocabularyMutationSucceeded = pcall(function()
	contracts.VisibilityProfileIds.Dark = "Changed"
end)
assert(not vocabularyMutationSucceeded, "frozen vocabulary must reject mutation")

assert(table.isfrozen(config), "configuration must be frozen")
assert(table.isfrozen(config.SupportedVisibilityProfileIds), "supported profiles must be frozen")
assertExactIds(config.SupportedVisibilityProfileIds, {
	Dark = "Dark",
	Dim = "Dim",
	Lit = "Lit",
}, "configured visibility profiles")
assert(config.MaximumActiveGameplayLocalizedLightsPerClientView == 8, "gameplay-light budget changed")
assert(config.MaximumShadowCastingDynamicLightsPerClientView == 2, "shadow-light budget changed")
assert(config.MaximumCosmeticDynamicLightsPerClientView == 24, "cosmetic-light budget changed")
assert(config.MaximumTemporaryLightParticlesPerClientView == 40, "temporary particle budget changed")
assert(
	config.MaximumConsequentialLineOfSightChecksPerOperativePerSecond == 10,
	"per-operative line-of-sight budget changed"
)
assert(config.GlobalFourOperativeLineOfSightChecksPerSecond == 40, "global line-of-sight target changed")

local function authoredDescriptor()
	return {
		sourceId = "light.authored.generator-room",
		sourceTypeId = "AuthoredEnvironmental",
		visibilityProfileId = "Dim",
		activation = {
			stateId = "Active",
			activatedAtServerTimestamp = 0,
			expiresAtServerTimestamp = nil,
		},
		coverage = {
			kind = "AuthoredZone",
			authoredZoneProfileId = "zone.generator-room",
		},
		ownerEntityId = nil,
	}
end

local function assertAccepted(descriptor: any)
	local result = validator.validate(descriptor)
	assert(result.isValid == true, "descriptor should be accepted")
	assert(result.rejectionReasonId == nil, "accepted descriptor cannot have a rejection reason")
	assert(table.isfrozen(result), "validation result must be frozen")
	return result
end

local function assertRejected(descriptor: any, expectedReason: string)
	local result = validator.validate(descriptor)
	assert(result.isValid == false, "descriptor should be rejected")
	assert(result.rejectionReasonId == expectedReason, "unexpected rejection reason")
	assert(table.isfrozen(result), "validation result must be frozen")
	return result
end

local authored = authoredDescriptor()
assertAccepted(authored)
assertAccepted({
	sourceId = "light.personal.operative-alpha",
	sourceTypeId = "ApprovedPersonal",
	visibilityProfileId = "Lit",
	activation = { stateId = "Active", activatedAtServerTimestamp = 10 },
	coverage = { kind = "ForwardCone", rangeStuds = 24, angleDegrees = 60 },
	ownerEntityId = "operative.alpha",
})
assertAccepted({
	sourceId = "light.temporary.fixture-one",
	sourceTypeId = "ApprovedTemporary",
	visibilityProfileId = "Dim",
	activation = {
		stateId = "Active",
		activatedAtServerTimestamp = 10,
		expiresAtServerTimestamp = 30,
	},
	coverage = { kind = "Radius", radiusStuds = 12 },
	ownerEntityId = "operative.alpha",
})

local firstResult = assertAccepted(authored)
local secondResult = assertAccepted(authored)
assert(firstResult.isValid == secondResult.isValid, "repeat validation changed acceptance")
assert(firstResult.rejectionReasonId == secondResult.rejectionReasonId, "repeat validation changed reason")
assert(authored.sourceId == "light.authored.generator-room", "validator mutated descriptor")
assert(authored.activation.stateId == "Active", "validator mutated nested activation")
assert(authored.coverage.kind == "AuthoredZone", "validator mutated nested coverage")
assert(authored.coverage.authoredZoneProfileId == "zone.generator-room", "validator mutated coverage identity")
assert(not table.isfrozen(authored), "validator must not freeze caller descriptor")
assert(not table.isfrozen(authored.coverage), "validator must not freeze caller coverage")

assertRejected(nil, "InvalidDescriptor")
assertRejected({ sourceId = "" }, "InvalidDescriptor")
local invalid = authoredDescriptor()
invalid.sourceId = nil
assertRejected(invalid, "InvalidSourceIdentity")
invalid = authoredDescriptor()
invalid.sourceId = ""
assertRejected(invalid, "InvalidSourceIdentity")
invalid = authoredDescriptor()
invalid.sourceTypeId = "Unknown"
assertRejected(invalid, "InvalidSourceType")
invalid = authoredDescriptor()
invalid.visibilityProfileId = "Bright"
assertRejected(invalid, "UnknownVisibilityProfile")
invalid = authoredDescriptor()
invalid.activation.stateId = "Enabled"
assertRejected(invalid, "InvalidActivationState")
invalid = authoredDescriptor()
invalid.sourceTypeId = "ApprovedPersonal"
invalid.ownerEntityId = 7
assertRejected(invalid, "InvalidOwnerIdentity")
invalid = authoredDescriptor()
invalid.sourceId = ""
invalid.sourceTypeId = "Unknown"
invalid.visibilityProfileId = "Bright"
invalid.coverage = nil
assertRejected(invalid, "InvalidSourceIdentity")

for _, timestamp in { -1, 0 / 0, math.huge, -math.huge } do
	invalid = authoredDescriptor()
	invalid.activation.activatedAtServerTimestamp = timestamp
	assertRejected(invalid, "InvalidTimestamp")
end
invalid = authoredDescriptor()
invalid.sourceTypeId = "ApprovedTemporary"
invalid.ownerEntityId = "operative.alpha"
assertRejected(invalid, "InvalidLifetime")
invalid = authoredDescriptor()
invalid.activation.expiresAtServerTimestamp = -1
assertRejected(invalid, "InvalidTimestamp")
invalid = authoredDescriptor()
invalid.activation.expiresAtServerTimestamp = 0
assertRejected(invalid, "InvalidLifetime")
invalid = authoredDescriptor()
invalid.activation.activatedAtServerTimestamp = 10
invalid.activation.expiresAtServerTimestamp = 9
assertRejected(invalid, "InvalidLifetime")
invalid = authoredDescriptor()
invalid.activation.expiresAtServerTimestamp = config.MaximumTemporaryLightLifetimeSeconds + 1
assertRejected(invalid, "InvalidLifetime")
assertAccepted(authoredDescriptor())

invalid = authoredDescriptor()
invalid.coverage = nil
assertRejected(invalid, "InvalidCoverage")
invalid = authoredDescriptor()
invalid.coverage = { kind = "Box" }
assertRejected(invalid, "InvalidCoverage")
for _, radius in { 0, -1, 0 / 0, math.huge, -math.huge, config.MaximumCoverageRadiusStuds + 1 } do
	invalid = authoredDescriptor()
	invalid.coverage = { kind = "Radius", radiusStuds = radius }
	assertRejected(invalid, "InvalidCoverage")
end
for _, angle in { 0, 0 / 0, math.huge, config.MaximumConeAngleDegrees + 1 } do
	invalid = authoredDescriptor()
	invalid.coverage = { kind = "ForwardCone", rangeStuds = 10, angleDegrees = angle }
	assertRejected(invalid, "InvalidCoverage")
end
for _, range in { 0, -1, 0 / 0, math.huge, config.MaximumConeRangeStuds + 1 } do
	invalid = authoredDescriptor()
	invalid.coverage = { kind = "ForwardCone", rangeStuds = range, angleDegrees = 45 }
	assertRejected(invalid, "InvalidCoverage")
end
invalid = authoredDescriptor()
invalid.coverage = { kind = "AuthoredZone", authoredZoneProfileId = "" }
assertRejected(invalid, "InvalidCoverage")

local contractSource = fs.readFile(contractsPath)
local configSource = fs.readFile(configPath)
local validatorSource = fs.readFile(validatorPath)
local combinedSource = contractSource .. configSource .. validatorSource
for _, prohibitedToken in
	{
		"Instance",
		"PointLight",
		"SpotLight",
		"SurfaceLight",
		"RemoteEvent",
		"RemoteFunction",
		"Vector3",
	}
do
	assert(
		string.find(combinedSource, prohibitedToken, 1, true) == nil,
		"prohibited contract token: " .. prohibitedToken
	)
end
assert(string.find(combinedSource, "init.server", 1, true) == nil, "server bootstrap import added")
assert(string.find(combinedSource, "init.client", 1, true) == nil, "client bootstrap import added")

print("GameplayLightContracts: LK-0401 vocabulary, config, validation, boundaries, and immutability passed")
