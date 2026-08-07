--!strict

-- Standalone LK-0303 fixtures for pure incapacitated transitions.
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
	TransitionNotReady = "TransitionNotReady",
	AlreadyResolved = "AlreadyResolved",
})
local contracts = {
	OperativeLifeStateIds = lifeStateIds,
	OperativeLifeTransitionRejectionReasonIds = reasons,
}
local config = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	ReviveHealth = 30,
	SoloRecoveryDurationSeconds = 8,
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

local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeIncapacitationResolver.luau"), {
	debugName = "OperativeIncapacitationResolver",
	environment = environment,
	injectGlobals = true,
})
local resolver = loader()

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

local function incapacitated(eligible: boolean?)
	local isEligible = eligible == true
	return {
		operativeEntityId = "operative.alpha",
		lifeStateId = "Incapacitated",
		healthState = {
			currentHealth = 0,
			maximumHealth = 100,
		},
		incapacitationState = {
			startedAtServerTimestamp = 10,
			bleedOutDeadlineServerTimestamp = 40,
		},
		soloRecoveryState = {
			isEligible = isEligible,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = if isEligible then 10 else nil,
			recoveryCompletionServerTimestamp = if isEligible then 18 else nil,
		},
		processedDamageEventIds = {
			["damage.prior"] = true,
		},
	}
end

local function finishingDamage(amount: number, timestamp: number?)
	return {
		damageEventId = "damage.finish.1",
		sourceEntityId = "hostile.fixture",
		targetEntityId = "operative.alpha",
		damageAmount = amount,
		serverTimestamp = timestamp or 20,
	}
end

local function soloFacts()
	return {
		operationStartedSolo = true,
		hasEverHadMultipleParticipants = false,
	}
end

local function aliveSnapshot()
	local value = incapacitated(false)
	value.lifeStateId = "Alive"
	value.healthState.currentHealth = 100
	value.incapacitationState = nil
	return value
end

local function deadSnapshot()
	local value = incapacitated(false)
	value.lifeStateId = "Dead"
	value.incapacitationState = nil
	return value
end

local function assertAccepted(result: any, afterState: string, timestamp: number, eventId: string?, context: string)
	assert(result.didTransition == true, context .. ": rejected")
	assert(result.rejectionReasonId == nil, context .. ": has rejection reason")
	assert(result.lifeStateIdBefore == "Incapacitated", context .. ": wrong prior state")
	assert(result.lifeStateIdAfter == afterState, context .. ": wrong resulting state")
	assert(result.transitionServerTimestamp == timestamp, context .. ": wrong timestamp")
	assert(result.damageEventId == eventId, context .. ": wrong event identity")
end

local function assertRejected(result: any, reasonId: string, original: any, context: string)
	assert(result.didTransition == false, context .. ": accepted")
	assert(result.rejectionReasonId == reasonId, context .. ": wrong reason")
	assert(result.lifeStateIdBefore == nil, context .. ": prior state leaked")
	assert(result.lifeStateIdAfter == nil, context .. ": resulting state leaked")
	assert(result.transitionServerTimestamp == nil, context .. ": timestamp leaked")
	assert(result.damageEventId == nil, context .. ": event identity leaked")
	assert(deepEqual(result.snapshotAfter, original), context .. ": rejected snapshot changed")
end

-- Bleed-out: before/exact/after boundaries use the stored deadline.
local beforeBleed = incapacitated(false)
assertRejected(
	resolver.evaluateBleedOut(beforeBleed, 39.999),
	reasons.TransitionNotReady,
	beforeBleed,
	"bleed-out before deadline"
)
local exactBleed = resolver.evaluateBleedOut(incapacitated(false), 40)
assertAccepted(exactBleed, "Dead", 40, nil, "bleed-out at deadline")
assert(exactBleed.snapshotAfter.healthState.currentHealth == 0, "bleed-out changed zero health")
assert(exactBleed.snapshotAfter.incapacitationState == nil, "bleed-out did not clear incapacitation")
local afterBleed = resolver.evaluateBleedOut(incapacitated(false), 45)
assertAccepted(afterBleed, "Dead", 45, nil, "bleed-out after deadline")

local snapshotDeadline = incapacitated(false)
snapshotDeadline.incapacitationState.startedAtServerTimestamp = 20
snapshotDeadline.incapacitationState.bleedOutDeadlineServerTimestamp = 50
assertRejected(
	resolver.evaluateBleedOut(snapshotDeadline, 49),
	reasons.TransitionNotReady,
	snapshotDeadline,
	"stored bleed-out deadline"
)
assertAccepted(resolver.evaluateBleedOut(snapshotDeadline, 50), "Dead", 50, nil, "stored deadline exact")

