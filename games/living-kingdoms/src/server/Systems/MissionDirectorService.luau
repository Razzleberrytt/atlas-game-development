--!strict

--[[
	Mission orchestration for Operation Blackwater Relay.

	P5-0103 established the authoritative phase machine, extraction unlock, holdout
	countdown, and terminal outcome. P8-0103..0107 grow the single relay
	interaction into the authored objective chain specified in
	docs/specifications/authored-objective-chain.md: restore the relay at the
	Lookout, charge the signal booster at the Military Roadblock, and optionally
	restore the extraction floodlights. The chain runs inside the existing
	Infiltration/Exfiltration phases and the single terminal boundary — there is
	no new phase and no parallel state machine.

	This service is the one stateful objective-runtime owner. Objective progress is
	server-sampled from operative presence at each authored location and advanced
	only by the pure ObjectiveChainResolver, so clients declare nothing: there is
	no client-authored objective request to replay or spam. Every completion,
	escalation, and extraction unlock is committed here from server-read facts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MatchResultConfig = require(ReplicatedStorage.Shared.Config.MatchResultConfig)
local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)
local MissionConfig = require(ReplicatedStorage.Shared.Config.MissionConfig)
local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)
local ObjectiveChainConfig = require(ReplicatedStorage.Shared.Config.ObjectiveChainConfig)
local ObjectiveChainResolver = require(ReplicatedStorage.Shared.Mission.ObjectiveChainResolver)
local ClassService = require(script.Parent.ClassService)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local SquadFailureService = require(script.Parent.SquadFailureService)
local TerminalResultResolver = require(script.Parent.TerminalResultResolver)

type ExtractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateId
type MissionResultCauseId = MatchResultContracts.MissionResultCauseId
type MissionPhaseId = MissionContracts.MissionPhaseId
type MissionOutcomeId = MissionContracts.MissionOutcomeId
type ObjectiveStateId = MissionContracts.ObjectiveStateId
type SafeMissionSnapshot = MissionContracts.SafeMissionSnapshot
type SafeObjectiveSnapshot = MissionContracts.SafeObjectiveSnapshot
type SafeRadioTransmission = MissionContracts.SafeRadioTransmission
type WorkerFact = ObjectiveChainResolver.WorkerFact

type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

export type OperationResult = {
	didChange: boolean,
	rejectionReasonId: string?,
	revision: number,
	phaseId: MissionPhaseId,
}

export type AuthoritativeMissionRead = {
	revision: number,
	phaseId: MissionPhaseId,
	objectiveStateId: ObjectiveStateId,
	extractionUnlocked: boolean,
	escalationLevel: number,
	outcomeId: MissionOutcomeId?,
	causeId: MissionResultCauseId?,
	extractionReadinessStateId: ExtractionReadinessStateId,
	insertionDeadlineServerTimestamp: number?,
	holdoutDeadlineServerTimestamp: number?,
	activeObjectiveId: string?,
	floodlightsRestored: boolean,
	requiredChainComplete: boolean,
	objectiveProgressById: { [string]: number },
	objectiveCompletedById: { [string]: boolean },
	requiredObjectiveCompletedAtServerTimestamp: number?,
	requiredObjectiveCompletedByOperativeEntityId: string?,
}

local PhaseIds = MissionContracts.MissionPhaseIds
local OutcomeIds = MissionContracts.MissionOutcomeIds
local ObjectiveStateIds = MissionContracts.ObjectiveStateIds
local ChainStateIds = MissionContracts.ObjectiveChainStateIds
local RejectionReasonIds = MissionContracts.RejectionReasonIds
local RadioLineIds = MissionContracts.RadioLineIds

local MISSION_FOLDER_NAME = "MissionObjects"
-- Publish a live progress snapshot when the active objective advances at least
-- this much, so progress bars move without flooding the network every sample.
local PROGRESS_PUBLISH_STEP = 0.02

local Service = {}

Service.RejectionReasonIds = RejectionReasonIds

local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork")
local stateRemote = missionNetwork:WaitForChild("State") :: RemoteEvent

-- Index the authored objectives once for O(1) lookups.
local objectiveDefinitionById: { [string]: any } = {}
local requiredObjectiveId: string? = nil
local floodlightsObjectiveId: string? = nil
for _, definition in ObjectiveChainConfig.Objectives do
	objectiveDefinitionById[definition.objectiveId] = definition
	if definition.isRequiredForExtraction then
		requiredObjectiveId = definition.objectiveId
	end
	if definition.interactionKindId == "EquipmentRepair" then
		floodlightsObjectiveId = definition.objectiveId
	end
