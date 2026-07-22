--!strict

-- Standalone LK-0304 fixtures for pure revive eligibility and transitions.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local COMBAT_CONTRACTS_TOKEN = {}

local lifeStateIds = table.freeze({
	Alive = "Alive",
	Incapacitated = "Incapacitated",
	Dead = "Dead",
})
local reasons = table.freeze({
	InvalidReviveInput = "InvalidReviveInput",
	ReviverNotAlive = "ReviverNotAlive",
	TargetNotIncapacitated = "TargetNotIncapacitated",
	SameOperative = "SameOperative",
	TargetBusy = "TargetBusy",
	OutOfRange = "OutOfRange",
	NoLineOfSight = "NoLineOfSight",
	SessionNotActive = "SessionNotActive",
	ReviveNotComplete = "ReviveNotComplete",
	ReviveInterrupted = "ReviveInterrupted",
	InvalidServerTimestamp = "InvalidServerTimestamp",
})
local statusIds = table.freeze({
	Active = "Active",
	Cancelled = "Cancelled",
	Completed = "Completed",
})
local contracts = {
	OperativeLifeStateIds = lifeStateIds,
	ReviveRejectionReasonIds = reasons,
	ReviveSessionStatusIds = statusIds,
}
local combatContracts = {
	WeaponReadinessStateIds = table.freeze({
		Ready = "Ready",
		CadenceBlocked = "CadenceBlocked",
		Reloading = "Reloading",
		Empty = "Empty",
		Disabled = "Disabled",
	}),
	TargetSelectionReasonIds = table.freeze({
		ThreateningClosest = "ThreateningClosest",
		ValidClosest = "ValidClosest",
	}),
}
local config = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	ReviveRangeStuds = 8,
	ReviveDurationSeconds = 4,
	ReviveHealth = 30,
	SoloRecoveriesPerOperation = 1,
}
local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = COMBAT_CONTRACTS_TOKEN },
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
		if token == COMBAT_CONTRACTS_TOKEN then
			return combatContracts
		end
		if token == CONTRACTS_TOKEN then
			return contracts
		end
		if token == CONFIG_TOKEN then
			return config
		end
		error("unexpected module request")
	end,
}

local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveResolver.luau"), {
	debugName = "OperativeReviveResolver",
	environment = environment,
	injectGlobals = true,
})
local productionResolver = loader()

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

local function alive(operativeEntityId: string)
	return {
		operativeEntityId = operativeEntityId,
		lifeStateId = "Alive",
		healthState = { currentHealth = 80, maximumHealth = 100 },
		incapacitationState = nil,
		soloRecoveryState = {
			isEligible = false,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = nil,
			recoveryCompletionServerTimestamp = nil,
		},
		processedDamageEventIds = { ["damage.reviver.prior"] = true },
	}
end

local function incapacitated(operativeEntityId: string)
	return {
		operativeEntityId = operativeEntityId,
		lifeStateId = "Incapacitated",
		healthState = { currentHealth = 0, maximumHealth = 100 },
		incapacitationState = {
			startedAtServerTimestamp = 10,
			bleedOutDeadlineServerTimestamp = 40,
		},
		soloRecoveryState = {
			isEligible = true,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = 10,
			recoveryCompletionServerTimestamp = 18,
		},
		processedDamageEventIds = { ["damage.target.prior"] = true },
	}
end

local function dead(operativeEntityId: string)
	local snapshot = incapacitated(operativeEntityId)
	snapshot.lifeStateId = "Dead"
	snapshot.incapacitationState = nil
	return snapshot
end

local function beginFacts()
	return {
		sessionId = "revive.1",
		reviverOperativeEntityId = "operative.reviver",
		targetOperativeEntityId = "operative.target",
		distanceStuds = 8,
		hasLineOfSight = true,
		serverTimestamp = 20,
		activeSessionIdForTarget = nil,
		hasConflictingActiveSession = false,
	}
end

local function continueFacts(timestamp: number?)
	return {
		sessionId = "revive.1",
		reviverOperativeEntityId = "operative.reviver",
		targetOperativeEntityId = "operative.target",
		distanceStuds = 8,
		hasLineOfSight = true,
		holdRemainsActive = true,
		serverTimestamp = timestamp or 20,
		activeSessionIdForTarget = "revive.1",
		hasConflictingActiveSession = false,
		reviverRemainsConnectedAndParticipating = true,
		reviverMovementRemainedValid = true,
		reviverReceivedNoInterruptingDamage = true,
	}