local invalidStart = incapacitated(false)
invalidStart.incapacitationState.startedAtServerTimestamp = 0 / 0
assert(
	resolver.evaluateBleedOut(invalidStart, 40).rejectionReasonId == reasons.InvalidSnapshot,
	"invalid bleed-out start accepted"
)
local invalidDeadline = incapacitated(false)
invalidDeadline.incapacitationState.bleedOutDeadlineServerTimestamp = math.huge
assert(
	resolver.evaluateBleedOut(invalidDeadline, 40).rejectionReasonId == reasons.InvalidSnapshot,
	"invalid bleed-out deadline accepted"
)
local reversedDeadline = incapacitated(false)
reversedDeadline.incapacitationState.bleedOutDeadlineServerTimestamp = 9
assert(
	resolver.evaluateBleedOut(reversedDeadline, 40).rejectionReasonId == reasons.InvalidSnapshot,
	"deadline before start accepted"
)
for _, invalidTimestamp in { -1, 0 / 0, math.huge, -math.huge } do
	assert(
		resolver.evaluateBleedOut(incapacitated(false), invalidTimestamp).rejectionReasonId
			== reasons.InvalidServerTimestamp,
		"invalid bleed-out server timestamp accepted"
	)
end
assert(
	resolver.evaluateBleedOut(incapacitated(false), 9).rejectionReasonId == reasons.StaleTransition,
	"stale bleed-out timestamp returned wrong reason"
)
assertRejected(
	resolver.evaluateBleedOut(aliveSnapshot(), 40),
	reasons.IllegalTransition,
	aliveSnapshot(),
	"Alive bleed-out"
)
assertRejected(resolver.evaluateBleedOut(deadSnapshot(), 40), reasons.AlreadyResolved, deadSnapshot(), "Dead bleed-out")
local immutableBleed = incapacitated(true)
local immutableBleedBefore = deepCopy(immutableBleed)
resolver.evaluateBleedOut(immutableBleed, 40)
assert(deepEqual(immutableBleed, immutableBleedBefore), "bleed-out mutated input")
assert(
	deepEqual(resolver.evaluateBleedOut(incapacitated(false), 40), resolver.evaluateBleedOut(incapacitated(false), 40)),
	"bleed-out was nondeterministic"
)

-- Finishing damage: magnitude-independent terminal transition and dedupe.
for _, amount in { 0.000001, 25, 999999 } do
	local result = resolver.resolveFinishingDamage(incapacitated(true), finishingDamage(amount), 20)
	assertAccepted(result, "Dead", 20, "damage.finish.1", "finishing damage")
	assert(result.snapshotAfter.healthState.currentHealth == 0, "finishing damage changed zero health")
	assert(result.snapshotAfter.incapacitationState == nil, "finishing damage retained incapacitation")
	assert(result.snapshotAfter.processedDamageEventIds["damage.finish.1"] == true, "event was not copied")
	assert(result.snapshotAfter.processedDamageEventIds["damage.prior"] == true, "prior event was not copied")
end
for _, invalidAmount in { 0, -1, 0 / 0, math.huge, -math.huge } do
	assert(
		resolver.resolveFinishingDamage(incapacitated(false), finishingDamage(invalidAmount), 20).rejectionReasonId
			== reasons.InvalidDamage,
		"invalid finishing damage accepted"
	)
end
local mismatch = finishingDamage(1)
mismatch.targetEntityId = "operative.other"
assert(
	resolver.resolveFinishingDamage(incapacitated(false), mismatch, 20).rejectionReasonId == reasons.InvalidDamage,
	"finishing target mismatch accepted"
)
for _, invalidIdentity in { "", false } do
	local invalidEvent = finishingDamage(1)
	invalidEvent.damageEventId = invalidIdentity
	assert(
		resolver.resolveFinishingDamage(incapacitated(false), invalidEvent, 20).rejectionReasonId
			== reasons.InvalidDamage,
		"invalid finishing identity accepted"
	)
