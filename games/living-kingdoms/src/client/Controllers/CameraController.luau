--!strict

--[[
	CameraController owns the local camera lifecycle and elevated tactical view.
	It preserves keyboard panning, mouse-wheel zoom, and world-space focus bounds,
	and can smoothly follow the local survivor on the horizontal plane.

	Rotation, edge scrolling, touch controls, and unrelated camera behavior remain
	intentionally deferred.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PAN_SPEED_STUDS_PER_SECOND = 48

local CameraConfig = table.freeze({
	FocusPoint = Vector3.new(-224, 0, -208),
	MinimumFocusX = -320,
	MaximumFocusX = 320,
	MinimumFocusZ = -320,
	MaximumFocusZ = 320,
	PitchDegrees = -60,
	YawDegrees = 45,
	MinimumHeight = 40,
	MaximumHeight = 160,
	ZoomSensitivity = 10,
	InitialHeight = 76,
})

local SurvivorFollowConfig = table.freeze({
	WorldSpaceOffset = Vector3.new(0, 0, 0),
	ResponsivenessPerSecond = 12,
	SettleDistanceStuds = 0.05,
	VerticalFollowPolicy = "PreserveConfiguredFocusHeight",
	PreservedFocusHeight = CameraConfig.FocusPoint.Y,
})

local PAN_INPUT_BINDINGS = table.freeze({
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
})

local function getCameraOffset(height: number): Vector3
	local pitchRadians = math.rad(-CameraConfig.PitchDegrees)
	local yawRadians = math.rad(CameraConfig.YawDegrees)
	local horizontalDistance = height / math.tan(pitchRadians)

	return Vector3.new(math.sin(yawRadians) * horizontalDistance, height, math.cos(yawRadians) * horizontalDistance)
end

local INITIAL_CAMERA_OFFSET = getCameraOffset(CameraConfig.InitialHeight)
local INITIAL_CAMERA_POSITION = CameraConfig.FocusPoint + INITIAL_CAMERA_OFFSET
local INITIAL_CAMERA_CFRAME = CFrame.lookAt(INITIAL_CAMERA_POSITION, CameraConfig.FocusPoint)
local CAMERA_FORWARD = Vector3.new(INITIAL_CAMERA_CFRAME.LookVector.X, 0, INITIAL_CAMERA_CFRAME.LookVector.Z).Unit
local CAMERA_RIGHT = Vector3.new(INITIAL_CAMERA_CFRAME.RightVector.X, 0, INITIAL_CAMERA_CFRAME.RightVector.Z).Unit

type CameraController = {
	init: () -> (),
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
	setKeyboardPanningEnabled: (enabled: boolean) -> (),
	setSurvivorFollowEnabled: (enabled: boolean) -> (),
}

type LifecycleState = {
	initialized: boolean,
	started: boolean,
	destroyed: boolean,
	localPlayer: Player?,
	currentCamera: Camera?,
	originalCameraType: Enum.CameraType?,
	originalCameraCFrame: CFrame?,
	currentCameraChangedConnection: RBXScriptConnection?,
	characterAddedConnection: RBXScriptConnection?,
	characterRemovingConnection: RBXScriptConnection?,
	characterChildAddedConnection: RBXScriptConnection?,
	characterChildRemovedConnection: RBXScriptConnection?,
	inputBeganConnection: RBXScriptConnection?,
	inputChangedConnection: RBXScriptConnection?,
	inputEndedConnection: RBXScriptConnection?,
	renderSteppedConnection: RBXScriptConnection?,
	activationLogged: boolean,
	focusPoint: Vector3,
	currentHeight: number,
	keyboardPanningEnabled: boolean,
	survivorFollowEnabled: boolean,
	followCharacter: Model?,
	followRootPart: BasePart?,
	pressedPanKeys: { [Enum.KeyCode]: boolean },
}

local CameraController: CameraController = {} :: CameraController
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	localPlayer = nil,
	currentCamera = nil,
	originalCameraType = nil,
	originalCameraCFrame = nil,
	currentCameraChangedConnection = nil,
	characterAddedConnection = nil,
	characterRemovingConnection = nil,
	characterChildAddedConnection = nil,
	characterChildRemovedConnection = nil,
	inputBeganConnection = nil,
	inputChangedConnection = nil,
	inputEndedConnection = nil,
	renderSteppedConnection = nil,
	activationLogged = false,
	focusPoint = CameraConfig.FocusPoint,
	currentHeight = CameraConfig.InitialHeight,
	keyboardPanningEnabled = true,
	survivorFollowEnabled = false,
	followCharacter = nil,
	followRootPart = nil,
	pressedPanKeys = {},
}

local function disconnectFollowCharacterConnections()
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

local function refreshFollowRootPart()
	local character = state.followCharacter
	if character == nil or character.Parent == nil then
		state.followRootPart = nil
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart ~= nil and rootPart:IsA("BasePart") then
		state.followRootPart = rootPart
	else
		state.followRootPart = nil
	end
end

local function clearFollowCharacter()
	disconnectFollowCharacterConnections()
	state.followCharacter = nil
	state.followRootPart = nil
end

local function bindFollowCharacter(character: Model)
	disconnectFollowCharacterConnections()
	state.followCharacter = character
	refreshFollowRootPart()
	state.characterChildAddedConnection = character.ChildAdded:Connect(refreshFollowRootPart)
	state.characterChildRemovedConnection = character.ChildRemoved:Connect(refreshFollowRootPart)
end

local function refreshFollowCharacter()
	local localPlayer = state.localPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	if character == state.followCharacter then
		refreshFollowRootPart()
		return
	end

	clearFollowCharacter()
	if character ~= nil then
		bindFollowCharacter(character)
	end
end

local function restoreOwnedCameraProperties()
	local camera = state.currentCamera
	local originalCameraType = state.originalCameraType
	local originalCameraCFrame = state.originalCameraCFrame

	state.originalCameraType = nil
	state.originalCameraCFrame = nil

	if camera == nil or originalCameraType == nil or originalCameraCFrame == nil then
		return
	end

	pcall(function()
		camera.CameraType = originalCameraType
		camera.CFrame = originalCameraCFrame
	end)
end

local function applyFixedView(camera: Camera)
	local focusPoint = state.focusPoint
	local cameraPosition = focusPoint + getCameraOffset(state.currentHeight)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPosition, focusPoint)
