--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassContracts.luau"), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()
local config = {
	Actions = {
		FieldTreatment = {
			resourceCost = 1,
			channelDurationSeconds = 3,
			cooldownSeconds = 4,
			maximumRangeStuds = 8,
			movementToleranceStuds = 1.5,
		},
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/FieldTreatmentResolver.luau"), {
	debugName = "FieldTreatmentResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "resolver may only read shared declarations")
				return {
					Shared = {
						Classes = { ClassContracts = CONTRACTS_TOKEN },
						Config = { ClassConfig = CONFIG_TOKEN },
					},
				}
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == CONFIG_TOKEN then
				return config
			end
			error("unexpected treatment dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local function idle()
	return table.freeze({
		actionStateId = contracts.ClassActionStateIds.Idle,
		actionId = nil,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = 7,
	})
end

local function intent(phaseId: string)
	return {
		requestId = "treatment-1",
		actionId = contracts.ClassActionIds.FieldTreatment,
		phaseId = phaseId,
		candidateTargetOperativeEntityId = "operative.player:2",
	}
end

local function startFacts(overrides: { [string]: any }?)
	local facts = {
		isParticipant = true,
		isOperationActive = true,
		assignedClassId = contracts.ClassIds.Medic,
		isActorAlive = true,
		resourceAmount = 3,
		isTargetKnown = true,
		isSelfTarget = false,
		isTargetAlive = true,
		isTargetInjured = true,
		distanceStuds = 4,
		hasLineOfSight = true,
		serverTimestamp = 10,
	}
	for key, value in overrides or {} do
		facts[key] = value
	end
	return facts
end

local accepted = resolver.resolveStart(idle(), intent(contracts.ClassActionPhaseIds.Begin), startFacts())
assertThat(accepted.didActivate, "valid treatment must activate")
assertThat(accepted.actionStateAfter.targetOperativeEntityId == "operative.player:2", "target is server-tracked")
assertThat(accepted.actionStateAfter.completionServerTimestamp == 13, "channel duration is configured")

local reasons = contracts.ClassActionRejectionReasonIds
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), startFacts({ resourceAmount = 0 })).rejectionReasonId
		== reasons.InsufficientResource,
	"finite resource gate"
)
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), startFacts({ isSelfTarget = true })).rejectionReasonId
		== reasons.SelfTargetNotAllowed,
	"self treatment is forbidden"
)
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), startFacts({ isTargetInjured = false })).rejectionReasonId
		== reasons.TargetNotInjured,
	"healthy target is rejected"
)
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), startFacts({ distanceStuds = 8.01 })).rejectionReasonId
		== reasons.OutOfRange,
	"range is bounded"
)

local function continuity(overrides: { [string]: any }?)
	local facts = {
		isOperationActive = true,
		isActorAlive = true,
		movementDistanceStuds = 0,
		didActorTakeDamage = false,
		isTargetKnown = true,
		isTargetAlive = true,
		isTargetInjured = true,
		distanceStuds = 4,
		hasLineOfSight = true,
		serverTimestamp = 11,
	}
	for key, value in overrides or {} do
		facts[key] = value
	end
	return facts
end

assertThat(not resolver.resolveContinuity(accepted.actionStateAfter, continuity()).didChange, "valid channel holds")
assertThat(
	resolver.resolveContinuity(accepted.actionStateAfter, continuity({ didActorTakeDamage = true })).rejectionReasonId
		== reasons.DamageInterrupted,
	"damage interrupts"
)
assertThat(
	resolver.resolveContinuity(accepted.actionStateAfter, continuity({ hasLineOfSight = false })).rejectionReasonId
		== reasons.NoLineOfSight,
	"line of sight is continuous"
)
local completed = resolver.resolveContinuity(accepted.actionStateAfter, continuity({ serverTimestamp = 13 }))
assertThat(completed.shouldCommitHealing, "deadline requests an authoritative healing commit")
assertThat(completed.actionStateAfter.actionStateId == contracts.ClassActionStateIds.Cooldown, "completion cools down")
local cancelled = resolver.resolveCancel(accepted.actionStateAfter, intent("Cancel"), 12)
assertThat(cancelled.rejectionReasonId == reasons.ActionCancelled, "explicit cancellation is supported")
local effectRejected = resolver.resolveEffectRejected(accepted.actionStateAfter, 13)
assertThat(effectRejected.rejectionReasonId == reasons.EffectCommitRejected, "failed life commit is disclosed")

print("FieldTreatmentResolver: eligibility, continuity, finite channel, cancellation, and commit request passed")
