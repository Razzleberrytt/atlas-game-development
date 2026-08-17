--!strict

--[[
	Compact specialist-action input and owner feedback. Candidate treatment
	targets are hints only; the server derives and validates every target fact.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassPresentationResolver = require(ReplicatedStorage.Shared.Classes.ClassPresentationResolver)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local ActionIds = ClassContracts.ClassActionIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ClassIds = ClassContracts.ClassIds
local PhaseIds = ClassContracts.ClassActionPhaseIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds

local localPlayer = Players.LocalPlayer
local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork", NETWORK_WAIT_SECONDS)
assert(classNetwork ~= nil, "ClassNetwork did not become available before the client bootstrap timeout")
local actionIntentRemote = classNetwork:WaitForChild("ActionIntent", NETWORK_WAIT_SECONDS)
assert(
	actionIntentRemote ~= nil,
	"ClassNetwork.ActionIntent did not become available before the client bootstrap timeout"
)
local stateRemote = classNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS)
assert(stateRemote ~= nil, "ClassNetwork.State did not become available before the client bootstrap timeout")
local readStateFunction = classNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)
assert(readStateFunction ~= nil, "ClassNetwork.ReadState did not become available before the client bootstrap timeout")

local ACTION_NAME = "LivingKingdomsClassAction"
local Controller = {}

local started = false
local isBound = false
local requestSequence = 0
local latestRosterRevision = -1
local latestSnapshot: ClassContracts.SafeClassSelectionSnapshot? = nil
local stateConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local identityLabel: TextLabel? = nil
local resourceLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local progressFill: Frame? = nil
local progressTween: Tween? = nil
local characterHighlight: Highlight? = nil
local temporaryFeedback: string? = nil
local temporaryFeedbackEndsAt = 0
local lastClockRefresh = 0
local lifecycleGeneration = 0

local function currentActionState(): ClassContracts.AuthoritativeClassActionState?
	local snapshot = latestSnapshot
	return if snapshot == nil then nil else snapshot.ownerActionState
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function nearestInjuredOperativeId(): string?
	local origin = rootPosition(localPlayer)
	if origin == nil then
		return nil
	end
	local nearestId, nearestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local currentHealth = player:GetAttribute("LK_P3_CurrentHealth")
		local maximumHealth = player:GetAttribute("LK_P3_MaximumHealth")
		local operativeEntityId = player:GetAttribute("LK_P3_OperativeEntityId")
		local position = rootPosition(player)
		if
			player ~= localPlayer
			and player:GetAttribute("LK_P3_LifeState") == "Alive"
			and type(currentHealth) == "number"
			and type(maximumHealth) == "number"
			and currentHealth < maximumHealth
			and type(operativeEntityId) == "string"
			and position ~= nil
		then
			local distance = (position - origin).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestId = operativeEntityId
			end
		end
	end
	return nearestId
end

local function nearestAliveTeammateOrSelfId(): string?
	local origin = rootPosition(localPlayer)
	if origin == nil then
		return nil
	end
	local nearestId, nearestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local operativeEntityId = player:GetAttribute("LK_P3_OperativeEntityId")
		local position = rootPosition(player)
		if
			player ~= localPlayer
			and player:GetAttribute("LK_P3_LifeState") == "Alive"
			and type(operativeEntityId) == "string"
			and position ~= nil
		then
			local distance = (position - origin).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestId = operativeEntityId
			end
		end
	end
	if nearestId ~= nil and nearestDistance <= ClassConfig.Actions.FieldResupply.maximumRangeStuds then
		return nearestId
	end
	local selfId = localPlayer:GetAttribute("LK_P3_OperativeEntityId")
	return if type(selfId) == "string" then selfId else nil
end

