--!strict

--[[
	CameraController owns the client camera lifecycle boundary. For LK-0010 it only
	retains the local player and current camera references needed by later camera
	work and tracks its explicit lifecycle.

	Overhead positioning, pan, zoom, smoothing, bounds, edge scrolling, touch
	controls, and all gameplay behavior are intentionally deferred to later tasks.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
}

local CameraController: CameraController = {} :: CameraController
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	localPlayer = nil,
	currentCamera = nil,
}

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
end

function CameraController.stop()
	if not state.started or state.destroyed then
		return
	end

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
