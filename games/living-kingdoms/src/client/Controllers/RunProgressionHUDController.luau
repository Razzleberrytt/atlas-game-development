--!strict

--[[
	HROI-0105 read-only Field XP HUD. The controller renders only the server's
	monotonic progression snapshot and sends no reward, XP, kill, or level input.
	One read-only RemoteFunction call recovers initial state; later updates arrive
	through the server-to-client State event.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local lastRevision = -1
local lastGainSequence = 0
local gainExpiresAtServerTimestamp = 0

local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
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

local function createGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
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

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(131, 105, 54)
	stroke.Transparency = 0.18
	stroke.Thickness = 1.5
	stroke.Parent = container

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
	gain.Size = UDim2.fromOffset(350, 34)
	gain.TextColor3 = Color3.fromRGB(255, 207, 90)
	gain.TextTransparency = 1
	gain.TextStrokeTransparency = 1
	gain.Text = ""

	screenGui = gui
	levelLabel = level
	xpLabel = progressText
	barFill = fill
	gainLabel = gain
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
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
	if
		not isFiniteNumber(revision)
		or revision <= lastRevision
		or not isFiniteNumber(level)
		or not isFiniteNumber(xp)
		or not isFiniteNumber(xpForNextLevel)
		or not isFiniteNumber(gainAmount)
		or not isFiniteNumber(gainSequence)
		or not isFiniteNumber(levelsGained)
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

	if gainSequence > lastGainSequence and gainAmount > 0 then
		lastGainSequence = gainSequence
		local gain = gainLabel
		if gain ~= nil then
			gain.Text = if levelsGained > 0
				then string.format("LEVEL UP!  FIELD LEVEL %d", level)
				else string.format("+%d FIELD XP", gainAmount)
			gain.TextTransparency = 0
			gain.TextStrokeTransparency = 0.45
			gainExpiresAtServerTimestamp = Workspace:GetServerTimeNow() + RunProgressionConfig.GainDisplaySeconds
		end
	end
end

function RunProgressionHUDController.start()
	if started then
		return
	end
	started = true
	lastRevision = -1
	lastGainSequence = 0
	gainExpiresAtServerTimestamp = 0
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
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	levelLabel = nil
	xpLabel = nil
	barFill = nil
	gainLabel = nil
	lastRevision = -1
	lastGainSequence = 0
	gainExpiresAtServerTimestamp = 0
end

return table.freeze(RunProgressionHUDController)
