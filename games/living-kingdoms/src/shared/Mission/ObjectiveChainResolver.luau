--!strict

--[[
	P8-0102 generic server-owned objective runtime (pure core).

	One deterministic resolver advances the whole authored objective chain from
	server-read facts and commits nothing a client declared. Given the authored
	chain, the current progress/completion state, the operation phase, the mission
	revision, a bounded time delta, and the set of validated workers standing on
	each objective, it returns the new progress, any objectives that completed on
	this sample (in deterministic chain order), and whether the required chain is
	now complete.

	It is pure and side-effect-free: it reads its inputs, writes nothing, and is
	fully driven by fixtures without wall-clock time. The mission director is the
	single stateful owner; this module is the validation-and-progression law it
	applies. Because progression is presence-driven and server-sampled, there is
	no client progress request to replay or spam — the only trust surface is the
	sample itself, which is validated here (phase, revision, delta, prerequisite,
	completion, disclosure) before any unit of progress is committed.
]]

export type WorkerFact = {
	operativeEntityId: string,
	classId: string?,
}

export type ObjectiveProgressState = {
	progress: number,
	completed: boolean,
}

export type SampleInput = {
	config: any,
	phaseId: string,
	activePhaseIds: { [string]: boolean },
	revision: number,
	expectedRevision: number,
	deltaSeconds: number,
	stateByObjectiveId: { [string]: ObjectiveProgressState },
	workersByObjectiveId: { [string]: { WorkerFact } },
	assistingClassId: string?,
}

export type ObjectiveUpdate = {
	objectiveId: string,
	progress: number,
	stateId: string,
	progressRatio: number,
	decaying: boolean,
	completedNow: boolean,
	waveIndexOnComplete: number?,
	radioLineIdOnComplete: string?,
	unlockedExtraction: boolean,
}

export type SampleResult = {
	rejectionReasonId: string?,
	updates: { ObjectiveUpdate },
	completedObjectiveIds: { string },
	unlockedExtraction: boolean,
	requiredChainComplete: boolean,
}

local ObjectiveChainResolver = {}

local RejectionReasonIds = table.freeze({
	InvalidPhase = "InvalidPhase",
	InvalidDelta = "InvalidDelta",
	StaleRevision = "StaleRevision",
	InvalidPrerequisite = "InvalidPrerequisite",
})

ObjectiveChainResolver.RejectionReasonIds = RejectionReasonIds

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clamp(value: number, low: number, high: number): number
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

local function hasAssistingWorker(workers: { WorkerFact }, assistingClassId: string?): boolean
	if assistingClassId == nil then
		return false
	end
	for _, worker in workers do
		if worker.classId == assistingClassId then
			return true
		end
	end
	return false
end

-- Returns true when every prerequisite of `definition` is completed in `state`.
local function prerequisiteSatisfied(definition: any, stateByObjectiveId: { [string]: ObjectiveProgressState }): boolean
	local prerequisiteId = definition.prerequisiteObjectiveId
	if prerequisiteId == nil then
		return true
	end
	local prerequisiteState = stateByObjectiveId[prerequisiteId]
	return prerequisiteState ~= nil and prerequisiteState.completed == true
end

-- Advance one objective by one bounded sample. Never regresses a completed
-- objective, never exceeds its completion units, and only decays a decaying
-- charge that is currently unattended.
local function advanceOne(
	definition: any,
	current: ObjectiveProgressState,
	workers: { WorkerFact },
	deltaSeconds: number,
	assistingClassId: string?
): (number, boolean, boolean)
	local completionUnits = definition.completionUnits
	local previous = clamp(current.progress, 0, completionUnits)
	local workerCount = #workers
	local decaying = false
	local nextProgress = previous

	if workerCount > 0 then
		local rate = definition.baseRatePerSecond
		if definition.assistedRateMultiplier > 1 and hasAssistingWorker(workers, assistingClassId) then
			rate = definition.baseRatePerSecond * definition.assistedRateMultiplier
		end
		nextProgress = previous + rate * deltaSeconds
	elseif definition.decayRatePerSecond > 0 and previous > 0 then
		decaying = true
		nextProgress = previous - definition.decayRatePerSecond * deltaSeconds
	end

	nextProgress = clamp(nextProgress, 0, completionUnits)
	local completedNow = nextProgress >= completionUnits
	return nextProgress, completedNow, decaying
end

