--!strict

--[[
	HROI-0105 Field XP and squad-upgrade HUD. The controller renders only the
	server's monotonic progression snapshot. Its sole mutation request is one
	upgrade ID from the current server-authored offer; the server validates the
	offer, stack cap, request shape, and winner before applying any modifier.
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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)

local RunProgressionHUDController = {}

local GUI_NAME = "LK_RunProgressionHUD"

local started = false
local stateConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local levelLabel: TextLabel? = nil
local xpLabel: TextLabel? = nil
local barFill: Frame? = nil
local gainLabel: TextLabel? = nil
local choiceFrame: Frame? = nil
local choiceButtons: { TextButton } = {}
local choiceButtonConnections: { RBXScriptConnection } = {}
local buttonUpgradeIds: { [number]: string } = {}
local lastRevision = -1
local lastGainSequence = 0
local lastSelectionSequence = 0
local gainExpiresAtServerTimestamp = 0

local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork", NETWORK_WAIT_SECONDS)
assert(progressionNetwork ~= nil, "ProgressionNetwork did not become available before the client bootstrap timeout")
local stateRemote = progressionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(stateRemote ~= nil, "ProgressionNetwork.State did not become available before the client bootstrap timeout")
local readStateRemote = progressionNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?
assert(
	readStateRemote ~= nil,
	"ProgressionNetwork.ReadState did not become available before the client bootstrap timeout"
)
local chooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	chooseUpgradeRemote ~= nil,
	"ProgressionNetwork.ChooseUpgrade did not become available before the client bootstrap timeout"
)

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

local function makeTextLabel(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 238, 232)
	label.TextStrokeColor3 = Color3.fromRGB(10, 12, 13)
	label.TextStrokeTransparency = 0.55
	label.TextScaled = true
	label.Parent = parent
	return label
end

local function createChoicePanel(gui: ScreenGui)
	local panel = Instance.new("Frame")
	panel.Name = "UpgradeChoices"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromOffset(690, 270)
	panel.BackgroundColor3 = Color3.fromRGB(13, 16, 17)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	addCorner(panel, 14)
	addStroke(panel, Color3.fromRGB(185, 133, 45), 0.08, 2)

	local title = makeTextLabel(panel, "Title")
	title.Position = UDim2.fromOffset(24, 15)
	title.Size = UDim2.new(1, -48, 0, 34)
	title.Text = "FIELD LEVEL UP — CHOOSE A FIELD UPGRADE"
	title.TextColor3 = Color3.fromRGB(255, 207, 90)

	local subtitle = makeTextLabel(panel, "Subtitle")
	subtitle.Position = UDim2.fromOffset(24, 51)
	subtitle.Size = UDim2.new(1, -48, 0, 22)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Text = "The first valid squad selection locks in for this run."
	subtitle.TextColor3 = Color3.fromRGB(176, 182, 176)

	for index = 1, RunProgressionConfig.UpgradeChoiceCount do
		local button = Instance.new("TextButton")
		button.Name = "Choice" .. tostring(index)
		button.Position = UDim2.fromOffset(22 + (index - 1) * 222, 88)
		button.Size = UDim2.fromOffset(202, 158)
		button.BackgroundColor3 = Color3.fromRGB(27, 31, 31)
		button.AutoButtonColor = true
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.fromRGB(239, 238, 224)
		button.TextSize = 17
		button.TextWrapped = true
		button.TextYAlignment = Enum.TextYAlignment.Center
		button.Text = ""
		button.Visible = false
		button.Parent = panel
		addCorner(button, 10)
		addStroke(button, Color3.fromRGB(116, 96, 57), 0.18, 1.5)
		table.insert(choiceButtons, button)
		table.insert(
			choiceButtonConnections,
			button.Activated:Connect(function()
				local upgradeId = buttonUpgradeIds[index]
				if upgradeId ~= nil and upgradeId ~= "" then
					chooseUpgradeRemote:FireServer(upgradeId)
				end
			end)
		)
	end

	choiceFrame = panel
end