end

local started = false
local revision = 0
local phaseId: MissionPhaseId = PhaseIds.Insertion
local extractionUnlocked = false
local escalationLevel = 0
local outcomeId: MissionOutcomeId? = nil
local resultCauseId: MissionResultCauseId? = nil
-- P10-0103: the extraction sequence is Locked during the boss fight, Inbound for
-- the configured arrival window after the boss is authoritatively defeated, and
-- Arrived once an admitted, Alive operative is inside the clearing at the
-- deadline. Only Arrived feeds the terminal resolver's extraction fact.
local extractionReadinessStateId: ExtractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateIds.Locked
local insertionDeadlineServerTimestamp: number? = nil
local holdoutDeadlineServerTimestamp: number? = nil
local requiredObjectiveCompletedAtServerTimestamp: number? = nil
local requiredObjectiveCompletedByOperativeEntityId: string? = nil
local lastRadio: SafeRadioTransmission? = nil
local spawnedWaves: { [number]: boolean } = {}

local objectiveProgress: { [string]: number } = {}
local objectiveCompleted: { [string]: boolean } = {}
local objectiveDecaying: { [string]: boolean } = {}
local activeObjectiveId: string? = nil
local floodlightsRestored = false
local lastObjectiveSampleServerTimestamp: number? = nil
local lastPublishedProgressRatio = -1

local timerGeneration = 0
local timerThread: thread? = nil
local presenceAccumulatedSeconds = 0
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local failureConnection: ListenerConnection? = nil