-- Resolve one presence sample across the whole chain.
function ObjectiveChainResolver.resolveSample(input: SampleInput): SampleResult
	local emptyUpdates: { ObjectiveUpdate } = {}
	local emptyCompleted: { string } = {}

	if input.activePhaseIds[input.phaseId] ~= true then
		return {
			rejectionReasonId = RejectionReasonIds.InvalidPhase,
			updates = emptyUpdates,
			completedObjectiveIds = emptyCompleted,
			unlockedExtraction = false,
			requiredChainComplete = false,
		}
	end
	if input.revision ~= input.expectedRevision then
		return {
			rejectionReasonId = RejectionReasonIds.StaleRevision,
			updates = emptyUpdates,
			completedObjectiveIds = emptyCompleted,
			unlockedExtraction = false,
			requiredChainComplete = false,
		}
	end
	if not isFiniteNumber(input.deltaSeconds) or input.deltaSeconds < 0 then
		return {
			rejectionReasonId = RejectionReasonIds.InvalidDelta,
			updates = emptyUpdates,
			completedObjectiveIds = emptyCompleted,
			unlockedExtraction = false,
			requiredChainComplete = false,
		}
	end

	local boundedDelta = clamp(input.deltaSeconds, 0, input.config.MaxSampleDeltaSeconds)
	local updates: { ObjectiveUpdate } = {}
	local completedObjectiveIds: { string } = {}
	local unlockedExtraction = false

	-- Iterate in authored chain order so completions cascade deterministically.
	for _, definition in input.config.Objectives do
		local objectiveId = definition.objectiveId
		local current = input.stateByObjectiveId[objectiveId] or { progress = 0, completed = false }
		local completionUnits = definition.completionUnits

		if current.completed then
			table.insert(updates, {
				objectiveId = objectiveId,
				progress = completionUnits,
				stateId = "Completed",
				progressRatio = 1,
				decaying = false,
				completedNow = false,
				waveIndexOnComplete = nil,
				radioLineIdOnComplete = nil,
				unlockedExtraction = false,
			})
			continue
		end

		-- Locked until every prerequisite is committed. A locked objective never
		-- accumulates progress, so a skipped required step cannot advance the run.
		if not prerequisiteSatisfied(definition, input.stateByObjectiveId) then
			table.insert(updates, {
				objectiveId = objectiveId,
				progress = clamp(current.progress, 0, completionUnits),
				stateId = "Locked",
				progressRatio = clamp(current.progress, 0, completionUnits) / completionUnits,
				decaying = false,
				completedNow = false,
				waveIndexOnComplete = nil,
				radioLineIdOnComplete = nil,
				unlockedExtraction = false,
			})
			continue
		end

		-- Unlocked but not workable in the current phase: hold progress, do not
		-- decay, and disclose it as an active (available) objective.
		if definition.activePhaseIds[input.phaseId] ~= true then
			table.insert(updates, {
				objectiveId = objectiveId,
				progress = clamp(current.progress, 0, completionUnits),
				stateId = "Active",
				progressRatio = clamp(current.progress, 0, completionUnits) / completionUnits,
				decaying = false,
				completedNow = false,
				waveIndexOnComplete = nil,
				radioLineIdOnComplete = nil,
				unlockedExtraction = false,
			})
			continue
		end

		local workers = input.workersByObjectiveId[objectiveId] or {}
		local nextProgress, completedNow, decaying =
			advanceOne(definition, current, workers, boundedDelta, input.assistingClassId)

		local objectiveUnlockedExtraction = false
		if completedNow and definition.isRequiredForExtraction then
			objectiveUnlockedExtraction = true
			unlockedExtraction = true
		end
		if completedNow then
			table.insert(completedObjectiveIds, objectiveId)
		end

		table.insert(updates, {
			objectiveId = objectiveId,
			progress = nextProgress,
			stateId = if completedNow then "Completed" else "Active",
			progressRatio = clamp(nextProgress / completionUnits, 0, 1),
			decaying = decaying,
			completedNow = completedNow,
			waveIndexOnComplete = if completedNow then definition.waveIndexOnComplete else nil,
			radioLineIdOnComplete = if completedNow then definition.radioLineIdOnComplete else nil,
			unlockedExtraction = objectiveUnlockedExtraction,
		})
	end

	-- The required chain is complete when every extraction-required objective is
	-- committed (either previously or on this sample).
	local requiredChainComplete = true
	for _, definition in input.config.Objectives do
		if definition.isRequiredForExtraction then
			local state = input.stateByObjectiveId[definition.objectiveId]
			local completedThisSample = false
			for _, completedId in completedObjectiveIds do
				if completedId == definition.objectiveId then
					completedThisSample = true
					break
				end
			end
			if not ((state ~= nil and state.completed) or completedThisSample) then
				requiredChainComplete = false
				break
			end
		end
	end

	return {
		rejectionReasonId = nil,
		updates = updates,
		completedObjectiveIds = completedObjectiveIds,
		unlockedExtraction = unlockedExtraction,
		requiredChainComplete = requiredChainComplete,
	}
end

return table.freeze(ObjectiveChainResolver)
