--!strict

-- Minimal standalone fixture runner for deterministic automatic-fire state
-- transitions. It loads the production resolver without Roblox runtime.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local rejectionReasons = table.freeze({
	NoSelectedTarget = "NoSelectedTarget",
	SelectedTargetInvalid = "SelectedTargetInvalid",
	OperativeStateInvalid = "OperativeStateInvalid",
	NoAmmunition = "NoAmmunition",
	WeaponNotReady = "WeaponNotReady",
	CadenceBlocked = "CadenceBlocked",
})

local contracts = {
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready" }),
	AutomaticFireRejectionReasonIds = rejectionReasons,
	AuthoritativeFireStatusIds = table.freeze({ Fired = "Fired", Rejected = "Rejected" }),
}

local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		CadenceSeconds = 0.2,
	}),
}

local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = CONFIG_TOKEN },
	},
}

local environment = {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected service request")
			return replicatedStorage
		end,
	},
	require = function(token: unknown)
		if token == CONTRACTS_TOKEN then
			return contracts
		end
		if token == CONFIG_TOKEN then
			return config
		end
		error("unexpected module request")
	end,
}

local source = fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau")
local loadResolver = luau.load(source, {
	debugName = "AutomaticFireResolver",
	environment = environment,
	injectGlobals = true,
})
local resolver = loadResolver()

local function operative()
	return {
		entityId = "operative.alpha",
		combatStateId = "Ready",
	}
end

local function selectedTarget()
	return {
		operativeEntityId = "operative.alpha",
		targetEntityId = "hostile.fixture",
		isValid = true,
		selectionReasonId = "ValidClosest",
		selectedAtServerTimestamp = nil,
	}
end

local function weaponState(loadedRounds: number?, nextAllowedTimestamp: number?)
	return {
		weaponId = "weapon.basic_firearm",
		readinessStateId = "Ready",
		ammunition = {
			weaponId = "weapon.basic_firearm",
			loadedRounds = loadedRounds or 12,
			reserveRounds = 24,
			magazineCapacity = 12,
		},
		cadence = {
			weaponId = "weapon.basic_firearm",
			lastFireServerTimestamp = 4,
			nextAllowedFireServerTimestamp = nextAllowedTimestamp or 5,
		},
		reloadState = nil,
	}
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

local function assertClose(actual: number, expected: number, context: string)
	assert(math.abs(actual - expected) < 1e-12, context)
end

local function assertRejected(result: any, reasonId: string, before: any, context: string)
	assert(result.decision.shouldFire == false, context .. ": decision accepted")
	assert(result.decision.rejectionReasonId == reasonId, context .. ": wrong decision reason")
	assert(result.fireResult.statusId == "Rejected", context .. ": wrong result status")
	assert(result.fireResult.shotId == nil, context .. ": rejected shot received an ID")
	assert(result.fireResult.firedAtServerTimestamp == nil, context .. ": rejected shot received a fire time")
	assert(result.fireResult.didHit == nil, context .. ": rejected shot resolved a hit")
	assert(result.fireResult.hitEntityId == nil, context .. ": rejected shot received a hit target")
	assert(result.fireResult.rejectionReasonId == reasonId, context .. ": wrong result reason")
	assert(deepEqual(result.weaponStateAfter, before), context .. ": rejected state changed")
	assert(deepEqual(result.fireResult.ammunitionAfter, before.ammunition), context .. ": rejected ammo changed")
end

local function assertAccepted(result: any, expectedLoadedRounds: number, timestamp: number, context: string)
	assert(result.decision.shouldFire == true, context .. ": decision rejected")
	assert(result.decision.rejectionReasonId == nil, context .. ": accepted decision has reason")
	assert(result.fireResult.statusId == "Fired", context .. ": wrong result status")
	assert(result.fireResult.shotId ~= nil, context .. ": accepted shot has no ID")
	assert(result.fireResult.targetEntityId == "hostile.fixture", context .. ": selected target not preserved")
	assert(result.fireResult.firedAtServerTimestamp == timestamp, context .. ": wrong fire time")
	assert(result.fireResult.didHit == nil, context .. ": accepted shot resolved a hit")
	assert(result.fireResult.hitEntityId == nil, context .. ": accepted shot received a hit target")
	assert(result.fireResult.rejectionReasonId == nil, context .. ": accepted shot has reason")
	assert(result.weaponStateAfter.ammunition.loadedRounds == expectedLoadedRounds, context .. ": wrong ammo")
	assert(result.fireResult.ammunitionAfter.loadedRounds == expectedLoadedRounds, context .. ": wrong result ammo")
	assert(result.weaponStateAfter.cadence.lastFireServerTimestamp == timestamp, context .. ": wrong last time")
	assertClose(
		result.weaponStateAfter.cadence.nextAllowedFireServerTimestamp,
		timestamp + 0.2,
		context .. ": wrong next time"
	)
