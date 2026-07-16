--!strict

-- Minimal standalone fixture runner for deterministic target selection. It
-- loads the production validator and selector without emulating Roblox runtime.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local VALIDATOR_TOKEN = {}

local contracts = {
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
	TeamRelationshipIds = table.freeze({ Hostile = "Hostile" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready" }),
	TargetValidationRejectionReasonIds = table.freeze({
		OperativeStateInvalid = "OperativeStateInvalid",
		RelationshipNotHostile = "RelationshipNotHostile",
		HostileDead = "HostileDead",
		HostileUntargetable = "HostileUntargetable",
		NotVisible = "NotVisible",
		NoLineOfSight = "NoLineOfSight",
		OutOfRange = "OutOfRange",
		NoAmmunition = "NoAmmunition",
		WeaponNotReady = "WeaponNotReady",
	}),
	TargetSelectionReasonIds = table.freeze({
		ThreateningClosest = "ThreateningClosest",
		ValidClosest = "ValidClosest",
	}),
}

local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		RangeStuds = 80,
	}),
}

local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = CONFIG_TOKEN },
	},
}

local baseEnvironment = {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected service request")
			return replicatedStorage
		end,
	},
}

local validatorSource = fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau")
local validatorEnvironment = table.clone(baseEnvironment)
validatorEnvironment.require = function(token: unknown)
	if token == CONTRACTS_TOKEN then
		return contracts
	end
	if token == CONFIG_TOKEN then
		return config
	end
	error("unexpected validator module request")
end
local loadValidator = luau.load(validatorSource, {
	debugName = "TargetCandidateValidator",
	environment = validatorEnvironment,
	injectGlobals = true,
})
local validator = loadValidator()

local selectorSource = fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateSelector.luau")
local selectorEnvironment = table.clone(baseEnvironment)
selectorEnvironment.script = { Parent = { TargetCandidateValidator = VALIDATOR_TOKEN } }
selectorEnvironment.require = function(token: unknown)
	if token == CONTRACTS_TOKEN then
		return contracts
	end
	if token == VALIDATOR_TOKEN then
		return validator
	end
	error("unexpected selector module request")
end
local loadSelector = luau.load(selectorSource, {
	debugName = "TargetCandidateSelector",
	environment = selectorEnvironment,
	injectGlobals = true,
})
local selector = loadSelector()

local function position(x: number, y: number, z: number)
	return { X = x, Y = y, Z = z }
end

local function validOperative()
	return {
		entityId = "operative.alpha",
		worldPosition = position(0, 0, 0),
		combatStateId = "Ready",
		weaponReadiness = {
			weaponId = "weapon.basic_firearm",
			readinessStateId = "Ready",
			ammunition = {
				weaponId = "weapon.basic_firearm",
				loadedRounds = 12,
				reserveRounds = 24,
				magazineCapacity = 12,
			},
			cadence = {
				weaponId = "weapon.basic_firearm",
				nextAllowedFireServerTimestamp = 0,
			},
		},
	}
end

local function validCandidate(entityId: string, x: number, z: number)
	return {
		entityId = entityId,
		entityKindId = "Hostile",
		teamId = "hostiles",
		relationshipId = "Hostile",
		worldPosition = position(x, 1000, z),
		distanceStuds = 999999,
		isAlive = true,
		isTargetable = true,
		isVisible = true,
		hasLineOfSight = true,
		isActivelyThreatening = false,
		activelyThreateningOperativeEntityId = nil,
	}
end

local function assertSelected(result: any, targetEntityId: string, reasonId: string, context: string)
	assert(result ~= nil, context .. ": expected a selected target")
	assert(result.operativeEntityId == "operative.alpha", context .. ": wrong operative")
	assert(result.targetEntityId == targetEntityId, context .. ": wrong target")
	assert(result.selectionReasonId == reasonId, context .. ": wrong selection reason")
	assert(result.selectedAtServerTimestamp == nil, context .. ": selector created a timestamp")
end

