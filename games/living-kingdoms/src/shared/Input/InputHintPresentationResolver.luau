--!strict

-- BA-062 shared display vocabulary for device-adaptive input hints. It converts
-- the canonical action map's raw key-code / binding names into short player-facing
-- tokens and formats one truthful hint per device family.
--
-- This module is pure: it listens for no input, touches no Roblox service, owns no
-- UI, and never invents a binding an action does not actually declare. When an
-- action has no direct binding on the active device family the resolver reports
-- that absence so callers can omit the hint instead of printing a key that does
-- nothing on that device.

local InputBindingHintResolver = require(script.Parent.InputBindingHintResolver)

export type ActionDefinition = InputBindingHintResolver.ActionDefinition

export type HintPresentation = {
	ResolutionId: string,
	DeviceFamilyId: string,
	BindingSourceId: string?,
	Tokens: { string },
	Text: string?,
}

-- Raw binding name -> player-facing token. Anything absent falls through
-- unchanged, so a single-letter keyboard key needs no entry.
local DisplayTokens = table.freeze({
	-- Keyboard
	One = "1",
	Two = "2",
	Three = "3",
	KeypadOne = "NUM 1",
	KeypadTwo = "NUM 2",
	KeypadThree = "NUM 3",
	LeftShift = "SHIFT",
	Space = "SPACE",
	Escape = "ESC",

	-- Mouse
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	MouseButton3 = "MMB",
	MouseMovement = "MOUSE",

	-- Gamepad
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonR1 = "RB",
	ButtonR2 = "RT",
	ButtonL1 = "LB",
	ButtonL2 = "LT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	DPadUp = "↑",
	DPadDown = "↓",
	DPadLeft = "←",
	DPadRight = "→",
	Thumbstick1 = "L STICK",
	Thumbstick2 = "R STICK",

	-- Touch. These name an affordance that is actually drawn on screen; they are
	-- deliberately not key names, because touch has no keys to claim.
	NativeMoveThumbstick = "THUMBSTICK",
	NativeJumpButton = "ON-SCREEN",
	NativeCameraDrag = "DRAG",
	GeneratedActionButton = "ON-SCREEN",
	MobileActionButton = "ON-SCREEN",
	PromptTap = "TAP PROMPT",
	GuiButton = "TAP",
})

local Resolver = {
	DisplayTokens = DisplayTokens,
	DeviceFamilyIds = InputBindingHintResolver.DeviceFamilyIds,
	ResolutionIds = InputBindingHintResolver.ResolutionIds,
	BindingSourceIds = InputBindingHintResolver.BindingSourceIds,
}

local SourceFieldNames = table.freeze({
	Keyboard = "KeyboardKeyCodeNames",
	Mouse = "MouseInputTypeNames",
	Gamepad = "GamepadKeyCodeNames",
	Touch = "TouchBindingIds",
})

function Resolver.displayToken(name: unknown): string?
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return DisplayTokens[name] or name
end

local function presentation(
	resolutionId: string,
	deviceFamilyId: string,
	bindingSourceId: string?,
	tokens: { string },
	text: string?
): HintPresentation
	return table.freeze({
		ResolutionId = resolutionId,
		DeviceFamilyId = deviceFamilyId,
		BindingSourceId = bindingSourceId,
		Tokens = table.freeze(tokens),
		Text = text,
	})
end

--[[
	Resolves every display token belonging to the one binding source that
	`InputBindingHintResolver` selected for this device family.

	`options.MaximumTokens` bounds how many tokens are returned (the numbered
	choice action declares six keyboard names but a prompt should show three).
	`options.Separator` joins them into `Text`; it defaults to " / ".
]]
function Resolver.resolve(
	definition: unknown,
	deviceFamilyId: string,
	options: { MaximumTokens: number?, Separator: string? }?
): HintPresentation
	local hint = InputBindingHintResolver.resolve(definition, deviceFamilyId)
	if hint.ResolutionId ~= Resolver.ResolutionIds.Available or hint.BindingSourceId == nil then
		return presentation(hint.ResolutionId, deviceFamilyId, nil, {}, nil)
	end

	local fieldName = SourceFieldNames[hint.BindingSourceId]
	local rawNames = (definition :: ActionDefinition)[fieldName]
	if type(rawNames) ~= "table" then
		return presentation(Resolver.ResolutionIds.Unavailable, deviceFamilyId, nil, {}, nil)
	end

	local maximum = if options ~= nil and type(options.MaximumTokens) == "number"
		then math.max(0, math.floor(options.MaximumTokens))
		else math.huge
	local separator = if options ~= nil and type(options.Separator) == "string" then options.Separator else " / "

	local tokens: { string } = {}
	for _, rawName in rawNames do
		if #tokens >= maximum then
			break
		end
		local token = Resolver.displayToken(rawName)
		if token ~= nil then
			table.insert(tokens, token)
		end
	end

	if #tokens == 0 then
		return presentation(Resolver.ResolutionIds.Unavailable, deviceFamilyId, nil, {}, nil)
	end

	return presentation(
		Resolver.ResolutionIds.Available,
		deviceFamilyId,
		hint.BindingSourceId,
		tokens,
		table.concat(tokens, separator)
	)
end

--[[
	Convenience for label surfaces: returns the joined hint text, or nil when the
	action has no direct binding on this device family. Callers must treat nil as
	"omit this hint", never as "fall back to the keyboard key".
]]
function Resolver.resolveText(
	definition: unknown,
	deviceFamilyId: string,
	options: { MaximumTokens: number?, Separator: string? }?
): string?
	return Resolver.resolve(definition, deviceFamilyId, options).Text
end

return table.freeze(Resolver)
