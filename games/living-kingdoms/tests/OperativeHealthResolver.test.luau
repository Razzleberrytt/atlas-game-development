--!strict

-- Standalone LK-0302 fixtures for the pure operative damage transition.
-- Production code is loaded with authoritative stubs and no Roblox runtime.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local lifeStateIds = table.freeze({
	Alive = "Alive",
	Incapacitated = "Incapacitated",
	Dead = "Dead",
})
local reasons = table.freeze({
	InvalidSnapshot = "InvalidSnapshot",
	InvalidHealth = "InvalidHealth",
	InvalidDamage = "InvalidDamage",
	InvalidServerTimestamp = "InvalidServerTimestamp",
	IllegalTransition = "IllegalTransition",
	StaleTransition = "StaleTransition",
	AlreadyResolved = "AlreadyResolved",
})
local contracts = {
	OperativeLifeStateIds = lifeStateIds,
	OperativeLifeTransitionRejectionReasonIds = reasons,
}
local config = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	SoloRecoveriesPerOperation = 1,
}
local replicatedStorage = {
	Shared = {
		Config = { OperativeLifeConfig = CONFIG_TOKEN },
		Health = { OperativeLifeContracts = CONTRACTS_TOKEN },
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

local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeHealthResolver.luau"), {
	debugName = "OperativeHealthResolver",
	environment = environment,
	injectGlobals = true,
})
local resolver = loader()

local function snapshot(currentHealth: number)
	return {
		operativeEntityId = "operative.alpha",
		lifeStateId = "Alive",
		healthState = {
			currentHealth = currentHealth,
			maximumHealth = 100,
		},
		incapacitationState = nil,
		soloRecoveryState = {
			isEligible = false,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = nil,
			recoveryCompletionServerTimestamp = nil,
		},
		processedDamageEventIds = {},
	}
end

