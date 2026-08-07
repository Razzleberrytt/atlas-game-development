--!strict

-- Focused LK-0307 pure viability and failure-grace fixtures.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local config = {
	MaximumHealth = 100,
	SoloRecoveryDurationSeconds = 8,
	SoloRecoveriesPerOperation = 1,
	SquadFailureGraceSeconds = 3,
}
local contracts = {
	OperativeLifeStateIds = table.freeze({ Alive = "Alive", Incapacitated = "Incapacitated", Dead = "Dead" }),
	SquadFailureStatusIds = table.freeze({ Viable = "Viable", Pending = "Pending", Failed = "Failed" }),
	SquadFailureRejectionReasonIds = table.freeze({
		InvalidFacts = "InvalidFacts",
		InvalidState = "InvalidState",
		InvalidServerTimestamp = "InvalidServerTimestamp",
		StaleEvaluation = "StaleEvaluation",
	}),
}
local replicatedStorage = {
	Shared = {
		Config = { OperativeLifeConfig = CONFIG_TOKEN },
		Health = { OperativeLifeContracts = CONTRACTS_TOKEN },
	},
}
local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/SquadFailureEvaluator.luau"), {
	debugName = "SquadFailureEvaluator",
	environment = {
		game = {
			GetService = function()
				return replicatedStorage
			end,
		},
		require = function(token)
			if token == CONFIG_TOKEN then
				return config
			end
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			error("unexpected module")
		end,
	},
	injectGlobals = true,
})
local evaluator = loader()
local realContracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau"),
	{ debugName = "OperativeLifeContracts" }
)()
assert(realContracts.SquadFailureStatusIds.Viable == "Viable", "Viable status vocabulary missing")
assert(realContracts.SquadFailureStatusIds.Pending == "Pending", "Pending status vocabulary missing")
assert(realContracts.SquadFailureStatusIds.Failed == "Failed", "Failed status vocabulary missing")
assert(table.isfrozen(realContracts.SquadFailureStatusIds), "squad failure status IDs must be frozen")

local function recovery(isEligible: boolean, used: number, startedAt: number?)
	return {
		isEligible = isEligible,
		recoveriesUsed = used,
		recoveryStartedAtServerTimestamp = startedAt,
		recoveryCompletionServerTimestamp = if startedAt == nil then nil else startedAt + 8,
	}
end

local function snapshot(identity: string, lifeStateId: string, soloRecovery)
	local incapacitated = lifeStateId == "Incapacitated"
	return {
		operativeEntityId = identity,
		lifeStateId = lifeStateId,
		healthState = { currentHealth = if lifeStateId == "Alive" then 100 else 0, maximumHealth = 100 },
		incapacitationState = if incapacitated
			then { startedAtServerTimestamp = 10, bleedOutDeadlineServerTimestamp = 40 }
			else nil,
		soloRecoveryState = soloRecovery or recovery(false, 0, nil),
		processedDamageEventIds = {},
	}
end

local function facts(snapshots, overrides)
	local value = {
		operativeSnapshots = snapshots,
		operationStartedSolo = false,
		hasEverHadMultipleParticipants = #snapshots > 1,
		lateJoiningProhibited = true,
		isAuthoritativelyAbandoned = false,
	}
	for key, child in overrides or {} do
		value[key] = child
	end
	return value
end

local function state(statusId: string, startedAt: number?, deadline: number?, failedAt: number?)
	return {
		statusId = statusId,
		pendingStartedAtServerTimestamp = startedAt,
		pendingDeadlineServerTimestamp = deadline,
		failedAtServerTimestamp = failedAt,
	}
end

local viable = state("Viable", nil, nil, nil)
local aliveA = snapshot("operative.a", "Alive", nil)
local aliveB = snapshot("operative.b", "Alive", nil)
local downA = snapshot("operative.a", "Incapacitated", nil)
local downB = snapshot("operative.b", "Incapacitated", nil)
local deadA = snapshot("operative.a", "Dead", nil)

-- Pure viability and the absence of invented revive paths.
assert(evaluator.evaluateViability(facts({ aliveA }), 10).isViable, "one Alive operative was not viable")
assert(evaluator.evaluateViability(facts({ downA, aliveB }), 10).isViable, "one of multiple Alive was not viable")
assert(
	not evaluator.evaluateViability(facts({ downA, downB }), 10).isViable,
	"all-incapacitated multiplayer was viable"
)
assert(not evaluator.evaluateViability(facts({ deadA }), 10).isViable, "all Dead was viable")
assert(not evaluator.evaluateViability(facts({}), 10).isViable, "zero registered operatives was viable")
assert(
	not evaluator.evaluateViability(facts({ downA, downB }), 10).hasAliveOperative,
	"incapacitated reviver was invented"
)