local missionFolder: Folder? = nil
local objectiveLampByObjectiveId: { [string]: BasePart } = {}
local extractionBeacon: Model? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isFiniteTimestamp(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function result(didChange: boolean, rejectionReasonId: string?): OperationResult
	return table.freeze({
		didChange = didChange,
		rejectionReasonId = rejectionReasonId,
		revision = revision,
		phaseId = phaseId,
	})
end

local function resetObjectiveState()
	table.clear(objectiveProgress)
	table.clear(objectiveCompleted)
	table.clear(objectiveDecaying)
	for _, definition in ObjectiveChainConfig.Objectives do
		objectiveProgress[definition.objectiveId] = 0
		objectiveCompleted[definition.objectiveId] = false
		objectiveDecaying[definition.objectiveId] = false
	end
	activeObjectiveId = nil
	floodlightsRestored = false
	lastObjectiveSampleServerTimestamp = nil
	lastPublishedProgressRatio = -1
end

local function prerequisiteSatisfied(definition: any): boolean
	local prerequisiteId = definition.prerequisiteObjectiveId
	if prerequisiteId == nil then
		return true
	end
	return objectiveCompleted[prerequisiteId] == true
end

local function isRequiredChainComplete(): boolean
	if requiredObjectiveId == nil then
		return true
	end
	return objectiveCompleted[requiredObjectiveId] == true
end

-- The current objective the squad should be working: the first authored
-- objective that is unlocked (prerequisite met) and not yet completed.
local function computeActiveObjectiveId(): string?
	for _, definition in ObjectiveChainConfig.Objectives do
		if not objectiveCompleted[definition.objectiveId] and prerequisiteSatisfied(definition) then
			return definition.objectiveId
		end
	end
	return nil
end

local function objectiveChainStateId(definition: any): string
	if objectiveCompleted[definition.objectiveId] then
		return ChainStateIds.Completed
	elseif not prerequisiteSatisfied(definition) then
		return ChainStateIds.Locked
	end
	return ChainStateIds.Active
end

local function summaryObjectiveStateId(): ObjectiveStateId
	if phaseId == PhaseIds.Insertion then
		return ObjectiveStateIds.Inactive
	elseif isRequiredChainComplete() then
		return ObjectiveStateIds.Completed
	end
	return ObjectiveStateIds.Active
end

local function buildObjectiveSnapshots(): { SafeObjectiveSnapshot }
	local snapshots: { SafeObjectiveSnapshot } = {}
	for _, definition in ObjectiveChainConfig.Objectives do
		local progress = objectiveProgress[definition.objectiveId] or 0
		local ratio = math.clamp(progress / definition.completionUnits, 0, 1)
		table.insert(snapshots, {
			objectiveId = definition.objectiveId,
			displayText = definition.displayText,
			stateId = objectiveChainStateId(definition),
			progressRatio = ratio,
			decaying = objectiveDecaying[definition.objectiveId] == true,
			isOptional = definition.isOptional,
			destinationDisplayName = definition.destinationDisplayName,
		})
	end
	return snapshots
end

local function headlineObjectiveText(): string
	local currentId = activeObjectiveId
	if currentId ~= nil then
		local definition = objectiveDefinitionById[currentId]
		if definition ~= nil then
			return definition.displayText
		end
	end
	return MissionConfig.ObjectiveTextByPhase[phaseId]
end

local function safeSnapshot(): SafeMissionSnapshot
	return table.freeze({
		operationId = MissionConfig.OperationId,
		revision = revision,
		phaseId = phaseId,
		objectiveStateId = summaryObjectiveStateId(),
		objectiveText = headlineObjectiveText(),
		extractionUnlocked = extractionUnlocked,
		escalationLevel = escalationLevel,
		holdoutDeadlineServerTimestamp = holdoutDeadlineServerTimestamp,
		outcomeId = outcomeId,
		radio = lastRadio,
		objectives = buildObjectiveSnapshots(),
		activeObjectiveId = activeObjectiveId,
		floodlightsRestored = floodlightsRestored,
	}) :: SafeMissionSnapshot
end

local function publish()
	local snapshot = safeSnapshot()
	-- Track the active objective's published progress so live updates throttle.
	local currentId = activeObjectiveId
	if currentId ~= nil then
		lastPublishedProgressRatio =
			math.clamp((objectiveProgress[currentId] or 0) / objectiveDefinitionById[currentId].completionUnits, 0, 1)
	else
		lastPublishedProgressRatio = -1
	end
	pcall(function()
		stateRemote:FireAllClients(snapshot)
	end)
end

local function setRadio(lineId: string, serverTimestamp: number)
	lastRadio = table.freeze({
		lineId = lineId,
		text = MissionConfig.RadioLines[lineId],
		serverTimestamp = serverTimestamp,
	})
end

local function spawnWave(waveIndex: number)
	if spawnedWaves[waveIndex] then
		return
	end
	local wave = MissionConfig.Escalation.Waves[waveIndex]
	if wave == nil then
		return
	end
	spawnedWaves[waveIndex] = true
	escalationLevel = math.max(escalationLevel, waveIndex)
	-- The production enemy director validates fairness, defers unfair placements,
	-- raises its escalation level, and opens the authored-wave recovery window.
	pcall(function()
		EnemyDirectorService.spawnAuthoredWave(waveIndex, wave)
	end)
end

local function countAdmittedAliveInsideExtraction(): number
	local center = MissionConfig.Extraction.Position
	local radius = MissionConfig.Extraction.RadiusStuds
	local count = 0
	for _, read in OperativeLifeService.readAll() do
		if SquadFailureService.isOperativeAdmitted(read.operativeEntityId) and read.snapshot.lifeStateId == "Alive" then
			local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
			local character = if player == nil then nil else player.Character
			local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				local position = (root :: BasePart).Position
				local dx = position.X - center.x
				local dz = position.Z - center.z
				if dx * dx + dz * dz <= radius * radius then
					count += 1
				end
			end
		end
	end
	return count
end

-- Gather, per authored objective, the validated operatives standing on it:
-- admitted, alive, with a readable position within the interaction radius. Each
-- worker carries its server-owned class so the engineer repair path is honored.
local function gatherWorkersByObjective(): { [string]: { WorkerFact } }
	local classById: { [string]: string } = {}
	local ok, roster = pcall(ClassService.readRoster)
	if ok and type(roster) == "table" then
		for _, assignment in roster :: { any } do
			if type(assignment.operativeEntityId) == "string" and type(assignment.classId) == "string" then
				classById[assignment.operativeEntityId] = assignment.classId
			end
		end
	end

	local workersByObjectiveId: { [string]: { WorkerFact } } = {}
	for _, definition in ObjectiveChainConfig.Objectives do
		workersByObjectiveId[definition.objectiveId] = {}
	end

	for _, read in OperativeLifeService.readAll() do
		local operativeEntityId = read.operativeEntityId
		if SquadFailureService.isOperativeAdmitted(operativeEntityId) and read.snapshot.lifeStateId == "Alive" then
			local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
			local character = if player == nil then nil else player.Character
			local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				local position = (root :: BasePart).Position
				local classId = classById[operativeEntityId]
				for _, definition in ObjectiveChainConfig.Objectives do
					local center = definition.center
					local dx = position.X - center.x
					local dy = position.Y - center.y
					local dz = position.Z - center.z
					local radius = definition.interactionRadiusStuds
					if dx * dx + dy * dy + dz * dz <= radius * radius then
						table.insert(
							workersByObjectiveId[definition.objectiveId],
							{ operativeEntityId = operativeEntityId, classId = classId }
						)
					end
				end
			end
		end
	end
	return workersByObjectiveId
end

local function cancelTimer()
	timerGeneration += 1
	if timerThread ~= nil then
		pcall(task.cancel, timerThread)
		timerThread = nil
	end
end

local evaluateTimersAt: (serverTimestamp: number) -> OperationResult

local function scheduleTimers()
	cancelTimer()
	if not started or phaseId == PhaseIds.Resolved then
		return
	end
	local earliest: number? = nil
	local function consider(deadline: number?)
		if deadline ~= nil and (earliest == nil or deadline < earliest) then
			earliest = deadline
		end
	end
	consider(insertionDeadlineServerTimestamp)
	consider(holdoutDeadlineServerTimestamp)
	if earliest == nil then
		return
	end
	local generation = timerGeneration
	timerThread = task.delay(math.max(0, earliest - now()), function()
		if started and generation == timerGeneration then
			timerThread = nil
			evaluateTimersAt(now())
		end
	end)
end

local function armInsertionCountdown(serverTimestamp: number)
	if phaseId ~= PhaseIds.Insertion or insertionDeadlineServerTimestamp ~= nil then
		return
	end
	insertionDeadlineServerTimestamp = serverTimestamp + MissionConfig.InsertionHoldSeconds
	scheduleTimers()
	publish()
end

local function markObjectiveLampRestored(objectiveId: string)
	local lamp = objectiveLampByObjectiveId[objectiveId]
	if lamp ~= nil then
		lamp.Color = Color3.fromRGB(74, 189, 96)
		lamp:SetAttribute("ObjectiveRestored", true)
	end
end

local function createExtractionBeacon()
	local folder = missionFolder
	if folder == nil or extractionBeacon ~= nil then
		return
	end
	local center = MissionConfig.Extraction.Position
	local beacon = Instance.new("Model")
	beacon.Name = "ExtractionBeacon"
	beacon:SetAttribute("MissionObject", true)

	local pillar = Instance.new("Part")
	pillar.Name = "SignalPillar"
	pillar.Size = Vector3.new(3, 90, 3)
	pillar.CFrame = CFrame.new(center.x, center.y + 45, center.z)
	pillar.Color = Color3.fromRGB(242, 138, 45)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.45
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Parent = beacon

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 154, 61)
	light.Range = 55
	light.Brightness = 2.4
	light.Shadows = false
	light.Parent = pillar

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ExtractionMarker"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffset = Vector3.new(0, 52, 0)
	billboard.MaxDistance = 1200
	billboard.Parent = pillar

	local label = Instance.new("TextLabel")
	label.Name = "Marker"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 190, 120)
	label.Text = "EXTRACTION"
	label.Parent = billboard

	beacon.Parent = folder
	extractionBeacon = beacon