local function assertNil(result: any, context: string)
	assert(result == nil, context .. ": expected nil")
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in value do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function deepEqual(first: any, second: any): boolean
	if type(first) ~= type(second) then
		return false
	end
	if type(first) ~= "table" then
		return first == second
	end

	for key, value in first do
		if not deepEqual(value, second[key]) then
			return false
		end
	end
	for key in second do
		if first[key] == nil then
			return false
		end
	end
	return true
end

assertNil(selector.select(validOperative(), {}), "no candidates")

local invalidCandidates = {
	validCandidate("hostile.hidden", 10, 0),
	validCandidate("hostile.obstructed", 11, 0),
	validCandidate("hostile.dead", 12, 0),
}
invalidCandidates[1].isVisible = false
invalidCandidates[2].hasLineOfSight = false
invalidCandidates[3].isAlive = false
assertNil(selector.select(validOperative(), invalidCandidates), "all invalid candidates")

assertSelected(
	selector.select(validOperative(), { validCandidate("hostile.only", 10, 0) }),
	"hostile.only",
	"ValidClosest",
	"one valid candidate"
)

local farther = validCandidate("hostile.farther", 20, 0)
local closest = validCandidate("hostile.closest", 5, 0)
assertSelected(
	selector.select(validOperative(), { farther, closest }),
	"hostile.closest",
	"ValidClosest",
	"closest valid candidate"
)

local closerNonThreat = validCandidate("hostile.close-nonthreat", 2, 0)
local fartherThreat = validCandidate("hostile.far-threat", 30, 0)
fartherThreat.activelyThreateningOperativeEntityId = "operative.alpha"
assertSelected(
	selector.select(validOperative(), { closerNonThreat, fartherThreat }),
	"hostile.far-threat",
	"ThreateningClosest",
	"threat preferred over closer non-threat"
)

local closeThreat = validCandidate("hostile.close-threat", 7, 0)
local farThreat = validCandidate("hostile.farther-threat", 15, 0)
closeThreat.activelyThreateningOperativeEntityId = "operative.alpha"
farThreat.activelyThreateningOperativeEntityId = "operative.alpha"
assertSelected(
	selector.select(validOperative(), { farThreat, closeThreat }),
	"hostile.close-threat",
	"ThreateningClosest",
	"closest threat"
)

assertSelected(
	selector.select(validOperative(), {
		validCandidate("hostile.fallback-far", 25, 0),
		validCandidate("hostile.fallback-close", 8, 0),
	}),
	"hostile.fallback-close",
	"ValidClosest",
	"fallback without threats"
)

local invalidThreat = validCandidate("hostile.invalid-threat", 1, 0)
invalidThreat.activelyThreateningOperativeEntityId = "operative.alpha"
invalidThreat.isVisible = false
assertSelected(
	selector.select(validOperative(), { invalidThreat, validCandidate("hostile.valid", 9, 0) }),
	"hostile.valid",
	"ValidClosest",
	"invalid threat excluded"
)

local exclusionMutations = {
	hidden = function(_operative: any, candidate: any)
		candidate.isVisible = false
	end,
	obstructed = function(_operative: any, candidate: any)
		candidate.hasLineOfSight = false
	end,
	dead = function(_operative: any, candidate: any)
		candidate.isAlive = false
	end,
	untargetable = function(_operative: any, candidate: any)
		candidate.isTargetable = false
	end,
	friendly = function(_operative: any, candidate: any)
		candidate.relationshipId = "Friendly"
	end,
	out_of_range = function(_operative: any, candidate: any)
		candidate.worldPosition = position(80.001, 0, 0)
	end,
	empty_ammo = function(operative: any, _candidate: any)
		operative.weaponReadiness.ammunition.loadedRounds = 0
	end,
	non_ready = function(operative: any, _candidate: any)
		operative.weaponReadiness.readinessStateId = "CadenceBlocked"
	end,
}

for name, mutate in exclusionMutations do
	local operative = validOperative()
	local candidate = validCandidate("hostile." .. name, 10, 0)
	mutate(operative, candidate)
	assertNil(selector.select(operative, { candidate }), name .. " excluded through validator")
