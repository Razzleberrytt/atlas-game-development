--!strict

--[[
	SurvivorController configures the local operative for Roblox's native
	character controls. PlayerModule remains the single movement owner, providing
	reliable keyboard, gamepad, and touch movement that is camera-relative in
	first person. This controller never writes a root transform or injects movement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraController = require(script.Parent.CameraController)
local MovementLimits = require(ReplicatedStorage.Shared.Config.MovementLimits)

type PlayerControls = {
	Enable: (self: PlayerControls) -> (),
}

type LifecycleState = {
	initialized: boolean,
	started: boolean,
	destroyed: boolean,
	localPlayer: Player?,
	playerControls: PlayerControls?,
	characterAddedConnection: RBXScriptConnection?,
}

local SurvivorController = {}
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	localPlayer = nil,
	playerControls = nil,
	characterAddedConnection = nil,
}

local function configureCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	end
	if humanoid == nil then
		warn("[SurvivorController] Character has no Humanoid; native movement could not be configured")
		return
	end

	humanoid.WalkSpeed = MovementLimits.MaximumPrototypeHorizontalSpeed
	humanoid.AutoRotate = true
end

local function getPlayerControls(localPlayer: Player): PlayerControls
	local playerScripts = localPlayer:WaitForChild("PlayerScripts")
	local playerModule = require(playerScripts:WaitForChild("PlayerModule")) :: any
	return playerModule:GetControls() :: PlayerControls
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

	state.started = true
	state.playerControls = getPlayerControls(localPlayer)
	-- Explicitly restore PlayerModule in case an earlier controller or Studio hot
	-- reload left it disabled. PlayerModule now owns every movement input path.
	state.playerControls:Enable()

	CameraController.setKeyboardPanningEnabled(false)
	CameraController.setSurvivorFollowEnabled(true)
	state.characterAddedConnection = localPlayer.CharacterAdded:Connect(configureCharacter)

	local character = localPlayer.Character
	if character ~= nil then
		task.spawn(configureCharacter, character)
	end

	print("[SurvivorController] Native Roblox character controls enabled")
end

function SurvivorController.stop()
	if not state.started or state.destroyed then
		return
	end

	local connection = state.characterAddedConnection
	if connection ~= nil then
		connection:Disconnect()
		state.characterAddedConnection = nil
	end

	-- Never strand the player with disabled controls during teardown or a hot
	-- reload in Studio.
	local playerControls = state.playerControls
	if playerControls ~= nil then
		playerControls:Enable()
	end
	state.playerControls = nil

	CameraController.setSurvivorFollowEnabled(false)
	CameraController.setKeyboardPanningEnabled(true)
	state.started = false
end

function SurvivorController.destroy()
	if state.destroyed then
		return
	end

	SurvivorController.stop()
	state.localPlayer = nil
	state.initialized = false
	state.destroyed = true
end

return table.freeze(SurvivorController)
