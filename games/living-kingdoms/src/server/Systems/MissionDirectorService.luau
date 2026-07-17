--!strict

--[[
	P5-0103 minimal mission orchestration for the first playable operation. This
	service owns the authoritative phase machine, the single authored objective,
	extraction unlock, the holdout countdown, and the final outcome. Every
	transition is derived from server timestamps and server-read facts; clients
	receive only the safe MissionContracts snapshot and can request nothing but
	one objective interaction that is fully revalidated here.

	Deliberately small so later operations can reuse the same phase vocabulary,
	timer evaluation, and disclosure shape. It composes — never rewrites — the
	existing life, squad-failure, and combat-fixture systems.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MissionConfig = require(ReplicatedStorage.Shared.Config.MissionConfig)
local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)
local AutomaticCombatDevelopmentHarness = require(script.Parent.AutomaticCombatDevelopmentHarness)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local SquadFailureService = require(script.Parent.SquadFailureService)

type MissionPhaseId = MissionContracts.MissionPhaseId
type MissionOutcomeId = MissionContracts.MissionOutcomeId
type ObjectiveStateId = MissionContracts.ObjectiveStateId
type SafeMissionSnapshot = MissionContracts.SafeMissionSnapshot
type SafeRadioTransmission = MissionContracts.SafeRadioTransmission

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
	insertionDeadlineServerTimestamp: number?,
	secondWaveDeadlineServerTimestamp: number?,
	holdoutDeadlineServerTimestamp: number?,
	objectiveCompletedAtServerTimestamp: number?,
	objectiveCompletedByOperativeEntityId: string?,
}

local PhaseIds = MissionContracts.MissionPhaseIds
local OutcomeIds = MissionContracts.MissionOutcomeIds
local ObjectiveStateIds = MissionContracts.ObjectiveStateIds
local RejectionReasonIds = MissionContracts.RejectionReasonIds
local RadioLineIds = MissionContracts.RadioLineIds

local MISSION_FOLDER_NAME = "MissionObjects"

local Service = {}

Service.RejectionReasonIds = RejectionReasonIds

local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork")
local stateRemote = missionNetwork:WaitForChild("State") :: RemoteEvent

local started = false
local revision = 0
local phaseId: MissionPhaseId = PhaseIds.Insertion
local objectiveStateId: ObjectiveStateId = ObjectiveStateIds.Inactive
local extractionUnlocked = false
local escalationLevel = 0
local outcomeId: MissionOutcomeId? = nil
local insertionDeadlineServerTimestamp: number? = nil
local secondWaveDeadlineServerTimestamp: number? = nil
local holdoutDeadlineServerTimestamp: number? = nil
local objectiveCompletedAtServerTimestamp: number? = nil
local objectiveCompletedByOperativeEntityId: string? = nil
local lastRadio: SafeRadioTransmission? = nil
local spawnedWaves: { [number]: boolean } = {}

local timerGeneration = 0
local timerThread: thread? = nil
local presenceAccumulatedSeconds = 0
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local failureConnection: ListenerConnection? = nil
local promptConnection: RBXScriptConnection? = nil

local missionFolder: Folder? = nil
local objectivePrompt: ProximityPrompt? = nil
local objectiveStatusLamp: BasePart? = nil
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

local function safeSnapshot(): SafeMissionSnapshot
	return table.freeze({
		operationId = MissionConfig.OperationId,
		revision = revision,
		phaseId = phaseId,
		objectiveStateId = objectiveStateId,
		objectiveText = MissionConfig.ObjectiveTextByPhase[phaseId],
		extractionUnlocked = extractionUnlocked,
		escalationLevel = escalationLevel,
		holdoutDeadlineServerTimestamp = holdoutDeadlineServerTimestamp,
		outcomeId = outcomeId,
		radio = lastRadio,
	}) :: SafeMissionSnapshot
end

local function publish()
	local snapshot = safeSnapshot()
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
	for _, definition in wave do
		-- The Studio-only combat harness owns the only existing hostile
		-- implementation; outside Studio this returns false and the mission
		-- proceeds without combat pressure.
		pcall(function()
			AutomaticCombatDevelopmentHarness.spawnMissionHostile({
				entityId = definition.id,
				name = definition.name,
				position = Vector3.new(definition.x, definition.y, definition.z),
			})
		end)
	end
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
	consider(secondWaveDeadlineServerTimestamp)
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

local function markObjectiveConsoleCompleted()
	local prompt = objectivePrompt
	if prompt ~= nil then
		pcall(function()
			prompt.Enabled = false
		end)
		prompt:Destroy()
		objectivePrompt = nil
	end
	local lamp = objectiveStatusLamp
	if lamp ~= nil then
		lamp.Color = Color3.fromRGB(74, 189, 96)
		lamp:SetAttribute("RelayRestored", true)
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