end

local function unlockExtraction(serverTimestamp: number)
	phaseId = PhaseIds.Exfiltration
	extractionUnlocked = true
	-- Restart objective sampling so the optional floodlights repair measures its
	-- own elapsed time rather than inheriting the Infiltration sample clock.
	lastObjectiveSampleServerTimestamp = serverTimestamp
	createExtractionBeacon()
end

-- Commit one authored objective's completion and its authored side effects.
local function applyObjectiveCompletion(objectiveId: string, serverTimestamp: number, workers: { WorkerFact })
	if objectiveCompleted[objectiveId] then
		return
	end
	local definition = objectiveDefinitionById[objectiveId]
	if definition == nil then
		return
	end
	objectiveCompleted[objectiveId] = true
	objectiveProgress[objectiveId] = definition.completionUnits
	objectiveDecaying[objectiveId] = false
	markObjectiveLampRestored(objectiveId)

	if definition.radioLineIdOnComplete ~= nil and RadioLineIds[definition.radioLineIdOnComplete] ~= nil then
		setRadio(definition.radioLineIdOnComplete, serverTimestamp)
	end
	if definition.waveIndexOnComplete ~= nil then
		spawnWave(definition.waveIndexOnComplete)
	end
	if floodlightsObjectiveId ~= nil and objectiveId == floodlightsObjectiveId then
		floodlightsRestored = true
	end
	if definition.isRequiredForExtraction then
		requiredObjectiveCompletedAtServerTimestamp = serverTimestamp
		requiredObjectiveCompletedByOperativeEntityId = if workers[1] ~= nil then workers[1].operativeEntityId else nil
		unlockExtraction(serverTimestamp)
	end
