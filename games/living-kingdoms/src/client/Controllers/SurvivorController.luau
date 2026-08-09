--!strict

--[[
	SurvivorController configures the local operative for Roblox's native
	character controls. PlayerModule remains the single movement owner, providing
	reliable keyboard, gamepad, and touch movement that is camera-relative in
	first person. This controller never writes a root transform or injects movement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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
	inputBeganConnection: RBXScriptConnection?,
	inputEndedConnection: RBXScriptConnection?,
}

local SurvivorController = {}
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	localPlayer = nil,
	playerControls = nil,
	characterAddedConnection = nil,
	inputBeganConnection = nil,
	inputEndedConnection = nil,
}

local sprinting = false

local PLAYER_MODULE_WAIT_SECONDS = 10

local function applyMovementSpeed()
	local localPlayer = state.localPlayer
	local character = if localPlayer == nil then nil else localPlayer.Character
	local humanoid = if character == nil then nil else character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid.Health > 0 then
		humanoid.WalkSpeed = if sprinting then MovementLimits.SprintingSpeed else MovementLimits.WalkingSpeed
	end
end

function SurvivorController.setSprinting(enabled: boolean)
	sprinting = enabled
	applyMovementSpeed()
end

local function configureCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	end
	if humanoid == nil then
		warn("[SurvivorController] Character has no Humanoid; native movement could not be configured")
		return
	end

	humanoid.WalkSpeed = if sprinting then MovementLimits.SprintingSpeed else MovementLimits.WalkingSpeed
	humanoid.AutoRotate = true
end

-- PlayerModule ships with the Studio place template rather than with this Rojo
-- tree, so a `rojo build` place can start without it. Both waits are bounded and
-- the result is optional: this controller starts fourth in the client bootstrap,
-- ahead of every HUD, weapon, enemy and expedition owner, so an unbounded
-- WaitForChild here stalls the entire client rather than just native movement.
local function findPlayerControls(localPlayer: Player): PlayerControls?
	local playerScripts = localPlayer:FindFirstChildOfClass("PlayerScripts")
		or localPlayer:WaitForChild("PlayerScripts", PLAYER_MODULE_WAIT_SECONDS)
	if playerScripts == nil then
		return nil
	end

	local moduleScript = playerScripts:FindFirstChild("PlayerModule")
		or playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_WAIT_SECONDS)
	if moduleScript == nil or not moduleScript:IsA("ModuleScript") then
		return nil
	end

	local loaded, controls = pcall(function()
		local playerModule = require(moduleScript) :: any
		return playerModule:GetControls()
	end)
	if not loaded or controls == nil then
		return nil
	end
	return controls :: PlayerControls
end

-- Acquired off the bootstrap thread for the same reason: native movement is an
-- enhancement to this controller, never a precondition for the controllers that
-- start after it.
local function enablePlayerControlsAsync(localPlayer: Player)
	task.spawn(function()
		local controls = findPlayerControls(localPlayer)
		if state.destroyed or not state.started then
			return
		end
		if controls == nil then
			warn(
				"[SurvivorController] PlayerModule is unavailable, so this controller cannot manage the "
					.. "control state. Roblox's built-in movement still applies and the rest of the "
					.. "client started normally."
			)
			return
		end
		state.playerControls = controls
		-- Explicitly restore PlayerModule in case an earlier controller or Studio
		-- hot reload left it disabled. PlayerModule owns every movement input path.
		controls:Enable()
	end)
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
	enablePlayerControlsAsync(localPlayer)

	CameraController.setKeyboardPanningEnabled(false)
	CameraController.setSurvivorFollowEnabled(true)
	state.characterAddedConnection = localPlayer.CharacterAdded:Connect(configureCharacter)
	state.inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftShift then
			SurvivorController.setSprinting(true)
		end
	end)
	state.inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			SurvivorController.setSprinting(false)
		end
	end)

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
	if state.inputBeganConnection ~= nil then
		state.inputBeganConnection:Disconnect()
		state.inputBeganConnection = nil
	end
	if state.inputEndedConnection ~= nil then
		state.inputEndedConnection:Disconnect()
		state.inputEndedConnection = nil
	end
	sprinting = false

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