end

local function combatState()
	return {
		weaponState = {
			weaponId = "weapon.basic_firearm",
			readinessStateId = "Reloading",
			ammunition = {
				weaponId = "weapon.basic_firearm",
				loadedRounds = 5,
				reserveRounds = 17,
				magazineCapacity = 12,
			},
			cadence = {
				weaponId = "weapon.basic_firearm",
				lastFireServerTimestamp = 15,
				nextAllowedFireServerTimestamp = 20,
			},
			reloadState = {
				weaponId = "weapon.basic_firearm",
				startedAtServerTimestamp = 19,
				completionServerTimestamp = 21,
			},
		},
		processedShotIds = {
			["shot.prior"] = true,
		},
		selectedTargetState = {
			operativeEntityId = "operative.target",
			targetEntityId = "hostile.fixture",
			isValid = true,
			selectionReasonId = "ValidClosest",
			selectedAtServerTimestamp = 19,
		},
	}
end

local resolver = {
	beginRevive = productionResolver.beginRevive,
	continueRevive = function(
		reviverSnapshot: any,
		targetSnapshot: any,
		sessionState: any,
		authorityFacts: any,
		completionCombatState: any?
	)
		return productionResolver.continueRevive(
			reviverSnapshot,
			targetSnapshot,
			sessionState,
			authorityFacts,
			completionCombatState or combatState()
		)
	end,
}

local function assertRejected(actual: any, expectedReason: string)
	assert(not actual.didTransition, "rejection must not transition")
	assert(actual.rejectionReasonId == expectedReason, "unexpected rejection reason")
end

local reviver = alive("operative.reviver")
local target = incapacitated("operative.target")

-- Begin eligibility, canonical timing, boundaries, precedence, and immutability.
local reviverBeforeBegin = deepCopy(reviver)
local targetBeforeBegin = deepCopy(target)
local facts = beginFacts()
local factsBeforeBegin = deepCopy(facts)
local began = resolver.beginRevive(reviver, target, facts)
assert(began.didTransition and began.rejectionReasonId == nil, "valid begin must transition")
assert(began.sessionStateAfter.statusId == "Active", "begin must create an Active session")
assert(began.sessionStateAfter.sessionId == facts.sessionId, "begin must preserve authoritative session identity")
assert(began.sessionStateAfter.startedAtServerTimestamp == 20, "begin must use authoritative start time")
assert(began.sessionStateAfter.completionServerTimestamp == 24, "begin must derive the four-second deadline")
assert(began.normalizedProgress == 0, "begin must start at zero progress")
assert(deepEqual(reviver, reviverBeforeBegin), "begin mutated reviver")
assert(deepEqual(target, targetBeforeBegin), "begin mutated target")
assert(deepEqual(facts, factsBeforeBegin), "begin mutated authority facts")
assert(began.targetSnapshotAfter ~= target, "begin must copy target output")
assert(began.targetSnapshotAfter.healthState ~= target.healthState, "begin must copy nested target health")

local overRange = beginFacts()
overRange.distanceStuds = 8.000001
assertRejected(resolver.beginRevive(reviver, target, overRange), "OutOfRange")
for _, invalidDistance in { -0.001, 0 / 0, math.huge, -math.huge } do
	local invalid = beginFacts()
	invalid.distanceStuds = invalidDistance
	assertRejected(resolver.beginRevive(reviver, target, invalid), "OutOfRange")
end
local noLineOfSight = beginFacts()
noLineOfSight.hasLineOfSight = false
assertRejected(resolver.beginRevive(reviver, target, noLineOfSight), "NoLineOfSight")
assertRejected(resolver.beginRevive(incapacitated("operative.reviver"), target, beginFacts()), "ReviverNotAlive")
assertRejected(resolver.beginRevive(reviver, alive("operative.target"), beginFacts()), "TargetNotIncapacitated")
assertRejected(resolver.beginRevive(reviver, dead("operative.target"), beginFacts()), "TargetNotIncapacitated")

