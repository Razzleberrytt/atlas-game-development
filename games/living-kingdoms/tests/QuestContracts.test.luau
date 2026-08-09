--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-020 quest contract assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/Quest/QuestContracts.luau"
local source = fs.readFile(sourcePath)
local Contracts = luau.load(source, {
	debugName = "QuestContracts",
	injectGlobals = true,
})()

local definition = table.freeze({
	QuestId = "quest.operation.first-descent",
	Version = "1",
	PrerequisiteQuestIds = table.freeze({ "quest.onboarding.field-ready" }),
	Objectives = table.freeze({
		table.freeze({
			ObjectiveId = "objective.complete.first-expedition",
			ProgressSourceRef = "operation-completion:first-expedition",
			RequiredCount = 1,
		}),
		table.freeze({
			ObjectiveId = "objective.discover.lookout-cache",
			ProgressSourceRef = "discovery:discovery.lookout-cache",
			RequiredCount = 1,
		}),
	}),
	RewardRefs = table.freeze({
		table.freeze({
			RewardRefId = "quest-reward:first-descent",
			RewardAuthorityOwnerId = "FutureCanonicalQuestOwner",
		}),
	}),
	RuntimeEnabled = false,
})

assert(Contracts.validateQuestDefinition(definition) == true)
assert(#Contracts.TransitionDefinitions == 4)

local function context(
	completed: { [string]: boolean },
	accepted: { [string]: boolean },
	progress: { [string]: number }
)
	return {
		CompletedQuestIds = completed,
		AcceptedQuestIds = accepted,
		ObjectiveProgressById = progress,
	}
end

local locked = context({}, {}, {})
assert(Contracts.resolveQuestState(definition, locked) == Contracts.StateIds.Locked)

local available = context({ ["quest.onboarding.field-ready"] = true }, {}, {})
assert(Contracts.resolveQuestState(definition, available) == Contracts.StateIds.Available)

local active = context(
	{ ["quest.onboarding.field-ready"] = true },
	{ ["quest.operation.first-descent"] = true },
	{ ["objective.complete.first-expedition"] = 1 }
)
assert(Contracts.resolveQuestState(definition, active) == Contracts.StateIds.Active)

local ready = context({ ["quest.onboarding.field-ready"] = true }, { ["quest.operation.first-descent"] = true }, {
	["objective.complete.first-expedition"] = 4,
	["objective.discover.lookout-cache"] = 1,
})
assert(Contracts.resolveQuestState(definition, ready) == Contracts.StateIds.ReadyToTurnIn)

local completed = context({
	["quest.onboarding.field-ready"] = true,
	["quest.operation.first-descent"] = true,
}, {}, {})
assert(Contracts.resolveQuestState(definition, completed) == Contracts.StateIds.Completed)

-- Completion state is deterministic and outranks stale accepted/progress data.
completed.AcceptedQuestIds["quest.operation.first-descent"] = true
completed.ObjectiveProgressById["objective.complete.first-expedition"] = 999
assert(Contracts.resolveQuestState(definition, completed) == Contracts.StateIds.Completed)

local expectedTransitions = {
	[Contracts.TransitionIds.PrerequisitesSatisfied] = {
		FromStateId = Contracts.StateIds.Locked,
		ToStateId = Contracts.StateIds.Available,
		TriggerId = Contracts.TransitionTriggerIds.Derived,
	},
	[Contracts.TransitionIds.Accept] = {
		FromStateId = Contracts.StateIds.Available,
		ToStateId = Contracts.StateIds.Active,
		TriggerId = Contracts.TransitionTriggerIds.Request,
	},
	[Contracts.TransitionIds.ObjectivesSatisfied] = {
		FromStateId = Contracts.StateIds.Active,
		ToStateId = Contracts.StateIds.ReadyToTurnIn,
		TriggerId = Contracts.TransitionTriggerIds.Derived,
	},
	[Contracts.TransitionIds.Complete] = {
		FromStateId = Contracts.StateIds.ReadyToTurnIn,
		ToStateId = Contracts.StateIds.Completed,
		TriggerId = Contracts.TransitionTriggerIds.Request,
	},
}

for transitionId, expected in expectedTransitions do
	local transition = Contracts.getTransition(transitionId)
	assert(transition ~= nil)
	assert(transition.FromStateId == expected.FromStateId)
	assert(transition.ToStateId == expected.ToStateId)
	assert(transition.TriggerId == expected.TriggerId)
	local acceptedTransition = Contracts.evaluateTransition(expected.FromStateId, transitionId)
	assert(acceptedTransition.Accepted == true)
	assert(acceptedTransition.ReasonId == nil)
	assert(acceptedTransition.ToStateId == expected.ToStateId)
end

local invalidTransition = Contracts.evaluateTransition(Contracts.StateIds.Locked, Contracts.TransitionIds.Complete)
assert(invalidTransition.Accepted == false)
assert(invalidTransition.ReasonId == Contracts.DenialReasonIds.InvalidTransition)
assert(invalidTransition.ToStateId == nil)

local selfPrerequisite = table.clone(definition)
selfPrerequisite.PrerequisiteQuestIds = { definition.QuestId }
assert(Contracts.validateQuestDefinition(selfPrerequisite) == false)

local duplicateObjective = table.clone(definition)
duplicateObjective.Objectives = {
	definition.Objectives[1],
	definition.Objectives[1],
}
assert(Contracts.validateQuestDefinition(duplicateObjective) == false)

local duplicateReward = table.clone(definition)
duplicateReward.RewardRefs = {
	definition.RewardRefs[1],
	definition.RewardRefs[1],
}
assert(Contracts.validateQuestDefinition(duplicateReward) == false)

local zeroObjective = table.clone(definition)
zeroObjective.Objectives = {}
assert(Contracts.validateQuestDefinition(zeroObjective) == false)

local unknownField = table.clone(definition)
unknownField.ClientMayComplete = true
assert(Contracts.validateQuestDefinition(unknownField) == false)

-- BA-020 must remain pure contract/resolver work. No runtime or authority path.
assert(string.find(source, "Instance.new", 1, true) == nil)
assert(string.find(source, "GetService", 1, true) == nil)
assert(string.find(source, "FireServer", 1, true) == nil)
assert(string.find(source, "InvokeServer", 1, true) == nil)
assert(string.find(source, "DataStore", 1, true) == nil)
assert(string.find(source, "RemoteEvent", 1, true) == nil)
assert(string.find(source, "RemoteFunction", 1, true) == nil)

print("BA-020 QuestContracts fixture passed")