local function createGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	local stale = playerGui:FindFirstChild(GUI_NAME)
	if stale ~= nil then
		stale:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 38
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -24)
	container.Size = UDim2.fromOffset(390, 62)
	container.BackgroundColor3 = Color3.fromRGB(17, 20, 21)
	container.BackgroundTransparency = 0.12
	container.BorderSizePixel = 0
	container.Parent = gui
	addCorner(container, 10)
	addStroke(container, Color3.fromRGB(131, 105, 54), 0.18, 1.5)

	local level = makeTextLabel(container, "Level")
	level.Position = UDim2.fromOffset(14, 7)
	level.Size = UDim2.fromOffset(190, 22)
	level.TextXAlignment = Enum.TextXAlignment.Left
	level.Text = "FIELD LEVEL 1"

	local progressText = makeTextLabel(container, "Progress")
	progressText.AnchorPoint = Vector2.new(1, 0)
	progressText.Position = UDim2.new(1, -14, 0, 7)
	progressText.Size = UDim2.fromOffset(160, 22)
	progressText.TextXAlignment = Enum.TextXAlignment.Right
	progressText.TextColor3 = Color3.fromRGB(225, 198, 119)
	progressText.Text = "0 / 100 XP"

	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.Position = UDim2.fromOffset(14, 35)
	barBackground.Size = UDim2.new(1, -28, 0, 14)
	barBackground.BackgroundColor3 = Color3.fromRGB(48, 51, 49)
	barBackground.BorderSizePixel = 0
	barBackground.ClipsDescendants = true
	barBackground.Parent = container
	addCorner(barBackground, 7)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(219, 164, 63)
	fill.BorderSizePixel = 0
	fill.Parent = barBackground
	addCorner(fill, 7)

	local gain = makeTextLabel(gui, "Gain")
	gain.AnchorPoint = Vector2.new(0.5, 1)
	gain.Position = UDim2.new(0.5, 0, 1, -92)
	gain.Size = UDim2.fromOffset(520, 34)
	gain.TextColor3 = Color3.fromRGB(255, 207, 90)
	gain.TextTransparency = 1
	gain.TextStrokeTransparency = 1
	gain.Text = ""

	createChoicePanel(gui)
	screenGui = gui
	levelLabel = level
	xpLabel = progressText
	barFill = fill
	gainLabel = gain
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function showGain(text: string)
	local gain = gainLabel
	if gain == nil then
		return
	end
	gain.Text = text
	gain.TextTransparency = 0
	gain.TextStrokeTransparency = 0.45
	gainExpiresAtServerTimestamp = Workspace:GetServerTimeNow() + RunProgressionConfig.GainDisplaySeconds
end

