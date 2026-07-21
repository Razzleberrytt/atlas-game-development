--!strict

--[[
	Compact P7-0103 Brace input and owner feedback. The client sends only an
	action ID and phase, then renders the server's authoritative state/timing.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local ActionIds = ClassContracts.ClassActionIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ClassIds = ClassContracts.ClassIds
local PhaseIds = ClassContracts.ClassActionPhaseIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds

local localPlayer = Players.LocalPlayer
local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork")
local actionIntentRemote = classNetwork:WaitForChild("ActionIntent") :: RemoteEvent
local stateRemote = classNetwork:WaitForChild("State") :: RemoteEvent
local readStateFunction = classNetwork:WaitForChild("ReadState") :: RemoteFunction

local ACTION_NAME = "LivingKingdomsBrace"
local Controller = {}

local started = false
local isBound = false
local requestSequence = 0
local latestRosterRevision = -1
local latestSnapshot: ClassContracts.SafeClassSelectionSnapshot? = nil
local stateConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local progressFill: Frame? = nil
local progressTween: Tween? = nil
local characterHighlight: Highlight? = nil

local interruptionLabels = {
	MovementInterrupted = "STANCE BROKEN — MOVED",
	ReloadInterrupted = "STANCE BROKEN — RELOADED",
	ActorNotAlive = "STANCE ENDED",
	OperationResolved = "OPERATION COMPLETE",
	ActionCancelled = "STANCE CANCELLED",
	ActionCompleted = "STANCE COMPLETE",
}

local function currentActionState(): ClassContracts.AuthoritativeClassActionState?
	local snapshot = latestSnapshot
	return if snapshot == nil then nil else snapshot.ownerActionState
end

local function sendIntent(phaseId: ClassContracts.ClassActionPhaseId)
	requestSequence += 1
	actionIntentRemote:FireServer({
		requestId = string.format("brace:%d:%d", localPlayer.UserId, requestSequence),
		actionId = ActionIds.Brace,
		phaseId = phaseId,
	})
end

local function onBraceInput(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local state = currentActionState()
	if state == nil or state.actionStateId == ActionStateIds.Cooldown then
		return Enum.ContextActionResult.Sink
	end
	if state.actionStateId == ActionStateIds.Active then
		sendIntent(PhaseIds.Cancel)
	else
		sendIntent(PhaseIds.Begin)
	end
	return Enum.ContextActionResult.Sink
end

local function setBinding(shouldBind: boolean)
	if shouldBind == isBound then
		return
	end
	isBound = shouldBind
	if shouldBind then
		ContextActionService:BindAction(ACTION_NAME, onBraceInput, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(ACTION_NAME, "BRACE")
		ContextActionService:SetPosition(ACTION_NAME, UDim2.new(1, -118, 1, -190))
	else
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

local function setHighlight(isActive: boolean)
	if not isActive then
		if characterHighlight ~= nil then
			characterHighlight:Destroy()
			characterHighlight = nil
		end
		return
	end
	local character = localPlayer.Character
	if character == nil then
		return
	end
	if characterHighlight == nil then
		local highlight = Instance.new("Highlight")
		highlight.Name = "BraceOwnerCue"
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
		and assignment.classId == ClassIds.CombatSpecialist
		and snapshot.selectionStateId == SelectionStateIds.Locked
	frame.Visible = shouldShow
	setBinding(shouldShow)
	if not shouldShow or state == nil then
		setHighlight(false)
		return
	end

	local serverTimestamp = Workspace:GetServerTimeNow()
	if state.actionStateId == ActionStateIds.Active then
		label.Text = "BRACE ACTIVE  •  HOLD POSITION  •  Q TO CANCEL"
		local completion = state.completionServerTimestamp or serverTimestamp
		local remaining = math.max(0, completion - serverTimestamp)
		tweenProgress(remaining / ClassConfig.Actions.Brace.durationSeconds, remaining)
		setHighlight(true)
	elseif state.actionStateId == ActionStateIds.Cooldown then
		local suffix = interruptionLabels[state.statusReasonId or ""]
		label.Text = if suffix == nil then "BRACE RECHARGING" else suffix .. "  •  RECHARGING"
		local completion = state.cooldownEndServerTimestamp or serverTimestamp
		local remaining = math.max(0, completion - serverTimestamp)
		tweenProgress(remaining / ClassConfig.Actions.Brace.cooldownSeconds, remaining)
		setHighlight(false)
	else
		label.Text = "BRACE READY  •  Q / GAMEPAD X"
		tweenProgress(1, 0)
		setHighlight(false)
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
		if label ~= nil and string.find(rejection.requestId or "", "brace:", 1, true) == 1 then
			label.Text = "BRACE UNAVAILABLE  •  " .. rejection.rejectionReasonId
		end
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
	frame.Size = UDim2.fromOffset(338, 42)
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

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Position = UDim2.fromOffset(13, 4)
	label.Size = UDim2.new(1, -26, 0, 27)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "BRACE READY  •  Q / GAMEPAD X"
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

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	stateConnection = stateRemote.OnClientEvent:Connect(onPayload)
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
	setBinding(false)
	setHighlight(false)
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
	statusLabel = nil
	progressFill = nil
	latestSnapshot = nil
	latestRosterRevision = -1
	requestSequence = 0
end

return Controller
