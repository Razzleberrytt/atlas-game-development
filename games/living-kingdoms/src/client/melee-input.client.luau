--!strict

-- MVP 0.1 client-only melee intent origin. This script never chooses a target,
-- applies damage, or reads firearm ammunition. The server re-derives every
-- authoritative combat fact in MeleeCombatService.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ACTION_NAME = "LK_MeleeStrike"
local LOCAL_REQUEST_FLOOR_SECONDS = 0.12
local localPlayer = Players.LocalPlayer
local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local meleeIntent = combatNetwork:WaitForChild("MeleeIntent") :: RemoteEvent

local requestSequence = 0
local lastRequestLocalTimestamp = -math.huge

local function currentAimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local direction = camera.CFrame.LookVector
	return if direction.Magnitude > 0.99 then direction.Unit else nil
end

local function requestStrike(): boolean
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	local timestamp = os.clock()
	if timestamp - lastRequestLocalTimestamp < LOCAL_REQUEST_FLOOR_SECONDS then
		return false
	end
	local direction = currentAimDirection()
	if direction == nil then
		return false
	end
	lastRequestLocalTimestamp = timestamp
	requestSequence += 1
	local requestId = string.format("melee:%d:%d", localPlayer.UserId, requestSequence)
	meleeIntent:FireServer(requestId, direction)
	return true
end

local function onAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if requestStrike() then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(ACTION_NAME, onAction, true, Enum.KeyCode.V, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle(ACTION_NAME, "Strike")
ContextActionService:SetPosition(ACTION_NAME, UDim2.new(1, -170, 1, -190))