end

--[[
	The single terminal commit. Every cause reaches it through
	`evaluateTerminalAt`, which asks the pure P10-0102 resolver for exactly one
	decision; this function only applies that decision once.
]]
local function resolveMission(
	finalOutcomeId: MissionOutcomeId,
	finalCauseId: MissionResultCauseId,
	serverTimestamp: number
)
	if phaseId == PhaseIds.Resolved then
		return
	end
	phaseId = PhaseIds.Resolved
	outcomeId = finalOutcomeId
	resultCauseId = finalCauseId
	insertionDeadlineServerTimestamp = nil
	holdoutDeadlineServerTimestamp = nil
	pcall(function()
		EnemyDirectorService.endOperationPressure()
	end)
	setRadio(
		if finalOutcomeId == OutcomeIds.Success then RadioLineIds.MissionSuccess else RadioLineIds.MissionFailure,
		serverTimestamp
	)
	revision += 1
	cancelTimer()
	publish()
end

local function beginInfiltration(serverTimestamp: number)
	phaseId = PhaseIds.Infiltration
	insertionDeadlineServerTimestamp = nil
	activeObjectiveId = computeActiveObjectiveId()
	lastObjectiveSampleServerTimestamp = serverTimestamp
	-- Freeze the operation roster: squad viability and admission now cover exactly
	-- the operatives who started this operation.
	SquadFailureService.beginOperation()
	pcall(function()
		EnemyDirectorService.beginOperationPressure()
	end)
	setRadio(RadioLineIds.ProceedToObjective, serverTimestamp)
	revision += 1
	scheduleTimers()
	publish()
end

local function beginHoldout(serverTimestamp: number)
	phaseId = PhaseIds.Holdout
	-- P10-0103: the holdout is no longer won by a bare timer. Extraction stays
	-- Locked until The Progenitor is authoritatively defeated, so there is no
	-- countdown to disclose during the boss fight.
	holdoutDeadlineServerTimestamp = nil
	extractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateIds.Locked
	setRadio(RadioLineIds.HoldPosition, serverTimestamp)
	spawnWave(3)
	-- The authored climax: one Progenitor boss anchors the extraction clearing.
	-- Collapse-phase readability depends on the P8 optional floodlight repair.
	pcall(function()
		EnemyDirectorService.spawnBoss(MissionConfig.Extraction.Position, floodlightsRestored)
	end)
	revision += 1
	scheduleTimers()
	publish()
end

local function isBossDefeated(): boolean
	local didRead, bossState = pcall(function()
		return EnemyDirectorService.readBossState()
	end)
	return didRead and type(bossState) == "table" and bossState.isDefeated == true
end

--[[
	Advances the extraction sequence from server-read facts only. Locked → Inbound
	on the boss's authoritative defeat, opening the configured arrival window;
	Inbound → Arrived once that window has elapsed and at least one admitted, Alive
	operative stands in the clearing.

	Late entry, early departure, incapacitation, death, and disconnect during the
	window all resolve through that same presence rule: nobody inside at the
	deadline simply means extraction has not arrived yet. It is deliberately not a
	failure — the only terminal failures are a committed squad wipe and
	authoritative abandonment — so a squad that steps out can still walk back in
	and extract.
]]
local function advanceExtractionReadiness(serverTimestamp: number): boolean
	if phaseId ~= PhaseIds.Holdout then
		return false
	end
	local ReadinessIds = MatchResultContracts.ExtractionReadinessStateIds
	if extractionReadinessStateId == ReadinessIds.Locked then
		if not isBossDefeated() then
			return false
		end
		extractionReadinessStateId = ReadinessIds.Inbound
		holdoutDeadlineServerTimestamp = serverTimestamp + MatchResultConfig.ExtractionArrivalWindowSeconds
		setRadio(RadioLineIds.ExtractionInbound, serverTimestamp)
		revision += 1
		scheduleTimers()
		publish()
		return true
	end
	if extractionReadinessStateId ~= ReadinessIds.Inbound then
		return false
	end
	local deadline = holdoutDeadlineServerTimestamp
	if deadline == nil or serverTimestamp < deadline then
		return false
	end
	if countAdmittedAliveInsideExtraction() < 1 then
		return false
	end
	extractionReadinessStateId = ReadinessIds.Arrived
	return true
end

