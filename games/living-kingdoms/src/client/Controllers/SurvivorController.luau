--!strict

--[[
	SurvivorController owns local desktop movement for the existing Roblox
	character. It converts keyboard input into a horizontal world-space direction
	relative to the tactical camera, then delegates collision, speed, and
	frame-rate-independent movement integration to the character Humanoid.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraController = require(script.Parent.CameraController)
local MovementLimits = require(ReplicatedStorage.Shared.Config.MovementLimits)

local INPUT_BINDINGS = table.freeze({
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
})

type PlayerControls = {
	Disable: (self: PlayerControls) -> (),
	Enable: (self: PlayerControls) -> (),
}

type SurvivorController = {
	init: () -> (),
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
}

type LifecycleState = {
	initialized: boolean,
	started: boolean,
	destroyed: boolean,
	localPlayer: Player?,
	character: Model?,
	humanoid: Humanoid?,
	humanoidRootPart: BasePart?,
	playerControls: PlayerControls?,
	defaultControlsDisabled: boolean,
	characterAddedConnection: RBXScriptConnection?,
	characterRemovingConnection: RBXScriptConnection?,
	characterChildAddedConnection: RBXScriptConnection?,
	characterChildRemovedConnection: RBXScriptConnection?,
	inputBeganConnection: RBXScriptConnection?,
	inputEndedConnection: RBXScriptConnection?,
	textBoxFocusedConnection: RBXScriptConnection?,
	renderSteppedConnection: RBXScriptConnection?,
	pressedMovementKeys: { [Enum.KeyCode]: boolean },
}

local SurvivorController: SurvivorController = {} :: SurvivorController
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	localPlayer = nil,
	character = nil,
	humanoid = nil,
	humanoidRootPart = nil,
	playerControls = nil,
	defaultControlsDisabled = false,
	characterAddedConnection = nil,
	characterRemovingConnection = nil,
	characterChildAddedConnection = nil,
	characterChildRemovedConnection = nil,
	inputBeganConnection = nil,
	inputEndedConnection = nil,
	textBoxFocusedConnection = nil,
	renderSteppedConnection = nil,
	pressedMovementKeys = {},
}

local function stopHumanoidMovement()
	local humanoid = state.humanoid
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero, false)
	end
end

local function clearMovementInput()
	table.clear(state.pressedMovementKeys)
	stopHumanoidMovement()
end

local function disableDefaultControls()
	local playerControls = state.playerControls
	if playerControls == nil or state.defaultControlsDisabled then
		return
	end

	playerControls:Disable()
	state.defaultControlsDisabled = true
end

local function enableDefaultControls()
	local playerControls = state.playerControls
	if playerControls == nil or not state.defaultControlsDisabled then
		return
	end

	playerControls:Enable()
	state.defaultControlsDisabled = false
end

local function disconnectCharacterConnections()
	local characterChildAddedConnection = state.characterChildAddedConnection
	if characterChildAddedConnection ~= nil then
		characterChildAddedConnection:Disconnect()
		state.characterChildAddedConnection = nil
	end

	local characterChildRemovedConnection = state.characterChildRemovedConnection
	if characterChildRemovedConnection ~= nil then
		characterChildRemovedConnection:Disconnect()
		state.characterChildRemovedConnection = nil
	end
end

local function refreshCharacterParts()
	local character = state.character
	if character == nil then
		state.humanoid = nil
		state.humanoidRootPart = nil
		return
	end

	state.humanoid = character:FindFirstChildOfClass("Humanoid")
	if state.humanoid ~= nil then
		state.humanoid.WalkSpeed = MovementLimits.MaximumPrototypeHorizontalSpeed
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart") then
		state.humanoidRootPart = humanoidRootPart
	else
		state.humanoidRootPart = nil
	end

	if state.humanoid ~= nil and state.humanoidRootPart ~= nil then
		disableDefaultControls()
	end
end

local function clearCharacter()
	disconnectCharacterConnections()
	clearMovementInput()
	state.character = nil
	state.humanoid = nil
	state.humanoidRootPart = nil
end

local function bindCharacter(character: Model)
	disconnectCharacterConnections()
	clearMovementInput()
	state.character = character
	refreshCharacterParts()

	state.characterChildAddedConnection = character.ChildAdded:Connect(function()
		refreshCharacterParts()
	end)
	state.characterChildRemovedConnection = character.ChildRemoved:Connect(function()
		refreshCharacterParts()
	end)
end

local function getPlayerControls(localPlayer: Player): PlayerControls
	local playerScripts = localPlayer:WaitForChild("PlayerScripts")
	local playerModule = require(playerScripts:WaitForChild("PlayerModule")) :: any

	return playerModule:GetControls() :: PlayerControls
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	if INPUT_BINDINGS[input.KeyCode] ~= nil then
		state.pressedMovementKeys[input.KeyCode] = true
	end
end

