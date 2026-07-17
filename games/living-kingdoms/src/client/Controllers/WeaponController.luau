--!strict

--[[
	Owns local reload input and immediate presentation of server-disclosed combat
	events. It never selects targets, spends ammunition, resolves hits, changes
	health, or fabricates an event that the server did not disclose.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CachePresentationContracts = require(ReplicatedStorage.Shared.Combat.AmmunitionCachePresentationContracts)
local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local REQUEST_COOLDOWN_SECONDS = 0.5
local COMBAT_ENTITY_ID_ATTRIBUTE = "CombatEntityId"
local SUPPLY_CACHE_ID_ATTRIBUTE = "SupplyCacheId"

type WeaponController = {
	init: () -> (),
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
}

type LifecycleState = {
	initialized: boolean,
	started: boolean,
	destroyed: boolean,
	lastReloadRequestLocalTimestamp: number,
	presentedShotIds: { [string]: boolean },
	selectedTargetEntityId: string?,
	inputBeganConnection: RBXScriptConnection?,
	presentationConnection: RBXScriptConnection?,
	screenGui: ScreenGui?,
	statusLabel: TextLabel?,
	ammunitionLabel: TextLabel?,
	targetHighlight: Highlight?,
}

local WeaponController: WeaponController = {} :: WeaponController
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	lastReloadRequestLocalTimestamp = -math.huge,
	presentedShotIds = {},
	selectedTargetEntityId = nil,
	inputBeganConnection = nil,
	presentationConnection = nil,
	screenGui = nil,
	statusLabel = nil,
	ammunitionLabel = nil,
	targetHighlight = nil,
}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function setStatus(text: string)
	local statusLabel = state.statusLabel
	if statusLabel ~= nil then
		statusLabel.Text = text
		statusLabel.Visible = text ~= ""
	end
end

local function presentAmmunition(loadedRounds: number, reserveRounds: number, magazineCapacity: number)
	local ammunitionLabel = state.ammunitionLabel
	if ammunitionLabel ~= nil then
		ammunitionLabel.Text = string.format("%d / %d   RESERVE %d", loadedRounds, magazineCapacity, reserveRounds)
		ammunitionLabel.Visible = true
	end
end

local function clearTargetPresentation()
	local targetHighlight = state.targetHighlight
	if targetHighlight ~= nil then
		targetHighlight:Destroy()
		state.targetHighlight = nil
	end
	state.selectedTargetEntityId = nil
end

local function findDisclosedTarget(entityId: string): Instance?
	for _, descendant in Workspace:GetDescendants() do
		if descendant:GetAttribute(COMBAT_ENTITY_ID_ATTRIBUTE) == entityId then
			return descendant
		end
	end

	return nil
end

local function presentSelectedTarget(targetEntityId: string)
	clearTargetPresentation()
	local target = findDisclosedTarget(targetEntityId)
	if target == nil then
		return
	end

	local targetHighlight = Instance.new("Highlight")
	targetHighlight.Name = "DisclosedCombatTarget"
	targetHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	targetHighlight.FillColor = Color3.fromRGB(255, 196, 72)
	targetHighlight.FillTransparency = 0.75
	targetHighlight.OutlineColor = Color3.fromRGB(255, 232, 160)
	targetHighlight.OutlineTransparency = 0
	targetHighlight.Adornee = target
	targetHighlight.Parent = target
	state.targetHighlight = targetHighlight
	state.selectedTargetEntityId = targetEntityId
	setStatus("Target acquired")
end

local function presentConsumedAmmunitionCache(cacheId: string)
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(SUPPLY_CACHE_ID_ATTRIBUTE) == cacheId then
			local cachePart = descendant :: BasePart
			local prompt = cachePart:FindFirstChild("CollectPrompt")
			if prompt ~= nil and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
				prompt.ActionText = "Depleted"
			end

			cachePart.Color = Color3.fromRGB(48, 51, 47)
			cachePart.Material = Enum.Material.SmoothPlastic
			cachePart.Transparency = 0.35

			if cachePart:FindFirstChild("ConsumedCacheHighlight") == nil then
				local highlight = Instance.new("Highlight")
				highlight.Name = "ConsumedCacheHighlight"
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.FillColor = Color3.fromRGB(42, 45, 42)
				highlight.FillTransparency = 0.65
				highlight.OutlineColor = Color3.fromRGB(122, 128, 119)
				highlight.OutlineTransparency = 0.2
				highlight.Adornee = cachePart
				highlight.Parent = cachePart
			end
			return
		end
	end
end

local function presentShot(shotId: string)
	if state.presentedShotIds[shotId] then
		return
	end

	state.presentedShotIds[shotId] = true
	setStatus("Shot fired")
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isWholeNonnegative(value: unknown): boolean
	return isFiniteNumber(value) and value >= 0 and value % 1 == 0
end

local function presentAmmunitionPayload(payload: any): boolean
	if
		payload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId
		or not isWholeNonnegative(payload.loadedRounds)
		or not isWholeNonnegative(payload.reserveRounds)
		or not isWholeNonnegative(payload.magazineCapacity)
		or payload.magazineCapacity <= 0
		or payload.loadedRounds > payload.magazineCapacity
		or not isWholeNonnegative(payload.maximumReserveRounds)
		or payload.reserveRounds > payload.maximumReserveRounds
	then
		return false
	end
	presentAmmunition(payload.loadedRounds, payload.reserveRounds, payload.magazineCapacity)
	return true
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end

	local payload = message :: any
	local kindId = payload.kindId
	if kindId == CombatContracts.PresentationMessageKindIds.TargetSelected then
		if
			isNonEmptyString(payload.operativeEntityId)
			and isNonEmptyString(payload.targetEntityId)
			and isFiniteNumber(payload.serverTimestamp)
		then
			presentSelectedTarget(payload.targetEntityId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.TargetCleared then
		if isNonEmptyString(payload.operativeEntityId) and isFiniteNumber(payload.serverTimestamp) then
			clearTargetPresentation()
			setStatus("")
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if
			isNonEmptyString(payload.shotId)
			and isNonEmptyString(payload.operativeEntityId)
			and payload.weaponId == FirearmConfig.BasicFirearm.WeaponId
			and isNonEmptyString(payload.targetEntityId)
			and isFiniteNumber(payload.serverTimestamp)
		then
			presentShot(payload.shotId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		if
			payload.weaponId == FirearmConfig.BasicFirearm.WeaponId
			and isFiniteNumber(payload.completionServerTimestamp)
		then
			setStatus("Reloading")
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadCompleted then
		if payload.weaponId == FirearmConfig.BasicFirearm.WeaponId then
			setStatus("Reload complete")
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then
		if payload.weaponId == FirearmConfig.BasicFirearm.WeaponId then
			setStatus("Reload interrupted")
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.AmmunitionState then
		presentAmmunitionPayload(payload)
	elseif kindId == CombatContracts.PresentationMessageKindIds.AmmunitionCollected then
		if
			presentAmmunitionPayload(payload)
			and isWholeNonnegative(payload.grantedRounds)
			and payload.grantedRounds > 0
		then
			setStatus("+" .. tostring(payload.grantedRounds) .. " rifle ammunition")
		end
	elseif kindId == CachePresentationContracts.MessageKindIds.Consumed and isNonEmptyString(payload.cacheId) then
		presentConsumedAmmunitionCache(payload.cacheId)
	end
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.KeyCode ~= Enum.KeyCode.R or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	local now = os.clock()
	if now - state.lastReloadRequestLocalTimestamp < REQUEST_COOLDOWN_SECONDS then
		return
	end

	state.lastReloadRequestLocalTimestamp = now
	reloadIntentRemote:FireServer(FirearmConfig.BasicFirearm.WeaponId)
end

local function createStatusGui()
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TemporaryCombatPresentation"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.AnchorPoint = Vector2.new(0.5, 1)
	statusLabel.Position = UDim2.new(0.5, 0, 1, -32)
	statusLabel.Size = UDim2.fromOffset(220, 28)
	statusLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	statusLabel.BackgroundTransparency = 0.25
	statusLabel.BorderSizePixel = 0
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	statusLabel.TextSize = 16
	statusLabel.Visible = false
	statusLabel.Parent = screenGui

	local ammunitionLabel = Instance.new("TextLabel")
	ammunitionLabel.Name = "Ammunition"
	ammunitionLabel.AnchorPoint = Vector2.new(1, 1)
	ammunitionLabel.Position = UDim2.new(1, -28, 1, -28)
	ammunitionLabel.Size = UDim2.fromOffset(280, 42)
	ammunitionLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	ammunitionLabel.BackgroundTransparency = 0.2
	ammunitionLabel.BorderSizePixel = 0
	ammunitionLabel.Font = Enum.Font.GothamBold
	ammunitionLabel.Text = ""
	ammunitionLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	ammunitionLabel.TextSize = 18
	ammunitionLabel.Visible = false
	ammunitionLabel.Parent = screenGui

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	state.screenGui = screenGui
	state.statusLabel = statusLabel
	state.ammunitionLabel = ammunitionLabel
end

function WeaponController.init()
	if state.initialized or state.destroyed then
		return
	end

	state.initialized = true
end

function WeaponController.start()
	if state.started or state.destroyed then
		return
	end

	WeaponController.init()
	state.started = true
	state.lastReloadRequestLocalTimestamp = -math.huge
	state.inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	state.presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
	createStatusGui()
end

function WeaponController.stop()
	if not state.started or state.destroyed then
		return
	end

	local inputBeganConnection = state.inputBeganConnection
	if inputBeganConnection ~= nil then
		inputBeganConnection:Disconnect()
		state.inputBeganConnection = nil
	end

	local presentationConnection = state.presentationConnection
	if presentationConnection ~= nil then
		presentationConnection:Disconnect()
		state.presentationConnection = nil
	end

	clearTargetPresentation()
	local screenGui = state.screenGui
	if screenGui ~= nil then
		screenGui:Destroy()
		state.screenGui = nil
	end
	state.statusLabel = nil
	state.ammunitionLabel = nil
	table.clear(state.presentedShotIds)
	state.started = false
end

function WeaponController.destroy()
	if state.destroyed then
		return
	end

	WeaponController.stop()
	state.initialized = false
	state.destroyed = true
end

return WeaponController
