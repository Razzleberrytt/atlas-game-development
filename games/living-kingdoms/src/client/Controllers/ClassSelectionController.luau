--!strict

--[[
	P7-0102 temporary class-selection presentation. The client may request one
	known starting class while the server-disclosed selection window is open. It
	never sends operative identity, lock state, revision, unlocks, resources,
	cooldowns, class effects, health, or ammunition.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local NetworkOperationIds = ClassContracts.ClassSelectionNetworkOperationIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds

local localPlayer = Players.LocalPlayer
local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork")
local selectionIntentRemote = classNetwork:WaitForChild("SelectionIntent") :: RemoteEvent
local stateRemote = classNetwork:WaitForChild("State") :: RemoteEvent
local readStateFunction = classNetwork:WaitForChild("ReadState") :: RemoteFunction

local Controller = {}

local started = false
local requestSequence = 0
local latestRosterRevision = -1
local stateConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local buttonsByClassId: { [string]: TextButton } = {}
local displayNameByClassId: { [string]: string } = {}
local latestSnapshot: ClassContracts.SafeClassSelectionSnapshot? = nil

for _, definition in ClassConfig.ClassDefinitions do
	displayNameByClassId[definition.classId] = definition.displayName
end

local function createTextLabel(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	textSize: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(238, 241, 238)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function requestClass(classId: string)
	local snapshot = latestSnapshot
	if snapshot == nil or snapshot.selectionStateId ~= SelectionStateIds.Open then
		return
	end
	requestSequence += 1
	selectionIntentRemote:FireServer({
		requestId = string.format("class-selection:%d:%d", localPlayer.UserId, requestSequence),
		classId = classId,
	})
end

local function updatePresentation()
	local snapshot = latestSnapshot
	local status = statusLabel
	local currentPanel = panel
	if snapshot == nil or status == nil or currentPanel == nil then
		return
	end
	local owner = snapshot.ownerAssignment
	local selectedClassId = if owner == nil then nil else owner.classId
	local selectedName = if selectedClassId == nil
		then "Unassigned"
		else displayNameByClassId[selectedClassId] or selectedClassId
	if snapshot.selectionStateId == SelectionStateIds.Open then
		currentPanel.Visible = true
		status.Text = "CHOOSE SPECIALIST — locks when insertion ends\nCurrent: " .. selectedName
		for classId, button in buttonsByClassId do
			local displayName = displayNameByClassId[classId] or classId
			button.Text = if classId == selectedClassId then "✓ " .. displayName .. " — SELECTED" else displayName
			button.Visible = true
		end
	else
		currentPanel.Visible = true
		status.Text = "SPECIALIST LOCKED: " .. selectedName
		for _, button in buttonsByClassId do
			button.Visible = false
		end
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
		local status = statusLabel
		if status ~= nil then
			status.Text = "CLASS REQUEST REJECTED: " .. rejection.rejectionReasonId
		end
	end
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TemporaryClassSelectionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 13

	local frame = Instance.new("Frame")
	frame.Name = "SelectionPanel"
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 18, 0.5, 0)
	frame.Size = UDim2.fromOffset(300, 228)
	frame.BackgroundColor3 = Color3.fromRGB(17, 21, 24)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = gui
	panel = frame

	local title = createTextLabel(frame, "Title", UDim2.fromOffset(16, 12), UDim2.fromOffset(268, 30), 20)
	title.Font = Enum.Font.GothamBold
	title.Text = "SPECIALIST ASSIGNMENT"

	statusLabel = createTextLabel(frame, "Status", UDim2.fromOffset(16, 44), UDim2.fromOffset(268, 48), 14)
	statusLabel.Text = "Loading server assignment…"

	for index, classId in ClassConfig.Selection.startingClassIds do
		local button = Instance.new("TextButton")
		button.Name = "ClassOption" .. tostring(index)
		button.Position = UDim2.fromOffset(16, 94 + (index - 1) * 40)
		button.Size = UDim2.fromOffset(268, 34)
		button.BackgroundColor3 = Color3.fromRGB(46, 55, 62)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.TextColor3 = Color3.fromRGB(244, 246, 244)
		button.TextSize = 15
		button.Text = displayNameByClassId[classId] or classId
		button.Parent = frame
		button.Activated:Connect(function()
			requestClass(classId)
		end)
		buttonsByClassId[classId] = button
	end

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
	table.clear(buttonsByClassId)
	latestSnapshot = nil
	latestRosterRevision = -1
	requestSequence = 0
end

return Controller