local sameFacts = beginFacts()
sameFacts.targetOperativeEntityId = "operative.reviver"
assertRejected(resolver.beginRevive(reviver, reviver, sameFacts), "SameOperative")
local busyFacts = beginFacts()
busyFacts.activeSessionIdForTarget = "revive.other"
assertRejected(resolver.beginRevive(reviver, target, busyFacts), "TargetBusy")
local duplicateFacts = beginFacts()
duplicateFacts.hasConflictingActiveSession = true
assertRejected(resolver.beginRevive(reviver, target, duplicateFacts), "TargetBusy")
local invalidSessionIdentity = beginFacts()
invalidSessionIdentity.sessionId = ""
assertRejected(resolver.beginRevive(reviver, target, invalidSessionIdentity), "InvalidReviveInput")
local invalidParticipantIdentity = beginFacts()
invalidParticipantIdentity.reviverOperativeEntityId = ""
assertRejected(resolver.beginRevive(reviver, target, invalidParticipantIdentity), "InvalidReviveInput")
for _, invalidTimestamp in { -1, 0 / 0, math.huge, -math.huge } do
	local invalid = beginFacts()
	invalid.serverTimestamp = invalidTimestamp
	assertRejected(resolver.beginRevive(reviver, target, invalid), "InvalidServerTimestamp")
end

local beginPrecedence = beginFacts()
beginPrecedence.sessionId = ""
beginPrecedence.serverTimestamp = -1
beginPrecedence.distanceStuds = 9
beginPrecedence.hasLineOfSight = false
assertRejected(
	resolver.beginRevive(dead("operative.reviver"), dead("operative.target"), beginPrecedence),
	"InvalidReviveInput"
)
beginPrecedence = beginFacts()
beginPrecedence.serverTimestamp = -1
beginPrecedence.reviverOperativeEntityId = "same"
beginPrecedence.targetOperativeEntityId = "same"
local same = alive("same")
assertRejected(resolver.beginRevive(same, same, beginPrecedence), "InvalidServerTimestamp")
beginPrecedence.serverTimestamp = 20
assertRejected(resolver.beginRevive(same, same, beginPrecedence), "SameOperative")
local statePrecedenceFacts = beginFacts()
statePrecedenceFacts.activeSessionIdForTarget = "revive.other"
statePrecedenceFacts.distanceStuds = 9
statePrecedenceFacts.hasLineOfSight = false
assertRejected(
	resolver.beginRevive(dead("operative.reviver"), dead("operative.target"), statePrecedenceFacts),
	"ReviverNotAlive"
)
assertRejected(resolver.beginRevive(reviver, dead("operative.target"), statePrecedenceFacts), "TargetNotIncapacitated")
assertRejected(resolver.beginRevive(reviver, target, statePrecedenceFacts), "TargetBusy")
statePrecedenceFacts.activeSessionIdForTarget = nil
assertRejected(resolver.beginRevive(reviver, target, statePrecedenceFacts), "OutOfRange")

-- Progress boundaries and continuity interruptions.
local session = began.sessionStateAfter
local function assertContinuityInterruption(authorityFacts: any, context: string)
	local reviverBefore = deepCopy(reviver)
	local targetBefore = deepCopy(target)
	local sessionBefore = deepCopy(session)
	local factsBefore = deepCopy(authorityFacts)
	local combatBefore = combatState()
	local combatInput = deepCopy(combatBefore)
	local interruption = resolver.continueRevive(reviver, target, session, authorityFacts, combatInput)
	assert(interruption.didTransition, context .. ": interruption must transition")
	assert(interruption.rejectionReasonId == "ReviveInterrupted", context .. ": wrong interruption reason")
	assert(interruption.sessionStateAfter.statusId == "Cancelled", context .. ": session must cancel")
	assert(interruption.normalizedProgress == 0, context .. ": progress must reset")
	assert(interruption.targetSnapshotAfter.lifeStateId == "Incapacitated", context .. ": target state changed")
	assert(interruption.targetSnapshotAfter.healthState.currentHealth == 0, context .. ": target health changed")
	assert(deepEqual(interruption.combatStateAfter, combatBefore), context .. ": combat state changed")
	assert(interruption.combatStateAfter ~= combatInput, context .. ": combat output was not copied")
	assert(deepEqual(reviver, reviverBefore), context .. ": reviver input mutated")
	assert(deepEqual(target, targetBefore), context .. ": target input mutated")
	assert(deepEqual(session, sessionBefore), context .. ": session input mutated")
	assert(deepEqual(authorityFacts, factsBefore), context .. ": facts input mutated")
	assert(deepEqual(combatInput, combatBefore), context .. ": combat input mutated")

	local retryAuthorityFacts = beginFacts()
	retryAuthorityFacts.sessionId = "retry." .. context
	retryAuthorityFacts.serverTimestamp = 30
	local retryResult = resolver.beginRevive(reviver, target, retryAuthorityFacts)
	assert(retryResult.didTransition, context .. ": retry did not begin")
	assert(retryResult.normalizedProgress == 0, context .. ": retry inherited progress")
	return interruption
