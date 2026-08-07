--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local FIREARM_CONFIG_TOKEN = {}
local PATTERN_CONFIG_TOKEN = {}
local VALIDATOR_TOKEN = {}
local BASE_SELECTOR_TOKEN = {}
local PATTERN_RESOLVER_TOKEN = {}

local contracts = {
	CombatEntityKindIds = table.freeze({ Hostile = "Hostile" }),
	TeamRelationshipIds = table.freeze({ Hostile = "Hostile" }),
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
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
		ThreateningPatternUtility = "ThreateningPatternUtility",
		ValidPatternUtility = "ValidPatternUtility",
	}),
}

local firearmDefinitions = {
	["weapon.basic_firearm"] = { WeaponId = "weapon.basic_firearm", RangeStuds = 80 },
	["weapon.light-machine-gun"] = { WeaponId = "weapon.light-machine-gun", RangeStuds = 92 },
	["weapon.breach-shotgun"] = { WeaponId = "weapon.breach-shotgun", RangeStuds = 38 },
	["weapon.sniper-rifle"] = { WeaponId = "weapon.sniper-rifle", RangeStuds = 165 },
}
local firearmConfig = {
	BasicFirearm = firearmDefinitions["weapon.basic_firearm"],
	get = function(weaponId: unknown)
		return if type(weaponId) == "string" then firearmDefinitions[weaponId] else nil
	end,
}

local modes = table.freeze({
	SingleTarget = "SingleTarget",
	ConeCleave = "ConeCleave",
	LinePierce = "LinePierce",
})
local patternDefinitions = {
	["weapon.basic_firearm"] = {
		WeaponId = "weapon.basic_firearm",
		ModeId = modes.SingleTarget,
		MaximumSecondaryTargets = 0,
		SecondaryDamageMultiplier = 1,
		MaximumSecondaryRangeStuds = 0,
	},
	["weapon.light-machine-gun"] = {
		WeaponId = "weapon.light-machine-gun",
		ModeId = modes.SingleTarget,
		MaximumSecondaryTargets = 0,
		SecondaryDamageMultiplier = 1,
		MaximumSecondaryRangeStuds = 0,
	},
	["weapon.breach-shotgun"] = {
		WeaponId = "weapon.breach-shotgun",
		ModeId = modes.ConeCleave,
		MaximumSecondaryTargets = 3,
		SecondaryDamageMultiplier = 0.7,
		MaximumSecondaryRangeStuds = 30,
		ConeHalfAngleDegrees = 26,
	},
	["weapon.sniper-rifle"] = {
		WeaponId = "weapon.sniper-rifle",
		ModeId = modes.LinePierce,
		MaximumSecondaryTargets = 1,
		SecondaryDamageMultiplier = 0.72,
		MaximumSecondaryRangeStuds = 165,
		PierceHalfWidthStuds = 3.25,
		MinimumBeyondPrimaryStuds = 2,
	},
}
local patternConfig = {
	ModeIds = modes,
	get = function(weaponId: unknown)
		return if type(weaponId) == "string" then patternDefinitions[weaponId] else nil
	end,
}

local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = {
			FirearmConfig = FIREARM_CONFIG_TOKEN,
			WeaponPatternConfig = PATTERN_CONFIG_TOKEN,
		},
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
	elseif token == FIREARM_CONFIG_TOKEN then
		return firearmConfig
	end
	error("unexpected validator dependency")
end
local validator = luau.load(validatorSource, {
	debugName = "TargetCandidateValidator",
	environment = validatorEnvironment,
	injectGlobals = true,
})()

local baseSelectorSource = fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateSelector.luau")
local baseSelectorEnvironment = table.clone(baseEnvironment)
baseSelectorEnvironment.script = { Parent = { TargetCandidateValidator = VALIDATOR_TOKEN } }
baseSelectorEnvironment.require = function(token: unknown)
	if token == CONTRACTS_TOKEN then
		return contracts
	elseif token == VALIDATOR_TOKEN then
		return validator
	end
	error("unexpected base selector dependency")
end
local baseSelector = luau.load(baseSelectorSource, {
	debugName = "TargetCandidateSelector",
	environment = baseSelectorEnvironment,
	injectGlobals = true,
})()