end

local function clampFocusPoint(focusPoint: Vector3): Vector3
	return Vector3.new(
		math.clamp(focusPoint.X, CameraConfig.MinimumFocusX, CameraConfig.MaximumFocusX),
		focusPoint.Y,
		math.clamp(focusPoint.Z, CameraConfig.MinimumFocusZ, CameraConfig.MaximumFocusZ)
	)
end

local function updateSurvivorFollow(deltaTime: number)
	if not state.survivorFollowEnabled then
		return
	end

	local rootPart = state.followRootPart
	local character = state.followCharacter
	if rootPart == nil or rootPart.Parent ~= character or character == nil or character.Parent == nil then
		refreshFollowCharacter()
		rootPart = state.followRootPart
		character = state.followCharacter
	end

	if rootPart == nil or character == nil or rootPart.Parent ~= character then
		return
	end

	local rootPosition = rootPart.Position
	local followOffset = SurvivorFollowConfig.WorldSpaceOffset
	local targetFocusPoint = clampFocusPoint(
		Vector3.new(
			rootPosition.X + followOffset.X,
			SurvivorFollowConfig.PreservedFocusHeight + followOffset.Y,
			rootPosition.Z + followOffset.Z
		)
	)
	local smoothingAlpha = 1 - math.exp(-SurvivorFollowConfig.ResponsivenessPerSecond * math.max(deltaTime, 0))
	local smoothedFocusPoint = state.focusPoint:Lerp(targetFocusPoint, smoothingAlpha)

	if (targetFocusPoint - smoothedFocusPoint).Magnitude <= SurvivorFollowConfig.SettleDistanceStuds then
		state.focusPoint = targetFocusPoint
	else
		state.focusPoint = clampFocusPoint(smoothedFocusPoint)
	end
end

