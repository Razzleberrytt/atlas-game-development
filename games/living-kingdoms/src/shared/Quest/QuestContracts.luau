--!strict

--[[
	BA-020 canonical quest contracts and deterministic state resolver.

	This module is intentionally pure and dormant. It defines quest IDs,
	prerequisites, objective progress references, reward references, state IDs,
	and legal state transitions. It does not create a QuestService, bind remotes,
	read/write persistence, grant rewards, or activate the recovered operation board.
]]

local Contracts = {}

Contracts.StateIds = table.freeze({
	Locked = "Locked",
	Available = "Available",
	Active = "Active",
	ReadyToTurnIn = "ReadyToTurnIn",
	Completed = "Completed",
})

Contracts.TransitionIds = table.freeze({
	PrerequisitesSatisfied = "PrerequisitesSatisfied",
	Accept = "Accept",
	ObjectivesSatisfied = "ObjectivesSatisfied",
	Complete = "Complete",
})

Contracts.TransitionTriggerIds = table.freeze({
	Derived = "Derived",
	Request = "Request",
})

Contracts.DenialReasonIds = table.freeze({
	InvalidDefinition = "InvalidDefinition",
	InvalidTransition = "InvalidTransition",
	PrerequisiteIncomplete = "PrerequisiteIncomplete",
	AlreadyAccepted = "AlreadyAccepted",
	AlreadyCompleted = "AlreadyCompleted",
	NotAccepted = "NotAccepted",
	ObjectivesIncomplete = "ObjectivesIncomplete",
})

export type QuestObjectiveDefinition = {
	ObjectiveId: string,
	ProgressSourceRef: string,
	RequiredCount: number,
}

export type QuestRewardReference = {
	RewardRefId: string,
	RewardAuthorityOwnerId: string,
}

export type QuestDefinition = {
	QuestId: string,
	Version: string,
	PrerequisiteQuestIds: { string },
	Objectives: { QuestObjectiveDefinition },
	RewardRefs: { QuestRewardReference },
	RuntimeEnabled: boolean,
}

export type QuestStateContext = {
	CompletedQuestIds: { [string]: boolean },
	AcceptedQuestIds: { [string]: boolean },
	ObjectiveProgressById: { [string]: number },
}

export type QuestTransitionDefinition = {
	TransitionId: string,
	FromStateId: string,
	ToStateId: string,
	TriggerId: string,
}

export type QuestTransitionResult = {
	Accepted: boolean,
	ReasonId: string?,
	TransitionId: string,
	FromStateId: string,
	ToStateId: string?,
}

local TransitionDefinitions: { QuestTransitionDefinition } = table.freeze({
	table.freeze({
		TransitionId = Contracts.TransitionIds.PrerequisitesSatisfied,
		FromStateId = Contracts.StateIds.Locked,
		ToStateId = Contracts.StateIds.Available,
		TriggerId = Contracts.TransitionTriggerIds.Derived,
	}),
	table.freeze({
		TransitionId = Contracts.TransitionIds.Accept,
		FromStateId = Contracts.StateIds.Available,
		ToStateId = Contracts.StateIds.Active,
		TriggerId = Contracts.TransitionTriggerIds.Request,
	}),
	table.freeze({
		TransitionId = Contracts.TransitionIds.ObjectivesSatisfied,
		FromStateId = Contracts.StateIds.Active,
		ToStateId = Contracts.StateIds.ReadyToTurnIn,
		TriggerId = Contracts.TransitionTriggerIds.Derived,
	}),
	table.freeze({
		TransitionId = Contracts.TransitionIds.Complete,
		FromStateId = Contracts.StateIds.ReadyToTurnIn,
		ToStateId = Contracts.StateIds.Completed,
		TriggerId = Contracts.TransitionTriggerIds.Request,
	}),
})

Contracts.TransitionDefinitions = TransitionDefinitions

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 1 and (value :: number) % 1 == 0
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