local patternResolverSource = fs.readFile("games/living-kingdoms/src/server/Systems/WeaponPatternResolver.luau")
local patternResolverEnvironment = table.clone(baseEnvironment)
patternResolverEnvironment.require = function(token: unknown)
	assert(token == PATTERN_CONFIG_TOKEN, "unexpected pattern resolver dependency")
	return patternConfig
end
local patternResolver = luau.load(patternResolverSource, {
	debugName = "WeaponPatternResolver",
	environment = patternResolverEnvironment,
	injectGlobals = true,
})()

local selectorSource = fs.readFile("games/living-kingdoms/src/server/Systems/WeaponTargetSelector.luau")
local selectorEnvironment = table.clone(baseEnvironment)
selectorEnvironment.script = {
	Parent = {
		TargetCandidateSelector = BASE_SELECTOR_TOKEN,
		TargetCandidateValidator = VALIDATOR_TOKEN,
		WeaponPatternResolver = PATTERN_RESOLVER_TOKEN,
	},
}
selectorEnvironment.require = function(token: unknown)
	if token == CONTRACTS_TOKEN then
		return contracts
	elseif token == PATTERN_CONFIG_TOKEN then
		return patternConfig
	elseif token == BASE_SELECTOR_TOKEN then
		return baseSelector
	elseif token == VALIDATOR_TOKEN then
		return validator
	elseif token == PATTERN_RESOLVER_TOKEN then
		return patternResolver
	end
	error("unexpected weapon selector dependency")
end
local selector = luau.load(selectorSource, {
	debugName = "WeaponTargetSelector",
	environment = selectorEnvironment,
	injectGlobals = true,
})()

local function position(x: number, z: number)
	return { X = x, Y = 0, Z = z }
end

local function operative(weaponId: string)
	return {
		entityId = "operative.alpha",
		worldPosition = position(0, 0),
		combatStateId = "Ready",
		weaponReadiness = {
			weaponId = weaponId,
			readinessStateId = "Ready",
			ammunition = {
				weaponId = weaponId,
				loadedRounds = 12,
				reserveRounds = 24,
				magazineCapacity = 12,
			},
			cadence = {
				weaponId = weaponId,
				nextAllowedFireServerTimestamp = 0,
			},
		},
	}
end

local function candidate(entityId: string, x: number, z: number, threatening: boolean?)
	return {
		entityId = entityId,
		entityKindId = "Hostile",
		teamId = "hostiles",
		relationshipId = "Hostile",
		worldPosition = position(x, z),
		distanceStuds = math.sqrt(x * x + z * z),
		isAlive = true,
		isTargetable = true,
		isVisible = true,
		hasLineOfSight = true,
		isActivelyThreatening = threatening == true,
		activelyThreateningOperativeEntityId = if threatening then "operative.alpha" else nil,
	}
end

local function assertSelected(result: any, targetId: string, reasonId: string, context: string)
	assert(result ~= nil, context .. ": expected selection")
	assert(result.targetEntityId == targetId, context .. ": wrong target")
	assert(result.selectionReasonId == reasonId, context .. ": wrong reason")
	assert(result.operativeEntityId == "operative.alpha", context .. ": wrong operative")
	assert(result.isValid == true, context .. ": target not marked valid")
end

local shotgunCluster = {
	candidate("hostile.closest-solo", 0, 8),
	candidate("hostile.cluster-primary", 18, 0),
	candidate("hostile.cluster-two", 22, 1),
	candidate("hostile.cluster-three", 25, -1),
	candidate("hostile.cluster-four", 28, 2),
}
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), shotgunCluster),
	"hostile.cluster-primary",
	"ValidPatternUtility",
	"shotgun seeks maximum cleave"
)

local threatAbsolute = table.clone(shotgunCluster)
threatAbsolute[1] = candidate("hostile.threat-solo", 0, 8, true)
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), threatAbsolute),
	"hostile.threat-solo",
	"ThreateningClosest",
	"threat cohort remains absolute"
)

