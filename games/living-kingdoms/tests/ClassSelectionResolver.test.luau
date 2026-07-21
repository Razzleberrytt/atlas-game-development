--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassContracts.luau"), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local MISSION_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Classes = { ClassContracts = CONTRACTS_TOKEN },
		Config = { ClassConfig = CONFIG_TOKEN },
		Mission = { MissionContracts = MISSION_TOKEN },
	},
}

local config = {
	Selection = {
		openMissionPhaseId = "Insertion",
	},
}

local missionContracts = {
	MissionPhaseIds = {
		Insertion = "Insertion",
		Infiltration = "Infiltration",
		Resolved = "Resolved",
	},
}

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ClassSelectionResolver.luau"), {
	debugName = "ClassSelectionResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "resolver must use only ReplicatedStorage")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == CONFIG_TOKEN then
				return config
			elseif token == MISSION_TOKEN then
				return missionContracts
			end
			error("unexpected resolver dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local function assignment(selectionStateId: string?)
	return table.freeze({
		operativeEntityId = "operative.player:1",
		classId = contracts.ClassIds.CombatSpecialist,
		selectionStateId = selectionStateId or contracts.ClassSelectionStateIds.Open,
		revision = 4,
	})
end

local function facts(overrides: { [string]: any }?)
	local result = {
		isParticipant = true,
		missionPhaseId = missionContracts.MissionPhaseIds.Insertion,
		insertionDeadlineServerTimestamp = 20,
		serverTimestamp = 10,
		availableClassIds = {
			[contracts.ClassIds.CombatSpecialist] = true,
			[contracts.ClassIds.Medic] = true,
			[contracts.ClassIds.Engineer] = true,
		},
		isDuplicateRequest = false,
		isRateLimited = false,
	}
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end

local validIntent = table.freeze({ requestId = "request-1", classId = contracts.ClassIds.Medic })

local invalidIntent = resolver.resolve(assignment(), { classId = contracts.ClassIds.Medic }, facts())
assertThat(not invalidIntent.didSelect, "malformed selection must fail")
assertThat(invalidIntent.rejectionReasonId == contracts.ClassActionRejectionReasonIds.InvalidIntent, "malformed reason")

local unknownClass = resolver.resolve(assignment(), { requestId = "request-2", classId = "class.unknown" }, facts())
assertThat(not unknownClass.didSelect, "unknown class must fail")
assertThat(unknownClass.rejectionReasonId == contracts.ClassActionRejectionReasonIds.UnknownClass, "unknown reason")

local notParticipant = resolver.resolve(assignment(), validIntent, facts({ isParticipant = false }))
assertThat(
	notParticipant.rejectionReasonId == contracts.ClassActionRejectionReasonIds.NotParticipant,
	"participant gate"
)

local resolved =
	resolver.resolve(assignment(), validIntent, facts({ missionPhaseId = missionContracts.MissionPhaseIds.Resolved }))
assertThat(resolved.rejectionReasonId == contracts.ClassActionRejectionReasonIds.OperationResolved, "resolved gate")

local wrongPhase = resolver.resolve(
	assignment(),
	validIntent,
	facts({ missionPhaseId = missionContracts.MissionPhaseIds.Infiltration })
)
assertThat(wrongPhase.rejectionReasonId == contracts.ClassActionRejectionReasonIds.SelectionClosed, "phase lock gate")

local exactDeadline = resolver.resolve(assignment(), validIntent, facts({ serverTimestamp = 20 }))
assertThat(
	exactDeadline.rejectionReasonId == contracts.ClassActionRejectionReasonIds.SelectionClosed,
	"exact deadline closes"
)

local locked = resolver.resolve(assignment(contracts.ClassSelectionStateIds.Locked), validIntent, facts())
assertThat(locked.rejectionReasonId == contracts.ClassActionRejectionReasonIds.ClassLocked, "assignment lock gate")

local unavailable = resolver.resolve(
	assignment(),
	validIntent,
	facts({ availableClassIds = { [contracts.ClassIds.CombatSpecialist] = true } })
)
assertThat(
	unavailable.rejectionReasonId == contracts.ClassActionRejectionReasonIds.ClassUnavailable,
	"availability gate"
)

local duplicate =
	resolver.resolve(assignment(), validIntent, facts({ isDuplicateRequest = true, isRateLimited = true }))
assertThat(
	duplicate.rejectionReasonId == contracts.ClassActionRejectionReasonIds.DuplicateRequest,
	"replay precedes rate limit"
)

local rateLimited = resolver.resolve(assignment(), validIntent, facts({ isRateLimited = true }))
assertThat(rateLimited.rejectionReasonId == contracts.ClassActionRejectionReasonIds.RateLimited, "rate-limit gate")

local before = assignment()
local accepted = resolver.resolve(before, validIntent, facts())
assertThat(accepted.didSelect, "valid selection must succeed")
assertThat(accepted.rejectionReasonId == nil, "accepted selection has no rejection")
assertThat(accepted.assignmentAfter.classId == contracts.ClassIds.Medic, "requested class must be selected")
assertThat(accepted.assignmentAfter.revision == before.revision + 1, "accepted selection advances revision")
assertThat(accepted.assignmentAfter.selectionStateId == contracts.ClassSelectionStateIds.Open, "selection remains open")
assertThat(before.classId == contracts.ClassIds.CombatSpecialist, "resolver must not mutate assignment input")
assertThat(validIntent.classId == contracts.ClassIds.Medic, "resolver must not mutate intent input")

local mutationSucceeded = pcall(function()
	accepted.assignmentAfter.classId = contracts.ClassIds.Engineer
end)
assertThat(not mutationSucceeded, "resolver output must be frozen")
