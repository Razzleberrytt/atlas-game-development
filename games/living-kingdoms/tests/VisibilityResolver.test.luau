--!strict

-- Standalone LK-0403 pure visibility and P2-boundary fixtures.
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
local resolverEnvironment = {
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
		error("unexpected resolver module request")
	end,
}
local resolverChunk = luau.load(fs.readFile("games/living-kingdoms/src/shared/Perception/VisibilityResolver.luau"), {
	debugName = "VisibilityResolver",
	environment = resolverEnvironment,
	injectGlobals = true,
})
local resolver = resolverChunk()

local reasons = visibilityContracts.VisibilityDecisionReasonIds
local rejections = visibilityContracts.VisibilityRejectionReasonIds

local function validFacts()
	return {
		observerEntityId = "operative.alpha",
		candidateEntityId = "hostile.alpha",
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

local function assertResult(
	name: string,
	result: any,
	isValid: boolean,
	isGameplayVisible: boolean,
	perceptionStateId: string,
	confidenceId: string,
	canCreateDirectSightObservation: boolean,
	isTargetingVisible: boolean,
	rejectionReasonId: string?,
	decisionReasonId: string?
)
	assert(result.isValid == isValid, name .. ": validity")
	assert(result.isGameplayVisible == isGameplayVisible, name .. ": gameplay visibility")
	assert(result.perceptionStateId == perceptionStateId, name .. ": perception")
	assert(result.confidenceId == confidenceId, name .. ": confidence")
	assert(result.canCreateDirectSightObservation == canCreateDirectSightObservation, name .. ": direct sight")
	assert(result.isTargetingVisible == isTargetingVisible, name .. ": targeting visibility")
	assert(result.rejectionReasonId == rejectionReasonId, name .. ": rejection")
	assert(result.decisionReasonId == decisionReasonId, name .. ": decision")
end

local function assertRejected(name: string, facts: any, rejectionReasonId: string)
	assertResult(name, resolver.resolve(facts), false, false, "Unknown", "Low", false, false, rejectionReasonId, nil)
end

local validationFixtures = {
	{
		name = "malformed facts",
		facts = false,
		rejection = rejections.InvalidFacts,
	},
	{
		name = "invalid observer identity",
		mutate = function(facts: any)
			facts.observerEntityId = ""
		end,
		rejection = rejections.InvalidObserverIdentity,
	},
	{
		name = "invalid candidate identity",
		mutate = function(facts: any)
			facts.candidateEntityId = nil
		end,
		rejection = rejections.InvalidCandidateIdentity,
	},
	{
		name = "same entity",
		mutate = function(facts: any)
			facts.candidateEntityId = facts.observerEntityId
		end,
		rejection = rejections.SelfEvaluation,
	},
	{
		name = "invalid observer state",
		mutate = function(facts: any)
			facts.observerCanPerceive = false
		end,
		rejection = rejections.ObserverStateInvalid,
	},
	{
		name = "invalid candidate state",
		mutate = function(facts: any)
			facts.candidateIsGameplayPresent = false
		end,
		rejection = rejections.CandidateStateInvalid,
	},
	{
		name = "invalid relationship or category",
		mutate = function(facts: any)
			facts.relationshipId = "Unknown"
		end,
		rejection = rejections.InvalidRelationshipOrCategory,
	},
	{
		name = "invalid visibility profile",
		mutate = function(facts: any)
			facts.illuminationFacts.visibilityProfileId = "Bright"
		end,
		rejection = rejections.InvalidVisibilityProfile,
	},
	{
		name = "invalid region",
		mutate = function(facts: any)
			facts.spatialFacts.perceptualRegionId = "BehindCamera"
		end,
		rejection = rejections.InvalidPerceptualRegion,
	},
	{
		name = "invalid illumination",
		mutate = function(facts: any)
			facts.illuminationFacts.hasQualifyingLocalLightCoverage = "yes"
		end,
		rejection = rejections.InvalidIlluminationFact,
	},
	{
		name = "invalid spatial fact",
		mutate = function(facts: any)
			facts.spatialFacts.distanceSquaredStuds = 0 / 0
		end,
		rejection = rejections.InvalidSpatialFact,
	},
	{
		name = "invalid LOS",
		mutate = function(facts: any)
			facts.spatialFacts.hasConsequentialLineOfSight = nil
		end,
		rejection = rejections.InvalidLineOfSightFact,
	},
	{
		name = "invalid disclosure",
		mutate = function(facts: any)
			facts.disclosureStateId = "Remembered"
		end,
		rejection = rejections.InvalidDisclosureFact,
	},
}

for _, fixture in validationFixtures do
	local facts = if fixture.facts ~= nil then fixture.facts else validFacts()
	if fixture.mutate ~= nil then
		fixture.mutate(facts)
	end
	assertRejected(fixture.name, facts, fixture.rejection)
end

local precedence = validFacts()
precedence.observerEntityId = ""
precedence.candidateEntityId = nil
precedence.observerCanPerceive = false
precedence.illuminationFacts.visibilityProfileId = "Bright"
assertRejected("deterministic rejection precedence", precedence, rejections.InvalidObserverIdentity)

local function resolveWith(changes: { [string]: any })
	local facts = validFacts()
	for key, value in changes do
		if key == "visibilityProfileId" or key == "hasQualifyingLocalLightCoverage" then
			facts.illuminationFacts[key] = value
		elseif key == "distanceSquaredStuds" or key == "perceptualRegionId" or key == "hasConsequentialLineOfSight" then
			facts.spatialFacts[key] = value
		else
			facts[key] = value
		end
	end
	return resolver.resolve(facts)
end

assertResult(
	"dark no light",
	resolveWith({ visibilityProfileId = "Dark", hasQualifyingLocalLightCoverage = false }),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.InsufficientIllumination
)
assertResult(
	"dark qualifying forward LOS",
	resolveWith({ visibilityProfileId = "Dark", hasQualifyingLocalLightCoverage = true }),
	true,
	true,
	"Observed",
	"High",
	true,
	true,
	nil,
	reasons.ObservedTargetingVisible
)
assertResult(
	"dark coverage without LOS",
	resolveWith({
		visibilityProfileId = "Dark",
		hasQualifyingLocalLightCoverage = true,
		hasConsequentialLineOfSight = false,
	}),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.NoLineOfSight
)
assertResult(
	"dark peripheral",
	resolveWith({
		visibilityProfileId = "Dark",
		perceptualRegionId = "Peripheral",
		hasConsequentialLineOfSight = false,
	}),
	true,
	false,
	"Suspected",
	"Low",
	false,
	false,
	nil,
	reasons.PeripheralOnly
)

assertResult(
	"dim forward LOS",
	resolveWith({ visibilityProfileId = "Dim" }),
	true,
	true,
	"Observed",
	"Medium",
	true,
	true,
	nil,
	reasons.ObservedTargetingVisible
)
assertResult(
	"dim without LOS",
	resolveWith({ visibilityProfileId = "Dim", hasConsequentialLineOfSight = false }),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.NoLineOfSight
)
assertResult(
	"dim peripheral",
	resolveWith({ visibilityProfileId = "Dim", perceptualRegionId = "Peripheral" }),
	true,
	false,
	"Suspected",
	"Low",
	false,
	false,
	nil,
	reasons.PeripheralOnly
)
assertResult(
	"dim outside",
	resolveWith({ visibilityProfileId = "Dim", perceptualRegionId = "Outside" }),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.OutsidePerceptualRegion
)

assertResult(
	"lit forward LOS",
	resolveWith({}),
	true,
	true,
	"Observed",
	"High",
	true,
	true,
	nil,
	reasons.ObservedTargetingVisible
)
assertResult(
	"lit no LOS",
	resolveWith({ hasConsequentialLineOfSight = false }),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.NoLineOfSight
)
assertResult(
	"lit outside",
	resolveWith({ perceptualRegionId = "Outside" }),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.OutsidePerceptualRegion
)
assertRejected(
	"lit dead candidate",
	(function()
		local facts = validFacts()
		facts.candidateIsAlive = false
		return facts
	end)(),
	rejections.CandidateStateInvalid
)
assertResult(
	"lit untargetable candidate",
	resolveWith({ candidateIsTargetable = false }),
	true,
	true,
	"Observed",
	"High",
	true,
	false,
	nil,
	reasons.CandidateUntargetable
)
assertResult(
	"lit non-hostile teammate",
	resolveWith({ candidateCategoryId = "Operative", relationshipId = "Friendly" }),
	true,
	true,
	"Observed",
	"High",
	true,
	false,
	nil,
	reasons.RelationshipNotHostile
)

assertResult(
	"hidden current candidate",
	resolveWith({ disclosureStateId = "Hidden" }),
	true,
	true,
	"Observed",
	"High",
	true,
	false,
	nil,
	reasons.NotDisclosedForTargeting
)
assert(resolveWith({ disclosureStateId = "Disclosed" }).isTargetingVisible, "disclosed current candidate")
for _, name in { "remembered candidate", "stale observation" } do
	local result = resolveWith({ hasConsequentialLineOfSight = false, disclosureStateId = "Disclosed" })
	assertResult(name, result, true, false, "Unknown", "Low", false, false, nil, reasons.NoLineOfSight)
end
assert(not resolveWith({ perceptualRegionId = "Peripheral" }).isTargetingVisible, "suspected state targeted")
assertResult(
	"authored objective information",
	resolveWith({ candidateCategoryId = "Objective", relationshipId = "Neutral" }),
	true,
	true,
	"Observed",
	"High",
	true,
	false,
	nil,
	reasons.RelationshipNotHostile
)
assertResult(
	"teammate information without LOS",
	resolveWith({
		candidateCategoryId = "Operative",
		relationshipId = "Friendly",
		hasConsequentialLineOfSight = false,
	}),
	true,
	false,
	"Unknown",
	"Low",
	false,
	false,
	nil,
	reasons.NoLineOfSight
)

for profileId, exactRange in { Dark = 24, Dim = 32, Lit = 64 } do
	local atBoundary = resolveWith({
		visibilityProfileId = profileId,
		hasQualifyingLocalLightCoverage = profileId == "Dark",
		distanceSquaredStuds = exactRange * exactRange,
	})
	assert(atBoundary.isGameplayVisible, profileId .. " exact range boundary")
	local beyond = resolveWith({
		visibilityProfileId = profileId,
		hasQualifyingLocalLightCoverage = profileId == "Dark",
		distanceSquaredStuds = exactRange * exactRange + 0.001,
	})
	assertResult(
		profileId .. " beyond range",
		beyond,
		true,
		false,
		"Unknown",
		"Low",
		false,
		false,
		nil,
		reasons.OutsideVisibilityRange
	)
end

-- Existing P2 validation remains the final independent combat gate.
local COMBAT_TOKEN = {}
local FIREARM_TOKEN = {}
local combatReasons = {
	OperativeStateInvalid = "OperativeStateInvalid",
	RelationshipNotHostile = "RelationshipNotHostile",
	HostileDead = "HostileDead",
	HostileUntargetable = "HostileUntargetable",
	NotVisible = "NotVisible",
	NoLineOfSight = "NoLineOfSight",
	OutOfRange = "OutOfRange",
	NoAmmunition = "NoAmmunition",
	WeaponNotReady = "WeaponNotReady",
}
local p2Environment = {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected P2 service request")
			return {
				Shared = { Combat = { CombatContracts = COMBAT_TOKEN }, Config = { FirearmConfig = FIREARM_TOKEN } },
			}
		end,
	},
	require = function(token: unknown)
		if token == COMBAT_TOKEN then
			return {
				OperativeCombatStateIds = { Ready = "Ready" },
				TeamRelationshipIds = { Hostile = "Hostile" },
				WeaponReadinessStateIds = { Ready = "Ready" },
				TargetValidationRejectionReasonIds = combatReasons,
			}
		elseif token == FIREARM_TOKEN then
			return { BasicFirearm = { WeaponId = "weapon.basic_firearm", RangeStuds = 80 } }
		end
		error("unexpected P2 module request")
	end,
}
local p2Chunk = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau"), {
	debugName = "TargetCandidateValidator",
	environment = p2Environment,
	injectGlobals = true,
})
local p2Validator = p2Chunk()

