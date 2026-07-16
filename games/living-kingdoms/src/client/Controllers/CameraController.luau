--!strict

--[[
	CameraController owns the local camera lifecycle and applies the fixed overhead
	strategy view configured for LK-0011, keyboard panning added in LK-0012, and
	mouse-wheel zoom added in LK-0013. LK-0014 constrains the mutable focus point
	to configurable world-space bounds.

	Smoothing, rotation, edge scrolling, touch controls, and all gameplay behavior
	remain intentionally deferred to later tasks.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PAN_SPEED_STUDS_PER_SECOND = 48

local CameraConfig = table.freeze({
	FocusPoint = Vector3.new(0, 0, 0),
	MinimumFocusX = -128,
	MaximumFocusX = 128,
	MinimumFocusZ = -128,
	MaximumFocusZ = 128,
	PitchDegrees = -60,
	YawDegrees = 45,
	MinimumHeight = 40,
	MaximumHeight = 160,
	ZoomSensitivity = 10,
	InitialHeight = 80,
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
	inputBeganConnection: RBXScriptConnection?,
	inputChangedConnection: RBXScriptConnection?,
	inputEndedConnection: RBXScriptConnection?,
	renderSteppedConnection: RBXScriptConnection?,
	activationLogged: boolean,
	focusPoint: Vector3,
	currentHeight: number,
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
	inputBeganConnection = nil,
	inputChangedConnection = nil,
	inputEndedConnection = nil,
	renderSteppedConnection = nil,
	activationLogged = false,
	focusPoint = CameraConfig.FocusPoint,
	currentHeight = CameraConfig.InitialHeight,
	pressedPanKeys = {},
}

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
	if UserInputService:GetFocusedTextBox() ~= nil then
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
	if gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil then
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

function CameraController.start()
	if state.started or state.destroyed then
		return
	end

	CameraController.init()
	state.started = true
	state.activationLogged = false
	state.currentCameraChangedConnection = Workspace:GetPropertyChangedSignal("CurrentCamera")
		:Connect(updateCurrentCamera)
	state.inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	state.inputChangedConnection = UserInputService.InputChanged:Connect(onInputChanged)
	state.inputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)
	state.renderSteppedConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if Workspace.CurrentCamera ~= state.currentCamera then
			updateCurrentCamera()
		end

		updateFocusPoint(deltaTime)

		local currentCamera = state.currentCamera
		if currentCamera ~= nil then
			applyFixedView(currentCamera)
		end
	end)
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
	state.initialized = false
	state.destroyed = true
end

return CameraController
