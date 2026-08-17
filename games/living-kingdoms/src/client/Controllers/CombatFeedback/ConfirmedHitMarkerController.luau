--!strict

--[[
	HROI-0110 shooter-specific impact confirmation. This controller renders one
	fixed client-local marker at an accepted server-disclosed impact position.
	It never requests fire, chooses a target, spends ammunition, resolves a hit,
	applies damage, establishes death, awards progression, or creates loot.
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

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local ConfirmedHitMarkerConfig = require(ReplicatedStorage.Shared.Config.ConfirmedHitMarkerConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local WeaponPatternConfig = require(ReplicatedStorage.Shared.Config.WeaponPatternConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end

local function isKnownWeaponId(weaponId: unknown): boolean
	return resolveWeaponDefinition(weaponId) ~= nil
end

local Controller = {}
local localPlayer = Players.LocalPlayer

local ARM_DEFINITIONS = table.freeze({
	table.freeze({ direction = Vector2.new(-1, -1), rotation = 45 }),
	table.freeze({ direction = Vector2.new(1, -1), rotation = -45 }),
	table.freeze({ direction = Vector2.new(-1, 1), rotation = -45 }),
	table.freeze({ direction = Vector2.new(1, 1), rotation = 45 }),
})
assert(#ARM_DEFINITIONS == 4, "confirmed hit marker must retain exactly four fixed arms")

local started = false
local connections: { RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local markerRoot: Frame? = nil
local markerLabel: TextLabel? = nil
local markerCenter: Frame? = nil
local markerScale: UIScale? = nil
local markerArms: { Frame } = {}
local impactWorldPosition: Vector3? = nil
local presentationStartedTimestamp = -math.huge
local confirmedChain = 0
local patternModeId: string? = nil
local patternHitCount = 1
local lastConfirmedServerTimestamp = -math.huge
local presentedShotIds: { [string]: boolean } = {}
local presentedShotOrder: { string } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)
assert(combatNetwork ~= nil, "CombatNetwork did not become available before the client bootstrap timeout")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS)
assert(
	presentationRemote ~= nil,
	"CombatNetwork.CombatPresentation did not become available before the client bootstrap timeout"
)

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isWholePositive(value: unknown): boolean
	return isFiniteNumber(value) and value > 0 and value % 1 == 0
end

local function colorFromTuple(tuple: { number }): Color3
	return Color3.fromRGB(tuple[1], tuple[2], tuple[3])
end

local function readSecondaryImpactCount(value: unknown, maximumSecondaryTargets: number): number?
	if value == nil then
		return 0
	end
	if type(value) ~= "table" then
		return nil
	end
	local impacts = value :: { any }
	local maximumAccepted = math.min(maximumSecondaryTargets, ConfirmedHitMarkerConfig.MaximumSecondaryImpacts)
	if #impacts > maximumAccepted then
		return nil
	end
	for _, impact in impacts do
		if
			type(impact) ~= "table"
			or not isNonEmptyString(impact.targetEntityId)
			or typeof(impact.impactWorldPosition) ~= "Vector3"
			or not isWholePositive(impact.damageAmount)
		then
			return nil
		end
	end
	return #impacts
end

local function isLocalOperativeEntityId(value: unknown): boolean
	return value == "operative.player:" .. tostring(localPlayer.UserId)
end

local function rememberShot(shotId: string): boolean
	if presentedShotIds[shotId] then
		return false
	end
	presentedShotIds[shotId] = true
	table.insert(presentedShotOrder, shotId)
	if #presentedShotOrder > ConfirmedHitMarkerConfig.MaximumRememberedShotIds then
		local expiredShotId = table.remove(presentedShotOrder, 1)
		if expiredShotId ~= nil then
			presentedShotIds[expiredShotId] = nil
		end
	end
	return true
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LivingKingdomsConfirmedHitMarker"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = ConfirmedHitMarkerConfig.DisplayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.Name = "ConfirmedImpact"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(96, 96)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = false
	root.ZIndex = 20
	root.Parent = gui
	markerRoot = root

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = root
	markerScale = scale

	for index, armDefinition in ARM_DEFINITIONS do
		local arm = Instance.new("Frame")
		arm.Name = "Arm" .. tostring(index)
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Size =
			UDim2.fromOffset(ConfirmedHitMarkerConfig.ArmLengthPixels, ConfirmedHitMarkerConfig.ArmThicknessPixels)
		arm.BackgroundColor3 = Color3.fromRGB(244, 238, 216)
		arm.BackgroundTransparency = 1
		arm.BorderSizePixel = 0
		arm.Rotation = armDefinition.rotation
		arm.ZIndex = 21
		arm.Parent = root
		table.insert(markerArms, arm)
	end

	local center = Instance.new("Frame")
	center.Name = "Center"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromOffset(48, 48)
	center.Size = UDim2.fromOffset(4, 4)
	center.BackgroundColor3 = Color3.fromRGB(255, 224, 139)
	center.BackgroundTransparency = 0.16
	center.BorderSizePixel = 0
	center.ZIndex = 21
	center.Parent = root
	markerCenter = center

	local label = Instance.new("TextLabel")
	label.Name = "Confirmation"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 1)
	label.Size = UDim2.fromOffset(290, 25)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 224, 139)
	label.TextSize = 14
	label.TextStrokeColor3 = Color3.fromRGB(18, 8, 6)
	label.TextStrokeTransparency = 0.18
	label.TextTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 22
	label.Parent = root
	markerLabel = label

	local playerGui = localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	gui.Parent = playerGui
	screenGui = gui
end

local function markerColorForPresentation(chain: number, modeId: string?): Color3
	local patternPresentation = ConfirmedHitMarkerConfig.getPatternPresentation(modeId)
	if patternPresentation ~= nil then
		return colorFromTuple(patternPresentation.Color)
	end
	if chain >= ConfirmedHitMarkerConfig.BrutalChainThreshold then
		return Color3.fromRGB(255, 70, 52)
	end
	if chain >= ConfirmedHitMarkerConfig.HotChainThreshold then
		return Color3.fromRGB(255, 166, 62)
	end
	return Color3.fromRGB(244, 238, 216)
end

local function hidePresentation()
	local root = markerRoot
	if root ~= nil then
		root.Visible = false
	end
end

local function updateFrame()
	local root = markerRoot
	local label = markerLabel
	local center = markerCenter
	local scale = markerScale
	local worldPosition = impactWorldPosition
	if root == nil or label == nil or center == nil or scale == nil or worldPosition == nil then
		hidePresentation()
		return
	end

	local nowTimestamp = Workspace:GetServerTimeNow()
	local elapsed = nowTimestamp - presentationStartedTimestamp
	local duration = ConfirmedHitMarkerConfig.MarkerDurationSeconds
	if elapsed < 0 or elapsed > duration then
		impactWorldPosition = nil
		hidePresentation()
		return
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		hidePresentation()
		return
	end
	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
	if not onScreen or viewportPoint.Z <= 0 then
		hidePresentation()
		return
	end

	local progress = math.clamp(elapsed / duration, 0, 1)
	local easedProgress = 1 - (1 - progress) * (1 - progress)
	local patternPresentation = ConfirmedHitMarkerConfig.getPatternPresentation(patternModeId)
	local radiusBonus = if patternPresentation ~= nil then ConfirmedHitMarkerConfig.PatternRadiusBonusPixels else 0
	local radius = ConfirmedHitMarkerConfig.MinimumRadiusPixels
		+ radiusBonus
		+ (ConfirmedHitMarkerConfig.MaximumRadiusPixels - ConfirmedHitMarkerConfig.MinimumRadiusPixels)
			* easedProgress
	local fadeProgress = math.clamp(
		(progress - ConfirmedHitMarkerConfig.FadeStartFraction) / (1 - ConfirmedHitMarkerConfig.FadeStartFraction),
		0,
		1
	)
	local color = markerColorForPresentation(confirmedChain, patternModeId)

	root.Position = UDim2.fromOffset(viewportPoint.X, viewportPoint.Y)
	root.Visible = true
	for index, arm in markerArms do
		local definition = ARM_DEFINITIONS[index]
		arm.Position = UDim2.fromOffset(48 + definition.direction.X * radius, 48 + definition.direction.Y * radius)
		arm.BackgroundColor3 = color
		arm.BackgroundTransparency = 0.08 + fadeProgress * 0.92
	end
	center.BackgroundColor3 = color
	center.BackgroundTransparency = 0.16 + fadeProgress * 0.84
	label.Text = if patternPresentation ~= nil
		then string.format("%s  x%d", patternPresentation.Title, patternHitCount)
		elseif confirmedChain >= 2 then string.format("CONFIRMED  x%d", confirmedChain)
		else "HIT CONFIRMED"
	label.TextColor3 = color
	local patternPulse = if patternPresentation ~= nil then (1 - progress) * (1 - progress) else 0
	scale.Scale = 1 + (ConfirmedHitMarkerConfig.PatternPulseScale - 1) * patternPulse
	label.TextTransparency = fadeProgress
	label.TextStrokeTransparency = 0.18 + fadeProgress * 0.82
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	local patternDefinition = WeaponPatternConfig.get(payload.weaponId)
	if patternDefinition == nil then
		return
	end
	local secondaryImpactCount =
		readSecondaryImpactCount(payload.secondaryImpacts, patternDefinition.MaximumSecondaryTargets)
	if secondaryImpactCount == nil then
		return
	end
	if
		payload.kindId ~= CombatContracts.PresentationMessageKindIds.ShotFired
		or not isNonEmptyString(payload.shotId)
		or not isLocalOperativeEntityId(payload.operativeEntityId)
		or not isKnownWeaponId(payload.weaponId)
		or not isNonEmptyString(payload.targetEntityId)
		or payload.didApplyDamage ~= true
		or typeof(payload.impactWorldPosition) ~= "Vector3"
		or not isFiniteNumber(payload.serverTimestamp)
		or not rememberShot(payload.shotId)
	then
		return
	end

	local chainDelta = payload.serverTimestamp - lastConfirmedServerTimestamp
	if chainDelta >= 0 and chainDelta <= ConfirmedHitMarkerConfig.ChainWindowSeconds then
		confirmedChain = math.min(99, confirmedChain + 1)
	else
		confirmedChain = 1
	end
	lastConfirmedServerTimestamp = payload.serverTimestamp
	impactWorldPosition = payload.impactWorldPosition
	patternModeId = if secondaryImpactCount > 0
			and patternDefinition.ModeId ~= WeaponPatternConfig.ModeIds.SingleTarget
		then patternDefinition.ModeId
		else nil
	patternHitCount = 1 + secondaryImpactCount
	presentationStartedTimestamp = Workspace:GetServerTimeNow()
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	table.insert(connections, presentationRemote.OnClientEvent:Connect(onPresentationMessage))
	table.insert(connections, RunService.RenderStepped:Connect(updateFrame))
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	markerRoot = nil
	markerLabel = nil
	markerCenter = nil
	markerScale = nil
	table.clear(markerArms)
	impactWorldPosition = nil
	presentationStartedTimestamp = -math.huge
	confirmedChain = 0
	patternModeId = nil
	patternHitCount = 1
	lastConfirmedServerTimestamp = -math.huge
	table.clear(presentedShotIds)
	table.clear(presentedShotOrder)
end

return table.freeze(Controller)
