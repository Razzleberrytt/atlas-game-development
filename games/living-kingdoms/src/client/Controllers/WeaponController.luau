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

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local REQUEST_COOLDOWN_SECONDS = 0.5
local COMBAT_ENTITY_ID_ATTRIBUTE = "CombatEntityId"

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

local function presentShot(shotId: string)
	if state.presentedShotIds[shotId] then
		return
	end

	state.presentedShotIds[shotId] = true
	setStatus("Shot fired")
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end

	local payload = message :: any
	local kindId = payload.kindId
	if kindId == CombatContracts.PresentationMessageKindIds.TargetSelected then
		if type(payload.targetEntityId) == "string" and payload.targetEntityId ~= "" then
			presentSelectedTarget(payload.targetEntityId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.TargetCleared then
		clearTargetPresentation()
		setStatus("")
	elseif kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if type(payload.shotId) == "string" and payload.shotId ~= "" then
			presentShot(payload.shotId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		setStatus("Reloading")
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadCompleted then
		setStatus("Reload complete")
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then
		setStatus("Reload interrupted")
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

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	state.screenGui = screenGui
	state.statusLabel = statusLabel
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
