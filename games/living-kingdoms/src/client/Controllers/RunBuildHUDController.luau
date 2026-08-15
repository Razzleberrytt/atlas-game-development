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

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local ChoiceInputCoordinator = require(script.Parent.ChoiceInputCoordinator)
local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)
local RewardContainerViewportPresenter = require(script.Parent.Parent.Presentation.RewardContainerViewportPresenter)
local ActiveInputDeviceFamily = require(script.Parent.Parent.State.ActiveInputDeviceFamily)
local InputActionMapConfig = require(ReplicatedStorage.Shared.Config.InputActionMapConfig)
local InputDeviceFamilyResolver = require(ReplicatedStorage.Shared.Input.InputDeviceFamilyResolver)
local InputHintPresentationResolver = require(ReplicatedStorage.Shared.Input.InputHintPresentationResolver)

local RunBuildHUDController = {}

local GUI_NAME = "LK_RunBuildHUD"
local SLOT_COUNT = RunRpgConfig.Limits.maximumEquippedRelicsPerOperative
local CHOICE_COUNT = RunRpgConfig.Limits.relicChoiceCountPerReward

local started = false
local stateConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}
local unregisterChoiceInput: (() -> ())? = nil
local screenGui: ScreenGui? = nil
local slotButtons: { TextButton } = {}
local choiceButtons: { TextButton } = {}
local choicePanel: Frame? = nil
local relicBar: Frame? = nil
local choiceTitle: TextLabel? = nil
local choiceSubtitle: TextLabel? = nil
local rewardViewport: ViewportFrame? = nil
local statusLabel: TextLabel? = nil

local choiceRelicIds: { [number]: string } = {}
local pendingReplacementRelicId: string? = nil
local activeRewardSequence: number? = nil
local activeGeneration = 0
local awaitingReplacement = false
local lastRelicSlots: any = nil
local lastRevision = -1
local requestSequence = 0
local choiceInputActive = false
local mouseIconWasEnabled = false

--[[
	BA-062 device-adaptive choice affordance. Direct number keys exist only on
	keyboard; gamepad reaches these buttons through selection focus and touch taps
	them. Rendering the canonical action map keeps the prompt truthful on every
	device instead of telling a controller player to press a number.
]]
local function activeDeviceFamily(): string
	return ActiveInputDeviceFamily.get()
end

local function choiceKeyTokens(familyId: string): { string }
	local action = InputActionMapConfig.get("NumberedChoiceInput")
	if action == nil then
		return {}
	end
	return InputHintPresentationResolver.resolve(action, familyId, { MaximumTokens = CHOICE_COUNT }).Tokens
end

-- Returns the per-button prefix for a choice, or an empty string when the active
-- device has no direct key for that index.
local function choiceButtonPrefix(tokens: { string }, choiceIndex: number): string
	local token = tokens[choiceIndex]
	return if token == nil then "" else string.format("[%s]  ", token)
end

local function choiceTitleText(tokens: { string }): string
	if #tokens == 0 then
		return "RUN RELIC — CHOOSE ONE"
	end
	return string.format("RUN RELIC — CHOOSE ONE [%s]", table.concat(tokens, " / "))
end

local function choiceSubtitleText(familyId: string, tokens: { string }): string
	if #tokens > 0 then
		return string.format("Temporary expedition power. Press %s, or click.", table.concat(tokens, " or "))
	end
	if familyId == InputDeviceFamilyResolver.DeviceFamilyIds.Touch then
		return "Temporary expedition power. Tap a relic to choose it."
	end
	return "Temporary expedition power. Select a relic to choose it."
end

local runBuildNetwork = ReplicatedStorage:WaitForChild("RunBuildNetwork", NETWORK_WAIT_SECONDS)
local stateRemote = runBuildNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = runBuildNetwork:WaitForChild("ReadState") :: RemoteFunction
local submitChoiceRemote = runBuildNetwork:WaitForChild("SubmitRelicChoice") :: RemoteEvent
local submitReplacementRemote = runBuildNetwork:WaitForChild("SubmitRelicReplacement") :: RemoteEvent