local function updateChoicePanel(pendingChoices: unknown)
	local panel = choiceFrame
	if panel == nil then
		return
	end
	table.clear(buttonUpgradeIds)
	for _, button in choiceButtons do
		button.Visible = false
		button.Text = ""
	end
	if type(pendingChoices) ~= "table" then
		panel.Visible = false
		return
	end

	local validChoiceCount = 0
	for index = 1, math.min(#pendingChoices, RunProgressionConfig.UpgradeChoiceCount) do
		local choice = pendingChoices[index]
		if type(choice) ~= "table" then
			continue
		end
		local id = choice.id
		local name = choice.name
		local description = choice.description
		local statPreview = choice.statPreview
		local stacks = choice.stacks
		local maximumStacks = choice.maximumStacks
		if
			type(id) ~= "string"
			or type(name) ~= "string"
			or type(description) ~= "string"
			or type(statPreview) ~= "string"
			or not isFiniteNumber(stacks)
			or not isFiniteNumber(maximumStacks)
		then
			continue
		end
		local button = choiceButtons[index]
		if button == nil then
			continue
		end
		validChoiceCount += 1
		buttonUpgradeIds[index] = id
		button.Text = string.format(
			"%s\n\n%s\n%s\n\nSTACK %d → %d / %d",
			name,
			statPreview,
			description,
			stacks,
			stacks + 1,
			maximumStacks
		)
		button.Visible = true
	end
	panel.Visible = validChoiceCount > 0
end

local function applySnapshot(snapshot: unknown)
	if type(snapshot) ~= "table" then
		return
	end
	local revision = snapshot.revision
	local level = snapshot.level
	local xp = snapshot.xp
	local xpForNextLevel = snapshot.xpForNextLevel
	local gainAmount = snapshot.lastGainAmount
	local gainSequence = snapshot.lastGainSequence
	local levelsGained = snapshot.levelsGainedLastAward
	local selectionSequence = snapshot.selectionSequence
	local lastSelectedUpgradeName = snapshot.lastSelectedUpgradeName
	local lastSelectedUpgradeStack = snapshot.lastSelectedUpgradeStack
	if
		not isFiniteNumber(revision)
		or revision <= lastRevision
		or not isFiniteNumber(level)
		or not isFiniteNumber(xp)
		or not isFiniteNumber(xpForNextLevel)
		or not isFiniteNumber(gainAmount)
		or not isFiniteNumber(gainSequence)
		or not isFiniteNumber(levelsGained)
		or not isFiniteNumber(selectionSequence)
		or type(lastSelectedUpgradeName) ~= "string"
		or not isFiniteNumber(lastSelectedUpgradeStack)
	then
		return
	end
	lastRevision = revision

	local levelText = levelLabel
	local progressText = xpLabel
	local fill = barFill
	if levelText == nil or progressText == nil or fill == nil then
		return
	end
	levelText.Text = "FIELD LEVEL " .. tostring(level)
	if xpForNextLevel <= 0 then
		progressText.Text = "MAX LEVEL"
		fill.Size = UDim2.fromScale(1, 1)
	else
		progressText.Text = string.format("%d / %d XP", xp, xpForNextLevel)
		fill.Size = UDim2.fromScale(math.clamp(xp / xpForNextLevel, 0, 1), 1)
	end

	updateChoicePanel(snapshot.pendingChoices)
	if selectionSequence > lastSelectionSequence and lastSelectedUpgradeName ~= "" then
		lastSelectionSequence = selectionSequence
		showGain(string.format("FIELD UPGRADE: %s  •  STACK %d", lastSelectedUpgradeName, lastSelectedUpgradeStack))
	elseif gainSequence > lastGainSequence and gainAmount > 0 then
		lastGainSequence = gainSequence
		showGain(
			if levelsGained > 0
				then string.format("LEVEL UP!  FIELD LEVEL %d", level)
				else string.format("+%d FIELD XP", gainAmount)
		)
	end
end

function RunProgressionHUDController.start()
	if started then
		return
	end
	started = true
	lastRevision = -1
	lastGainSequence = 0
	lastSelectionSequence = 0
	gainExpiresAtServerTimestamp = 0
	table.clear(choiceButtons)
	table.clear(choiceButtonConnections)
	table.clear(buttonUpgradeIds)
	createGui()

	stateConnection = stateRemote.OnClientEvent:Connect(applySnapshot)
	renderConnection = RunService.RenderStepped:Connect(function()
		local gain = gainLabel
		if gain == nil or gain.TextTransparency >= 1 then
			return
		end
		local remaining = gainExpiresAtServerTimestamp - Workspace:GetServerTimeNow()
		if remaining <= 0 then
			gain.TextTransparency = 1
			gain.TextStrokeTransparency = 1
			return
		end
		local fadeWindow = math.min(0.35, RunProgressionConfig.GainDisplaySeconds)
		if remaining < fadeWindow then
			local transparency = 1 - remaining / fadeWindow
			gain.TextTransparency = transparency
			gain.TextStrokeTransparency = math.clamp(0.45 + transparency * 0.55, 0, 1)
		end
	end)

	local didRead, initialSnapshot = pcall(function()
		return readStateRemote:InvokeServer()
	end)
	if didRead then
		applySnapshot(initialSnapshot)
	end
end

function RunProgressionHUDController.stop()
	if not started then
		return
	end
	started = false
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	for _, connection in choiceButtonConnections do
		connection:Disconnect()
	end
	table.clear(choiceButtonConnections)
	table.clear(choiceButtons)
	table.clear(buttonUpgradeIds)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	levelLabel = nil
	xpLabel = nil
	barFill = nil
	gainLabel = nil
	choiceFrame = nil
	lastRevision = -1
	lastGainSequence = 0
	lastSelectionSequence = 0
	gainExpiresAtServerTimestamp = 0
end

return table.freeze(RunProgressionHUDController)
