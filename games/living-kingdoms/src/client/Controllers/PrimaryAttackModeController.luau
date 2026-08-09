--!strict

--[[
	Routes the existing primary-attack inputs between firearm and melee ownership.
	The server-owned LK_PrimaryCombatMode attribute is the only switch. Firearm
	mode leaves WeaponController unchanged. Melee mode stops WeaponController
	before binding the same semantic LK_Fire action to one-shot melee intent, so a
	single mouse/R2/touch press cannot fan out into both weapon systems.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local WeaponController = require(script.Parent.WeaponController)

local Controller = {}
local localPlayer = Players.LocalPlayer
local AttributeName = PrimaryCombatModeContracts.AttributeName
local ModeIds = PrimaryCombatModeContracts.ModeIds
local FIRE_ACTION_NAME = "LK_Fire"

local started = false
local meleeBound = false
local requestSequence = 0
local modeConnection: RBXScriptConnection? = nil
local mouseConnection: RBXScriptConnection? = nil
local meleeNetwork = ReplicatedStorage:WaitForChild("MeleeNetwork")
local strikeIntent = meleeNetwork:WaitForChild("StrikeIntent") :: RemoteEvent

local function currentAimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local direction = camera.CFrame.LookVector
	return if direction.Magnitude > 0.99 then direction.Unit else nil
end

local function requestStrike()
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	local direction = currentAimDirection()
	if direction == nil then
		return
	end
	requestSequence += 1
	strikeIntent:FireServer("melee:" .. tostring(localPlayer.UserId) .. ":" .. tostring(requestSequence), direction)
end

local function onMeleeAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if not started or not meleeBound then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		requestStrike()
		return Enum.ContextActionResult.Sink
	end
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onMouseInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	requestStrike()
end

local function bindMelee()
	if meleeBound then
		return
	end
	-- WeaponController owns mouse/R2/touch firearm intent. Stop it first so the
	-- same physical press cannot reach both authoritative combat paths.
	WeaponController.stop()
	ContextActionService:BindAction(FIRE_ACTION_NAME, onMeleeAction, true, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(FIRE_ACTION_NAME, "Attack")
	mouseConnection = UserInputService.InputBegan:Connect(onMouseInputBegan)
	meleeBound = true
end

local function unbindMelee()
	if not meleeBound then
		return
	end
	ContextActionService:UnbindAction(FIRE_ACTION_NAME)
	if mouseConnection ~= nil then
		mouseConnection:Disconnect()
		mouseConnection = nil
	end
	meleeBound = false
	WeaponController.start()
end

local function reconcileMode()
	local modeId = localPlayer:GetAttribute(AttributeName)
	if modeId == ModeIds.Melee then
		bindMelee()
	else
		unbindMelee()
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	requestSequence = 0
	modeConnection = localPlayer:GetAttributeChangedSignal(AttributeName):Connect(reconcileMode)
	reconcileMode()
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if modeConnection ~= nil then
		modeConnection:Disconnect()
		modeConnection = nil
	end
	unbindMelee()
end

return table.freeze(Controller)