end

local validWeapon = weaponState()
local validResult = resolver.resolve(operative(), selectedTarget(), validWeapon, 5)
assertAccepted(validResult, 11, 5, "valid shot")
assert(validResult.weaponStateAfter.ammunition.reserveRounds == 24, "accepted shot changed reserve ammo")
assert(validResult.weaponStateAfter.ammunition.magazineCapacity == 12, "accepted shot changed magazine capacity")
assert(validResult.weaponStateAfter.readinessStateId == "Ready", "accepted shot changed readiness")

local boundaryResult = resolver.resolve(operative(), selectedTarget(), weaponState(12, 10), 10)
assertAccepted(boundaryResult, 11, 10, "exact cadence boundary")

local beforeBoundary = weaponState(12, 10)
assertRejected(
	resolver.resolve(operative(), selectedTarget(), beforeBoundary, 9.999999),
	rejectionReasons.CadenceBlocked,
	beforeBoundary,
	"just before cadence"
)

for _, combatStateId in { "Reloading", "Incapacitated", "Dead", "Disabled" } do
	local blockedOperative = operative()
	blockedOperative.combatStateId = combatStateId
	local before = weaponState()
	assertRejected(
		resolver.resolve(blockedOperative, selectedTarget(), before, 5),
		rejectionReasons.OperativeStateInvalid,
		before,
		"operative " .. combatStateId
	)
end

local missingTargetWeapon = weaponState()
assertRejected(
	resolver.resolve(operative(), nil, missingTargetWeapon, 5),
	rejectionReasons.NoSelectedTarget,
	missingTargetWeapon,
	"nil selected target"
)

local invalidSelections = { selectedTarget(), selectedTarget(), selectedTarget() }
invalidSelections[1].operativeEntityId = "operative.other"
invalidSelections[2].targetEntityId = nil
invalidSelections[3].isValid = false
for index, invalidSelection in invalidSelections do
	local before = weaponState()
	assertRejected(
		resolver.resolve(operative(), invalidSelection, before, 5),
		rejectionReasons.SelectedTargetInvalid,
		before,
		"invalid selected target " .. tostring(index)
	)
end

for _, weaponIdLocation in { "state", "ammunition", "cadence" } do
	local before = weaponState()
	if weaponIdLocation == "state" then
		before.weaponId = "weapon.wrong"
	elseif weaponIdLocation == "ammunition" then
		before.ammunition.weaponId = "weapon.wrong"
	else
		before.cadence.weaponId = "weapon.wrong"
	end
	assertRejected(
		resolver.resolve(operative(), selectedTarget(), before, 5),
		rejectionReasons.WeaponNotReady,
		before,
		"wrong weapon ID in " .. weaponIdLocation
	)
end

for _, readinessStateId in { "CadenceBlocked", "Reloading", "Empty", "Disabled" } do
	local before = weaponState()
	before.readinessStateId = readinessStateId
	assertRejected(
		resolver.resolve(operative(), selectedTarget(), before, 5),
		rejectionReasons.WeaponNotReady,
		before,
		"weapon readiness " .. readinessStateId
	)
end

local reloadingState = weaponState()
reloadingState.readinessStateId = "Reloading"
reloadingState.reloadState = {
	weaponId = "weapon.basic_firearm",
	startedAtServerTimestamp = 4,
	completionServerTimestamp = 6,
}
assertRejected(
	resolver.resolve(operative(), selectedTarget(), reloadingState, 5),
	rejectionReasons.WeaponNotReady,
	reloadingState,
	"reload timing state preserved"
)

local emptyWeapon = weaponState()
emptyWeapon.ammunition.loadedRounds = 0
assertRejected(
	resolver.resolve(operative(), selectedTarget(), emptyWeapon, 5),
	rejectionReasons.NoAmmunition,
	emptyWeapon,
	"zero loaded ammunition"
)

