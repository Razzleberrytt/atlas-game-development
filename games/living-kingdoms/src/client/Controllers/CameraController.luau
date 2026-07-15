--!strict

--[[
	CameraController owns the local camera lifecycle and applies the fixed overhead
	strategy view configured for LK-0011.

	Pan, zoom, smoothing, bounds, rotation, edge scrolling, touch controls, and all
	gameplay behavior remain intentionally deferred to later tasks.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CAMERA_FOCUS_POINT = Vector3.new(0, 0, 0)
local CAMERA_PITCH_DEGREES = -60
local CAMERA_YAW_DEGREES = 45
local CAMERA_HEIGHT = 80

local pitchRadians = math.rad(-CAMERA_PITCH_DEGREES)
local yawRadians = math.rad(CAMERA_YAW_DEGREES)
local horizontalDistance = CAMERA_HEIGHT / math.tan(pitchRadians)
local CAMERA_INITIAL_POSITION = CAMERA_FOCUS_POINT
	+ Vector3.new(math.sin(yawRadians) * horizontalDistance, CAMERA_HEIGHT, math.cos(yawRadians) * horizontalDistance)

local CameraConfig = table.freeze({
	FocusPoint = CAMERA_FOCUS_POINT,
	PitchDegrees = CAMERA_PITCH_DEGREES,
	YawDegrees = CAMERA_YAW_DEGREES,
	Height = CAMERA_HEIGHT,
	InitialPosition = CAMERA_INITIAL_POSITION,
})
local FIXED_CAMERA_CFRAME = CFrame.lookAt(CameraConfig.InitialPosition, CameraConfig.FocusPoint)

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
	renderSteppedConnection: RBXScriptConnection?,
	activationLogged: boolean,
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
	renderSteppedConnection = nil,
	activationLogged = false,
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
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = FIXED_CAMERA_CFRAME
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
	state.renderSteppedConnection = RunService.RenderStepped:Connect(function()
		if Workspace.CurrentCamera ~= state.currentCamera then
			updateCurrentCamera()
		end

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

	restoreOwnedCameraProperties()
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
