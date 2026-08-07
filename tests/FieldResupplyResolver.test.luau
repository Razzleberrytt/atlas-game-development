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
		FieldResupply = {
			resourceCost = 1,
			channelDurationSeconds = 2.5,
			cooldownSeconds = 6,
			maximumRangeStuds = 8,
			movementToleranceStuds = 1.5,
		},
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/FieldResupplyResolver.luau"), {
	debugName = "FieldResupplyResolver",
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
			error("unexpected resupply dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local function idle()
	return {
		actionStateId = contracts.ClassActionStateIds.Idle,
		actionId = nil,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = 4,
	}
end

local function intent(phaseId: string)
	return {
		requestId = "resupply-1",
		actionId = contracts.ClassActionIds.FieldResupply,
		phaseId = phaseId,
		candidateTargetOperativeEntityId = "operative.player:2",
	}
end

local function facts(overrides: { [string]: any }?)
	local value = {
		isParticipant = true,
		isOperationActive = true,
		assignedClassId = contracts.ClassIds.Engineer,
		isActorAlive = true,
		resourceAmount = 2,
		isTargetKnown = true,
		isTargetAlive = true,
		isWeaponCompatible = true,
		hasCapacity = true,
		distanceStuds = 5,
		hasLineOfSight = true,
		movementDistanceStuds = 0,
		didActorTakeDamage = false,
		serverTimestamp = 10,
	}
	for key, override in overrides or {} do
		value[key] = override
	end
	return value
end

local reasons = contracts.ClassActionRejectionReasonIds
local accepted = resolver.resolveStart(idle(), intent("Begin"), facts())
assertThat(accepted.didActivate, "valid resupply must activate")
assertThat(accepted.actionStateAfter.completionServerTimestamp == 12.5, "channel deadline")
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), facts({ resourceAmount = 0 })).rejectionReasonId
		== reasons.InsufficientResource,
	"finite charge gate"
)
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), facts({ isWeaponCompatible = false })).rejectionReasonId
		== reasons.IncompatibleWeapon,
	"compatibility gate"
)
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), facts({ hasCapacity = false })).rejectionReasonId
		== reasons.NoCapacity,
	"reserve cap gate"
)
assertThat(
	resolver.resolveStart(idle(), intent("Begin"), facts({ distanceStuds = 8.01 })).rejectionReasonId
		== reasons.OutOfRange,
	"range gate"
)
assertThat(
	resolver.resolveContinuity(accepted.actionStateAfter, facts({ didActorTakeDamage = true })).rejectionReasonId
		== reasons.DamageInterrupted,
	"damage interruption"
)
local completed = resolver.resolveContinuity(accepted.actionStateAfter, facts({ serverTimestamp = 12.5 }))
assertThat(completed.shouldCommitResupply, "deadline requests ammunition owner commit")
assertThat(completed.actionStateAfter.actionStateId == contracts.ClassActionStateIds.Cooldown, "completion cooldown")
local cancelled = resolver.resolveCancel(accepted.actionStateAfter, intent("Cancel"), 11)
assertThat(cancelled.rejectionReasonId == reasons.ActionCancelled, "explicit cancel")
assertThat(
	resolver.resolveEffectRejected(accepted.actionStateAfter, 12.5).rejectionReasonId == reasons.EffectCommitRejected,
	"commit rejection"
)

print("FieldResupplyResolver: finite resource, compatibility, capacity, continuity, and commit request passed")
