--!strict

--[[
	RPG-0111 relic bar, reward-choice interface, and replacement interface.

	The controller renders only the server's safe run-build snapshot: three relic
	slots with their charge and counter state, and the current reward offer. Its
	only mutation requests are one offered relic ID, and — when every slot is full
	— that relic ID plus the slot index to overwrite. The server owns the offer,
	the slot rules, the replacement rule, and every effect.

	Readability: state is carried by text and slot position, never by colour or
	audio alone. An occupied slot names its relic; an empty slot says so; a slot
	awaiting replacement is labelled as the discard target.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)

local RunBuildHUDController = {}

local GUI_NAME = "LK_RunBuildHUD"
local SLOT_COUNT = RunRpgConfig.Limits.maximumEquippedRelicsPerOperative
local CHOICE_COUNT = RunRpgConfig.Limits.relicChoiceCountPerReward

local started = false
local stateConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local slotButtons: { TextButton } = {}
local choiceButtons: { TextButton } = {}
local choicePanel: Frame? = nil
local choiceTitle: TextLabel? = nil
local choiceSubtitle: TextLabel? = nil
local statusLabel: TextLabel? = nil

local choiceRelicIds: { [number]: string } = {}
local pendingReplacementRelicId: string? = nil
local activeRewardSequence: number? = nil
local activeGeneration = 0
local awaitingReplacement = false
local lastRelicSlots: any = nil
local lastRevision = -1
local requestSequence = 0

local runBuildNetwork = ReplicatedStorage:WaitForChild("RunBuildNetwork")
local stateRemote = runBuildNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = runBuildNetwork:WaitForChild("ReadState") :: RemoteFunction
local submitChoiceRemote = runBuildNetwork:WaitForChild("SubmitRelicChoice") :: RemoteEvent
local submitReplacementRemote = runBuildNetwork:WaitForChild("SubmitRelicReplacement") :: RemoteEvent

local relicDisplayNames: { [string]: string } = {}
for _, definition in RunRpgConfig.RelicCatalog do
	relicDisplayNames[definition.relicId] = definition.displayName
end

local function displayName(relicId: unknown): string
	if type(relicId) ~= "string" then
		return "UNKNOWN RELIC"
	end
	return relicDisplayNames[relicId] or relicId
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, transparency: number, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function makeButton(parent: Instance, name: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(18, 21, 23)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextColor3 = Color3.fromRGB(232, 236, 230)
	button.TextScaled = false
	button.TextSize = 15
	button.TextWrapped = true
	button.Text = ""
	button.Parent = parent
	addCorner(button, 10)
	return button
end

local function createGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	-- Relic bar: one row of slots along the lower edge, always visible so the
	-- player can read their build without opening anything.
	local bar = Instance.new("Frame")
	bar.Name = "RelicBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -96)
	bar.Size = UDim2.fromOffset(SLOT_COUNT * 186 + (SLOT_COUNT - 1) * 8, 62)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for slotIndex = 1, SLOT_COUNT do
		local slot = makeButton(bar, "Slot" .. tostring(slotIndex))
		slot.LayoutOrder = slotIndex
		slot.Size = UDim2.fromOffset(186, 62)
		slot.Text = string.format("SLOT %d\nEMPTY", slotIndex)
		addStroke(slot, Color3.fromRGB(120, 128, 118), 0.4, 1)
		slotButtons[slotIndex] = slot
	end

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -164)
	status.Size = UDim2.fromOffset(560, 24)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextColor3 = Color3.fromRGB(255, 207, 90)
	status.TextStrokeColor3 = Color3.fromRGB(10, 12, 13)
	status.TextStrokeTransparency = 0.5
	status.TextSize = 16
	status.Text = ""
	status.Parent = gui
	statusLabel = status

	-- Reward panel: the two server-authored choices.
	local panel = Instance.new("Frame")
	panel.Name = "RelicReward"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.3)
	panel.Size = UDim2.fromOffset(640, 232)
	panel.BackgroundColor3 = Color3.fromRGB(13, 16, 17)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	addCorner(panel, 14)
	addStroke(panel, Color3.fromRGB(185, 133, 45), 0.08, 2)
	choicePanel = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(22, 14)
	title.Size = UDim2.new(1, -44, 0, 28)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 207, 90)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "RELIC RECOVERED — CHOOSE ONE"
	title.Parent = panel
	choiceTitle = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromOffset(22, 42)
	subtitle.Size = UDim2.new(1, -44, 0, 22)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextColor3 = Color3.fromRGB(198, 204, 195)
	subtitle.TextSize = 15
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = "The relic equips into your first empty slot."
	subtitle.Parent = panel
	choiceSubtitle = subtitle

	local choiceRow = Instance.new("Frame")
	choiceRow.Name = "Choices"
	choiceRow.Position = UDim2.fromOffset(22, 76)
	choiceRow.Size = UDim2.new(1, -44, 0, 138)
	choiceRow.BackgroundTransparency = 1
	choiceRow.Parent = panel

	local choiceLayout = Instance.new("UIListLayout")
	choiceLayout.FillDirection = Enum.FillDirection.Horizontal
	choiceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	choiceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	choiceLayout.Padding = UDim.new(0, 12)
	choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	choiceLayout.Parent = choiceRow

	for choiceIndex = 1, CHOICE_COUNT do
		local button = makeButton(choiceRow, "Choice" .. tostring(choiceIndex))
		button.LayoutOrder = choiceIndex
		button.Size = UDim2.fromOffset(288, 138)
		addStroke(button, Color3.fromRGB(185, 133, 45), 0.35, 1)
		choiceButtons[choiceIndex] = button
	end
