--!strict

--[[
	HROI-0104 accessibility settings panel. One small fixed FX button opens a
	panel with one text-labeled cycle button per comfort setting (camera shake,
	blood). Everything is client-local presentation preference: the controller
	creates no remote, sends no request, reads no gameplay state, and runs no
	per-frame work. Labels carry the full setting name and level as text so the
	control never depends on color or audio alone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PresentationAccessibilityConfig = require(ReplicatedStorage.Shared.Config.PresentationAccessibilityConfig)
local PresentationAccessibilityState = require(script.Parent.Parent.Presentation.PresentationAccessibilityState)

local SETTING_ORDER = table.freeze({
	PresentationAccessibilityConfig.SettingIds.CameraShake,
	PresentationAccessibilityConfig.SettingIds.Blood,
})

local Controller = {}
local localPlayer = Players.LocalPlayer

local started = false
local screenGui: ScreenGui? = nil
local buttonConnections: { RBXScriptConnection } = {}
local disconnectStateListener: (() -> ())? = nil
local settingButtons: { [string]: TextButton } = {}

local function settingButtonText(settingId: string): string
	return string.format(
		"%s: %s",
		PresentationAccessibilityState.getDisplayName(settingId),
		PresentationAccessibilityState.getLevelDisplayName(settingId)
	)
end

local function refreshButton(settingId: string)
	local button = settingButtons[settingId]
	if button ~= nil then
		button.Text = settingButtonText(settingId)
	end
end

local function createSettingButton(parent: Instance, settingId: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Setting" .. tostring(order)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(34, 30, 32)
	button.BackgroundTransparency = 0.18
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(228, 220, 214)
	button.Text = settingButtonText(settingId)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button
	return button
end

function Controller.start()
	if started then
		return
	end
	started = true

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PresentationSettings"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	screenGui = gui

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.AnchorPoint = Vector2.new(0, 1)
	toggleButton.Position = UDim2.new(0, 12, 1, -12)
	toggleButton.Size = UDim2.fromOffset(44, 32)
	toggleButton.BackgroundColor3 = Color3.fromRGB(26, 23, 25)
	toggleButton.BackgroundTransparency = 0.24
	toggleButton.BorderSizePixel = 0
	toggleButton.AutoButtonColor = true
	toggleButton.Font = Enum.Font.GothamBlack
	toggleButton.TextSize = 14
	toggleButton.TextColor3 = Color3.fromRGB(214, 206, 200)
	toggleButton.Text = "FX"
	toggleButton.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 6)
	toggleCorner.Parent = toggleButton

	local settingsPanel = Instance.new("Frame")
	settingsPanel.Name = "Panel"
	settingsPanel.AnchorPoint = Vector2.new(0, 1)
	settingsPanel.Position = UDim2.new(0, 12, 1, -52)
	settingsPanel.Size = UDim2.fromOffset(228, 118)
	settingsPanel.BackgroundColor3 = Color3.fromRGB(16, 13, 15)
	settingsPanel.BackgroundTransparency = 0.08
	settingsPanel.BorderSizePixel = 0
	settingsPanel.Visible = false
	settingsPanel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = settingsPanel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = settingsPanel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = settingsPanel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(164, 156, 150)
	title.Text = "PRESENTATION COMFORT"
	title.Parent = settingsPanel

	for order, settingId in SETTING_ORDER do
		local button = createSettingButton(settingsPanel, settingId, order)
		settingButtons[settingId] = button
		table.insert(
			buttonConnections,
			button.Activated:Connect(function()
				PresentationAccessibilityState.cycle(settingId)
			end)
		)
	end

	table.insert(
		buttonConnections,
		toggleButton.Activated:Connect(function()
			settingsPanel.Visible = not settingsPanel.Visible
		end)
	)

	disconnectStateListener = PresentationAccessibilityState.onChanged(function(settingId, _levelId)
		refreshButton(settingId)
	end)

	gui.Parent = playerGui
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	for _, connection in buttonConnections do
		connection:Disconnect()
	end
	table.clear(buttonConnections)
	if disconnectStateListener ~= nil then
		disconnectStateListener()
		disconnectStateListener = nil
	end
	table.clear(settingButtons)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
end

return Controller