--[[
	Asks the pure terminal resolver for the single result to commit, from
	server-owned facts only. Abandonment is reported separately from a wipe so the
	resolver's fixed precedence labels each cause correctly.
]]
local function evaluateTerminalAt(serverTimestamp: number): boolean
	if phaseId == PhaseIds.Resolved then
		return false
	end
	local didReadFailure, failureRead = pcall(function()
		return SquadFailureService.read()
	end)
	local didReadParticipation, participation = pcall(function()
		return SquadFailureService.readParticipationFacts()
	end)
	local isAbandoned = didReadParticipation
		and type(participation) == "table"
		and participation.isAuthoritativelyAbandoned == true
	local hasFailed = didReadFailure
		and type(failureRead) == "table"
		and type(failureRead.state) == "table"
		and failureRead.state.statusId == "Failed"
	local decision = TerminalResultResolver.resolve({
		resolvedCauseId = resultCauseId,
		squadWiped = hasFailed and not isAbandoned,
		isAbandoned = isAbandoned,
		extractionArrived = extractionReadinessStateId == MatchResultContracts.ExtractionReadinessStateIds.Arrived,
		serverTimestamp = serverTimestamp,
	})
	if not decision.shouldCommit or decision.causeId == nil or decision.outcomeId == nil then
		return false
	end
	resolveMission(decision.outcomeId :: MissionOutcomeId, decision.causeId :: MissionResultCauseId, serverTimestamp)
	return true
end

evaluateTimersAt = function(serverTimestamp: number): OperationResult
	if not started then
		return result(false, RejectionReasonIds.ServiceStopped)
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return result(false, RejectionReasonIds.InvalidTimestamp)
	end
	local didChange = false
	local insertionDeadline = insertionDeadlineServerTimestamp
	if phaseId == PhaseIds.Insertion and insertionDeadline ~= nil and serverTimestamp >= insertionDeadline then
		beginInfiltration(serverTimestamp)
		didChange = true
	end
	if advanceExtractionReadiness(serverTimestamp) then
		didChange = true
	end
	if evaluateTerminalAt(serverTimestamp) then
		didChange = true
	end
	if not didChange then
		scheduleTimers()
	end
	return result(didChange, nil)
end

function Service.evaluateTimersAt(serverTimestamp: number): OperationResult
	return evaluateTimersAt(serverTimestamp)
end

-- One server-owned objective-progress sample. Presence-driven: it reads which
-- validated operatives stand on each authored objective and advances the chain
-- through the pure resolver. Clients never call this and never declare progress.
function Service.evaluateObjectivePresenceAt(serverTimestamp: number): OperationResult
	if not started then
		return result(false, RejectionReasonIds.ServiceStopped)
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return result(false, RejectionReasonIds.InvalidTimestamp)
	end
	if ObjectiveChainConfig.ActiveChainPhaseIds[phaseId] ~= true then
		return result(false, RejectionReasonIds.InvalidPhase)
	end

	local lastSample = lastObjectiveSampleServerTimestamp
	local deltaSeconds = if lastSample == nil then 0 else serverTimestamp - lastSample
	if deltaSeconds < 0 then
		deltaSeconds = 0
	end
	lastObjectiveSampleServerTimestamp = serverTimestamp

	local workersByObjectiveId = gatherWorkersByObjective()
	local stateByObjectiveId: { [string]: ObjectiveChainResolver.ObjectiveProgressState } = {}
	for _, definition in ObjectiveChainConfig.Objectives do
		stateByObjectiveId[definition.objectiveId] = {
			progress = objectiveProgress[definition.objectiveId] or 0,
			completed = objectiveCompleted[definition.objectiveId] == true,
		}
	end

	local sample = ObjectiveChainResolver.resolveSample({
		config = ObjectiveChainConfig,
		phaseId = phaseId,
		activePhaseIds = ObjectiveChainConfig.ActiveChainPhaseIds,
		revision = revision,
		expectedRevision = revision,
		deltaSeconds = deltaSeconds,
		stateByObjectiveId = stateByObjectiveId,
		workersByObjectiveId = workersByObjectiveId,
		assistingClassId = ObjectiveChainConfig.AssistingClassId,
	})
	if sample.rejectionReasonId ~= nil then
		return result(false, sample.rejectionReasonId)
	end

	for _, update in sample.updates do
		if not objectiveCompleted[update.objectiveId] then
			objectiveProgress[update.objectiveId] = update.progress
			objectiveDecaying[update.objectiveId] = update.decaying
		end
	end

	local committedChange = false
	for _, completedObjectiveId in sample.completedObjectiveIds do
		applyObjectiveCompletion(
			completedObjectiveId,
			serverTimestamp,
			workersByObjectiveId[completedObjectiveId] or {}
		)
		committedChange = true
	end

	if committedChange then
		activeObjectiveId = computeActiveObjectiveId()
		revision += 1
		scheduleTimers()
		publish()
		return result(true, nil)
	end

	-- No completion: publish a throttled live-progress update so the objective UI
	-- stays responsive without a revision flood.
	local currentId = activeObjectiveId
	if currentId ~= nil then
		local ratio =
			math.clamp((objectiveProgress[currentId] or 0) / objectiveDefinitionById[currentId].completionUnits, 0, 1)
		if math.abs(ratio - lastPublishedProgressRatio) >= PROGRESS_PUBLISH_STEP then
			revision += 1
			publish()
		end
	end
	return result(false, nil)