end

local function slotText(slot: any, slotIndex: number, isDiscardTarget: boolean): string
	if type(slot) ~= "table" or slot.slotStateId ~= RunRpgContracts.RelicSlotStateIds.Equipped then
		return string.format("SLOT %d\nEMPTY", slotIndex)
	end
	local detail = ""
	if isFiniteNumber(slot.chargeCount) and slot.chargeCount > 0 then
		detail = string.format("  •  %d CHARGE", slot.chargeCount)
	elseif isFiniteNumber(slot.counterValue) and slot.counterValue > 0 then
		detail = string.format("  •  %d", slot.counterValue)
	end
	if isDiscardTarget then
		return string.format("SLOT %d — DISCARD?\n%s%s", slotIndex, displayName(slot.relicId), detail)
	end
	return string.format("SLOT %d\n%s%s", slotIndex, displayName(slot.relicId), detail)
end

-- Slot labels depend on both the server snapshot and the local "which slot do I
-- discard?" decision, so rendering them is shared between the two.
local function renderSlots()
	for slotIndex = 1, SLOT_COUNT do
		local button = slotButtons[slotIndex]
		if button == nil then
			continue
		end
		local slot = if type(lastRelicSlots) == "table" then lastRelicSlots[slotIndex] else nil
		local isDiscardTarget = pendingReplacementRelicId ~= nil
			and type(slot) == "table"
			and slot.slotStateId == RunRpgContracts.RelicSlotStateIds.Equipped
		button.Text = slotText(slot, slotIndex, isDiscardTarget)
		button.AutoButtonColor = isDiscardTarget
	end
end

local function nextRequestId(): string
	requestSequence += 1
	return string.format("hud:%d:%d", os.time(), requestSequence)
end

--[[
	With an empty slot, pressing a relic sends the choice immediately. With every
	slot full the server requires an explicit replacement, so the press only
	selects the relic and the player then presses the slot to discard.
]]
local function submitChoice(choiceIndex: number)
	local relicId = choiceRelicIds[choiceIndex]
	local rewardSequence = activeRewardSequence
	if relicId == nil or rewardSequence == nil then
		return
	end
	if awaitingReplacement then
		pendingReplacementRelicId = relicId
		local subtitle = choiceSubtitle
		if subtitle ~= nil then
			subtitle.Text = string.format("Choose the slot to discard for %s.", displayName(relicId))
		end
		renderSlots()
		return
	end
	submitChoiceRemote:FireServer({
		requestId = nextRequestId(),
		operationGeneration = activeGeneration,
		rewardSequence = rewardSequence,
		relicId = relicId,
	})
end

local function submitReplacement(slotIndex: number)
	local relicId = pendingReplacementRelicId
	local rewardSequence = activeRewardSequence
	if relicId == nil or rewardSequence == nil then
		return
	end
	submitReplacementRemote:FireServer({
		requestId = nextRequestId(),
		operationGeneration = activeGeneration,
		rewardSequence = rewardSequence,
		relicId = relicId,
		replaceSlotIndex = slotIndex,
	})
end

