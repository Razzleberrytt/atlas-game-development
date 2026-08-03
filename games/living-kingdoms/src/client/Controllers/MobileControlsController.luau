--!strict

--[[
	Mobile-only action buttons that supplement Roblox's native touch movement.
	PlayerModule owns the thumbstick, jumping, and camera, so this controller does
	not create a competing movement surface. Reload still routes through the same
	WeaponController request used by desktop input.
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local WeaponController = require(script.Parent.WeaponController)

local MobileControlsController = {}
local RELOAD_ACTION = "LK_Reload"
local started = false

local function isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function onReloadAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		WeaponController.requestReload()
	end
	return Enum.ContextActionResult.Pass
end

function MobileControlsController.start()
	if started or not isTouchDevice() then
		return
	end
	started = true

	ContextActionService:BindAction(RELOAD_ACTION, onReloadAction, true)
	ContextActionService:SetTitle(RELOAD_ACTION, "Reload")
end

function MobileControlsController.stop()
	if not started then
		return
	end
	started = false
	ContextActionService:UnbindAction(RELOAD_ACTION)
end

return table.freeze(MobileControlsController)