end

function Service.evaluateExtractionPresenceAt(serverTimestamp: number): OperationResult
	if not started then
		return result(false, RejectionReasonIds.ServiceStopped)
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return result(false, RejectionReasonIds.InvalidTimestamp)
	end
	if phaseId ~= PhaseIds.Exfiltration or not extractionUnlocked then
		return result(false, RejectionReasonIds.InvalidPhase)
	end
	if countAdmittedAliveInsideExtraction() < 1 then
		return result(false, nil)
	end
	beginHoldout(serverTimestamp)
	return result(true, nil)
end

function Service.read(): AuthoritativeMissionRead
	return table.freeze({
		revision = revision,
		phaseId = phaseId,
		objectiveStateId = summaryObjectiveStateId(),
		extractionUnlocked = extractionUnlocked,
		escalationLevel = escalationLevel,
		outcomeId = outcomeId,
		causeId = resultCauseId,
		extractionReadinessStateId = extractionReadinessStateId,
		insertionDeadlineServerTimestamp = insertionDeadlineServerTimestamp,
		holdoutDeadlineServerTimestamp = holdoutDeadlineServerTimestamp,
		activeObjectiveId = activeObjectiveId,
		floodlightsRestored = floodlightsRestored,
		requiredChainComplete = isRequiredChainComplete(),
		objectiveProgressById = table.clone(objectiveProgress),
		objectiveCompletedById = table.clone(objectiveCompleted),
		requiredObjectiveCompletedAtServerTimestamp = requiredObjectiveCompletedAtServerTimestamp,
		requiredObjectiveCompletedByOperativeEntityId = requiredObjectiveCompletedByOperativeEntityId,
	}) :: AuthoritativeMissionRead
end

function Service.readSafeSnapshot(): SafeMissionSnapshot
	return safeSnapshot()
end

-- One authored graybox marker per objective: a body, a status lamp (registered
-- so completion can turn it green), and a floating label. Presence, not a prompt,
-- is the authority, so nothing here accepts client input.
local function buildObjectiveMarker(parent: Folder, definition: any, modelName: string, bodyColor: Color3)
	local center = definition.center
	local model = Instance.new("Model")
	model.Name = modelName
	model:SetAttribute("MissionObject", true)
	model:SetAttribute("ObjectiveId", definition.objectiveId)

	local body = Instance.new("Part")
	body.Name = "MarkerBody"
	body.Size = Vector3.new(4, 5, 3)
	body.CFrame = CFrame.new(center.x, center.y, center.z)
	body.Color = bodyColor
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = true
	body.CanTouch = false
	body.Parent = model

	local lamp = Instance.new("Part")
	lamp.Name = "StatusLamp"
	lamp.Size = Vector3.new(1.4, 1.4, 1.4)
	lamp.CFrame = CFrame.new(center.x, center.y + 3.4, center.z)
	lamp.Color = Color3.fromRGB(184, 41, 29)
	lamp.Material = Enum.Material.Neon
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanTouch = false
	lamp.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 84, 52)
	light.Range = 24
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = lamp

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ObjectiveMarker"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(240, 36)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.MaxDistance = 400
	billboard.Parent = lamp

	local label = Instance.new("TextLabel")
	label.Name = "Marker"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 170)
	label.Text = definition.displayText
	label.Parent = billboard

	model.Parent = parent
	objectiveLampByObjectiveId[definition.objectiveId] = lamp
end