local function p2Operative()
	return {
		worldPosition = { X = 0, Y = 0, Z = 0 },
		combatStateId = "Ready",
		weaponReadiness = {
			weaponId = "weapon.basic_firearm",
			readinessStateId = "Ready",
			ammunition = { loadedRounds = 1 },
		},
	}
end

local function p2Candidate(isVisible: boolean)
	return {
		relationshipId = "Hostile",
		isAlive = true,
		isTargetable = true,
		isVisible = isVisible,
		hasLineOfSight = true,
		worldPosition = { X = 10, Y = 0, Z = 0 },
	}
end

local visibleResult = resolveWith({})
local rangeCandidate = p2Candidate(visibleResult.isTargetingVisible)
rangeCandidate.worldPosition = { X = 81, Y = 0, Z = 0 }
assert(
	p2Validator.validate(p2Operative(), rangeCandidate).rejectionReasonId == combatReasons.OutOfRange,
	"P2 range bypassed"
)
local emptyOperative = p2Operative()
emptyOperative.weaponReadiness.ammunition.loadedRounds = 0
assert(
	p2Validator.validate(emptyOperative, p2Candidate(visibleResult.isTargetingVisible)).rejectionReasonId
		== combatReasons.NoAmmunition,
	"P2 ammunition bypassed"
)
local blockedOperative = p2Operative()
blockedOperative.weaponReadiness.readinessStateId = "Reloading"
assert(
	p2Validator.validate(blockedOperative, p2Candidate(visibleResult.isTargetingVisible)).rejectionReasonId
		== combatReasons.WeaponNotReady,
	"P2 readiness bypassed"
)
local hiddenResult = resolveWith({ disclosureStateId = "Hidden" })
assert(
	p2Validator.validate(p2Operative(), p2Candidate(hiddenResult.isTargetingVisible)).rejectionReasonId
		== combatReasons.NotVisible,
	"hidden candidate entered P2"
)