end

local immediate = resolver.continueRevive(reviver, target, session, continueFacts(20))
assertRejected(immediate, "ReviveNotComplete")
assert(immediate.normalizedProgress == 0, "immediate progress must be zero")
local almost = resolver.continueRevive(reviver, target, session, continueFacts(23.999999))
assertRejected(almost, "ReviveNotComplete")
assert(almost.normalizedProgress > 0 and almost.normalizedProgress < 1, "pre-deadline progress must be bounded")
local exact = resolver.continueRevive(reviver, target, session, continueFacts(24))
assert(exact.didTransition and exact.sessionStateAfter.statusId == "Completed", "deadline must complete")
local after = resolver.continueRevive(reviver, target, session, continueFacts(30))
assert(
	after.didTransition and after.sessionStateAfter.statusId == "Completed",
	"post-deadline evaluation must complete"
)
assert(after.normalizedProgress == 1, "completed progress must be clamped to one")

local stale = resolver.continueRevive(reviver, target, session, continueFacts(19.999))
assertRejected(stale, "InvalidServerTimestamp")
local inactive = deepCopy(session)
inactive.statusId = "Cancelled"
assertRejected(resolver.continueRevive(reviver, target, inactive, continueFacts(24)), "SessionNotActive")
local completed = deepCopy(exact.sessionStateAfter)
assertRejected(resolver.continueRevive(reviver, target, completed, continueFacts(25)), "SessionNotActive")

local mismatchFacts = continueFacts(21)
mismatchFacts.sessionId = "revive.replaced"
mismatchFacts.activeSessionIdForTarget = "revive.replaced"
local mismatch = resolver.continueRevive(reviver, target, session, mismatchFacts)
assert(mismatch.didTransition and mismatch.rejectionReasonId == "ReviveInterrupted", "mismatch must interrupt")
assert(mismatch.sessionStateAfter.statusId == "Cancelled", "mismatch must cancel")

local reviverLost = resolver.continueRevive(incapacitated("operative.reviver"), target, session, continueFacts(21))
assert(reviverLost.didTransition and reviverLost.rejectionReasonId == "ReviverNotAlive", "reviver state must interrupt")
local targetRecovered = resolver.continueRevive(reviver, alive("operative.target"), session, continueFacts(21))
assert(
	targetRecovered.didTransition and targetRecovered.rejectionReasonId == "TargetNotIncapacitated",
	"target state must interrupt"
)
local targetDied = resolver.continueRevive(reviver, dead("operative.target"), session, continueFacts(21))
assert(targetDied.didTransition and targetDied.sessionStateAfter.statusId == "Cancelled", "death must interrupt")

local disconnectedFacts = continueFacts(21)
disconnectedFacts.reviverRemainsConnectedAndParticipating = false
local disconnected = assertContinuityInterruption(disconnectedFacts, "disconnect")
local invalidMovementFacts = continueFacts(21)
invalidMovementFacts.distanceStuds = 4
invalidMovementFacts.reviverMovementRemainedValid = false
local invalidMovement = assertContinuityInterruption(invalidMovementFacts, "movement")
local damagedFacts = continueFacts(21)
damagedFacts.reviverReceivedNoInterruptingDamage = false
local damaged = assertContinuityInterruption(damagedFacts, "damage")
assert(disconnected.normalizedProgress == 0, "disconnect banked progress")
assert(invalidMovement.normalizedProgress == 0, "movement banked progress")
assert(damaged.normalizedProgress == 0, "damage banked progress")