local threatCluster = {
	candidate("hostile.threat-close", 0, 8, true),
	candidate("hostile.threat-cluster", 18, 0, true),
	candidate("hostile.cluster-two", 22, 1),
	candidate("hostile.cluster-three", 25, -1),
	candidate("hostile.cluster-four", 28, 2),
}
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), threatCluster),
	"hostile.threat-cluster",
	"ThreateningPatternUtility",
	"shotgun optimizes inside threat cohort"
)

local sniperLine = {
	candidate("hostile.closest-solo", 0, 8),
	candidate("hostile.line-primary", 25, 0),
	candidate("hostile.line-rear", 48, 1),
}
sniperLine[3].hasLineOfSight = false
assertSelected(
	selector.select(operative("weapon.sniper-rifle"), sniperLine),
	"hostile.line-primary",
	"ValidPatternUtility",
	"sniper seeks rear lineup despite primary occlusion"
)

local noPattern = {
	candidate("hostile.far", 20, 0),
	candidate("hostile.close", 0, 6),
}
assertSelected(
	selector.select(operative("weapon.light-machine-gun"), noPattern),
	"hostile.close",
	"ValidClosest",
	"single-target weapon preserves fallback"
)
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), noPattern),
	"hostile.close",
	"ValidClosest",
	"pattern weapon without opportunity preserves fallback"
)

local invalidPatternPrimary = {
	candidate("hostile.valid-close", 0, 8),
	candidate("hostile.invalid-primary", 18, 0),
	candidate("hostile.invalid-secondary-one", 22, 1),
	candidate("hostile.invalid-secondary-two", 25, -1),
}
invalidPatternPrimary[2].hasLineOfSight = false
invalidPatternPrimary[3].hasLineOfSight = false
invalidPatternPrimary[4].hasLineOfSight = false
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), invalidPatternPrimary),
	"hostile.valid-close",
	"ValidClosest",
	"invalid pattern primary cannot be selected"
)

local friendlySecondary = {
	candidate("hostile.primary", 18, 0),
	candidate("friendly.lookalike", 22, 1),
	candidate("hostile.closest", 0, 8),
}
friendlySecondary[2].relationshipId = "Friendly"
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), friendlySecondary),
	"hostile.closest",
	"ValidClosest",
	"friendly candidate cannot create pattern utility"
)

local ordered = shotgunCluster
local reversed = { ordered[5], ordered[4], ordered[3], ordered[2], ordered[1] }
local shuffled = { ordered[3], ordered[1], ordered[5], ordered[2], ordered[4] }
for _, candidates in { ordered, reversed, shuffled } do
	assertSelected(
		selector.select(operative("weapon.breach-shotgun"), candidates),
		"hostile.cluster-primary",
		"ValidPatternUtility",
		"input order independence"
	)
end

assertSelected(
	selector.select(operative("weapon.breach-shotgun"), shotgunCluster, "hostile.cluster-two"),
	"hostile.cluster-two",
	"ValidPatternUtility",
	"equivalent utility inside the distance allowance retains the current target"
)
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), shotgunCluster, "hostile.cluster-four"),
	"hostile.cluster-primary",
	"ValidPatternUtility",
	"equivalent utility beyond the distance allowance switches to the best target"
)
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), shotgunCluster, "hostile.closest-solo"),
	"hostile.cluster-primary",
	"ValidPatternUtility",
	"greater pattern utility switches immediately"
)
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), threatAbsolute, "hostile.cluster-primary"),
	"hostile.threat-solo",
	"ThreateningClosest",
	"active threat priority switches immediately across cohorts"
)

local invalidCurrent = {
	candidate("hostile.cluster-primary", 18, 0),
	candidate("hostile.invalid-current", 22, 1),
	candidate("hostile.cluster-three", 25, -1),
	candidate("hostile.cluster-four", 28, 2),
}
invalidCurrent[2].hasLineOfSight = false
assertSelected(
	selector.select(operative("weapon.breach-shotgun"), invalidCurrent, "hostile.invalid-current"),
	"hostile.cluster-primary",
	"ValidPatternUtility",
	"invalid current target cannot be retained"
)
assertSelected(
	selector.select(operative("weapon.light-machine-gun"), noPattern, "hostile.far"),
	"hostile.close",
	"ValidClosest",
	"single-target fallback remains exact and does not become sticky"
)

print("WeaponTargetSelector: threat-safe pattern utility with bounded equivalent-target retention passed")