local function onInputEnded(input: InputObject)
	if INPUT_BINDINGS[input.KeyCode] == nil then
		return
	end

	state.pressedMovementKeys[input.KeyCode] = nil

	for _, pressed in state.pressedMovementKeys do
		if pressed then
			return
		end
	end

	stopHumanoidMovement()
end

local function getInputDirection(): Vector2
	local inputDirection = Vector2.zero
	for keyCode, direction in INPUT_BINDINGS do
		if state.pressedMovementKeys[keyCode] then
			inputDirection += direction
		end
	end

	if inputDirection.Magnitude > 1 then
		return inputDirection.Unit
	end

	return inputDirection
end

local function getCameraRelativeDirection(inputDirection: Vector2): Vector3
	local camera = Workspace.CurrentCamera
	if camera == nil or inputDirection.Magnitude == 0 then
		return Vector3.zero
	end

	local lookVector = camera.CFrame.LookVector
	local rightVector = camera.CFrame.RightVector
	local horizontalForward = Vector3.new(lookVector.X, 0, lookVector.Z)
	local horizontalRight = Vector3.new(rightVector.X, 0, rightVector.Z)

	if horizontalForward.Magnitude == 0 or horizontalRight.Magnitude == 0 then
		return Vector3.zero
	end

	local worldDirection = horizontalRight.Unit * inputDirection.X + horizontalForward.Unit * inputDirection.Y
	if worldDirection.Magnitude > 1 then
		return worldDirection.Unit
	end

	return worldDirection
end

local function updateMovement()
	if UserInputService:GetFocusedTextBox() ~= nil then
		clearMovementInput()
		return
	end

	local character = state.character
	local humanoid = state.humanoid
	local humanoidRootPart = state.humanoidRootPart
	if
		character == nil
		or character.Parent == nil
		or humanoid == nil
		or humanoid.Parent ~= character
		or humanoidRootPart == nil
		or humanoidRootPart.Parent ~= character
	then
		stopHumanoidMovement()
		return
	end

	local inputDirection = getInputDirection()
	local worldDirection = getCameraRelativeDirection(inputDirection)
	humanoid:Move(worldDirection, false)
end

function SurvivorController.init()
	if state.initialized or state.destroyed then
		return
	end

	state.localPlayer = Players.LocalPlayer
	state.initialized = true
end

function SurvivorController.start()
	if state.started or state.destroyed then
		return
	end

	SurvivorController.init()

	local localPlayer = state.localPlayer
	if localPlayer == nil then
		return
	end

	state.playerControls = getPlayerControls(localPlayer)
	state.started = true
	CameraController.setKeyboardPanningEnabled(false)
	state.characterAddedConnection = localPlayer.CharacterAdded:Connect(bindCharacter)
	state.characterRemovingConnection = localPlayer.CharacterRemoving:Connect(function(character)
		if state.character == character then
			clearCharacter()
		end
	end)
	state.inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	state.inputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)
	state.textBoxFocusedConnection = UserInputService.TextBoxFocused:Connect(function()
		clearMovementInput()
	end)
	state.renderSteppedConnection = RunService.RenderStepped:Connect(updateMovement)

	local character = localPlayer.Character
	if character ~= nil then
		bindCharacter(character)
	end
end

function SurvivorController.stop()
	if not state.started or state.destroyed then
		return
	end

	clearCharacter()

	local characterAddedConnection = state.characterAddedConnection
	if characterAddedConnection ~= nil then
		characterAddedConnection:Disconnect()
		state.characterAddedConnection = nil
	end

	local characterRemovingConnection = state.characterRemovingConnection
	if characterRemovingConnection ~= nil then
		characterRemovingConnection:Disconnect()
		state.characterRemovingConnection = nil
	end

	local inputBeganConnection = state.inputBeganConnection
	if inputBeganConnection ~= nil then
		inputBeganConnection:Disconnect()
		state.inputBeganConnection = nil
	end

	local inputEndedConnection = state.inputEndedConnection
	if inputEndedConnection ~= nil then
		inputEndedConnection:Disconnect()
		state.inputEndedConnection = nil
	end

	local textBoxFocusedConnection = state.textBoxFocusedConnection
	if textBoxFocusedConnection ~= nil then
		textBoxFocusedConnection:Disconnect()
		state.textBoxFocusedConnection = nil
	end

	local renderSteppedConnection = state.renderSteppedConnection
	if renderSteppedConnection ~= nil then
		renderSteppedConnection:Disconnect()
		state.renderSteppedConnection = nil
	end

	enableDefaultControls()
	state.playerControls = nil
	CameraController.setKeyboardPanningEnabled(true)
	state.started = false
end

function SurvivorController.destroy()
	if state.destroyed then
		return
	end

	SurvivorController.stop()
	state.localPlayer = nil
	state.character = nil
	state.humanoid = nil
	state.humanoidRootPart = nil
	state.playerControls = nil
	state.initialized = false
	state.destroyed = true
end

return SurvivorController
