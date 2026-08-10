--!strict

--[[
	Single client-side owner of "which input device is the player actually using".

	Every hint-bearing surface needs this answer, and before this module each one
	re-derived it from `UserInputService:GetLastInputType()`. That is wrong on its
	own: Roblox reports `Focus` through the same channel as real input whenever the
	window regains focus, plus `TextInput`, `InputMethod` and `None`. A surface
	that maps those onto a device family rewrites a gamepad player's hints as
	keyboard text the moment they alt-tab back in.

	This module keeps the last *classified* family instead. Unclassifiable input is
	ignored, not resolved. The capability default is used only until a real device
	has been observed.

	It owns no gameplay and no presentation; it reports a fact and nothing else.
	Initialization is lazy so it never adds a bootstrap-ordering dependency.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputDeviceFamilyResolver = require(ReplicatedStorage.Shared.Input.InputDeviceFamilyResolver)

local ActiveInputDeviceFamily = {}

local bound = false
local currentFamilyId: string? = nil
local connection: RBXScriptConnection? = nil
local changedSignal = Instance.new("BindableEvent")
changedSignal.Name = "ActiveInputDeviceFamilyChanged"

-- Used only until a real device has been seen. Touch-only devices should not be
-- told to press keys before their first touch registers.
local function capabilityDefault(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return InputDeviceFamilyResolver.DeviceFamilyIds.Touch
	end
	return InputDeviceFamilyResolver.DeviceFamilyIds.KeyboardPointer
end

local function observe(inputType: Enum.UserInputType)
	local adopted = InputDeviceFamilyResolver.adopt(inputType.Name, currentFamilyId)
	if adopted == nil or adopted == currentFamilyId then
		return
	end
	currentFamilyId = adopted
	changedSignal:Fire(adopted)
end

local function ensureBound()
	if bound then
		return
	end
	bound = true
	currentFamilyId = InputDeviceFamilyResolver.adopt(UserInputService:GetLastInputType().Name, nil)
	connection = UserInputService.LastInputTypeChanged:Connect(observe)
end

--[[
	The device family to present hints for. Never nil: falls back to the
	capability default until a real device has been observed.
]]
function ActiveInputDeviceFamily.get(): string
	ensureBound()
	return currentFamilyId or capabilityDefault()
end

--[[
	Fires only when the family actually changes, so a surface that re-renders on
	this signal is not woken by every window focus event.
]]
function ActiveInputDeviceFamily.onChanged(callback: (string) -> ()): RBXScriptConnection
	assert(type(callback) == "function", "onChanged callback must be a function")
	ensureBound()
	return changedSignal.Event:Connect(callback)
end

function ActiveInputDeviceFamily.stop()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	bound = false
	currentFamilyId = nil
end

return table.freeze(ActiveInputDeviceFamily)
