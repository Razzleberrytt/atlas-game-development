--!strict

--[[
	HROI-0105 squad run-upgrade choice presentation. The client renders only the
	current server-authored offer and may return one request ID, that exact offer
	ID, and one offered upgrade ID. It cannot submit XP, levels, stacks, modifier
	values, reward facts, or offer contents.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)
local RunUpgradeContracts = require(ReplicatedStorage.Shared.Progression.RunUpgradeContracts)

type UpgradeId = RunUpgradeContracts.UpgradeId
type UpgradeOffer = RunUpgradeContracts.UpgradeOffer

local localPlayer = Players.LocalPlayer
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local selectionIntentRemote = progressionNetwork:WaitForChild("SelectionIntent") :: RemoteEvent

local Controller = {}

local GUI_NAME = "LK_RunUpgradeChoice"

local started = false
local requestSequence = 0
local latestRevision = -1
local latestOffer: UpgradeOffer? = nil
local stateConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local buttons: { TextButton } = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function createLabel(parent: Instance, name: string, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(238, 241, 235)
	label.TextStrokeColor3 = Color3.fromRGB(8, 10, 11)
	label.TextStrokeTransparency = 0.55
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function requestUpgrade(upgradeId: UpgradeId)
	local offer = latestOffer
	if offer == nil or table.find(offer.upgradeIds, upgradeId) == nil then
		return
	end
	requestSequence += 1
	selectionIntentRemote:FireServer({
		requestId = string.format("squad-run-upgrade:%d:%d", localPlayer.UserId, requestSequence),
		offerId = offer.offerId,
		upgradeId = upgradeId,
	})
end

local function updateOfferPresentation(offer: UpgradeOffer?, stacks: unknown)
	local currentPanel = panel
	if currentPanel == nil then
		return
	end
	latestOffer = offer
	currentPanel.Visible = offer ~= nil
	for index, button in buttons do
		local upgradeId = if offer == nil then nil else offer.upgradeIds[index]
		if upgradeId == nil then
			button.Visible = false
			button:SetAttribute("UpgradeId", nil)
		else
			local definition = RunProgressionConfig.UpgradeDefinitions[upgradeId]
			local stackCount = if type(stacks) == "table" and type(stacks[upgradeId]) == "number"
				then stacks[upgradeId]
				else 0
			button.Text = if definition == nil
				then upgradeId
				else string.format("%s\n\n%s\n\nCURRENT STACKS: %d", definition.displayName, definition.description, stackCount)
			button:SetAttribute("UpgradeId", upgradeId)
			button.Visible = true
		end
	end
end

local function applySnapshot(snapshot: unknown)
	if type(snapshot) ~= "table" then
		return
	end
	local revision = snapshot.revision
	local offer = snapshot.pendingUpgradeOffer
	local stacks = snapshot.upgradeStacks
	if type(revision) ~= "number" or revision ~= revision or revision <= latestRevision then
		return
	end
	if offer ~= nil and not RunUpgradeContracts.validateOffer(offer) then
		return
	end
	if not RunUpgradeContracts.validateStacks(stacks, RunProgressionConfig.MaximumUpgradeStacks) then
		return
	end
	latestRevision = revision
	updateOfferPresentation(offer :: UpgradeOffer?, stacks)
end

local function createGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local stale = playerGui:FindFirstChild(GUI_NAME)
	if stale ~= nil then
		stale:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 42
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local choicePanel = Instance.new("Frame")
	choicePanel.Name = "ChoicePanel"
	choicePanel.AnchorPoint = Vector2.new(0.5, 0.5)
	choicePanel.Position = UDim2.fromScale(0.5, 0.52)
	choicePanel.Size = UDim2.new(0.9, 0, 0, 270)
	choicePanel.BackgroundColor3 = Color3.fromRGB(12, 16, 18)
	choicePanel.BackgroundTransparency = 0.03
	choicePanel.BorderSizePixel = 0
	choicePanel.Visible = false
	choicePanel.Parent = gui
	addCorner(choicePanel, 12)
	panel = choicePanel

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 270)
	sizeConstraint.MaxSize = Vector2.new(720, 270)
	sizeConstraint.Parent = choicePanel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(187, 63, 46)
	stroke.Transparency = 0.08
	stroke.Thickness = 2
	stroke.Parent = choicePanel

	local title = createLabel(choicePanel, "Title", 24)
	title.Position = UDim2.new(0, 18, 0, 12)
	title.Size = UDim2.new(1, -36, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = "SQUAD FIELD LEVEL UP — CHOOSE ONE"

	local subtitle = createLabel(choicePanel, "Subtitle", 14)
	subtitle.Position = UDim2.new(0, 18, 0, 48)
	subtitle.Size = UDim2.new(1, -36, 0, 26)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextColor3 = Color3.fromRGB(183, 188, 181)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Text = "First accepted squad selection locks the run-only upgrade"

	local choices = Instance.new("Frame")
	choices.Name = "Choices"
	choices.Position = UDim2.new(0, 14, 0, 84)
	choices.Size = UDim2.new(1, -28, 0, 168)
	choices.BackgroundTransparency = 1
	choices.Parent = choicePanel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = choices

	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "UpgradeOption" .. tostring(index)
		button.Size = UDim2.new(1 / 3, -8, 1, 0)
		button.BackgroundColor3 = Color3.fromRGB(41, 49, 52)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.TextColor3 = Color3.fromRGB(244, 246, 241)
		button.TextSize = 14
		button.TextWrapped = true
		button.AutoButtonColor = true
		button.Visible = false
		button.Parent = choices
		addCorner(button, 8)
		button.Activated:Connect(function()
			local upgradeId = button:GetAttribute("UpgradeId")
			if RunUpgradeContracts.isUpgradeId(upgradeId) then
				requestUpgrade(upgradeId :: UpgradeId)
			end
		end)
		table.insert(buttons, button)
	end

	screenGui = gui
end

function Controller.start()
	if started then
		return
	end
	started = true
	createGui()
	stateConnection = stateRemote.OnClientEvent:Connect(applySnapshot)
	local didRead, snapshot = pcall(function()
		return readStateRemote:InvokeServer()
	end)
	if didRead then
		applySnapshot(snapshot)
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
	table.clear(buttons)
	latestOffer = nil
	latestRevision = -1
	requestSequence = 0
end

return table.freeze(Controller)