local function onInputChanged(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end

	state.currentHeight = math.clamp(
		state.currentHeight - input.Position.Z * CameraConfig.ZoomSensitivity,
		CameraConfig.MinimumHeight,
		CameraConfig.MaximumHeight
	)
end

local function updateFocusPoint(deltaTime: number)
	if not state.keyboardPanningEnabled or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	local inputDirection = Vector2.zero
	for keyCode, direction in PAN_INPUT_BINDINGS do
		if state.pressedPanKeys[keyCode] then
			inputDirection += direction
		end
	end

	if inputDirection.Magnitude == 0 then
		return
	end

	if inputDirection.Magnitude > 1 then
		inputDirection = inputDirection.Unit
	end

	local worldDirection = CAMERA_RIGHT * inputDirection.X + CAMERA_FORWARD * inputDirection.Y
	local displacement = worldDirection * PAN_SPEED_STUDS_PER_SECOND * deltaTime
	state.focusPoint = clampFocusPoint(state.focusPoint + Vector3.new(displacement.X, 0, displacement.Z))
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if not state.keyboardPanningEnabled or gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	if PAN_INPUT_BINDINGS[input.KeyCode] ~= nil then
		state.pressedPanKeys[input.KeyCode] = true
	end
end

local function onInputEnded(input: InputObject)
	if PAN_INPUT_BINDINGS[input.KeyCode] ~= nil then
		state.pressedPanKeys[input.KeyCode] = nil
	end
end

local function updateCurrentCamera()
	local currentCamera = Workspace.CurrentCamera

	if currentCamera ~= state.currentCamera then
		restoreOwnedCameraProperties()
		state.currentCamera = currentCamera
	end

	if currentCamera == nil then
		return
	end

	if state.originalCameraType == nil or state.originalCameraCFrame == nil then
		state.originalCameraType = currentCamera.CameraType
		state.originalCameraCFrame = currentCamera.CFrame
	end

	applyFixedView(currentCamera)

	if not state.activationLogged then
		print("[Living Kingdoms] Fixed overhead camera activated")
		state.activationLogged = true
	end
end

function CameraController.init()
	if state.initialized or state.destroyed then
		return
	end

	state.localPlayer = Players.LocalPlayer
	state.currentCamera = Workspace.CurrentCamera
	state.initialized = true
end

function CameraController.setKeyboardPanningEnabled(enabled: boolean)
	state.keyboardPanningEnabled = enabled

	if not enabled then
		table.clear(state.pressedPanKeys)
	end
end

function CameraController.setSurvivorFollowEnabled(enabled: boolean)
	if state.destroyed then
		return
	end

	state.survivorFollowEnabled = enabled
	if enabled and state.started then
		refreshFollowCharacter()
	else
		clearFollowCharacter()
	end
end

function CameraController.start()
	if state.started or state.destroyed then
		return
	end

	CameraController.init()
	local localPlayer = state.localPlayer
	if localPlayer == nil then
		return
	end

	state.started = true
	state.activationLogged = false
	state.currentCameraChangedConnection = Workspace:GetPropertyChangedSignal("CurrentCamera")
		:Connect(updateCurrentCamera)
	state.characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
		if state.survivorFollowEnabled then
			bindFollowCharacter(character)
		end
	end)
	state.characterRemovingConnection = localPlayer.CharacterRemoving:Connect(function(character)
		if state.followCharacter == character then
			clearFollowCharacter()
		end
	end)
	state.inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	state.inputChangedConnection = UserInputService.InputChanged:Connect(onInputChanged)
	state.inputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)
	state.renderSteppedConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if Workspace.CurrentCamera ~= state.currentCamera then
			updateCurrentCamera()
		end

		updateFocusPoint(deltaTime)
		updateSurvivorFollow(deltaTime)

		local currentCamera = state.currentCamera
		if currentCamera ~= nil then
			applyFixedView(currentCamera)
		end
	end)
	if state.survivorFollowEnabled then
		refreshFollowCharacter()
	end
	updateCurrentCamera()
end

function CameraController.stop()
	if not state.started or state.destroyed then
		return
	end

	local currentCameraChangedConnection = state.currentCameraChangedConnection
	if currentCameraChangedConnection ~= nil then
		currentCameraChangedConnection:Disconnect()
		state.currentCameraChangedConnection = nil
	end

	local renderSteppedConnection = state.renderSteppedConnection
	if renderSteppedConnection ~= nil then
		renderSteppedConnection:Disconnect()
		state.renderSteppedConnection = nil
	end

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

	clearFollowCharacter()

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

	local inputChangedConnection = state.inputChangedConnection
	if inputChangedConnection ~= nil then
		inputChangedConnection:Disconnect()
		state.inputChangedConnection = nil
	end

	restoreOwnedCameraProperties()
	table.clear(state.pressedPanKeys)
	state.currentCamera = nil
	state.activationLogged = false
	state.started = false
end

function CameraController.destroy()
	if state.destroyed then
		return
	end

	CameraController.stop()
	state.localPlayer = nil
	state.currentCamera = nil
	state.survivorFollowEnabled = false
	state.initialized = false
	state.destroyed = true
end

return CameraController
