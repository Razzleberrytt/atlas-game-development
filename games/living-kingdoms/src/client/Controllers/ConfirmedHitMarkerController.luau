--!strict

--[[
	HROI-0110 shooter-specific impact confirmation. This controller renders one
	fixed client-local marker at an accepted server-disclosed impact position.
	It never requests fire, chooses a target, spends ammunition, resolves a hit,
	applies damage, establishes death, awards progression, or creates loot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local ConfirmedHitMarkerConfig = require(ReplicatedStorage.Shared.Config.ConfirmedHitMarkerConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

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
local markerArms: { Frame } = {}
local impactWorldPosition: Vector3? = nil
local presentationStartedTimestamp = -math.huge
local confirmedChain = 0
local lastConfirmedServerTimestamp = -math.huge
local presentedShotIds: { [string]: boolean } = {}
local presentedShotOrder: { string } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
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
	label.Size = UDim2.fromOffset(210, 25)
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

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

local function markerColorForChain(chain: number): Color3
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
	local worldPosition = impactWorldPosition
	if root == nil or label == nil or center == nil or worldPosition == nil then
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
	local radius = ConfirmedHitMarkerConfig.MinimumRadiusPixels
		+ (ConfirmedHitMarkerConfig.MaximumRadiusPixels - ConfirmedHitMarkerConfig.MinimumRadiusPixels)
			* easedProgress
	local fadeProgress = math.clamp(
		(progress - ConfirmedHitMarkerConfig.FadeStartFraction) / (1 - ConfirmedHitMarkerConfig.FadeStartFraction),
		0,
		1
	)
	local color = markerColorForChain(confirmedChain)

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
	label.Text = if confirmedChain >= 2 then string.format("CONFIRMED  x%d", confirmedChain) else "HIT CONFIRMED"
	label.TextColor3 = color
	label.TextTransparency = fadeProgress
	label.TextStrokeTransparency = 0.18 + fadeProgress * 0.82
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	if
		payload.kindId ~= CombatContracts.PresentationMessageKindIds.ShotFired
		or not isNonEmptyString(payload.shotId)
		or not isLocalOperativeEntityId(payload.operativeEntityId)
		or payload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId
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
	table.clear(markerArms)
	impactWorldPosition = nil
	presentationStartedTimestamp = -math.huge
	confirmedChain = 0
	lastConfirmedServerTimestamp = -math.huge
	table.clear(presentedShotIds)
	table.clear(presentedShotOrder)
end

return table.freeze(Controller)