end
local missingIdentity = finishingDamage(1)
missingIdentity.damageEventId = nil
assert(
	resolver.resolveFinishingDamage(incapacitated(false), missingIdentity, 20).rejectionReasonId
		== reasons.InvalidDamage,
	"missing finishing identity accepted"
)
local duplicateSnapshot = incapacitated(false)
duplicateSnapshot.processedDamageEventIds["damage.finish.1"] = true
assertRejected(
	resolver.resolveFinishingDamage(duplicateSnapshot, finishingDamage(1), 20),
	reasons.AlreadyResolved,
	duplicateSnapshot,
	"duplicate finishing damage"
)
assertRejected(
	resolver.resolveFinishingDamage(aliveSnapshot(), finishingDamage(1), 20),
	reasons.IllegalTransition,
	aliveSnapshot(),
	"Alive finishing damage"
)
assertRejected(
	resolver.resolveFinishingDamage(deadSnapshot(), finishingDamage(1), 20),
	reasons.AlreadyResolved,
	deadSnapshot(),
	"Dead finishing damage"
)
assert(
	resolver.resolveFinishingDamage(incapacitated(false), finishingDamage(1, 9), 9).rejectionReasonId
		== reasons.StaleTransition,
	"stale finishing damage returned wrong reason"
)
local immutableFinishingSnapshot = incapacitated(true)
local immutableFinishingDamage = finishingDamage(1)
local immutableFinishingSnapshotBefore = deepCopy(immutableFinishingSnapshot)
local immutableFinishingDamageBefore = deepCopy(immutableFinishingDamage)
local immutableFinishingResult =
	resolver.resolveFinishingDamage(immutableFinishingSnapshot, immutableFinishingDamage, 20)
assert(deepEqual(immutableFinishingSnapshot, immutableFinishingSnapshotBefore), "finishing mutated snapshot")
assert(deepEqual(immutableFinishingDamage, immutableFinishingDamageBefore), "finishing mutated event")
assert(
	immutableFinishingResult.snapshotAfter.processedDamageEventIds ~= immutableFinishingSnapshot.processedDamageEventIds,
	"finishing reused processed-event set"
)
local invalidEverything = incapacitated(false)
invalidEverything.operativeEntityId = ""
assert(
	resolver.resolveFinishingDamage(invalidEverything, finishingDamage(0, -1), -1).rejectionReasonId
		== reasons.InvalidSnapshot,
	"finishing snapshot precedence failed"
)
local healthBeforeDamage = incapacitated(false)
healthBeforeDamage.healthState.currentHealth = 1
assert(
	resolver.resolveFinishingDamage(healthBeforeDamage, finishingDamage(0, -1), -1).rejectionReasonId
		== reasons.InvalidHealth,
	"finishing health precedence failed"
)
assert(
	resolver.resolveFinishingDamage(incapacitated(false), finishingDamage(0, -1), -1).rejectionReasonId
		== reasons.InvalidDamage,
	"finishing damage precedence failed"
)
assert(
	deepEqual(
		resolver.resolveFinishingDamage(incapacitated(false), finishingDamage(1), 20),
		resolver.resolveFinishingDamage(incapacitated(false), finishingDamage(1), 20)
	),
	"finishing damage was nondeterministic"
)

-- Solo recovery: explicit operation history, canonical timing, one atomic use.
assertRejected(
	resolver.evaluateSoloRecovery(incapacitated(true), soloFacts(), 17.999),
	reasons.TransitionNotReady,
	incapacitated(true),
	"solo recovery before completion"
)
for _, timestamp in { 18, 25 } do
	local result = resolver.evaluateSoloRecovery(incapacitated(true), soloFacts(), timestamp)
	assertAccepted(result, "Alive", timestamp, nil, "solo recovery completion")
	assert(result.snapshotAfter.healthState.currentHealth == config.ReviveHealth, "wrong recovered health")
	assert(result.snapshotAfter.healthState.currentHealth == 30, "canonical recovered health changed")
	assert(result.snapshotAfter.soloRecoveryState.recoveriesUsed == 1, "recovery use not consumed once")
	assert(result.snapshotAfter.soloRecoveryState.isEligible == false, "recovery remained eligible")
	assert(result.snapshotAfter.incapacitationState == nil, "recovery retained incapacitation")
	assert(
		result.snapshotAfter.soloRecoveryState.recoveryStartedAtServerTimestamp == nil
			and result.snapshotAfter.soloRecoveryState.recoveryCompletionServerTimestamp == nil,
		"recovery timing was not cleared"
	)
	assert(result.snapshotAfter.invulnerabilityState == nil, "recovery created invulnerability")