local function isDenseArray(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count += 1
	end
	return #value == count
end

local function validateStringList(values: unknown, maximumLength: number, forbiddenValue: string?): boolean
	if type(values) ~= "table" or not isDenseArray(values :: { [any]: any }) then
		return false
	end
	local seen = {}
	for _, value in values :: { any } do
		if not isNonEmptyBoundedString(value, maximumLength) or value == forbiddenValue or seen[value] then
			return false
		end
		seen[value] = true
	end
	return true
end

local function validateObjective(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local objective = value :: { [any]: any }
	return hasOnlyKeys(objective, {
		ObjectiveId = true,
		ProgressSourceRef = true,
		RequiredCount = true,
	})
		and isNonEmptyBoundedString(objective.ObjectiveId, 96)
		and isNonEmptyBoundedString(objective.ProgressSourceRef, 128)
		and isPositiveInteger(objective.RequiredCount)
end

local function validateRewardRef(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local rewardRef = value :: { [any]: any }
	return hasOnlyKeys(rewardRef, {
		RewardRefId = true,
		RewardAuthorityOwnerId = true,
	})
		and isNonEmptyBoundedString(rewardRef.RewardRefId, 128)
		and isNonEmptyBoundedString(rewardRef.RewardAuthorityOwnerId, 96)
end

function Contracts.validateQuestDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			QuestId = true,
			Version = true,
			PrerequisiteQuestIds = true,
			Objectives = true,
			RewardRefs = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(definition.QuestId, 96) or not isNonEmptyBoundedString(definition.Version, 24) then
		return false
	end
	if not validateStringList(definition.PrerequisiteQuestIds, 96, definition.QuestId) then
		return false
	end
	if type(definition.Objectives) ~= "table" or not isDenseArray(definition.Objectives) or #definition.Objectives < 1 then
		return false
	end
	local objectiveIds = {}
	for _, objective in definition.Objectives do
		if not validateObjective(objective) or objectiveIds[objective.ObjectiveId] then
			return false
		end
		objectiveIds[objective.ObjectiveId] = true
	end
	if type(definition.RewardRefs) ~= "table" or not isDenseArray(definition.RewardRefs) then
		return false
	end
	local rewardIds = {}
	for _, rewardRef in definition.RewardRefs do
		if not validateRewardRef(rewardRef) or rewardIds[rewardRef.RewardRefId] then
			return false
		end
		rewardIds[rewardRef.RewardRefId] = true
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

local function prerequisitesComplete(definition: QuestDefinition, context: QuestStateContext): boolean
	for _, prerequisiteQuestId in definition.PrerequisiteQuestIds do
		if context.CompletedQuestIds[prerequisiteQuestId] ~= true then
			return false
		end
	end
	return true
end

local function objectivesComplete(definition: QuestDefinition, context: QuestStateContext): boolean
	for _, objective in definition.Objectives do
		local progress = context.ObjectiveProgressById[objective.ObjectiveId]
		if not isFiniteNumber(progress) or (progress :: number) < objective.RequiredCount then
			return false
		end
	end
	return true
end

function Contracts.resolveQuestState(definition: QuestDefinition, context: QuestStateContext): string
	if context.CompletedQuestIds[definition.QuestId] == true then
		return Contracts.StateIds.Completed
	end
	if not prerequisitesComplete(definition, context) then
		return Contracts.StateIds.Locked
	end
	if context.AcceptedQuestIds[definition.QuestId] ~= true then
		return Contracts.StateIds.Available
	end
	if objectivesComplete(definition, context) then
		return Contracts.StateIds.ReadyToTurnIn
	end
	return Contracts.StateIds.Active
end

function Contracts.getTransition(transitionId: string): QuestTransitionDefinition?
	for _, transition in TransitionDefinitions do
		if transition.TransitionId == transitionId then
			return transition
		end
	end
	return nil
end

function Contracts.evaluateTransition(fromStateId: string, transitionId: string): QuestTransitionResult
	local transition = Contracts.getTransition(transitionId)
	if transition == nil or transition.FromStateId ~= fromStateId then
		return table.freeze({
			Accepted = false,
			ReasonId = Contracts.DenialReasonIds.InvalidTransition,
			TransitionId = transitionId,
			FromStateId = fromStateId,
			ToStateId = nil,
		})
	end
	return table.freeze({
		Accepted = true,
		ReasonId = nil,
		TransitionId = transitionId,
		FromStateId = fromStateId,
		ToStateId = transition.ToStateId,
	})
end

return table.freeze(Contracts)