local lastRoundWeapon = weaponState(1, 5)
local lastRoundResult = resolver.resolve(operative(), selectedTarget(), lastRoundWeapon, 5)
assertAccepted(lastRoundResult, 0, 5, "last loaded round")
assert(lastRoundResult.weaponStateAfter.ammunition.reserveRounds == 24, "last round changed reserve")
local afterLastRound = lastRoundResult.weaponStateAfter
assertRejected(
	resolver.resolve(operative(), selectedTarget(), afterLastRound, 5.2),
	rejectionReasons.NoAmmunition,
	afterLastRound,
	"fire after last loaded round"
)

local repeatedBlocked = weaponState(12, 10)
for _ = 1, 10 do
	assertRejected(
		resolver.resolve(operative(), selectedTarget(), repeatedBlocked, 9),
		rejectionReasons.CadenceBlocked,
		repeatedBlocked,
		"repeated blocked call"
	)
end

local longElapsedResult = resolver.resolve(operative(), selectedTarget(), weaponState(12, 0), 100)
assertAccepted(longElapsedResult, 11, 100, "long elapsed interval")
assertClose(
	longElapsedResult.weaponStateAfter.cadence.nextAllowedFireServerTimestamp,
	100.2,
	"long elapsed interval caught up from old cadence"
)

local immutableOperative = operative()
local immutableTarget = selectedTarget()
local immutableWeapon = weaponState()
local operativeBefore = deepCopy(immutableOperative)
local targetBefore = deepCopy(immutableTarget)
local weaponBefore = deepCopy(immutableWeapon)
resolver.resolve(immutableOperative, immutableTarget, immutableWeapon, 5)
assert(deepEqual(immutableOperative, operativeBefore), "accepted call mutated operative input")
assert(deepEqual(immutableTarget, targetBefore), "accepted call mutated target input")
assert(deepEqual(immutableWeapon, weaponBefore), "accepted call mutated weapon input")
local rejectedImmutableWeapon = weaponState(12, 10)
local rejectedImmutableBefore = deepCopy(rejectedImmutableWeapon)
resolver.resolve(immutableOperative, immutableTarget, rejectedImmutableWeapon, 9)
assert(deepEqual(rejectedImmutableWeapon, rejectedImmutableBefore), "rejected call mutated weapon input")

local precedenceOperative = operative()
precedenceOperative.combatStateId = "Dead"
local precedenceWeapon = weaponState()
precedenceWeapon.weaponId = "weapon.wrong"
precedenceWeapon.ammunition.loadedRounds = 0
assertRejected(
	resolver.resolve(precedenceOperative, nil, precedenceWeapon, 0),
	rejectionReasons.OperativeStateInvalid,
	precedenceWeapon,
	"operative rejection precedence"
)
local invalidPrecedenceTarget = selectedTarget()
invalidPrecedenceTarget.operativeEntityId = "operative.other"
assertRejected(
	resolver.resolve(operative(), invalidPrecedenceTarget, precedenceWeapon, 0),
	rejectionReasons.SelectedTargetInvalid,
	precedenceWeapon,
	"target rejection precedence"
)
local weaponPrecedenceTarget = selectedTarget()
assertRejected(
	resolver.resolve(operative(), weaponPrecedenceTarget, precedenceWeapon, 0),
	rejectionReasons.WeaponNotReady,
	precedenceWeapon,
	"weapon rejection precedence"
)
local ammoPrecedenceWeapon = weaponState(12, 10)
ammoPrecedenceWeapon.ammunition.loadedRounds = 0
assertRejected(
	resolver.resolve(operative(), selectedTarget(), ammoPrecedenceWeapon, 0),
	rejectionReasons.NoAmmunition,
	ammoPrecedenceWeapon,
	"ammunition rejection precedence"
)

local repeatOperative = operative()
local repeatTarget = selectedTarget()
local repeatWeapon = weaponState()
local firstRepeat = resolver.resolve(repeatOperative, repeatTarget, repeatWeapon, 5)
for _ = 1, 10 do
	local repeated = resolver.resolve(repeatOperative, repeatTarget, repeatWeapon, 5)
	assert(deepEqual(repeated, firstRepeat), "deterministic accepted result changed")
end

assert(validResult.fireResult.shotId == "shot:operative.alpha:weapon.basic_firearm:5", "unexpected ShotId policy")
assert(validResult.weaponStateAfter.ammunition.loadedRounds == 11, "one call consumed more than one round")

print(
	"AutomaticFireResolver: acceptance, rejection, cadence, ammo, precedence, determinism, and immutability checks passed"
)
