--!strict

--[[
	HROI-0109 client-local low-health urgency. This controller reads only the
	server-replicated P3 life attributes already used by the unified HUD and adds
	a bounded pulsing screen-edge warning. It cannot establish health, life state,
	damage, incapacitation, death, or recovery.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CriticalConditionConfig = require(ReplicatedStorage.Shared.Config.CriticalConditionConfig)

local Controller = {}
local localPlayer = Players.LocalPlayer

local started = false
local renderConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local warningLabel: TextLabel? = nil
local edgeFrames: { Frame } = {}

local function readNumberAttribute(name: string, fallback: number): number
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" and value == value then value else fallback
end

local function readStringAttribute(name: string, fallback: string): string
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "string" then value else fallback
end

local function createEdge(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	anchorPoint: Vector2,
	gradientRotation: number
): Frame
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.AnchorPoint = anchorPoint
	edge.Position = position
	edge.Size = size
	edge.BackgroundColor3 = Color3.fromRGB(196, 18, 24)
	edge.BackgroundTransparency = 1
	edge.BorderSizePixel = 0
	edge.ZIndex = 1
	edge.Parent = parent

	local gradient = Instance.new("UIGradient")
	gradient.Name = "Fade"
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 36, 40), Color3.fromRGB(112, 0, 8))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.58, 0.36),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = gradientRotation
	gradient.Parent = edge

	table.insert(edgeFrames, edge)
	return edge
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LivingKingdomsCriticalCondition"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 49
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local thickness = CriticalConditionConfig.EdgeThicknessPixels
	createEdge(gui, "TopEdge", UDim2.fromScale(0.5, 0), UDim2.new(1, 0, 0, thickness), Vector2.new(0.5, 0), 90)
	createEdge(gui, "BottomEdge", UDim2.fromScale(0.5, 1), UDim2.new(1, 0, 0, thickness), Vector2.new(0.5, 1), 270)
	createEdge(gui, "LeftEdge", UDim2.fromScale(0, 0.5), UDim2.new(0, thickness, 1, 0), Vector2.new(0, 0.5), 0)
	createEdge(gui, "RightEdge", UDim2.fromScale(1, 0.5), UDim2.new(0, thickness, 1, 0), Vector2.new(1, 0.5), 180)

	local warning = Instance.new("TextLabel")
	warning.Name = "CriticalWarning"
	warning.AnchorPoint = Vector2.new(0.5, 0.5)
	warning.Position = UDim2.fromScale(0.5, 0.64)
	warning.Size = UDim2.fromOffset(620, 42)
	warning.BackgroundTransparency = 1
	warning.BorderSizePixel = 0
	warning.Font = Enum.Font.GothamBlack
	warning.Text = ""
	warning.TextColor3 = Color3.fromRGB(255, 74, 64)
	warning.TextSize = 23
	warning.TextStrokeColor3 = Color3.fromRGB(25, 0, 2)
	warning.TextStrokeTransparency = 0.18
	warning.TextTransparency = 1
	warning.TextXAlignment = Enum.TextXAlignment.Center
	warning.TextYAlignment = Enum.TextYAlignment.Center
	warning.Visible = false
	warning.ZIndex = 2
	warning.Parent = gui
	warningLabel = warning

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

local function hidePresentation()
	for _, edge in edgeFrames do
		edge.BackgroundTransparency = 1
	end
	local warning = warningLabel
	if warning ~= nil then
		warning.Visible = false
		warning.TextTransparency = 1
	end
end

local function updateFrame()
	local maximumHealth = math.max(1, readNumberAttribute("LK_P3_MaximumHealth", 100))
	local currentHealth = math.clamp(readNumberAttribute("LK_P3_CurrentHealth", maximumHealth), 0, maximumHealth)
	local lifeState = readStringAttribute("LK_P3_LifeState", "REGISTERING")
	local healthFraction = currentHealth / maximumHealth
	if
		lifeState ~= "Alive"
		or healthFraction <= 0
		or healthFraction > CriticalConditionConfig.CriticalHealthFraction
	then
		hidePresentation()
		return
	end

	local severity = math.clamp(
		(CriticalConditionConfig.CriticalHealthFraction - healthFraction)
			/ CriticalConditionConfig.CriticalHealthFraction,
		0,
		1
	)
	local isMortal = healthFraction <= CriticalConditionConfig.MortalHealthFraction
	local pulseSpeed = CriticalConditionConfig.PulseRadiansPerSecond
		* (if isMortal then CriticalConditionConfig.MortalPulseSpeedMultiplier else 1)
	local pulse = (math.sin(Workspace:GetServerTimeNow() * pulseSpeed) + 1) * 0.5
	local baseTransparency = CriticalConditionConfig.EdgeMaximumTransparency
		+ (CriticalConditionConfig.EdgeMinimumTransparency - CriticalConditionConfig.EdgeMaximumTransparency)
			* severity
	local edgeTransparency =
		math.clamp(baseTransparency - pulse * CriticalConditionConfig.PulseTransparencyAmplitude, 0.05, 0.85)
	local edgeColor = if isMortal then Color3.fromRGB(255, 18, 26) else Color3.fromRGB(196, 18, 24)
	for _, edge in edgeFrames do
		edge.BackgroundColor3 = edgeColor
		edge.BackgroundTransparency = edgeTransparency
	end

	local warning = warningLabel
	if warning ~= nil then
		warning.Visible = true
		warning.Text = string.format(
			if isMortal then "MORTAL CONDITION  //  %d%% HEALTH" else "CRITICAL CONDITION  //  %d%% HEALTH",
			math.floor(healthFraction * 100 + 0.5)
		)
		warning.TextColor3 = if isMortal then Color3.fromRGB(255, 44, 39) else Color3.fromRGB(255, 94, 71)
		warning.TextTransparency = CriticalConditionConfig.WarningMaximumTransparency
			+ (
					CriticalConditionConfig.WarningMinimumTransparency
					- CriticalConditionConfig.WarningMaximumTransparency
				)
				* pulse
		warning.TextStrokeTransparency = 0.12 + (1 - pulse) * 0.18
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	renderConnection = RunService.RenderStepped:Connect(updateFrame)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	warningLabel = nil
	table.clear(edgeFrames)
end

return table.freeze(Controller)
