--!strict

-- BA-062 pure device-binding hint resolver. It selects one truthful display
-- token from an action-map definition without listening for input or claiming
-- that indirect GUI navigation is a direct shortcut.

export type ActionDefinition = {
	KeyboardKeyCodeNames: { string },
	MouseInputTypeNames: { string },
	GamepadKeyCodeNames: { string },
	TouchBindingIds: { string },
}

export type HintResolution = {
	ResolutionId: string,
	DeviceFamilyId: string,
	BindingSourceId: string?,
	BindingToken: string?,
}

local DeviceFamilyIds = table.freeze({
	KeyboardPointer = "KeyboardPointer",
	Gamepad = "Gamepad",
	Touch = "Touch",
})

local ResolutionIds = table.freeze({
	Available = "Available",
	Unavailable = "Unavailable",
	InvalidAction = "InvalidAction",
	InvalidDeviceFamily = "InvalidDeviceFamily",
})

local BindingSourceIds = table.freeze({
	Keyboard = "Keyboard",
	Mouse = "Mouse",
	Gamepad = "Gamepad",
	Touch = "Touch",
})

local Resolver = {
	DeviceFamilyIds = DeviceFamilyIds,
	ResolutionIds = ResolutionIds,
	BindingSourceIds = BindingSourceIds,
}

local function result(
	resolutionId: string,
	deviceFamilyId: string,
	bindingSourceId: string?,
	bindingToken: string?
): HintResolution
	return table.freeze({
		ResolutionId = resolutionId,
		DeviceFamilyId = deviceFamilyId,
		BindingSourceId = bindingSourceId,
		BindingToken = bindingToken,
	})
end

local function firstToken(values: unknown): string?
	if type(values) ~= "table" then
		return nil
	end
	local token = values[1]
	return if type(token) == "string" and token ~= "" then token else nil
end

local function validActionDefinition(definition: unknown): boolean
	if type(definition) ~= "table" then
		return false
	end
	return type(definition.KeyboardKeyCodeNames) == "table"
		and type(definition.MouseInputTypeNames) == "table"
		and type(definition.GamepadKeyCodeNames) == "table"
		and type(definition.TouchBindingIds) == "table"
end

function Resolver.resolve(definition: unknown, deviceFamilyId: string): HintResolution
	if not validActionDefinition(definition) then
		return result(ResolutionIds.InvalidAction, deviceFamilyId, nil, nil)
	end
	local action = definition :: ActionDefinition

	if deviceFamilyId == DeviceFamilyIds.KeyboardPointer then
		local keyboard = firstToken(action.KeyboardKeyCodeNames)
		if keyboard ~= nil then
			return result(ResolutionIds.Available, deviceFamilyId, BindingSourceIds.Keyboard, keyboard)
		end
		local mouse = firstToken(action.MouseInputTypeNames)
		if mouse ~= nil then
			return result(ResolutionIds.Available, deviceFamilyId, BindingSourceIds.Mouse, mouse)
		end
	elseif deviceFamilyId == DeviceFamilyIds.Gamepad then
		local gamepad = firstToken(action.GamepadKeyCodeNames)
		if gamepad ~= nil then
			return result(ResolutionIds.Available, deviceFamilyId, BindingSourceIds.Gamepad, gamepad)
		end
	elseif deviceFamilyId == DeviceFamilyIds.Touch then
		local touch = firstToken(action.TouchBindingIds)
		if touch ~= nil then
			return result(ResolutionIds.Available, deviceFamilyId, BindingSourceIds.Touch, touch)
		end
	else
		return result(ResolutionIds.InvalidDeviceFamily, deviceFamilyId, nil, nil)
	end

	return result(ResolutionIds.Unavailable, deviceFamilyId, nil, nil)
end

return table.freeze(Resolver)
