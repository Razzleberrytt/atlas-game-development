--!strict

--[[
	HROI-0111 shooter-specific floating combat text. Every number comes from an
	accepted server-disclosed ShotFired message and the exact authoritative
	damage event. This controller cannot request fire, resolve hits, apply damage,
	change health, establish death, award progression, or create loot.
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
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

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
local FloatingDamageTextConfig = require(ReplicatedStorage.Shared.Config.FloatingDamageTextConfig)

local Controller = {}
local localPlayer = Players.LocalPlayer

local MAXIMUM_DISPLAYED_DAMAGE = 9999
local SETTLE_FRACTION = 0.18

type FloatingEntry = {
	label: TextLabel,
	scale: UIScale,
	active: boolean,
	worldPosition: Vector3,
	startedTimestamp: number,
	lateralOffsetPixels: number,
	verticalOffsetPixels: number,
}

local started = false
local connections: { RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local entries: { FloatingEntry } = {}
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

local function isWholePositiveDamage(value: unknown): boolean
	return isFiniteNumber(value) and value > 0 and value <= MAXIMUM_DISPLAYED_DAMAGE and value % 1 == 0
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
	if #presentedShotOrder > FloatingDamageTextConfig.MaximumRememberedShotIds then
		local expiredShotId = table.remove(presentedShotOrder, 1)
		if expiredShotId ~= nil then
			presentedShotIds[expiredShotId] = nil
		end
	end
	return true
end

local function stableShotHash(shotId: string): number
	local hash = 0
	for index = 1, #shotId do
		hash = (hash + string.byte(shotId, index) * index) % 104729
	end
	return hash
end

local function damageColor(damageAmount: number, weaponId: string): Color3
	local configuredDamage = (resolveWeaponDefinition(weaponId) or FirearmConfig.BasicFirearm).DamagePerHit
	if damageAmount >= configuredDamage * FloatingDamageTextConfig.BrutalDamageMultiplier then
		return Color3.fromRGB(255, 74, 54)
	end
	if damageAmount >= configuredDamage * FloatingDamageTextConfig.HotDamageMultiplier then
		return Color3.fromRGB(255, 174, 66)
	end
	return Color3.fromRGB(255, 235, 177)
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LivingKingdomsFloatingDamageText"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = FloatingDamageTextConfig.DisplayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	for index = 1, FloatingDamageTextConfig.MaximumActiveEntries do
		local label = Instance.new("TextLabel")
		label.Name = "Damage" .. tostring(index)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(128, 48)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBlack
		label.Text = ""
		label.TextColor3 = Color3.fromRGB(255, 235, 177)
		label.TextSize = FloatingDamageTextConfig.BaseTextSize
		label.TextStrokeColor3 = Color3.fromRGB(16, 7, 5)
		label.TextStrokeTransparency = 0.08
		label.TextTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Visible = false
		label.ZIndex = 30
		label.Parent = gui

		local scale = Instance.new("UIScale")
		scale.Name = "ImpactScale"
		scale.Scale = FloatingDamageTextConfig.ImpactScale
		scale.Parent = label

		table.insert(entries, {
			label = label,
			scale = scale,
			active = false,
			worldPosition = Vector3.zero,
			startedTimestamp = -math.huge,
			lateralOffsetPixels = 0,
			verticalOffsetPixels = 0,
		})
	end

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

local function deactivateEntry(entry: FloatingEntry)
	entry.active = false
	entry.label.Visible = false
	entry.label.Text = ""
	entry.label.TextTransparency = 1
	entry.label.TextStrokeTransparency = 1
end

local function selectEntry(): FloatingEntry?
	local oldestEntry: FloatingEntry? = nil
	for _, entry in entries do
		if not entry.active then
			return entry
		end
		if oldestEntry == nil or entry.startedTimestamp < oldestEntry.startedTimestamp then
			oldestEntry = entry
		end
	end
	return oldestEntry
end

local function activateEntry(shotId: string, weaponId: string, damageAmount: number, worldPosition: Vector3)
	local entry = selectEntry()
	if entry == nil then
		return
	end
	local hash = stableShotHash(shotId)
	local lateralFactor = (hash % 2001) / 1000 - 1
	local verticalBand = math.floor(hash / 2001) % 5

	entry.active = true
	entry.worldPosition = worldPosition
	entry.startedTimestamp = Workspace:GetServerTimeNow()
	entry.lateralOffsetPixels = lateralFactor * FloatingDamageTextConfig.MaximumLateralDriftPixels
	entry.verticalOffsetPixels = verticalBand * 3
	entry.label.Text = tostring(damageAmount)
	entry.label.TextColor3 = damageColor(damageAmount, weaponId)
	entry.label.TextTransparency = 0
	entry.label.TextStrokeTransparency = 0.08
	entry.label.Rotation = lateralFactor * 4
	entry.label.Visible = true
	entry.scale.Scale = FloatingDamageTextConfig.ImpactScale
end

local function updateEntry(entry: FloatingEntry, camera: Camera, nowTimestamp: number)
	local elapsed = nowTimestamp - entry.startedTimestamp
	local duration = FloatingDamageTextConfig.DurationSeconds
	if elapsed < 0 or elapsed > duration then
		deactivateEntry(entry)
		return
	end

	local viewportPoint, onScreen = camera:WorldToViewportPoint(entry.worldPosition)
	if not onScreen or viewportPoint.Z <= 0 then
		entry.label.Visible = false
		return
	end

	local progress = math.clamp(elapsed / duration, 0, 1)
	local easedProgress = 1 - (1 - progress) * (1 - progress) * (1 - progress)
	local fadeProgress = math.clamp(
		(progress - FloatingDamageTextConfig.FadeStartFraction) / (1 - FloatingDamageTextConfig.FadeStartFraction),
		0,
		1
	)
	local scaleValue: number
	if progress <= SETTLE_FRACTION then
		local settleProgress = progress / SETTLE_FRACTION
		local easedSettle = 1 - (1 - settleProgress) * (1 - settleProgress)
		scaleValue = FloatingDamageTextConfig.ImpactScale
			+ (FloatingDamageTextConfig.SettledScale - FloatingDamageTextConfig.ImpactScale) * easedSettle
	else
		local tailProgress = (progress - SETTLE_FRACTION) / (1 - SETTLE_FRACTION)
		scaleValue = FloatingDamageTextConfig.SettledScale
			+ (FloatingDamageTextConfig.EndScale - FloatingDamageTextConfig.SettledScale) * tailProgress
	end

	entry.label.Position = UDim2.fromOffset(
		viewportPoint.X + entry.lateralOffsetPixels * easedProgress,
		viewportPoint.Y - entry.verticalOffsetPixels - FloatingDamageTextConfig.RisePixels * easedProgress
	)
	entry.label.TextTransparency = fadeProgress
	entry.label.TextStrokeTransparency = 0.08 + fadeProgress * 0.92
	entry.label.Visible = true
	entry.scale.Scale = scaleValue
end

local function updateFrame()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		for _, entry in entries do
			entry.label.Visible = false
		end
		return
	end
	local nowTimestamp = Workspace:GetServerTimeNow()
	for _, entry in entries do
		if entry.active then
			updateEntry(entry, camera, nowTimestamp)
		end
	end
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
		or not isKnownWeaponId(payload.weaponId)
		or not isNonEmptyString(payload.targetEntityId)
		or payload.didApplyDamage ~= true
		or typeof(payload.impactWorldPosition) ~= "Vector3"
		or not isWholePositiveDamage(payload.damageAmount)
		or not isFiniteNumber(payload.serverTimestamp)
		or not rememberShot(payload.shotId)
	then
		return
	end

	activateEntry(payload.shotId, payload.weaponId, payload.damageAmount, payload.impactWorldPosition)
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
	table.clear(entries)
	table.clear(presentedShotIds)
	table.clear(presentedShotOrder)
end

return table.freeze(Controller)