local immutableFacts = validFacts()
local immutableSnapshot = table.clone(immutableFacts)
local immutableIllumination = table.clone(immutableFacts.illuminationFacts)
local immutableSpatial = table.clone(immutableFacts.spatialFacts)
local first = resolver.resolve(immutableFacts)
for key, value in immutableSnapshot do
	assert(immutableFacts[key] == value, "input mutated at " .. key)
end
for key, value in immutableIllumination do
	assert(immutableFacts.illuminationFacts[key] == value, "nested illumination input mutated at " .. key)
end
for key, value in immutableSpatial do
	assert(immutableFacts.spatialFacts[key] == value, "nested spatial input mutated at " .. key)
end
for _ = 1, 10 do
	local repeated = resolver.resolve(immutableFacts)
	for key, value in first do
		assert(repeated[key] == value, "repeated result changed at " .. key)
	end
end

local reordered = {}
local keys = {
	"disclosureStateId",
	"spatialFacts",
	"illuminationFacts",
	"relationshipId",
	"candidateIsTargetable",
	"candidateIsAlive",
	"candidateIsGameplayPresent",
	"candidateCategoryId",
	"observerCanPerceive",
	"candidateEntityId",
	"observerEntityId",
}
for _, key in keys do
	reordered[key] = immutableFacts[key]