local soloDown = snapshot("operative.solo", "Incapacitated", recovery(true, 0, 10))
local soloFacts = facts({ soloDown }, { operationStartedSolo = true, hasEverHadMultipleParticipants = false })
assert(evaluator.evaluateViability(soloFacts, 10).hasPendingSoloRecovery, "valid solo recovery was missed")
local usedSolo = snapshot("operative.solo", "Incapacitated", recovery(true, 1, 10))
assert(
	not evaluator.evaluateViability(
		facts({ usedSolo }, { operationStartedSolo = true, hasEverHadMultipleParticipants = false }),
		10
	).isViable,
	"second solo incapacitation was viable"
)
local ineligibleSolo = snapshot("operative.solo", "Incapacitated", recovery(false, 0, 10))
assert(
	not evaluator.evaluateViability(
		facts({ ineligibleSolo }, { operationStartedSolo = true, hasEverHadMultipleParticipants = false }),
		10
	).isViable,
	"ineligible solo recovery was viable"
)
assert(
	not evaluator.evaluateViability(
		facts({ soloDown }, { operationStartedSolo = false, hasEverHadMultipleParticipants = true }),
		10
	).isViable,
	"multiplayer history allowed solo recovery"
)
assert(
	not evaluator.evaluateViability(
		facts({ soloDown }, { operationStartedSolo = true, hasEverHadMultipleParticipants = true }),
		10
	).isViable,
	"multiplayer participation after a solo start allowed recovery"
)
assert(
	not evaluator.evaluateViability(
		facts(
			{ soloDown },
			{ operationStartedSolo = true, hasEverHadMultipleParticipants = false, isAuthoritativelyAbandoned = true }
		),
		10
	).isViable,
	"abandonment remained viable"
)

-- Input order cannot influence the outcome.
local ordered = evaluator.evaluateViability(facts({ downA, aliveB }), 10)
local reversed = evaluator.evaluateViability(facts({ aliveB, downA }), 10)
assert(
	ordered.isViable == reversed.isViable and ordered.activeOperativeCount == reversed.activeOperativeCount,
	"input order changed viability"
)

-- Grace creation, stored deadline, exact boundary, and deterministic repetition.
local noViability = facts({ downA, downB })
local first = evaluator.resolve(viable, noViability, 20)
assert(first.didResolve and first.stateAfter.statusId == "Pending", "first loss did not create Pending")
assert(first.stateAfter.pendingStartedAtServerTimestamp == 20, "pending start did not use server time")
assert(first.stateAfter.pendingDeadlineServerTimestamp == 23, "deadline was not start plus three")
local before = evaluator.resolve(first.stateAfter, noViability, 22.999)
assert(before.stateAfter.statusId == "Pending", "failure committed before deadline")
assert(before.stateAfter.pendingDeadlineServerTimestamp == 23, "stored deadline changed")
local exact = evaluator.resolve(first.stateAfter, noViability, 23)
assert(
	exact.stateAfter.statusId == "Failed" and exact.stateAfter.failedAtServerTimestamp == 23,
	"exact deadline did not fail"
)
local after = evaluator.resolve(first.stateAfter, noViability, 24)
assert(
	after.stateAfter.statusId == "Failed" and after.stateAfter.failedAtServerTimestamp == 24,
	"after deadline did not fail"
)
local repeated = evaluator.resolve(first.stateAfter, noViability, 22)
local repeatedAgain = evaluator.resolve(first.stateAfter, noViability, 22)
assert(
	repeated.stateAfter.pendingDeadlineServerTimestamp == repeatedAgain.stateAfter.pendingDeadlineServerTimestamp,
	"equivalent calls differed"
)

-- Cancellation clears timing and a later loss receives a fresh full grace.
local aliveReturn = evaluator.resolve(first.stateAfter, facts({ aliveA, downB }), 22.999)
assert(aliveReturn.stateAfter.statusId == "Viable", "Alive return did not cancel Pending")
assert(
	aliveReturn.stateAfter.pendingStartedAtServerTimestamp == nil
		and aliveReturn.stateAfter.pendingDeadlineServerTimestamp == nil,
	"cancellation retained timing"
)
local timelySoloDown = snapshot("operative.solo", "Incapacitated", recovery(true, 0, 20))
timelySoloDown.incapacitationState = { startedAtServerTimestamp = 20, bleedOutDeadlineServerTimestamp = 50 }
local soloReturn = evaluator.resolve(
	first.stateAfter,
	facts({ timelySoloDown }, { operationStartedSolo = true, hasEverHadMultipleParticipants = false }),
	22
)
assert(soloReturn.stateAfter.statusId == "Viable", "solo recovery path did not cancel Pending")
local fresh = evaluator.resolve(aliveReturn.stateAfter, noViability, 30)
assert(
	fresh.stateAfter.pendingStartedAtServerTimestamp == 30 and fresh.stateAfter.pendingDeadlineServerTimestamp == 33,
	"fresh grace reused partial time"
)
local failed = exact.stateAfter
assert(
	evaluator.resolve(failed, facts({ aliveA }), 24).stateAfter.statusId == "Failed",
	"ordinary viability undid Failed"
)
assert(
	evaluator.resolve(first.stateAfter, facts({ aliveA, downB }), 23).stateAfter.statusId == "Failed",
	"viability at the exact deadline cancelled failure"
)

-- Stable malformed and stale rejection.
assert(
	evaluator.resolve(first.stateAfter, noViability, 19).rejectionReasonId == "StaleEvaluation",
	"stale time was accepted"
)
assert(
	evaluator.resolve(viable, noViability, 0 / 0).rejectionReasonId == "InvalidServerTimestamp",
	"NaN time was accepted"
)
assert(
	evaluator.resolve({ statusId = "Pending" } :: any, noViability, 20).rejectionReasonId == "InvalidState",
	"malformed state was accepted"
)
assert(evaluator.resolve(viable, {} :: any, 20).rejectionReasonId == "InvalidFacts", "malformed facts were accepted")

print("SquadFailureEvaluator: viability, grace, cancellation, validation, and idempotence passed")