local relicDisplayNames: { [string]: string } = {}
local relicDescriptions: { [string]: string } = {}
for _, definition in RunRpgConfig.RelicCatalog do
	relicDisplayNames[definition.relicId] = definition.displayName
	relicDescriptions[definition.relicId] = definition.description
end

local function displayName(relicId: unknown): string
	if type(relicId) ~= "string" then
		return "UNKNOWN RELIC"
	end
	return relicDisplayNames[relicId] or relicId
end

local function description(relicId: unknown): string
	return if type(relicId) == "string" then relicDescriptions[relicId] or "Run modifier" else "Run modifier"
end

local function progressionChoiceIsVisible(): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hordeHud = if playerGui == nil then nil else playerGui:FindFirstChild("LivingKingdomsHordeHUD")
	local overlay = if hordeHud == nil then nil else hordeHud:FindFirstChild("UpgradeOverlay", true)
	return overlay ~= nil and overlay:IsA("GuiObject") and overlay.Visible
end

local function setChoiceInputActive(active: boolean)
	if active == choiceInputActive then
		return
	end
	choiceInputActive = active
	if active then
		mouseIconWasEnabled = UserInputService.MouseIconEnabled
		Players.LocalPlayer:SetAttribute("LK_InputModalOpen", true)
		UserInputService.MouseIconEnabled = true
		GuiService.SelectedObject = choiceButtons[1]
	elseif not progressionChoiceIsVisible() then
		Players.LocalPlayer:SetAttribute("LK_InputModalOpen", nil)
		UserInputService.MouseIconEnabled = mouseIconWasEnabled
		if GuiService.SelectedObject ~= nil and table.find(choiceButtons, GuiService.SelectedObject) ~= nil then
			GuiService.SelectedObject = nil
		end
	end
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Thin adapters onto the shared theme, so the relic bar matches every other
-- surface. Signatures are unchanged, so the rest of the controller is untouched.
local function addCorner(parent: Instance, radius: number)
	InterfaceTheme.corner(parent, radius)
end

local function addStroke(parent: Instance, color: Color3, transparency: number, thickness: number)
	InterfaceTheme.stroke(parent, color, transparency, thickness)
end