for _, factName in
	{
		"reviverRemainsConnectedAndParticipating",
		"reviverMovementRemainedValid",
		"reviverReceivedNoInterruptingDamage",
	}
do
	local malformedFacts = continueFacts(21)
	malformedFacts[factName] = "not-a-boolean"
	assertRejected(resolver.continueRevive(reviver, target, session, malformedFacts), "InvalidReviveInput")
end

local releasedFacts = continueFacts(21)
releasedFacts.holdRemainsActive = false
local released = resolver.continueRevive(reviver, target, session, releasedFacts)
assert(released.didTransition and released.rejectionReasonId == "ReviveInterrupted", "release must interrupt")
local movedFacts = continueFacts(21)
movedFacts.distanceStuds = 8.001
local moved = resolver.continueRevive(reviver, target, session, movedFacts)
assert(moved.didTransition and moved.rejectionReasonId == "OutOfRange", "range loss must interrupt")
local obscuredFacts = continueFacts(21)
obscuredFacts.hasLineOfSight = false
local obscured = resolver.continueRevive(reviver, target, session, obscuredFacts)
assert(obscured.didTransition and obscured.rejectionReasonId == "NoLineOfSight", "line-of-sight loss must interrupt")

local activePrecedence = continueFacts(-1)
activePrecedence.holdRemainsActive = false
activePrecedence.distanceStuds = 9
activePrecedence.hasLineOfSight = false
local malformedSession = deepCopy(session)
malformedSession.sessionId = ""
assertRejected(
	resolver.continueRevive(dead("operative.reviver"), dead("operative.target"), malformedSession, activePrecedence),
	"InvalidReviveInput"
)
local malformedTiming = deepCopy(session)
malformedTiming.startedAtServerTimestamp = nil
local malformedTimingResult = resolver.continueRevive(reviver, target, malformedTiming, continueFacts(21))
assertRejected(malformedTimingResult, "InvalidReviveInput")
assert(malformedTimingResult.normalizedProgress == 0, "malformed session must not derive progress")
assertRejected(
	resolver.continueRevive(dead("operative.reviver"), dead("operative.target"), session, activePrecedence),
	"InvalidServerTimestamp"
)
activePrecedence.serverTimestamp = 21
local cancelledForPrecedence = deepCopy(session)
cancelledForPrecedence.statusId = "Cancelled"
assertRejected(
	resolver.continueRevive(
		dead("operative.reviver"),
		dead("operative.target"),
		cancelledForPrecedence,
		activePrecedence
	),
	"SessionNotActive"
)
local participantPrecedence = continueFacts(21)
participantPrecedence.sessionId = "revive.replaced"
participantPrecedence.activeSessionIdForTarget = "revive.replaced"
local participantFirst =
	resolver.continueRevive(dead("operative.reviver"), dead("operative.target"), session, participantPrecedence)
assert(participantFirst.rejectionReasonId == "ReviveInterrupted", "participant mismatch precedence changed")
local continuityPrecedence = continueFacts(21)
continuityPrecedence.reviverRemainsConnectedAndParticipating = false
continuityPrecedence.reviverMovementRemainedValid = false
continuityPrecedence.reviverReceivedNoInterruptingDamage = false
continuityPrecedence.holdRemainsActive = false
continuityPrecedence.distanceStuds = 9
continuityPrecedence.hasLineOfSight = false
assert(
	resolver.continueRevive(dead("operative.reviver"), dead("operative.target"), session, continuityPrecedence).rejectionReasonId
		== "ReviverNotAlive",
	"reviver precedence changed"
)
assert(
	resolver.continueRevive(reviver, dead("operative.target"), session, continuityPrecedence).rejectionReasonId
		== "TargetNotIncapacitated",
	"target precedence changed"
)
assert(
	resolver.continueRevive(reviver, target, session, continuityPrecedence).rejectionReasonId == "ReviveInterrupted",
	"connected/participating precedence changed"
)
continuityPrecedence.reviverRemainsConnectedAndParticipating = true
assert(
	resolver.continueRevive(reviver, target, session, continuityPrecedence).rejectionReasonId == "ReviveInterrupted",
	"movement precedence changed"
)
continuityPrecedence.reviverMovementRemainedValid = true
assert(
	resolver.continueRevive(reviver, target, session, continuityPrecedence).rejectionReasonId == "ReviveInterrupted",
	"damage precedence changed"
)
continuityPrecedence.reviverReceivedNoInterruptingDamage = true
assert(
	resolver.continueRevive(reviver, target, session, continuityPrecedence).rejectionReasonId == "ReviveInterrupted",
	"hold precedence changed"
)
continuityPrecedence.holdRemainsActive = true
assert(
	resolver.continueRevive(reviver, target, session, continuityPrecedence).rejectionReasonId == "OutOfRange",
	"range precedence changed"
)
continuityPrecedence.distanceStuds = 8
assert(
	resolver.continueRevive(reviver, target, session, continuityPrecedence).rejectionReasonId == "NoLineOfSight",
	"line-of-sight precedence changed"
)