local function applySnapshot(snapshot: unknown)
	if type(snapshot) ~= "table" then
		return
	end
	if snapshot.operationId == RunRpgContracts.RunBuildNetworkOperationIds.Rejected then
		local status = statusLabel
		if status ~= nil and type(snapshot.rejectionReasonId) == "string" then
			status.Text = "RELIC REQUEST REJECTED: " .. snapshot.rejectionReasonId
		end
		return
	end
	if not isFiniteNumber(snapshot.revision) or not isFiniteNumber(snapshot.operationGeneration) then
		return
	end
	if snapshot.operationGeneration == activeGeneration and snapshot.revision < lastRevision then
		return
	end
	if snapshot.operationGeneration ~= activeGeneration then
		-- A fresh operation invalidates any half-finished replacement decision.
		pendingReplacementRelicId = nil
	end
	activeGeneration = snapshot.operationGeneration
	lastRevision = snapshot.revision

	local rewards = snapshot.pendingRewards
	local reward = if type(rewards) == "table" then rewards[1] else nil
	awaitingReplacement = snapshot.replacementStateId == RunRpgContracts.ReplacementStateIds.AwaitingChoice
	if reward == nil or not awaitingReplacement then
		pendingReplacementRelicId = nil
	end

	lastRelicSlots = snapshot.relicSlots
	renderSlots()

	local panel = choicePanel
	local title = choiceTitle
	local subtitle = choiceSubtitle
	if panel == nil or title == nil or subtitle == nil then
		return
	end
	table.clear(choiceRelicIds)
	if reward == nil or type(reward.offeredRelicIds) ~= "table" or not isFiniteNumber(reward.rewardSequence) then
		activeRewardSequence = nil
		panel.Visible = false
		for _, button in choiceButtons do
			button.Visible = false
		end
		return
	end
	activeRewardSequence = reward.rewardSequence
	local visibleChoices = 0
	for choiceIndex = 1, CHOICE_COUNT do
		local button = choiceButtons[choiceIndex]
		local relicId = reward.offeredRelicIds[choiceIndex]
		if button == nil then
			continue
		end
		if type(relicId) ~= "string" then
			button.Visible = false
			continue
		end
		visibleChoices += 1
		choiceRelicIds[choiceIndex] = relicId
		button.Text = displayName(relicId)
		button.Visible = true
	end
	if awaitingReplacement then
		title.Text = "RELIC RECOVERED — SLOTS FULL"
		subtitle.Text = if pendingReplacementRelicId == nil
			then "Choose a relic, then choose the slot it replaces."
			else string.format("Choose the slot to discard for %s.", displayName(pendingReplacementRelicId))
	else
		title.Text = "RELIC RECOVERED — CHOOSE ONE"
		subtitle.Text = "The relic equips into your first empty slot."
	end
	panel.Visible = visibleChoices > 0
end

function RunBuildHUDController.start()
	if started then
		return
	end
	started = true
	lastRevision = -1
	activeGeneration = 0
	activeRewardSequence = nil
	pendingReplacementRelicId = nil
	awaitingReplacement = false
	lastRelicSlots = nil
	table.clear(choiceRelicIds)
	table.clear(slotButtons)
	table.clear(choiceButtons)
	table.clear(buttonConnections)
	createGui()

	for choiceIndex, button in choiceButtons do
		table.insert(
			buttonConnections,
			button.Activated:Connect(function()
				submitChoice(choiceIndex)
			end)
		)
	end
	for slotIndex, button in slotButtons do
		table.insert(
			buttonConnections,
			button.Activated:Connect(function()
				submitReplacement(slotIndex)
			end)
		)
	end

	stateConnection = stateRemote.OnClientEvent:Connect(applySnapshot)
	local didRead, initialSnapshot = pcall(function()
		return readStateRemote:InvokeServer()
	end)
	if didRead then
		applySnapshot(initialSnapshot)
	end
end

function RunBuildHUDController.stop()
	if not started then
		return
	end
	started = false
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	for _, connection in buttonConnections do
		connection:Disconnect()
	end
	table.clear(buttonConnections)
	table.clear(slotButtons)
	table.clear(choiceButtons)
	table.clear(choiceRelicIds)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	choicePanel = nil
	choiceTitle = nil
	choiceSubtitle = nil
	statusLabel = nil
	activeRewardSequence = nil
	pendingReplacementRelicId = nil
	awaitingReplacement = false
	lastRelicSlots = nil
	activeGeneration = 0
	lastRevision = -1
end

return table.freeze(RunBuildHUDController)
