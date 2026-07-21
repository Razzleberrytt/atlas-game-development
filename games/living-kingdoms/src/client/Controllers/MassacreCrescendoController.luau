--!strict

--[[
	Client-only crescendo for the server-authored, non-rewarding horde streak.
	One existing horde-state disclosure connection and one frame connection drive
	a fixed UI, one fixed stinger Sound, and no per-kill Instances, tasks, tweens,
	or gameplay requests. The controller cannot establish kills, rewards, damage,
	cadence, ammunition, health, movement, or targeting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local MassacreCrescendoConfig = require(ReplicatedStorage.Shared.Config.MassacreCrescendoConfig)

local Controller = {}
local localPlayer = Players.LocalPlayer
local stateRemote = ReplicatedStorage:WaitForChild("HordeNetwork"):WaitForChild("State") :: RemoteEvent

local started = false
local stateConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local group: CanvasGroup? = nil
local flash: Frame? = nil
local titleLabel: TextLabel? = nil
local countLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local timeFill: Frame? = nil
local accentStroke: UIStroke? = nil
local presentationScale: UIScale? = nil
local stinger: Sound? = nil

local lastRevision = -1
local hasSnapshot = false
local currentStreak = 0
local currentTierIndex = 0
local streakExpiresServerTimestamp = 0
local visibleAlpha = 0
local lastPulseClock = -math.huge
local lastStingerClock = -math.huge

local function isBlockingChoiceVisible(): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hordeHud = if playerGui == nil then nil else playerGui:FindFirstChild("LivingKingdomsHordeHUD")
	local upgradeOverlay = if hordeHud == nil then nil else hordeHud:FindFirstChild("UpgradeOverlay")
	if upgradeOverlay ~= nil and upgradeOverlay:IsA("GuiObject") and upgradeOverlay.Visible then
		return true
	end
	local runBuildHud = if playerGui == nil then nil else playerGui:FindFirstChild("LK_RunBuildHUD")
	local relicReward = if runBuildHud == nil then nil else runBuildHud:FindFirstChild("RelicReward")
	return relicReward ~= nil and relicReward:IsA("GuiObject") and relicReward.Visible
end

local function colorFromTuple(tuple: { number }): Color3
	return Color3.fromRGB(tuple[1], tuple[2], tuple[3])
end

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = ""
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.08
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LivingKingdomsMassacreCrescendo"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 54
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local createdFlash = Instance.new("Frame")
	createdFlash.Name = "TierFlash"
	createdFlash.Size = UDim2.fromScale(1, 1)
	createdFlash.BackgroundColor3 = Color3.new(1, 1, 1)
	createdFlash.BackgroundTransparency = 1
	createdFlash.BorderSizePixel = 0
	createdFlash.ZIndex = 1
	createdFlash.Parent = gui
	flash = createdFlash

	local createdGroup = Instance.new("CanvasGroup")
	createdGroup.Name = "Crescendo"
	createdGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	createdGroup.Position = UDim2.fromScale(0.5, 0.7)
	createdGroup.Size = UDim2.fromOffset(610, 116)
	createdGroup.BackgroundColor3 = Color3.fromRGB(13, 8, 11)
	createdGroup.BackgroundTransparency = 0.18
	createdGroup.BorderSizePixel = 0
	createdGroup.GroupTransparency = 1
	createdGroup.Visible = false
	createdGroup.ZIndex = 2
	createdGroup.Parent = gui
	group = createdGroup

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = createdGroup

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.12
	stroke.Parent = createdGroup
	accentStroke = stroke

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0.42),
	})
	gradient.Parent = createdGroup

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = createdGroup
	presentationScale = scale

	titleLabel = makeLabel(createdGroup, "TierTitle", UDim2.fromOffset(16, 5), UDim2.new(1, -32, 0, 47), 34)
	countLabel = makeLabel(createdGroup, "ChainCount", UDim2.fromOffset(18, 48), UDim2.fromOffset(126, 32), 24)
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel = makeLabel(createdGroup, "TierSubtitle", UDim2.fromOffset(138, 50), UDim2.new(1, -156, 0, 28), 15)
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Right

	local timeTrack = Instance.new("Frame")
	timeTrack.Name = "StreakWindow"
	timeTrack.Position = UDim2.fromOffset(18, 88)
	timeTrack.Size = UDim2.new(1, -36, 0, 10)
	timeTrack.BackgroundColor3 = Color3.fromRGB(38, 31, 36)
	timeTrack.BorderSizePixel = 0
	timeTrack.ClipsDescendants = true
	timeTrack.Parent = createdGroup
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = timeTrack

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = timeTrack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	timeFill = fill

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	local sound = Instance.new("Sound")
	sound.Name = "LivingKingdomsMassacreTierStinger"
	sound.SoundId = MassacreCrescendoConfig.StingerSoundId
	sound.Volume = 0
	sound.Parent = SoundService
	stinger = sound
end