local function completeObjectiveCommit(operativeEntityId: string, serverTimestamp: number)
	objectiveStateId = ObjectiveStateIds.Completed
	objectiveCompletedAtServerTimestamp = serverTimestamp
	objectiveCompletedByOperativeEntityId = operativeEntityId
	phaseId = PhaseIds.Exfiltration
	extractionUnlocked = true
	secondWaveDeadlineServerTimestamp = serverTimestamp + MissionConfig.Escalation.SecondWaveDelaySeconds
	setRadio(RadioLineIds.ObjectiveComplete, serverTimestamp)
	spawnWave(1)
	markObjectiveConsoleCompleted()
	createExtractionBeacon()
	revision += 1
	scheduleTimers()
	publish()
end

local function resolveMission(finalOutcomeId: MissionOutcomeId, serverTimestamp: number)
	if phaseId == PhaseIds.Resolved then
		return
	end
	phaseId = PhaseIds.Resolved
	outcomeId = finalOutcomeId
	insertionDeadlineServerTimestamp = nil
	secondWaveDeadlineServerTimestamp = nil
	holdoutDeadlineServerTimestamp = nil
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
	objectiveStateId = ObjectiveStateIds.Active
	insertionDeadlineServerTimestamp = nil
	local prompt = objectivePrompt
	if prompt ~= nil then
		prompt.Enabled = true
	end
	-- Freeze the operation roster: squad viability and admission now cover
	-- exactly the operatives who started this operation.
	SquadFailureService.beginOperation()
	setRadio(RadioLineIds.ProceedToObjective, serverTimestamp)
	revision += 1
	scheduleTimers()
	publish()
end

local function beginHoldout(serverTimestamp: number)
	phaseId = PhaseIds.Holdout
	holdoutDeadlineServerTimestamp = serverTimestamp + MissionConfig.Extraction.ArrivalSeconds
	setRadio(RadioLineIds.HoldPosition, serverTimestamp)
	spawnWave(3)
	revision += 1
	scheduleTimers()
	publish()
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
	local secondWaveDeadline = secondWaveDeadlineServerTimestamp
	if
		(phaseId == PhaseIds.Exfiltration or phaseId == PhaseIds.Holdout)
		and secondWaveDeadline ~= nil
		and serverTimestamp >= secondWaveDeadline
	then
		secondWaveDeadlineServerTimestamp = nil
		spawnWave(2)
		setRadio(RadioLineIds.PressureRising, serverTimestamp)
		revision += 1
		scheduleTimers()
		publish()
		didChange = true
	end
	local holdoutDeadline = holdoutDeadlineServerTimestamp
	if phaseId == PhaseIds.Holdout and holdoutDeadline ~= nil and serverTimestamp >= holdoutDeadline then
		holdoutDeadlineServerTimestamp = nil
		local survivorsInsideClearing = countAdmittedAliveInsideExtraction()
		resolveMission(if survivorsInsideClearing >= 1 then OutcomeIds.Success else OutcomeIds.Failure, serverTimestamp)
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

function Service.requestObjectiveInteraction(player: Player): OperationResult
	if not started then
		return result(false, RejectionReasonIds.ServiceStopped)
	end
	if objectiveStateId == ObjectiveStateIds.Completed then
		return result(false, RejectionReasonIds.AlreadyCompleted)
	end
	if phaseId ~= PhaseIds.Infiltration then
		return result(false, RejectionReasonIds.InvalidPhase)
	end
	local read = if player == nil then nil else OperativeLifeService.read(player)
	if read == nil then
		return result(false, RejectionReasonIds.UnknownOperative)
	end
	if read.snapshot.lifeStateId ~= "Alive" then
		return result(false, RejectionReasonIds.InvalidLifeState)
	end
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return result(false, RejectionReasonIds.MissingPosition)
	end
	local position = (root :: BasePart).Position
	local console = MissionConfig.Objective.ConsolePosition
	local dx = position.X - console.x
	local dy = position.Y - console.y
	local dz = position.Z - console.z
	local radius = MissionConfig.Objective.InteractionRadiusStuds
	if dx * dx + dy * dy + dz * dz > radius * radius then
		return result(false, RejectionReasonIds.OutOfRange)
	end
	completeObjectiveCommit(read.snapshot.operativeEntityId, now())
	return result(true, nil)
end

function Service.read(): AuthoritativeMissionRead
	return table.freeze({
		revision = revision,
		phaseId = phaseId,
		objectiveStateId = objectiveStateId,
		extractionUnlocked = extractionUnlocked,
		escalationLevel = escalationLevel,
		outcomeId = outcomeId,
		insertionDeadlineServerTimestamp = insertionDeadlineServerTimestamp,
		secondWaveDeadlineServerTimestamp = secondWaveDeadlineServerTimestamp,
		holdoutDeadlineServerTimestamp = holdoutDeadlineServerTimestamp,
		objectiveCompletedAtServerTimestamp = objectiveCompletedAtServerTimestamp,
		objectiveCompletedByOperativeEntityId = objectiveCompletedByOperativeEntityId,
	}) :: AuthoritativeMissionRead
