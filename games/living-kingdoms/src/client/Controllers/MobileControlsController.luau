--!strict

--[[
	On-screen touch controls for mobile play.

	The operative moves via camera-relative WASD, which a phone has no keys for, so
	this owns a left-side virtual thumbstick that produces the same analog movement
	vector the keyboard produces and pushes it into SurvivorController's single
	analog channel. It also owns a reload button that calls WeaponController's one
	reload path, since reload was keyboard-only.

	It establishes no gameplay authority: it feeds the exact client intents the
	desktop input already feeds — movement direction and a reload request — both of
	which the server still validates. It activates only on a touch device without a
	keyboard, so desktop input is untouched, and it draws from the shared
	InterfaceTheme so it matches every other surface.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)
local SurvivorController = require(script.Parent.SurvivorController)
local WeaponController = require(script.Parent.WeaponController)

local MobileControlsController = {}

local GUI_NAME = "LK_MobileControls"
local STICK_RADIUS = 84
local STICK_BASE_SIZE = 190
local STICK_KNOB_SIZE = 84

local started = false
local screenGui: ScreenGui? = nil
local stickBase: Frame? = nil
local stickKnob: Frame? = nil
local activeStickInput: InputObject? = nil
local connections: { RBXScriptConnection } = {}

local function isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- A circular frame, via a corner radius of half its size.
local function circle(parent: Instance, name: string, size: number, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(size, size)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = parent
	InterfaceTheme.corner(frame, size // 2)
	return frame
end

local function releaseStick()
	activeStickInput = nil
	SurvivorController.setAnalogMovement(Vector2.zero)
	local base = stickBase
	local knob = stickKnob
	if base ~= nil then
		base.Visible = false
	end
	if knob ~= nil then
		knob.Visible = false
	end
end

-- Places the knob relative to the base centre, clamped to the stick radius, and
-- pushes the resulting analog vector. Screen Y is down, forward is up, so the Y
-- axis is negated to match the WASD convention (W = forward = +Y).
local function updateStick(screenX: number, screenY: number, baseX: number, baseY: number)
	local knob = stickKnob
	if knob == nil then
		return
	end
	local deltaX = screenX - baseX
	local deltaY = screenY - baseY
	local magnitude = math.sqrt(deltaX * deltaX + deltaY * deltaY)
	if magnitude > STICK_RADIUS then
		deltaX = deltaX / magnitude * STICK_RADIUS
		deltaY = deltaY / magnitude * STICK_RADIUS
	end
	knob.Position = UDim2.fromOffset(baseX + deltaX, baseY + deltaY)
	SurvivorController.setAnalogMovement(Vector2.new(deltaX / STICK_RADIUS, -deltaY / STICK_RADIUS))
end

local function beginStick(input: InputObject)
	if activeStickInput ~= nil then
		return
	end
	local base = stickBase
	local knob = stickKnob
	if base == nil or knob == nil then
		return
	end
	activeStickInput = input
	-- Dynamic thumbstick: the base appears where the thumb lands.
	local x, y = input.Position.X, input.Position.Y
	base.Position = UDim2.fromOffset(x, y)
	base.Visible = true
	knob.Position = UDim2.fromOffset(x, y)
	knob.Visible = true
	SurvivorController.setAnalogMovement(Vector2.zero)
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
	gui.DisplayOrder = 5
	gui.Parent = playerGui
	screenGui = gui

	-- The movement zone: the lower-left of the screen, transparent, so a thumb
	-- landing there drives the stick without covering the HUD (centre and right).
	local zone = Instance.new("TextButton")
	zone.Name = "MovementZone"
	zone.AnchorPoint = Vector2.new(0, 1)
	zone.Position = UDim2.fromScale(0, 1)
	zone.Size = UDim2.fromScale(0.45, 0.6)
	zone.BackgroundTransparency = 1
	zone.Text = ""
	zone.AutoButtonColor = false
	zone.Modal = false
	zone.Parent = gui

	stickBase = circle(gui, "StickBase", STICK_BASE_SIZE, InterfaceTheme.Palette.Panel, 0.55)
	InterfaceTheme.stroke(stickBase :: Frame, InterfaceTheme.Palette.Line, 0.4, InterfaceTheme.Stroke.Bold)
	stickKnob = circle(gui, "StickKnob", STICK_KNOB_SIZE, InterfaceTheme.Palette.Accent, 0.3)

	-- Reload button: lower-right, clear of the movement zone.
	local reload = Instance.new("TextButton")
	reload.Name = "ReloadButton"
	reload.AnchorPoint = Vector2.new(1, 1)
	reload.Position = UDim2.new(1, -28, 1, -28)
	reload.Size = UDim2.fromOffset(150, 84)
	reload.BackgroundColor3 = InterfaceTheme.Palette.PanelRaised
	reload.BackgroundTransparency = 0.1
	reload.BorderSizePixel = 0
	reload.Font = InterfaceTheme.Font.Heading
	reload.TextSize = InterfaceTheme.TextSize.Subtitle
	reload.TextColor3 = InterfaceTheme.Palette.Accent
	reload.Text = "RELOAD"
	reload.Parent = gui
	InterfaceTheme.corner(reload, InterfaceTheme.Radius.Control)
	InterfaceTheme.stroke(reload, InterfaceTheme.Palette.AccentDim, 0.35, InterfaceTheme.Stroke.Bold)

	table.insert(
		connections,
		zone.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				beginStick(input)
			end
		end)
	)
	table.insert(
		connections,
		reload.Activated:Connect(function()
			WeaponController.requestReload()
		end)
	)
end

function MobileControlsController.start()
	if started or not isTouchDevice() then
		return
	end
	started = true
	createGui()

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if input == activeStickInput then
				local base = stickBase
				if base ~= nil then
					updateStick(input.Position.X, input.Position.Y, base.Position.X.Offset, base.Position.Y.Offset)
				end
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input == activeStickInput then
				releaseStick()
			end
		end)
	)
end

function MobileControlsController.stop()
	if not started then
		return
	end
	started = false
	releaseStick()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	stickBase = nil
	stickKnob = nil
	activeStickInput = nil
end

return table.freeze(MobileControlsController)