local function sendIntent(actionId: ClassContracts.ClassActionId, phaseId: ClassContracts.ClassActionPhaseId)
	requestSequence += 1
	if (actionId == ActionIds.FieldTreatment or actionId == ActionIds.FieldResupply) and phaseId == PhaseIds.Begin then
		local targetId = if actionId == ActionIds.FieldTreatment
			then nearestInjuredOperativeId()
			else nearestAliveTeammateOrSelfId()
		if targetId == nil then
			if statusLabel ~= nil then
				statusLabel.Text = if actionId == ActionIds.FieldTreatment
					then "NO INJURED TEAMMATE NEARBY"
					else "NO VALID RESUPPLY TARGET"
			end
			return
		end
		actionIntentRemote:FireServer({
			requestId = string.format("targeted-action:%d:%d", localPlayer.UserId, requestSequence),
			actionId = actionId,
			phaseId = phaseId,
			candidateTargetOperativeEntityId = targetId,
		})
	else
		actionIntentRemote:FireServer({
			requestId = string.format("class-action:%d:%d", localPlayer.UserId, requestSequence),
			actionId = actionId,
			phaseId = phaseId,
		})
	end
end

local function onBraceInput(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local state = currentActionState()
	local assignment = if latestSnapshot == nil then nil else latestSnapshot.ownerAssignment
	if state == nil or assignment == nil or state.actionStateId == ActionStateIds.Cooldown then
		return Enum.ContextActionResult.Sink
	end
	local actionId = if assignment.classId == ClassIds.Medic
		then ActionIds.FieldTreatment
		else if assignment.classId == ClassIds.Engineer then ActionIds.FieldResupply else ActionIds.Brace
	if state.actionStateId == ActionStateIds.Active then
		sendIntent(actionId, PhaseIds.Cancel)
	else
		sendIntent(actionId, PhaseIds.Begin)
	end
	return Enum.ContextActionResult.Sink
end

local function setBinding(shouldBind: boolean)
	if shouldBind == isBound then
		return
	end
	isBound = shouldBind
	if shouldBind then
		ContextActionService:BindAction(ACTION_NAME, onBraceInput, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle(ACTION_NAME, "ACTION")
	else
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

local function setHighlight(isActive: boolean, targetOperativeEntityId: string?)
	if not isActive then
		if characterHighlight ~= nil then
			characterHighlight:Destroy()
			characterHighlight = nil
		end
		return
	end
	local highlightedPlayer = localPlayer
	if targetOperativeEntityId ~= nil then
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("LK_P3_OperativeEntityId") == targetOperativeEntityId then
				highlightedPlayer = player
				break
			end
		end
	end
	local character = highlightedPlayer.Character
	if character == nil then
		return
	end
	if characterHighlight == nil then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ClassActionCue"
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Color3.fromRGB(240, 172, 67)
		highlight.FillTransparency = 0.82
		highlight.OutlineColor = Color3.fromRGB(255, 218, 145)
		highlight.OutlineTransparency = 0.12
		highlight.Parent = character
		characterHighlight = highlight
	end
	characterHighlight.Adornee = character
end

local function tweenProgress(fraction: number, remainingSeconds: number)
	local fill = progressFill
	if fill == nil then
		return
	end
	if progressTween ~= nil then
		progressTween:Cancel()
		progressTween = nil
	end
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if remainingSeconds > 0 then
		local tween = TweenService:Create(
			fill,
			TweenInfo.new(remainingSeconds, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0, 1) }
		)
		progressTween = tween
		tween:Play()
	end
end

local function updatePresentation()
	local snapshot = latestSnapshot
	local frame = panel
	local label = statusLabel
	if snapshot == nil or frame == nil or label == nil then
		return
	end
	local assignment = snapshot.ownerAssignment
	local state = snapshot.ownerActionState
	local shouldShow = assignment ~= nil
		and (assignment.classId == ClassIds.CombatSpecialist or assignment.classId == ClassIds.Medic or assignment.classId == ClassIds.Engineer)
		and snapshot.selectionStateId == SelectionStateIds.Locked
	frame.Visible = shouldShow
	setBinding(shouldShow)
	if not shouldShow or state == nil then
		setHighlight(false, nil)
		return
	end
	local isMedic = assignment.classId == ClassIds.Medic
	local isEngineer = assignment.classId == ClassIds.Engineer
	local identity = ClassPresentationResolver.identity(assignment.classId)
	if identityLabel ~= nil and identity ~= nil then
		identityLabel.Text = identity.shapeToken .. "  " .. identity.displayName .. "  •  " .. identity.roleSummary
	end
	if resourceLabel ~= nil then
		resourceLabel.Text = ClassPresentationResolver.resourceLabel(assignment.classId, snapshot.ownerResources)
	end
	ContextActionService:SetTitle(ACTION_NAME, if isMedic then "TREAT" else if isEngineer then "RESUPPLY" else "BRACE")

	local serverTimestamp = Workspace:GetServerTimeNow()
	if state.actionStateId == ActionStateIds.Active then
		label.Text = ClassPresentationResolver.ownerStatus(assignment.classId, state, serverTimestamp)
		local completion = state.completionServerTimestamp or serverTimestamp
		local remaining = math.max(0, completion - serverTimestamp)
		local duration = if isMedic
			then ClassConfig.Actions.FieldTreatment.channelDurationSeconds
			else if isEngineer
				then ClassConfig.Actions.FieldResupply.channelDurationSeconds
				else ClassConfig.Actions.Brace.durationSeconds
		tweenProgress(remaining / duration, remaining)
		setHighlight(true, if isMedic or isEngineer then state.targetOperativeEntityId else nil)
	elseif state.actionStateId == ActionStateIds.Cooldown then
		label.Text = ClassPresentationResolver.ownerStatus(assignment.classId, state, serverTimestamp)
		local completion = state.cooldownEndServerTimestamp or serverTimestamp
		local remaining = math.max(0, completion - serverTimestamp)
		local cooldown = if isMedic
			then ClassConfig.Actions.FieldTreatment.cooldownSeconds
			else if isEngineer
				then ClassConfig.Actions.FieldResupply.cooldownSeconds
				else ClassConfig.Actions.Brace.cooldownSeconds
		tweenProgress(remaining / cooldown, remaining)
		setHighlight(false, nil)
	else
		label.Text = ClassPresentationResolver.ownerStatus(assignment.classId, state, serverTimestamp)
		tweenProgress(1, 0)
		setHighlight(false, nil)
	end
end

local function onPayload(payload: unknown)
	if ClassContracts.validateSafeClassSelectionSnapshot(payload) then
		local snapshot = payload :: ClassContracts.SafeClassSelectionSnapshot
		if snapshot.rosterRevision < latestRosterRevision then
			return
		end
		latestRosterRevision = snapshot.rosterRevision
		latestSnapshot = snapshot
		updatePresentation()
		return
	end
	if ClassContracts.validateSafeClassSelectionRejection(payload) then
		local rejection = payload :: ClassContracts.SafeClassSelectionRejection
		local label = statusLabel
		if label ~= nil and rejection.requestId ~= nil then
			temporaryFeedback = ClassPresentationResolver.rejectionLabel(rejection.rejectionReasonId)
			temporaryFeedbackEndsAt = os.clock() + 2.5
			label.Text = temporaryFeedback or "ACTION UNAVAILABLE"
		end
	end
end

local function refreshClock()
	if os.clock() - lastClockRefresh < 0.1 then
		return
	end
	lastClockRefresh = os.clock()
	if temporaryFeedback ~= nil and os.clock() < temporaryFeedbackEndsAt then
		if statusLabel ~= nil then
			statusLabel.Text = temporaryFeedback
		end
		return
	end
	temporaryFeedback = nil
	local snapshot = latestSnapshot
	if
		snapshot ~= nil
		and snapshot.ownerAssignment ~= nil
		and snapshot.ownerActionState ~= nil
		and statusLabel ~= nil
	then
		statusLabel.Text = ClassPresentationResolver.ownerStatus(
			snapshot.ownerAssignment.classId,
			snapshot.ownerActionState,
			Workspace:GetServerTimeNow()
		)
	end
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClassActionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12

	local frame = Instance.new("Frame")
	frame.Name = "BracePanel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -18)
	frame.Size = UDim2.fromOffset(430, 72)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 26)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	panel = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(178, 121, 48)
	stroke.Transparency = 0.3
	stroke.Thickness = 1
	stroke.Parent = frame

	local ownerIdentity = Instance.new("TextLabel")
	ownerIdentity.Name = "ClassIdentity"
	ownerIdentity.Position = UDim2.fromOffset(13, 4)
	ownerIdentity.Size = UDim2.new(1, -26, 0, 18)
	ownerIdentity.BackgroundTransparency = 1
	ownerIdentity.Font = Enum.Font.GothamBold
	ownerIdentity.Text = "[SHIELD]  COMBAT SPECIALIST"
	ownerIdentity.TextColor3 = Color3.fromRGB(247, 222, 174)
	ownerIdentity.TextSize = 11
	ownerIdentity.TextXAlignment = Enum.TextXAlignment.Left
	ownerIdentity.Parent = frame
	identityLabel = ownerIdentity

	local resources = Instance.new("TextLabel")
	resources.Name = "Resources"
	resources.Position = UDim2.fromOffset(13, 22)
	resources.Size = UDim2.new(1, -26, 0, 16)
	resources.BackgroundTransparency = 1
	resources.Font = Enum.Font.GothamMedium
	resources.Text = "BRACE • COOLDOWN LIMITED"
	resources.TextColor3 = Color3.fromRGB(205, 210, 207)
	resources.TextSize = 10
	resources.TextXAlignment = Enum.TextXAlignment.Left
	resources.Parent = frame
	resourceLabel = resources

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Position = UDim2.fromOffset(13, 38)
	label.Size = UDim2.new(1, -26, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "BRACE READY  •  Q / GAMEPAD B"
	label.TextColor3 = Color3.fromRGB(247, 222, 174)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
	statusLabel = label

	local track = Instance.new("Frame")
	track.Name = "ProgressTrack"
	track.Position = UDim2.new(0, 10, 1, -8)
	track.Size = UDim2.new(1, -20, 0, 3)
	track.BackgroundColor3 = Color3.fromRGB(56, 61, 65)
	track.BorderSizePixel = 0
	track.Parent = frame
	local fill = Instance.new("Frame")
	fill.Name = "ProgressFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(241, 166, 67)
	fill.BorderSizePixel = 0
	fill.Parent = track
	progressFill = fill

	local playerGui = localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	gui.Parent = playerGui
	screenGui = gui
end

function Controller.start()
	if started then
		return
	end
	started = true
	lifecycleGeneration += 1
	local generation = lifecycleGeneration
	createPresentation()
	stateConnection = stateRemote.OnClientEvent:Connect(onPayload)
	task.spawn(function()
		while started and generation == lifecycleGeneration do
			refreshClock()
			task.wait(0.1)
		end
	end)
	local succeeded, snapshot = pcall(function()
		return readStateFunction:InvokeServer()
	end)
	if succeeded then
		onPayload(snapshot)
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	lifecycleGeneration += 1
	setBinding(false)
	setHighlight(false, nil)
	if progressTween ~= nil then
		progressTween:Cancel()
		progressTween = nil
	end
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	panel = nil
	identityLabel = nil
	resourceLabel = nil
	statusLabel = nil
	progressFill = nil
	latestSnapshot = nil
	latestRosterRevision = -1
	requestSequence = 0
	temporaryFeedback = nil
	temporaryFeedbackEndsAt = 0
	lastClockRefresh = 0
end

return Controller