end

function Service.readSafeSnapshot(): SafeMissionSnapshot
	return safeSnapshot()
end

local function buildObjectiveConsole(parent: Folder)
	local console = MissionConfig.Objective.ConsolePosition
	local model = Instance.new("Model")
	model.Name = "RelayConsole"
	model:SetAttribute("MissionObject", true)
	model:SetAttribute("ObjectiveId", MissionConfig.Objective.ObjectiveId)

	local body = Instance.new("Part")
	body.Name = "ConsoleBody"
	body.Size = Vector3.new(4, 5, 3)
	body.CFrame = CFrame.new(console.x, console.y, console.z)
	body.Color = Color3.fromRGB(88, 96, 92)
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = true
	body.CanTouch = false
	body.Parent = model

	local lamp = Instance.new("Part")
	lamp.Name = "StatusLamp"
	lamp.Size = Vector3.new(1.4, 1.4, 1.4)
	lamp.CFrame = CFrame.new(console.x, console.y + 3.4, console.z)
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestoreRelayPrompt"
	prompt.ActionText = MissionConfig.Objective.PromptActionText
	prompt.ObjectText = MissionConfig.Objective.PromptObjectText
	prompt.HoldDuration = MissionConfig.Objective.PromptHoldDurationSeconds
	prompt.MaxActivationDistance = MissionConfig.Objective.InteractionRadiusStuds
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body

	model.Parent = parent
	objectivePrompt = prompt
	objectiveStatusLamp = lamp

	-- The prompt is presentation-side input only; acceptance always runs the
	-- full authoritative validation in requestObjectiveInteraction.
	pcall(function()
		promptConnection = prompt.Triggered:Connect(function(triggeringPlayer: Player)
			Service.requestObjectiveInteraction(triggeringPlayer)
		end)
	end)
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
	buildObjectiveConsole(folder)
end

function Service.start()
	if started then
		return
	end
	started = true
	local startTimestamp = now()
	revision = 1
	phaseId = PhaseIds.Insertion
	objectiveStateId = ObjectiveStateIds.Inactive
	extractionUnlocked = false
	escalationLevel = 0
	outcomeId = nil
	insertionDeadlineServerTimestamp = startTimestamp + MissionConfig.InsertionHoldSeconds
	secondWaveDeadlineServerTimestamp = nil
	holdoutDeadlineServerTimestamp = nil
	objectiveCompletedAtServerTimestamp = nil
	objectiveCompletedByOperativeEntityId = nil
	table.clear(spawnedWaves)
	presenceAccumulatedSeconds = 0
	buildMissionObjects()
	setRadio(RadioLineIds.InsertionComplete, startTimestamp)
	failureConnection = SquadFailureService.subscribe(function(state)
		if started and state.statusId == "Failed" then
			resolveMission(OutcomeIds.Failure, now())
		end
	end)
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		pcall(function()
			stateRemote:FireClient(player, safeSnapshot())
		end)
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		presenceAccumulatedSeconds += deltaTime
		if presenceAccumulatedSeconds < MissionConfig.ExtractionPresenceIntervalSeconds then
			return
		end
		presenceAccumulatedSeconds = 0
		if phaseId == PhaseIds.Exfiltration then
			Service.evaluateExtractionPresenceAt(now())
		end
	end)
	scheduleTimers()
	publish()
	print("[Living Kingdoms] Mission director started: " .. MissionConfig.OperationDisplayName)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	cancelTimer()
	for _, connection in { heartbeatConnection, playerAddedConnection, promptConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	playerAddedConnection = nil
	promptConnection = nil
	if failureConnection ~= nil then
		failureConnection:Disconnect()
		failureConnection = nil
	end
	objectivePrompt = nil
	objectiveStatusLamp = nil
	extractionBeacon = nil
	if missionFolder ~= nil then
		missionFolder:Destroy()
		missionFolder = nil
	end
	revision = 0
	phaseId = PhaseIds.Insertion
	objectiveStateId = ObjectiveStateIds.Inactive
	extractionUnlocked = false
	escalationLevel = 0
	outcomeId = nil
	insertionDeadlineServerTimestamp = nil
	secondWaveDeadlineServerTimestamp = nil
	holdoutDeadlineServerTimestamp = nil
	objectiveCompletedAtServerTimestamp = nil
	objectiveCompletedByOperativeEntityId = nil
	lastRadio = nil
	table.clear(spawnedWaves)
	presenceAccumulatedSeconds = 0
end

return Service
