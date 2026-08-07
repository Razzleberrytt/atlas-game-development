--!strict

--[[
	First-person camera owner. Roblox's camera module supplies mouse-look while
	this controller owns the FPS policy: locked first person, centered cursor,
	a readable field of view, and lifecycle-safe restoration.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FIRST_PERSON_FIELD_OF_VIEW = 78
local FIRST_PERSON_ZOOM_DISTANCE = 0.5

type CameraController = {
	init: () -> (),
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
	setKeyboardPanningEnabled: (enabled: boolean) -> (),
	setSurvivorFollowEnabled: (enabled: boolean) -> (),
}

type State = {
	initialized: boolean,
	started: boolean,
	destroyed: boolean,
	localPlayer: Player?,
	character: Model?,
	humanoid: Humanoid?,
	originalCameraMode: Enum.CameraMode?,
	originalMinimumZoom: number?,
	originalMaximumZoom: number?,
	originalMouseBehavior: Enum.MouseBehavior?,
	originalMouseIconEnabled: boolean?,
	originalCameraType: Enum.CameraType?,
	originalFieldOfView: number?,
	characterAddedConnection: RBXScriptConnection?,
	characterRemovingConnection: RBXScriptConnection?,
	currentCameraConnection: RBXScriptConnection?,
	renderConnection: RBXScriptConnection?,
}

local CameraController: CameraController = {} :: CameraController
local state: State = {
	initialized = false,
	started = false,
	destroyed = false,
	localPlayer = nil,
	character = nil,
	humanoid = nil,
	originalCameraMode = nil,
	originalMinimumZoom = nil,
	originalMaximumZoom = nil,
	originalMouseBehavior = nil,
	originalMouseIconEnabled = nil,
	originalCameraType = nil,
	originalFieldOfView = nil,
	characterAddedConnection = nil,
	characterRemovingConnection = nil,
	currentCameraConnection = nil,
	renderConnection = nil,
}

local function applyCameraSubject()
	local camera = Workspace.CurrentCamera
	local humanoid = state.humanoid
	if camera == nil then
		return
	end
	if state.originalCameraType == nil then
		state.originalCameraType = camera.CameraType
		state.originalFieldOfView = camera.FieldOfView
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = FIRST_PERSON_FIELD_OF_VIEW
	if humanoid ~= nil and humanoid.Parent == state.character then
		camera.CameraSubject = humanoid
	end
end

local function bindCharacter(character: Model)
	state.character = character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	end
	state.humanoid = humanoid
	applyCameraSubject()
end

local function applyFirstPersonPolicy()
	local localPlayer = state.localPlayer
	if localPlayer == nil then
		return
	end
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	localPlayer.CameraMinZoomDistance = FIRST_PERSON_ZOOM_DISTANCE
	localPlayer.CameraMaxZoomDistance = FIRST_PERSON_ZOOM_DISTANCE
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	applyCameraSubject()
end

local function restorePolicy()
	local localPlayer = state.localPlayer
	if localPlayer ~= nil then
		if state.originalCameraMode ~= nil then
			localPlayer.CameraMode = state.originalCameraMode
		end
		if state.originalMinimumZoom ~= nil then
			localPlayer.CameraMinZoomDistance = state.originalMinimumZoom
		end
		if state.originalMaximumZoom ~= nil then
			localPlayer.CameraMaxZoomDistance = state.originalMaximumZoom
		end
	end
	if state.originalMouseBehavior ~= nil then
		UserInputService.MouseBehavior = state.originalMouseBehavior
	end
	if state.originalMouseIconEnabled ~= nil then
		UserInputService.MouseIconEnabled = state.originalMouseIconEnabled
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		if state.originalCameraType ~= nil then
			camera.CameraType = state.originalCameraType
		end
		if state.originalFieldOfView ~= nil then
			camera.FieldOfView = state.originalFieldOfView
		end
	end
end

function CameraController.init()
	if state.initialized or state.destroyed then
		return
	end
	state.localPlayer = Players.LocalPlayer
	state.initialized = true
end

-- Compatibility surfaces retained for SurvivorController. Movement is no
-- longer camera panning and the camera always follows the local operative.
function CameraController.setKeyboardPanningEnabled(_enabled: boolean) end

function CameraController.setSurvivorFollowEnabled(_enabled: boolean) end

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
	state.originalCameraMode = localPlayer.CameraMode
	state.originalMinimumZoom = localPlayer.CameraMinZoomDistance
	state.originalMaximumZoom = localPlayer.CameraMaxZoomDistance
	state.originalMouseBehavior = UserInputService.MouseBehavior
	state.originalMouseIconEnabled = UserInputService.MouseIconEnabled
	state.characterAddedConnection = localPlayer.CharacterAdded:Connect(bindCharacter)
	state.characterRemovingConnection = localPlayer.CharacterRemoving:Connect(function(character)
		if state.character == character then
			state.character = nil
			state.humanoid = nil
		end
	end)
	state.currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyCameraSubject)
	state.renderConnection = RunService:BindToRenderStep(
		"LivingKingdomsFirstPersonCamera",
		Enum.RenderPriority.Camera.Value + 1,
		applyFirstPersonPolicy
	) :: any
	if localPlayer.Character ~= nil then
		bindCharacter(localPlayer.Character)
	end
	applyFirstPersonPolicy()
	print("[Living Kingdoms] First-person camera activated")
end

function CameraController.stop()
	if not state.started or state.destroyed then
		return
	end
	RunService:UnbindFromRenderStep("LivingKingdomsFirstPersonCamera")
	state.renderConnection = nil
	for _, connection in
		{
			state.characterAddedConnection,
			state.characterRemovingConnection,
			state.currentCameraConnection,
		}
	do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	state.characterAddedConnection = nil
	state.characterRemovingConnection = nil
	state.currentCameraConnection = nil
	restorePolicy()
	state.character = nil
	state.humanoid = nil
	state.originalCameraMode = nil
	state.originalMinimumZoom = nil
	state.originalMaximumZoom = nil
	state.originalMouseBehavior = nil
	state.originalMouseIconEnabled = nil
	state.originalCameraType = nil
	state.originalFieldOfView = nil
	state.started = false
end

function CameraController.destroy()
	if state.destroyed then
		return
	end
	CameraController.stop()
	state.localPlayer = nil
	state.initialized = false
	state.destroyed = true
end

return CameraController