local function readFiniteNumber(value: unknown, fallback: number): number
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else fallback
end

local function playTierStinger(tier: MassacreCrescendoConfig.TierDefinition)
	local sound = stinger
	if sound == nil then
		return
	end
	local nowClock = os.clock()
	if nowClock - lastStingerClock < MassacreCrescendoConfig.StingerMinimumIntervalSeconds then
		return
	end
	lastStingerClock = nowClock
	sound.Volume = tier.StingerVolume
	sound.PlaybackSpeed = tier.StingerPlaybackSpeed
	sound.TimePosition = 0
	sound:Play()
end

local function applyState(payload: any)
	local revision = readFiniteNumber(payload.revision, -1)
	if revision <= lastRevision then
		return
	end
	lastRevision = revision

	local streak =
		math.floor(math.clamp(readFiniteNumber(payload.streak, 0), 0, MassacreCrescendoConfig.MaximumPresentedStreak))
	local expiresAt = math.max(0, readFiniteNumber(payload.streakExpiresServerTimestamp, 0))
	local tier, tierIndex = MassacreCrescendoConfig.tierForStreak(streak)

	if hasSnapshot and streak > currentStreak and tier ~= nil then
		lastPulseClock = os.clock()
		if tierIndex > currentTierIndex then
			playTierStinger(tier)
		end
	end

	currentStreak = streak
	currentTierIndex = tierIndex
	streakExpiresServerTimestamp = expiresAt
	hasSnapshot = true
end

local function onState(message: unknown)
	if type(message) == "table" then
		applyState(message :: any)
	end
end

local function updatePresentation(deltaTime: number)
	local createdGroup = group
	local createdFlash = flash
	local createdTitle = titleLabel
	local createdCount = countLabel
	local createdSubtitle = subtitleLabel
	local createdFill = timeFill
	local createdStroke = accentStroke
	local createdScale = presentationScale
	if
		createdGroup == nil
		or createdFlash == nil
		or createdTitle == nil
		or createdCount == nil
		or createdSubtitle == nil
		or createdFill == nil
		or createdStroke == nil
		or createdScale == nil
	then
		return
	end

	local serverTimestamp = Workspace:GetServerTimeNow()
	local tier = MassacreCrescendoConfig.tierForStreak(currentStreak)
	local remainingFraction =
		math.clamp((streakExpiresServerTimestamp - serverTimestamp) / MassacreCrescendoConfig.StreakWindowSeconds, 0, 1)
	-- A progression choice needs an unobstructed reading and input surface. The
	-- crescendo remains time-correct while hidden and can resume if its streak
	-- window is still active after the choice closes.
	local shouldShow = tier ~= nil and remainingFraction > 0 and not isBlockingChoiceVisible()
	local alphaStep = deltaTime / MassacreCrescendoConfig.FadeDurationSeconds
	visibleAlpha = math.clamp(visibleAlpha + (if shouldShow then alphaStep else -alphaStep), 0, 1)
	createdGroup.Visible = visibleAlpha > 0.001
	createdGroup.GroupTransparency = 1 - visibleAlpha

	if tier == nil then
		createdFlash.BackgroundTransparency = 1
		return
	end

	local color = colorFromTuple(tier.Color)
	createdTitle.Text = tier.Title
	createdTitle.TextColor3 = color
	createdCount.Text = string.format("CHAIN x%d", currentStreak)
	createdCount.TextColor3 = color
	createdSubtitle.Text = tier.Subtitle
	createdSubtitle.TextColor3 = Color3.fromRGB(241, 231, 224)
	createdFill.BackgroundColor3 = color
	createdFill.Size = UDim2.fromScale(remainingFraction, 1)
	createdStroke.Color = color

	local pulseFraction =
		math.clamp(1 - (os.clock() - lastPulseClock) / MassacreCrescendoConfig.PulseDurationSeconds, 0, 1)
	local pulse = pulseFraction * pulseFraction
	local breathing = if shouldShow then math.sin(os.clock() * 8) * 0.012 * remainingFraction else 0
	createdScale.Scale = 1 + (tier.PulseScale - 1) * pulse + breathing
	createdFlash.BackgroundColor3 = color
	createdFlash.BackgroundTransparency = 1 - tier.FlashStrength * pulse * visibleAlpha
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	stateConnection = stateRemote.OnClientEvent:Connect(onState)
	renderConnection = RunService.RenderStepped:Connect(updatePresentation)
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
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	if stinger ~= nil then
		stinger:Destroy()
		stinger = nil
	end
	group = nil
	flash = nil
	titleLabel = nil
	countLabel = nil
	subtitleLabel = nil
	timeFill = nil
	accentStroke = nil
	presentationScale = nil
	lastRevision = -1
	hasSnapshot = false
	currentStreak = 0
	currentTierIndex = 0
	streakExpiresServerTimestamp = 0
	visibleAlpha = 0
	lastPulseClock = -math.huge
	lastStingerClock = -math.huge
end

return table.freeze(Controller)