end
local exhausted = incapacitated(true)
exhausted.soloRecoveryState.recoveriesUsed = 1
assertRejected(
	resolver.evaluateSoloRecovery(exhausted, soloFacts(), 18),
	reasons.AlreadyResolved,
	exhausted,
	"exhausted solo recovery"
)
local priorMultiplayer = soloFacts()
priorMultiplayer.hasEverHadMultipleParticipants = true
assertRejected(
	resolver.evaluateSoloRecovery(incapacitated(true), priorMultiplayer, 18),
	reasons.IllegalTransition,
	incapacitated(true),
	"prior multiplayer participation"
)
local nonSolo = soloFacts()
nonSolo.operationStartedSolo = false
assertRejected(
	resolver.evaluateSoloRecovery(incapacitated(true), nonSolo, 18),
	reasons.IllegalTransition,
	incapacitated(true),
	"non-solo operation"
)
local ineligible = incapacitated(true)
ineligible.soloRecoveryState.isEligible = false
assertRejected(
	resolver.evaluateSoloRecovery(ineligible, soloFacts(), 18),
	reasons.IllegalTransition,
	ineligible,
	"ineligible recovery"
)
assert(
	resolver.evaluateSoloRecovery(incapacitated(true), nil, 18).rejectionReasonId == reasons.InvalidSnapshot,
	"missing participation facts accepted"
)
for _, malformedFacts in
	{
		{},
		{ operationStartedSolo = 1, hasEverHadMultipleParticipants = false },
		{ operationStartedSolo = true, hasEverHadMultipleParticipants = "no" },
	}
do
	assert(
		resolver.evaluateSoloRecovery(incapacitated(true), malformedFacts, 18).rejectionReasonId
			== reasons.InvalidSnapshot,
		"malformed participation facts accepted"
	)
end
local missingTiming = incapacitated(true)
missingTiming.soloRecoveryState.recoveryStartedAtServerTimestamp = nil
missingTiming.soloRecoveryState.recoveryCompletionServerTimestamp = nil
assert(
	resolver.evaluateSoloRecovery(missingTiming, soloFacts(), 18).rejectionReasonId == reasons.InvalidSnapshot,
	"missing recovery timing accepted"
)
local wrongStart = incapacitated(true)
wrongStart.soloRecoveryState.recoveryStartedAtServerTimestamp = 11
assert(
	resolver.evaluateSoloRecovery(wrongStart, soloFacts(), 18).rejectionReasonId == reasons.InvalidSnapshot,
	"noncanonical recovery start accepted"
)
local wrongCompletion = incapacitated(true)
wrongCompletion.soloRecoveryState.recoveryCompletionServerTimestamp = 19
assert(
	resolver.evaluateSoloRecovery(wrongCompletion, soloFacts(), 19).rejectionReasonId == reasons.InvalidSnapshot,
	"noncanonical recovery completion accepted"
)
assert(
	resolver.evaluateSoloRecovery(incapacitated(true), soloFacts(), 9).rejectionReasonId == reasons.StaleTransition,
	"stale recovery returned wrong reason"
)
local immutableRecoverySnapshot = incapacitated(true)
local immutableParticipation = soloFacts()
local immutableRecoveryBefore = deepCopy(immutableRecoverySnapshot)
local immutableParticipationBefore = deepCopy(immutableParticipation)
local recovered = resolver.evaluateSoloRecovery(immutableRecoverySnapshot, immutableParticipation, 18)
assert(deepEqual(immutableRecoverySnapshot, immutableRecoveryBefore), "recovery mutated snapshot")
assert(deepEqual(immutableParticipation, immutableParticipationBefore), "recovery mutated participation facts")
assert(recovered.snapshotAfter ~= immutableRecoverySnapshot, "recovery returned input snapshot")
assert(recovered.snapshotAfter.healthState ~= immutableRecoverySnapshot.healthState, "recovery reused health state")
assert(
	recovered.snapshotAfter.soloRecoveryState ~= immutableRecoverySnapshot.soloRecoveryState,
	"recovery reused solo state"
)
assert(
	deepEqual(
		resolver.evaluateSoloRecovery(incapacitated(true), soloFacts(), 18),
		resolver.evaluateSoloRecovery(incapacitated(true), soloFacts(), 18)
	),
	"solo recovery was nondeterministic"
)
assertRejected(
	resolver.evaluateSoloRecovery(recovered.snapshotAfter, soloFacts(), 18),
	reasons.AlreadyResolved,
	recovered.snapshotAfter,
	"replayed recovered snapshot"
)
local secondIncapacitation = deepCopy(recovered.snapshotAfter)
secondIncapacitation.lifeStateId = "Incapacitated"
secondIncapacitation.healthState.currentHealth = 0
secondIncapacitation.incapacitationState = {
	startedAtServerTimestamp = 30,
	bleedOutDeadlineServerTimestamp = 60,
}
assertRejected(
	resolver.evaluateSoloRecovery(secondIncapacitation, soloFacts(), 38),
	reasons.AlreadyResolved,
	secondIncapacitation,
	"second-incapacitation recovery"
)

assert(table.isfrozen(resolver), "resolver module must be frozen")
print(
	"OperativeIncapacitationResolver: bleed-out, finishing death, solo recovery, precedence, determinism, and immutability passed"
)
