--!strict

-- BA-062 pure input-device family resolver. It classifies an observed Roblox
-- UserInputType name without querying services, inferring hardware capability,
-- or changing input ownership.

export type Resolution = {
	ResolutionId: string,
	DeviceFamilyId: string?,
	InputTypeName: string?,
}

local DeviceFamilyIds = table.freeze({
	KeyboardPointer = "KeyboardPointer",
	Gamepad = "Gamepad",
	Touch = "Touch",
})

local ResolutionIds = table.freeze({
	Classified = "Classified",
	Unknown = "Unknown",
	InvalidInput = "InvalidInput",
})

local KeyboardPointerInputTypeNames = table.freeze({
	Keyboard = true,
	MouseButton1 = true,
	MouseButton2 = true,
	MouseButton3 = true,
	MouseMovement = true,
	MouseWheel = true,
})

local GamepadInputTypeNames = table.freeze({
	Gamepad1 = true,
	Gamepad2 = true,
	Gamepad3 = true,
	Gamepad4 = true,
	Gamepad5 = true,
	Gamepad6 = true,
	Gamepad7 = true,
	Gamepad8 = true,
})

local Resolver = {
	DeviceFamilyIds = DeviceFamilyIds,
	ResolutionIds = ResolutionIds,
}

local function result(resolutionId: string, deviceFamilyId: string?, inputTypeName: string?): Resolution
	return table.freeze({
		ResolutionId = resolutionId,
		DeviceFamilyId = deviceFamilyId,
		InputTypeName = inputTypeName,
	})
end

function Resolver.resolve(inputTypeName: unknown): Resolution
	if type(inputTypeName) ~= "string" or inputTypeName == "" then
		return result(ResolutionIds.InvalidInput, nil, nil)
	end
	if KeyboardPointerInputTypeNames[inputTypeName] == true then
		return result(ResolutionIds.Classified, DeviceFamilyIds.KeyboardPointer, inputTypeName)
	end
	if GamepadInputTypeNames[inputTypeName] == true then
		return result(ResolutionIds.Classified, DeviceFamilyIds.Gamepad, inputTypeName)
	end
	if inputTypeName == "Touch" then
		return result(ResolutionIds.Classified, DeviceFamilyIds.Touch, inputTypeName)
	end
	return result(ResolutionIds.Unknown, nil, inputTypeName)
end

return table.freeze(Resolver)
