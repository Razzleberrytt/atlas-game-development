--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function assertNear(actual: number, expected: number, message: string)
	assertThat(math.abs(actual - expected) < 1e-9, message)
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassContracts.luau"), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local config = {
	Actions = {
		Brace = {
			durationSeconds = 6,
			cooldownSeconds = 14,
			movementToleranceStuds = 1.5,
			interruptOnReload = true,
		},
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/BraceResolver.luau"), {
	debugName = "BraceResolver",
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
			error("unexpected BraceResolver dependency", 2)
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
		revision = 3,
	})
end

local function intent(phaseId: string, requestId: string?)
	return table.freeze({
		requestId = requestId or "brace-1",
		actionId = contracts.ClassActionIds.Brace,
		phaseId = phaseId,
	})
end

local function startFacts(overrides: { [string]: any }?)
	local value = {
		isParticipant = true,
		isOperationActive = true,
		assignedClassId = contracts.ClassIds.CombatSpecialist,
		isActorAlive = true,
		serverTimestamp = 10,
		isDuplicateRequest = false,
		isRateLimited = false,
	}
	for key, override in overrides or {} do
		value[key] = override
	end
	return value
end

local accepted = resolver.resolveStart(idle(), intent(contracts.ClassActionPhaseIds.Begin), startFacts())
assertThat(accepted.didActivate and accepted.didChange, "valid Brace must activate")
assertThat(accepted.actionStateAfter.actionStateId == contracts.ClassActionStateIds.Active, "active state")
assertThat(accepted.actionStateAfter.completionServerTimestamp == 16, "duration must be server-authored")
assertThat(accepted.actionStateAfter.revision == 4, "activation must advance revision")

local wrongClass = resolver.resolveStart(
	idle(),
	intent(contracts.ClassActionPhaseIds.Begin),
	startFacts({ assignedClassId = contracts.ClassIds.Medic })
)
assertThat(wrongClass.rejectionReasonId == contracts.ClassActionRejectionReasonIds.WrongAssignedClass, "class gate")
local wrongPhase = resolver.resolveStart(
	idle(),
	intent(contracts.ClassActionPhaseIds.Begin),
	startFacts({ isOperationActive = false })
)
assertThat(wrongPhase.rejectionReasonId == contracts.ClassActionRejectionReasonIds.OperationPhaseInvalid, "phase gate")
local duplicate = resolver.resolveStart(
	idle(),
	intent(contracts.ClassActionPhaseIds.Begin),
	startFacts({ isDuplicateRequest = true })
)
assertThat(duplicate.rejectionReasonId == contracts.ClassActionRejectionReasonIds.DuplicateRequest, "replay gate")
assertThat(idle().revision == 3, "input state must remain immutable")

local function continuity(overrides: { [string]: any }?)
	local value = {
		isOperationActive = true,
		isActorAlive = true,
		movementDistanceStuds = 0,
		didReloadBegin = false,
		serverTimestamp = 11,
	}
	for key, override in overrides or {} do
		value[key] = override
	end
	return value
end

local held = resolver.resolveContinuity(accepted.actionStateAfter, continuity())
assertThat(not held.didChange, "Brace must remain active inside all bounds")
local moved = resolver.resolveContinuity(accepted.actionStateAfter, continuity({ movementDistanceStuds = 1.51 }))
assertThat(moved.actionStateAfter.actionStateId == contracts.ClassActionStateIds.Cooldown, "movement interrupts")
assertThat(moved.rejectionReasonId == contracts.ClassActionRejectionReasonIds.MovementInterrupted, "movement reason")
assertThat(moved.actionStateAfter.cooldownEndServerTimestamp == 25, "interruption starts configured cooldown")
local movedWithHaste = resolver.resolveContinuity(
	accepted.actionStateAfter,
	continuity({ movementDistanceStuds = 1.51 }),
	0.9
)
assertNear(
	movedWithHaste.actionStateAfter.cooldownEndServerTimestamp,
	23.6,
	"server-derived haste must shorten configured cooldown duration"
)
assertThat(
	resolver.resolveContinuity(accepted.actionStateAfter, continuity({ movementDistanceStuds = 1.51 }), 0).rejectionReasonId
		== contracts.ClassActionRejectionReasonIds.InvalidIntent,
	"invalid cooldown multipliers must fail closed"
)
local reloaded = resolver.resolveContinuity(accepted.actionStateAfter, continuity({ didReloadBegin = true }))
assertThat(reloaded.rejectionReasonId == contracts.ClassActionRejectionReasonIds.ReloadInterrupted, "reload interrupts")
local dead = resolver.resolveContinuity(accepted.actionStateAfter, continuity({ isActorAlive = false }))
assertThat(dead.rejectionReasonId == contracts.ClassActionRejectionReasonIds.ActorNotAlive, "life gate interrupts")
local completed = resolver.resolveContinuity(accepted.actionStateAfter, continuity({ serverTimestamp = 16 }))
assertThat(completed.rejectionReasonId == contracts.ClassActionRejectionReasonIds.ActionCompleted, "duration completes")

local cancelled =
	resolver.resolveCancel(accepted.actionStateAfter, intent(contracts.ClassActionPhaseIds.Cancel, "brace-cancel"), 12)
assertThat(cancelled.actionStateAfter.actionStateId == contracts.ClassActionStateIds.Cooldown, "cancel starts cooldown")
assertThat(cancelled.actionStateAfter.cooldownEndServerTimestamp == 26, "cancel cooldown deadline")
local cancelledWithHaste =
	resolver.resolveCancel(accepted.actionStateAfter, intent(contracts.ClassActionPhaseIds.Cancel, "brace-haste"), 12, 0.9)
assertNear(cancelledWithHaste.actionStateAfter.cooldownEndServerTimestamp, 24.6, "cancel must consume haste snapshot")
local cooled = resolver.resolveContinuity(cancelled.actionStateAfter, continuity({ serverTimestamp = 26 }))
assertThat(cooled.actionStateAfter.actionStateId == contracts.ClassActionStateIds.Idle, "cooldown returns to idle")
assertThat(cooled.actionStateAfter.actionId == nil, "idle clears action identity")

print(
	"BraceResolver: activation, authority gates, interruption, cancellation, bounded haste, cooldown, and immutability checks passed"
)