local function makeButton(parent: Instance, name: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = InterfaceTheme.Palette.PanelRaised
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Font = InterfaceTheme.Font.Body
	button.TextColor3 = InterfaceTheme.Palette.TextPrimary
	button.TextScaled = false
	button.TextSize = InterfaceTheme.TextSize.Body
	button.TextWrapped = true
	button.Text = ""
	button.Parent = parent
	InterfaceTheme.corner(button, InterfaceTheme.Radius.Control)
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
	bar.Position = UDim2.new(0.5, 0, 1, -28)
	bar.Size = UDim2.fromOffset(SLOT_COUNT * 140 + (SLOT_COUNT - 1) * 6, 42)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	relicBar = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for slotIndex = 1, SLOT_COUNT do
		local slot = makeButton(bar, "Slot" .. tostring(slotIndex))
		slot.LayoutOrder = slotIndex
		slot.Size = UDim2.fromOffset(140, 42)
		slot.Text = string.format("SLOT %d\nEMPTY", slotIndex)
		addStroke(slot, InterfaceTheme.Palette.Line, 0.4, 1)
		slotButtons[slotIndex] = slot
	end

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -76)
	status.Size = UDim2.fromOffset(440, 20)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextColor3 = InterfaceTheme.Palette.Accent
	status.TextStrokeColor3 = InterfaceTheme.Palette.Ink
	status.TextStrokeTransparency = 0.5
	status.TextSize = 13
	status.Text = ""
	status.Parent = gui
	statusLabel = status

	-- Reward panel: the two server-authored choices plus their presentation-only
	-- modular reward container preview.
	local panel = Instance.new("Frame")
	panel.Name = "RelicReward"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -18, 0.5, -36)
	panel.Size = UDim2.fromOffset(430, 330)
	panel.BackgroundColor3 = InterfaceTheme.Palette.Panel
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	addCorner(panel, 14)
	addStroke(panel, InterfaceTheme.Palette.AccentDim, 0.08, 2)
	choicePanel = panel

	rewardViewport = RewardContainerViewportPresenter.create(panel)
	rewardViewport.Position = UDim2.fromOffset(22, 10)
	rewardViewport.Size = UDim2.fromOffset(80, 80)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(114, 14)
	title.Size = UDim2.new(1, -136, 0, 28)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = InterfaceTheme.Palette.Accent
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "RELIC RECOVERED — CHOOSE ONE"
	title.Parent = panel
	choiceTitle = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromOffset(114, 42)
	subtitle.Size = UDim2.new(1, -136, 0, 42)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextColor3 = InterfaceTheme.Palette.TextMuted
	subtitle.TextSize = 15
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = "The relic equips into your first empty slot."
	subtitle.Parent = panel
	choiceSubtitle = subtitle

	local choiceRow = Instance.new("Frame")
	choiceRow.Name = "Choices"
	choiceRow.Position = UDim2.fromOffset(22, 104)
	choiceRow.Size = UDim2.new(1, -44, 1, -120)
	choiceRow.BackgroundTransparency = 1
	choiceRow.Parent = panel

	local choiceLayout = Instance.new("UIListLayout")
	choiceLayout.FillDirection = Enum.FillDirection.Vertical
	choiceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	choiceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	choiceLayout.Padding = UDim.new(0, 12)
	choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	choiceLayout.Parent = choiceRow

	for choiceIndex = 1, CHOICE_COUNT do
		local button = makeButton(choiceRow, "Choice" .. tostring(choiceIndex))
		button.LayoutOrder = choiceIndex
		button.Size = UDim2.new(1, 0, 0, 96)
		addStroke(button, InterfaceTheme.Palette.AccentDim, 0.35, 1)
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
	local occupied = false
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
		if type(slot) == "table" and slot.slotStateId == RunRpgContracts.RelicSlotStateIds.Equipped then
			occupied = true
		end
	end
	if relicBar ~= nil then
		relicBar.Visible = occupied or awaitingReplacement
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
		if rewardViewport ~= nil then
			RewardContainerViewportPresenter.clear(rewardViewport)
		end
		panel.Visible = false
		setChoiceInputActive(false)
		for _, button in choiceButtons do
			button.Visible = false
		end
		return
	end
	activeRewardSequence = reward.rewardSequence
	local familyId = activeDeviceFamily()
	local keyTokens = choiceKeyTokens(familyId)
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
		button.Text = string.format(
			"%s%s\n%s",
			choiceButtonPrefix(keyTokens, choiceIndex),
			displayName(relicId),
			description(relicId)
		)
		button.Visible = true
	end
	if awaitingReplacement then
		title.Text = "RUN RELIC — SLOTS FULL"
		subtitle.Text = if pendingReplacementRelicId == nil
			then "Choose a relic, then choose the slot it replaces."
			else string.format("Choose the slot to discard for %s.", displayName(pendingReplacementRelicId))
	else
		title.Text = choiceTitleText(keyTokens)
		subtitle.Text = choiceSubtitleText(familyId, keyTokens)
	end
	local panelVisible = visibleChoices > 0
	if rewardViewport ~= nil then
		if panelVisible then
			RewardContainerViewportPresenter.renderRunReward(rewardViewport, reward)
		else
			RewardContainerViewportPresenter.clear(rewardViewport)
		end
	end
	panel.Visible = panelVisible
	setChoiceInputActive(panel.Visible)
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

	unregisterChoiceInput = ChoiceInputCoordinator.register("RelicChoice", function()
		return choiceInputActive
	end, function(selectionIndex)
		if pendingReplacementRelicId ~= nil then
			submitReplacement(selectionIndex)
		else
			submitChoice(selectionIndex)
		end
	end)

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
	setChoiceInputActive(false)
	if unregisterChoiceInput ~= nil then
		unregisterChoiceInput()
		unregisterChoiceInput = nil
	end
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
	relicBar = nil
	choiceTitle = nil
	choiceSubtitle = nil
	rewardViewport = nil
	statusLabel = nil
	activeRewardSequence = nil
	pendingReplacementRelicId = nil
	awaitingReplacement = false
	lastRelicSlots = nil
	activeGeneration = 0
	lastRevision = -1
end

return table.freeze(RunBuildHUDController)