local function buildMissionObjects()
	local existing = Workspace:FindFirstChild(MISSION_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = MISSION_FOLDER_NAME
	folder.Parent = Workspace
	missionFolder = folder
	table.clear(objectiveLampByObjectiveId)

	-- Objective 1 keeps the RelayConsole identity; the others get distinct bodies.
	local markerNames: { [string]: string } = {
		["objective.restore-lookout-relay"] = "RelayConsole",
		["objective.charge-roadblock-booster"] = "SignalBooster",
		["objective.restore-extraction-floodlights"] = "FloodlightArray",
	}
	local markerColors: { [string]: Color3 } = {
		["objective.restore-lookout-relay"] = Color3.fromRGB(88, 96, 92),
		["objective.charge-roadblock-booster"] = Color3.fromRGB(96, 88, 72),
		["objective.restore-extraction-floodlights"] = Color3.fromRGB(72, 84, 96),
	}
	for _, definition in ObjectiveChainConfig.Objectives do
		local modelName = markerNames[definition.objectiveId] or ("Objective_" .. definition.objectiveId)
		local color = markerColors[definition.objectiveId] or Color3.fromRGB(88, 96, 92)
		buildObjectiveMarker(folder, definition, modelName, color)
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	local startTimestamp = now()
	revision = 1
	phaseId = PhaseIds.Insertion
	extractionUnlocked = false
	escalationLevel = 0
	outcomeId = nil
	resultCauseId = nil
	extractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateIds.Locked
	-- Studio can boot an empty server several seconds before its first client is
	-- connected. Do not spend the insertion window or freeze a zero-player roster
	-- before an actual player exists.
	insertionDeadlineServerTimestamp = nil
	holdoutDeadlineServerTimestamp = nil
	requiredObjectiveCompletedAtServerTimestamp = nil
	requiredObjectiveCompletedByOperativeEntityId = nil
	table.clear(spawnedWaves)
	resetObjectiveState()
	presenceAccumulatedSeconds = 0
	buildMissionObjects()
	setRadio(RadioLineIds.InsertionComplete, startTimestamp)
	failureConnection = SquadFailureService.subscribe(function(state)
		-- Squad failure no longer commits an outcome directly: it is one fact the
		-- single terminal resolver weighs, so a wipe and an abandonment reach the
		-- result with their own cause.
		if started and state.statusId == "Failed" then
			evaluateTerminalAt(now())
		end
	end)
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		armInsertionCountdown(now())
		pcall(function()
			stateRemote:FireClient(player, safeSnapshot())
		end)
	end)
	if #Players:GetPlayers() > 0 then
		armInsertionCountdown(startTimestamp)
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		presenceAccumulatedSeconds += deltaTime
		if presenceAccumulatedSeconds < MissionConfig.ExtractionPresenceIntervalSeconds then
			return
		end
		presenceAccumulatedSeconds = 0
		if ObjectiveChainConfig.ActiveChainPhaseIds[phaseId] == true then
			Service.evaluateObjectivePresenceAt(now())
		end
		if phaseId == PhaseIds.Exfiltration then
			Service.evaluateExtractionPresenceAt(now())
		end
		if phaseId == PhaseIds.Holdout then
			-- The extraction sequence is presence- and boss-driven, so it advances
			-- on the same bounded heartbeat rather than a per-enemy hook.
			local serverTimestamp = now()
			advanceExtractionReadiness(serverTimestamp)
			evaluateTerminalAt(serverTimestamp)
		end
	end)
	if insertionDeadlineServerTimestamp ~= nil then
		scheduleTimers()
	end
	publish()
	print("[Living Kingdoms] Mission director started: " .. MissionConfig.OperationDisplayName)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	cancelTimer()
	for _, connection in { heartbeatConnection, playerAddedConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	playerAddedConnection = nil
	if failureConnection ~= nil then
		failureConnection:Disconnect()
		failureConnection = nil
	end
	table.clear(objectiveLampByObjectiveId)
	extractionBeacon = nil
	if missionFolder ~= nil then
		missionFolder:Destroy()
		missionFolder = nil
	end
	revision = 0
	phaseId = PhaseIds.Insertion
	extractionUnlocked = false
	escalationLevel = 0
	outcomeId = nil
	resultCauseId = nil
	extractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateIds.Locked
	insertionDeadlineServerTimestamp = nil
	holdoutDeadlineServerTimestamp = nil
	requiredObjectiveCompletedAtServerTimestamp = nil
	requiredObjectiveCompletedByOperativeEntityId = nil
	lastRadio = nil
	table.clear(spawnedWaves)
	resetObjectiveState()
	presenceAccumulatedSeconds = 0
end

return Service
