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

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Config.MeleeCombatConfig)
local MeleePresentationController = require(script.Parent.MeleePresentationController)
local WeaponController = require(script.Parent.WeaponController)

local Controller = {}
local localPlayer = Players.LocalPlayer
local AttributeName = PrimaryCombatModeContracts.AttributeName
local ModeIds = PrimaryCombatModeContracts.ModeIds
local LifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"
local FIRE_ACTION_NAME = "LK_Fire"

local started = false
local meleeBound = false
local requestSequence = 0
local lastLocalSwingClock = -math.huge
local modeConnection: RBXScriptConnection? = nil
local mouseConnection: RBXScriptConnection? = nil
local meleeNetwork = ReplicatedStorage:WaitForChild("MeleeNetwork", NETWORK_WAIT_SECONDS)
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
	-- This replicated life state is presentation/input guidance only. Failing
	-- closed here prevents false local swings and useless traffic while down/dead;
	-- the server still independently owns and revalidates combat eligibility.
	if localPlayer:GetAttribute(LIFE_STATE_ATTRIBUTE) ~= LifeStateIds.Alive then
		return
	end
	local direction = currentAimDirection()
	if direction == nil then
		return
	end

	-- This local cadence is presentation/traffic prediction only. The server-owned
	-- MeleeCombatService remains authoritative and independently enforces the same
	-- configured cadence for every valid swing attempt.
	local nowClock = os.clock()
	if nowClock - lastLocalSwingClock < MeleeCombatConfig.OpeningWeapon.CadenceSeconds then
		return
	end
	lastLocalSwingClock = nowClock
	MeleePresentationController.playLocalSwing()

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

local function presentMeleeHud()
	local weapon = MeleeCombatConfig.OpeningWeapon
	localPlayer:SetAttribute("LK_HUD_WeaponId", weapon.WeaponId)
	localPlayer:SetAttribute("LK_HUD_WeaponName", weapon.ShortName)
	localPlayer:SetAttribute("LK_HUD_LoadedRounds", nil)
	localPlayer:SetAttribute("LK_HUD_ReserveRounds", nil)
	localPlayer:SetAttribute("LK_HUD_MagazineCapacity", nil)
	localPlayer:SetAttribute("LK_HUD_CombatStatus", "RECOVER A FIREARM")
	localPlayer:SetAttribute("LK_HUD_CombatStatusUntil", nil)
end

local function bindMelee()
	if meleeBound then
		return
	end
	-- WeaponController owns mouse/R2/touch firearm intent. Stop it first so the
	-- same physical press cannot reach both authoritative combat paths.
	WeaponController.stop()
	lastLocalSwingClock = -math.huge
	presentMeleeHud()
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
	lastLocalSwingClock = -math.huge
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
	lastLocalSwingClock = -math.huge
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