-- Interruption resets all progress; a retry is a new canonical session.
assert(released.sessionStateAfter.statusId == "Cancelled", "interrupted session must be Cancelled")
assert(released.normalizedProgress == 0, "interruption must reset progress")
assert(released.targetSnapshotAfter.lifeStateId == "Incapacitated", "interruption changed target state")
assert(released.targetSnapshotAfter.healthState.currentHealth == 0, "interruption restored health")
assertRejected(
	resolver.continueRevive(reviver, target, released.sessionStateAfter, continueFacts(24)),
	"SessionNotActive"
)
local retryFacts = beginFacts()
retryFacts.sessionId = "revive.2"
retryFacts.serverTimestamp = 30
local retry = resolver.beginRevive(reviver, target, retryFacts)
assert(retry.didTransition and retry.sessionStateAfter.statusId == "Active", "retry must begin fresh")
assert(retry.normalizedProgress == 0, "retry must not inherit progress")
assert(retry.sessionStateAfter.startedAtServerTimestamp == 30, "retry must have a new start")
assert(retry.sessionStateAfter.completionServerTimestamp == 34, "retry must have a new canonical deadline")
local retryContinueFacts = continueFacts(30)
retryContinueFacts.sessionId = "revive.2"
retryContinueFacts.activeSessionIdForTarget = "revive.2"
assert(
	resolver.continueRevive(reviver, target, retry.sessionStateAfter, retryContinueFacts).normalizedProgress == 0,
	"retry carried partial progress"
)