end
local reorderedResult = resolver.resolve(reordered)
for key, value in first do
	assert(reorderedResult[key] == value, "table order changed result at " .. key)
end

local allowedResultKeys = {
	isValid = true,
	isGameplayVisible = true,
	perceptionStateId = true,
	confidenceId = true,
	canCreateDirectSightObservation = true,
	isTargetingVisible = true,
	rejectionReasonId = true,
	decisionReasonId = true,
}
for key in first do
	assert(allowedResultKeys[key], "resolver returned integration state: " .. key)
end
assert(
	first.selectedTargetState == nil and first.fireResult == nil and first.observationRecord == nil,
	"resolver created owned state"
)

local resolverSource = fs.readFile("games/living-kingdoms/src/shared/Perception/VisibilityResolver.luau")
for _, forbidden in
	{
		"game:GetService",
		"Raycast",
		"RemoteEvent",
		"RemoteFunction",
		"os.clock",
		"tick(",
		"Bootstrap",
		"Player",
		"Character",
		"Humanoid",
		"Camera",
		"game.Lighting",
	}
do
	assert(not string.find(resolverSource, forbidden, 1, true), "forbidden runtime dependency: " .. forbidden)
end

assert(table.isfrozen(visibilityContracts), "visibility contracts not frozen")
assert(table.isfrozen(visibilityContracts.PerceptualRegionIds), "region vocabulary not frozen")
assert(table.isfrozen(visibilityContracts.VisibilityDecisionReasonIds), "decision vocabulary not frozen")
assert(table.isfrozen(perceptionConfig), "perception config not frozen")
assert(table.isfrozen(perceptionConfig.PrototypeForwardVisibilityRangeStuds), "visibility ranges not frozen")

print("VisibilityResolver: LK-0403 validation, policy, P2 compatibility, determinism, and scope fixtures passed")