local function damage(amount: number, timestamp: number?)
	return {
		damageEventId = "damage.event.1",
		sourceEntityId = "hostile.fixture",
		targetEntityId = "operative.alpha",
		damageAmount = amount,
		serverTimestamp = timestamp or 10,
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

local function assertAccepted(result: any, beforeState: string, afterState: string, context: string)
	assert(result.didTransition == true, context .. ": rejected")
	assert(result.rejectionReasonId == nil, context .. ": accepted result has rejection")
	assert(result.lifeStateIdBefore == beforeState, context .. ": wrong prior state")
	assert(result.lifeStateIdAfter == afterState, context .. ": wrong resulting state")
	assert(result.transitionServerTimestamp == 10, context .. ": wrong transition timestamp")
	assert(result.damageEventId == "damage.event.1", context .. ": missing damage correlation")
end

local function assertRejected(result: any, reasonId: string, original: any, context: string)
	assert(result.didTransition == false, context .. ": accepted")
	assert(result.rejectionReasonId == reasonId, context .. ": wrong rejection reason")
	assert(result.lifeStateIdBefore == nil, context .. ": rejected result has prior accepted state")
	assert(result.lifeStateIdAfter == nil, context .. ": rejected result has resulting accepted state")
	assert(result.transitionServerTimestamp == nil, context .. ": rejected result has accepted timestamp")
	assert(result.damageEventId == nil, context .. ": rejected result has accepted correlation")
	assert(deepEqual(result.snapshotAfter, original), context .. ": rejected snapshot changed")
end

local validSnapshot = snapshot(100)
local validDamage = damage(20)
local nonlethal = resolver.resolveDamage(validSnapshot, validDamage, 10)
assertAccepted(nonlethal, "Alive", "Alive", "valid nonlethal damage")
assert(nonlethal.snapshotAfter.healthState.currentHealth == 80, "nonlethal damage was not subtracted")
assert(nonlethal.snapshotAfter.healthState.maximumHealth == 100, "maximum health changed")
assert(nonlethal.snapshotAfter.incapacitationState == nil, "nonlethal damage created incapacitation")
assert(nonlethal.snapshotAfter.processedDamageEventIds["damage.event.1"] == true, "event was not committed")

local leavesOne = resolver.resolveDamage(snapshot(21), damage(20), 10)
assertAccepted(leavesOne, "Alive", "Alive", "damage leaving exactly one health")
assert(leavesOne.snapshotAfter.healthState.currentHealth == 1, "exactly one health boundary failed")

local exactZero = resolver.resolveDamage(snapshot(20), damage(20), 10)
assertAccepted(exactZero, "Alive", "Incapacitated", "exact-zero damage")
assert(exactZero.snapshotAfter.healthState.currentHealth == 0, "exact-zero health was not clamped")
assert(exactZero.snapshotAfter.lifeStateId == "Incapacitated", "exact-zero did not incapacitate")
assert(exactZero.snapshotAfter.lifeStateId ~= "Dead", "ordinary lethal damage entered Dead")
assert(exactZero.snapshotAfter.incapacitationState.startedAtServerTimestamp == 10, "wrong incapacitation time")
assert(exactZero.snapshotAfter.incapacitationState.bleedOutDeadlineServerTimestamp == 40, "deadline is not 30 seconds")
assert(exactZero.snapshotAfter.soloRecoveryState.recoveryStartedAtServerTimestamp == nil, "solo recovery began")
assert(exactZero.snapshotAfter.soloRecoveryState.recoveryCompletionServerTimestamp == nil, "solo recovery completed")

local overkill = resolver.resolveDamage(snapshot(5), damage(999), 10)
assertAccepted(overkill, "Alive", "Incapacitated", "overkill")
assert(overkill.snapshotAfter.healthState.currentHealth == 0, "overkill was not discarded")
assert(overkill.snapshotAfter.incapacitationState.bleedOutDeadlineServerTimestamp == 40, "overkill shortened deadline")

for name, invalidAmount in
	{
		zero = 0,
		negative = -1,
		nan = 0 / 0,
		positive_infinity = math.huge,
		negative_infinity = -math.huge,
	}
do
	local before = snapshot(100)
	local result = resolver.resolveDamage(before, damage(invalidAmount), 10)
	assert(result.rejectionReasonId == reasons.InvalidDamage, name .. " damage returned wrong reason")
	assert(before.healthState.currentHealth == 100, name .. " damage mutated input health")
end

local mismatchedDamage = damage(20)
mismatchedDamage.targetEntityId = "operative.other"
assertRejected(
	resolver.resolveDamage(snapshot(100), mismatchedDamage, 10),
	reasons.InvalidDamage,
	snapshot(100),
	"mismatched target"
)
local emptyIdentityDamage = damage(20)
emptyIdentityDamage.damageEventId = ""
assertRejected(
	resolver.resolveDamage(snapshot(100), emptyIdentityDamage, 10),
	reasons.InvalidDamage,
	snapshot(100),
	"empty event identity"
)
local missingIdentityDamage = damage(20)
missingIdentityDamage.damageEventId = nil
assertRejected(
	resolver.resolveDamage(snapshot(100), missingIdentityDamage, 10),
	reasons.InvalidDamage,
	snapshot(100),
	"missing event identity"
)
local emptySourceDamage = damage(20)
emptySourceDamage.sourceEntityId = ""
assertRejected(
	resolver.resolveDamage(snapshot(100), emptySourceDamage, 10),
	reasons.InvalidDamage,
	snapshot(100),
	"empty source identity"
)

for name, invalidTimestamp in
	{
		negative = -1,
		nan = 0 / 0,
		positive_infinity = math.huge,
		negative_infinity = -math.huge,
	}
do
	local result = resolver.resolveDamage(snapshot(100), damage(20, invalidTimestamp), invalidTimestamp)
	assert(result.rejectionReasonId == reasons.InvalidServerTimestamp, name .. " timestamp returned wrong reason")
end
local inconsistentTimestamp = resolver.resolveDamage(snapshot(100), damage(20, 9), 10)
assert(inconsistentTimestamp.rejectionReasonId == reasons.InvalidServerTimestamp, "inconsistent timestamp accepted")

local unknownState = snapshot(100)
unknownState.lifeStateId = "Unknown"
assertRejected(
	resolver.resolveDamage(unknownState, damage(20), 10),
	reasons.InvalidSnapshot,
	unknownState,
	"unknown life state"
)
local emptyOperativeId = snapshot(100)
emptyOperativeId.operativeEntityId = ""
assertRejected(
	resolver.resolveDamage(emptyOperativeId, damage(20), 10),
	reasons.InvalidSnapshot,
	emptyOperativeId,
	"empty operative identity"
)

local invalidHealthCases = {
	{ name = "NaN current", currentHealth = 0 / 0, maximumHealth = 100 },
	{ name = "negative current", currentHealth = -1, maximumHealth = 100 },
	{ name = "above maximum", currentHealth = 101, maximumHealth = 100 },
	{ name = "zero maximum", currentHealth = 1, maximumHealth = 0 },
	{ name = "infinite maximum", currentHealth = 1, maximumHealth = math.huge },
	{ name = "noncanonical maximum", currentHealth = 50, maximumHealth = 99 },
	{ name = "Alive at zero", currentHealth = 0, maximumHealth = 100 },
}
for _, fixture in invalidHealthCases do
	local malformed = snapshot(100)
	malformed.healthState.currentHealth = fixture.currentHealth
	malformed.healthState.maximumHealth = fixture.maximumHealth
	local result = resolver.resolveDamage(malformed, damage(20), 10)
	assert(result.rejectionReasonId == reasons.InvalidHealth, fixture.name .. " returned wrong reason")
end

local aliveWithIncapacitation = snapshot(100)
aliveWithIncapacitation.incapacitationState = {
	startedAtServerTimestamp = 1,
	bleedOutDeadlineServerTimestamp = 31,
}
assertRejected(
	resolver.resolveDamage(aliveWithIncapacitation, damage(20), 10),
	reasons.InvalidSnapshot,
	aliveWithIncapacitation,
	"Alive with incapacitation state"
)

local malformedSolo = snapshot(100)
malformedSolo.soloRecoveryState.recoveriesUsed = 2
assertRejected(
	resolver.resolveDamage(malformedSolo, damage(20), 10),
	reasons.InvalidSnapshot,
	malformedSolo,
	"malformed solo recovery count"
)
local malformedSoloTime = snapshot(100)
malformedSoloTime.soloRecoveryState.recoveryStartedAtServerTimestamp = 2
assertRejected(
	resolver.resolveDamage(malformedSoloTime, damage(20), 10),
	reasons.InvalidSnapshot,
	malformedSoloTime,
	"malformed solo recovery timestamp pair"
)

local incapacitated = snapshot(0)
incapacitated.lifeStateId = "Incapacitated"
incapacitated.incapacitationState = {
	startedAtServerTimestamp = 1,
	bleedOutDeadlineServerTimestamp = 31,
}
assertRejected(
	resolver.resolveDamage(incapacitated, damage(20), 10),
	reasons.IllegalTransition,
	incapacitated,
	"Incapacitated input"
)
local malformedIncapacitation = deepCopy(incapacitated)
malformedIncapacitation.incapacitationState.startedAtServerTimestamp = 0 / 0
assert(
	resolver.resolveDamage(malformedIncapacitation, damage(20), 10).rejectionReasonId == reasons.InvalidSnapshot,
	"malformed incapacitation timestamp returned wrong reason"
)
local dead = snapshot(0)
dead.lifeStateId = "Dead"
assertRejected(resolver.resolveDamage(dead, damage(20), 10), reasons.IllegalTransition, dead, "Dead input")

local firstApplication = resolver.resolveDamage(snapshot(100), damage(20), 10)
local duplicate = resolver.resolveDamage(firstApplication.snapshotAfter, damage(20), 10)
assertRejected(duplicate, reasons.AlreadyResolved, firstApplication.snapshotAfter, "committed duplicate event")
assert(duplicate.snapshotAfter.healthState.currentHealth == 80, "duplicate reduced health twice")
local duplicateLethal = resolver.resolveDamage(exactZero.snapshotAfter, damage(20), 10)
assertRejected(duplicateLethal, reasons.IllegalTransition, exactZero.snapshotAfter, "committed lethal duplicate")
assert(duplicateLethal.snapshotAfter.lifeStateId == "Incapacitated", "lethal duplicate changed life state")

local invalidEverything = snapshot(0)
invalidEverything.operativeEntityId = ""
invalidEverything.lifeStateId = "Unknown"
assert(
	resolver.resolveDamage(invalidEverything, damage(0, -1), -1).rejectionReasonId == reasons.InvalidSnapshot,
	"snapshot precedence failed"
)
local healthBeforeDamage = snapshot(0)
assert(
	resolver.resolveDamage(healthBeforeDamage, damage(0, -1), -1).rejectionReasonId == reasons.InvalidHealth,
	"health precedence failed"
)
local damageBeforeTimestamp = snapshot(100)
assert(
	resolver.resolveDamage(damageBeforeTimestamp, damage(0, -1), -1).rejectionReasonId == reasons.InvalidDamage,
	"damage precedence failed"
)
local timestampBeforeIllegal = deepCopy(incapacitated)
timestampBeforeIllegal.processedDamageEventIds["damage.event.1"] = true
assert(
	resolver.resolveDamage(timestampBeforeIllegal, damage(20, -1), -1).rejectionReasonId
		== reasons.InvalidServerTimestamp,
	"timestamp precedence failed"
)
local illegalBeforeDuplicate = deepCopy(incapacitated)
illegalBeforeDuplicate.processedDamageEventIds["damage.event.1"] = true
assert(
	resolver.resolveDamage(illegalBeforeDuplicate, damage(20), 10).rejectionReasonId == reasons.IllegalTransition,
	"illegal-transition precedence failed"
)

local immutableSnapshot = snapshot(20)
local immutableDamage = damage(20)
local immutableSnapshotBefore = deepCopy(immutableSnapshot)
local immutableDamageBefore = deepCopy(immutableDamage)
local immutableResult = resolver.resolveDamage(immutableSnapshot, immutableDamage, 10)
assert(deepEqual(immutableSnapshot, immutableSnapshotBefore), "accepted call mutated snapshot input")
assert(deepEqual(immutableDamage, immutableDamageBefore), "accepted call mutated damage input")
assert(immutableResult.snapshotAfter ~= immutableSnapshot, "accepted call returned input snapshot")
assert(immutableResult.snapshotAfter.healthState ~= immutableSnapshot.healthState, "accepted health was not copied")
assert(
	immutableResult.snapshotAfter.soloRecoveryState ~= immutableSnapshot.soloRecoveryState,
	"accepted solo state was not copied"
)
assert(
	immutableResult.snapshotAfter.processedDamageEventIds ~= immutableSnapshot.processedDamageEventIds,
	"accepted processed-event set was not copied"
)

local rejectedSnapshot = snapshot(100)
local rejectedDamage = damage(20)
rejectedDamage.targetEntityId = "operative.other"
local rejectedSnapshotBefore = deepCopy(rejectedSnapshot)
local rejectedDamageBefore = deepCopy(rejectedDamage)
local rejectedResult = resolver.resolveDamage(rejectedSnapshot, rejectedDamage, 10)
assert(deepEqual(rejectedSnapshot, rejectedSnapshotBefore), "rejected call mutated snapshot input")
assert(deepEqual(rejectedDamage, rejectedDamageBefore), "rejected call mutated damage input")
assert(deepEqual(rejectedResult.snapshotAfter, rejectedSnapshotBefore), "rejected result did not preserve snapshot")
assert(rejectedResult.snapshotAfter ~= rejectedSnapshot, "rejected result returned input snapshot")

local equivalentSnapshotA = snapshot(20)
local equivalentSnapshotB = deepCopy(equivalentSnapshotA)
local equivalentDamageA = damage(20)
local equivalentDamageB = deepCopy(equivalentDamageA)
local deterministicA = resolver.resolveDamage(equivalentSnapshotA, equivalentDamageA, 10)
local deterministicB = resolver.resolveDamage(equivalentSnapshotB, equivalentDamageB, 10)
assert(deepEqual(deterministicA, deterministicB), "equivalent inputs produced different results")

local p2DamageEvent = damage(20)
p2DamageEvent.shotId = "shot:operative.alpha:weapon.basic_firearm:9.9"
p2DamageEvent.weaponId = "weapon.basic_firearm"
p2DamageEvent.damageTypeId = "Ballistic"
local adaptedP2 = resolver.resolveDamage(snapshot(100), p2DamageEvent, 10)
assertAccepted(adaptedP2, "Alive", "Alive", "P2 authoritative damage adaptation")
assert(adaptedP2.snapshotAfter.healthState.currentHealth == 80, "P2 event adaptation changed damage")

assert(table.isfrozen(resolver), "resolver module must be frozen")
print(
	"OperativeHealthResolver: health boundaries, incapacitation, authority, validation precedence, duplicates, determinism, and immutability passed"
)