-- Completion state, exact restoration, preservation, copied output, and determinism.
local reviverBeforeCompletion = deepCopy(reviver)
local targetBeforeCompletion = deepCopy(target)
local sessionBeforeCompletion = deepCopy(session)
local completionFacts = continueFacts(24)
local factsBeforeCompletion = deepCopy(completionFacts)
local completionCombatInput = combatState()
local combatBeforeCompletion = deepCopy(completionCombatInput)
local completedOnce = resolver.continueRevive(reviver, target, session, completionFacts, completionCombatInput)
assert(completedOnce.targetSnapshotAfter.lifeStateId == "Alive", "completion must revive target")
assert(completedOnce.targetSnapshotAfter.healthState.currentHealth == 30, "completion must restore exactly 30 health")
assert(completedOnce.targetSnapshotAfter.healthState.maximumHealth == 100, "completion changed maximum health")
assert(completedOnce.targetSnapshotAfter.incapacitationState == nil, "completion must clear incapacitation")
assert(completedOnce.sessionStateAfter.statusId == "Completed", "completion must complete session")
assert(completedOnce.sessionStateAfter.completionServerTimestamp == 24, "completion must use evaluation time")
assert(completedOnce.targetSnapshotAfter.invulnerabilityState == nil, "completion created invulnerability")
assert(completedOnce.targetSnapshotAfter.soloRecoveryState.recoveriesUsed == 0, "completion consumed recovery")
assert(completedOnce.targetSnapshotAfter.soloRecoveryState.isEligible, "completion consumed recovery eligibility")
assert(
	completedOnce.targetSnapshotAfter.soloRecoveryState.recoveryStartedAtServerTimestamp == nil
		and completedOnce.targetSnapshotAfter.soloRecoveryState.recoveryCompletionServerTimestamp == nil,
	"completion must clear active recovery timing"
)
assert(
	completedOnce.targetSnapshotAfter.processedDamageEventIds["damage.target.prior"] == true,
	"completion lost processed damage IDs"
)
assert(
	deepEqual(completedOnce.combatStateAfter.weaponState.ammunition, combatBeforeCompletion.weaponState.ammunition),
	"completion changed ammunition"
)
assert(
	completedOnce.combatStateAfter.weaponState.ammunition ~= completionCombatInput.weaponState.ammunition,
	"completion did not copy ammunition"
)
assert(
	deepEqual(completedOnce.combatStateAfter.processedShotIds, combatBeforeCompletion.processedShotIds),
	"completion changed processed ShotIds"
)
assert(
	completedOnce.combatStateAfter.processedShotIds ~= completionCombatInput.processedShotIds,
	"completion did not copy processed ShotIds"
)
assert(completedOnce.combatStateAfter.weaponState.reloadState == nil, "completion did not clear reload state")
assert(
	completedOnce.combatStateAfter.weaponState.readinessStateId == "Ready",
	"completion left weapon readiness Reloading"
)
assert(completedOnce.combatStateAfter.selectedTargetState == nil, "completion did not clear selected target")
assert(
	deepEqual(completedOnce.combatStateAfter.weaponState.cadence, combatBeforeCompletion.weaponState.cadence),
	"completion changed cadence"
)
assert(deepEqual(reviver, reviverBeforeCompletion), "completion mutated reviver")
assert(deepEqual(target, targetBeforeCompletion), "completion mutated target")
assert(deepEqual(session, sessionBeforeCompletion), "completion mutated session")
assert(deepEqual(completionFacts, factsBeforeCompletion), "completion mutated facts")
assert(deepEqual(completionCombatInput, combatBeforeCompletion), "completion mutated combat input")
assert(completedOnce.targetSnapshotAfter ~= target, "completion must construct target output")
assert(completedOnce.targetSnapshotAfter.healthState ~= target.healthState, "completion must copy health")
assert(
	completedOnce.targetSnapshotAfter.soloRecoveryState ~= target.soloRecoveryState,
	"completion must copy solo-recovery state"
)
assert(
	completedOnce.targetSnapshotAfter.processedDamageEventIds ~= target.processedDamageEventIds,
	"completion must copy processed IDs"
)
local completedTwice = resolver.continueRevive(reviver, target, session, completionFacts, completionCombatInput)
assert(deepEqual(completedOnce, completedTwice), "equivalent completion calls must be deterministic")

local medicBeginFacts = beginFacts()
medicBeginFacts.sessionId = "revive.medic"
medicBeginFacts.reviveDurationSeconds = 3
medicBeginFacts.restoredHealth = 40
local medicBegin = resolver.beginRevive(reviver, target, medicBeginFacts)
assert(medicBegin.didTransition, "bounded medic revive must begin")
assert(medicBegin.sessionStateAfter.completionServerTimestamp == 23, "medic deadline must use server benefit")
local medicCompletionFacts = continueFacts(23)
medicCompletionFacts.sessionId = "revive.medic"
medicCompletionFacts.activeSessionIdForTarget = "revive.medic"
medicCompletionFacts.reviveDurationSeconds = 3
medicCompletionFacts.restoredHealth = 40
local medicCompletion =
	resolver.continueRevive(reviver, target, medicBegin.sessionStateAfter, medicCompletionFacts, combatState())
assert(medicCompletion.didTransition, "medic deadline must complete")
assert(medicCompletion.targetSnapshotAfter.healthState.currentHealth == 40, "medic restore must be bounded")
local forgedMedicFacts = deepCopy(medicCompletionFacts)
forgedMedicFacts.restoredHealth = 101
assertRejected(
	resolver.continueRevive(reviver, target, medicBegin.sessionStateAfter, forgedMedicFacts, combatState()),
	"InvalidReviveInput"
)

local sessionImmutability = deepCopy(session)
local factsImmutability = continueFacts(22)
local factsImmutabilityBefore = deepCopy(factsImmutability)
resolver.continueRevive(reviver, target, session, factsImmutability)
assert(deepEqual(session, sessionImmutability), "progress evaluation mutated session")
assert(deepEqual(factsImmutability, factsImmutabilityBefore), "progress evaluation mutated facts")

print(
	"OperativeReviveResolver: eligibility, continuous progress, interruption reset, completion, precedence, determinism, and immutability passed"
)