end

local lexicalLater = validCandidate("hostile.zulu", 3, 4)
local lexicalEarlier = validCandidate("hostile.alpha", -3, -4)
assertSelected(
	selector.select(validOperative(), { lexicalLater, lexicalEarlier }),
	"hostile.alpha",
	"ValidClosest",
	"equal-distance lexical tie"
)

local orderedCandidates = {
	validCandidate("hostile.bravo", 20, 0),
	validCandidate("hostile.alpha", 10, 0),
	validCandidate("hostile.charlie", 30, 0),
}
local reversedCandidates = { orderedCandidates[3], orderedCandidates[2], orderedCandidates[1] }
local shuffledCandidates = { orderedCandidates[2], orderedCandidates[1], orderedCandidates[3] }
for _, candidates in { orderedCandidates, reversedCandidates, shuffledCandidates } do
	assertSelected(
		selector.select(validOperative(), candidates),
		"hostile.alpha",
		"ValidClosest",
		"input order independence"
	)
end

local repeatOperative = validOperative()
local repeatCandidates = {
	validCandidate("hostile.repeat-fallback", 2, 0),
	validCandidate("hostile.repeat-threat", 40, 0),
}
repeatCandidates[2].activelyThreateningOperativeEntityId = "operative.alpha"
for _ = 1, 10 do
	assertSelected(
		selector.select(repeatOperative, repeatCandidates),
		"hostile.repeat-threat",
		"ThreateningClosest",
		"repeated deterministic call"
	)
end

local reacquiredCandidate = validCandidate("hostile.reacquired", 12, 0)
assertSelected(
	selector.select(validOperative(), { reacquiredCandidate }),
	"hostile.reacquired",
	"ValidClosest",
	"target before loss"
)
assertNil(selector.select(validOperative(), {}), "target loss")
assertSelected(
	selector.select(validOperative(), { reacquiredCandidate }),
	"hostile.reacquired",
	"ValidClosest",
	"safe reacquisition"
)

local threatToThisOperative = validCandidate("hostile.threat-this-operative", 20, 0)
local threatToAnotherOperative = validCandidate("hostile.threat-another-operative", 2, 0)
threatToThisOperative.activelyThreateningOperativeEntityId = "operative.alpha"
threatToAnotherOperative.isActivelyThreatening = true
threatToAnotherOperative.activelyThreateningOperativeEntityId = "operative.bravo"
assertSelected(
	selector.select(validOperative(), { threatToAnotherOperative, threatToThisOperative }),
	"hostile.threat-this-operative",
	"ThreateningClosest",
	"operative-specific threat"
)

local onlyThreatToAnother = validCandidate("hostile.only-other-threat", 6, 0)
onlyThreatToAnother.isActivelyThreatening = true
onlyThreatToAnother.activelyThreateningOperativeEntityId = "operative.bravo"
assertSelected(
	selector.select(validOperative(), { onlyThreatToAnother }),
	"hostile.only-other-threat",
	"ValidClosest",
	"another operative threat is not prioritized"
)

local boundaryCandidate = validCandidate("hostile.maximum-range", 80, 0)
assertSelected(
	selector.select(validOperative(), { boundaryCandidate }),
	"hostile.maximum-range",
	"ValidClosest",
	"inclusive maximum range"
)

local immutableOperative = validOperative()
local immutableCandidates = {
	validCandidate("hostile.immutable-a", 10, 0),
	validCandidate("hostile.immutable-b", 20, 0),
}
immutableCandidates[2].activelyThreateningOperativeEntityId = "operative.alpha"
local operativeBefore = deepCopy(immutableOperative)
local candidatesBefore = deepCopy(immutableCandidates)
selector.select(immutableOperative, immutableCandidates)
assert(deepEqual(immutableOperative, operativeBefore), "operative input was mutated")
assert(deepEqual(immutableCandidates, candidatesBefore), "candidate inputs were mutated")

print("TargetCandidateSelector: priority, validation, determinism, threat, boundary, and immutability checks passed")
