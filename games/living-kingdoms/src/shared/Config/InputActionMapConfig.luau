--!strict

-- BA-062 canonical semantic input map. This module describes bindings and
-- ownership only; it does not listen for input, mutate gameplay state, or own UI.

export type ActionDefinition = {
	ActionId: string,
	OwnerId: string,
	MechanismId: string,
	KeyboardKeyCodeNames: { string },
	MouseInputTypeNames: { string },
	GamepadKeyCodeNames: { string },
	TouchBindingIds: { string },
}

local function frozenList(...: string): { string }
	return table.freeze({ ... })
end

local function action(
	actionId: string,
	ownerId: string,
	mechanismId: string,
	keyboard: { string },
	mouse: { string },
	gamepad: { string },
	touch: { string }
): ActionDefinition
	return table.freeze({
		ActionId = actionId,
		OwnerId = ownerId,
		MechanismId = mechanismId,
		KeyboardKeyCodeNames = keyboard,
		MouseInputTypeNames = mouse,
		GamepadKeyCodeNames = gamepad,
		TouchBindingIds = touch,
	})
end

local Actions: { [string]: ActionDefinition } = {
	Move = action(
		"Move",
		"NativePlayerControls",
		"Engine",
		frozenList("W", "A", "S", "D"),
		frozenList(),
		frozenList("Thumbstick1"),
		frozenList("NativeMoveThumbstick")
	),
	Jump = action(
		"Jump",
		"NativePlayerControls",
		"Engine",
		frozenList("Space"),
		frozenList(),
		frozenList("ButtonA"),
		frozenList("NativeJumpButton")
	),
	CameraLook = action(
		"CameraLook",
		"NativePlayerControls",
		"Engine",
		frozenList(),
		frozenList("MouseMovement"),
		frozenList("Thumbstick2"),
		frozenList("NativeCameraDrag")
	),
	Fire = action(
		"Fire",
		"WeaponController",
		"Mixed",
		frozenList(),
		frozenList("MouseButton1"),
		frozenList("ButtonR2"),
		frozenList("GeneratedActionButton")
	),
	Reload = action(
		"Reload",
		"WeaponController",
		"Mixed",
		frozenList("R"),
		frozenList(),
		frozenList("ButtonR1"),
		frozenList("MobileActionButton")
	),
	Sprint = action(
		"Sprint",
		"SurvivorController",
		"Mixed",
		frozenList("LeftShift"),
		frozenList(),
		frozenList("ButtonL3"),
		frozenList("MobileActionButton")
	),
	ClassAction = action(
		"ClassAction",
		"ClassActionController",
		"ContextAction",
		frozenList("Q"),
		frozenList(),
		frozenList("ButtonB"),
		frozenList("GeneratedActionButton")
	),
	Flashlight = action(
		"Flashlight",
		"PersonalFlashlightController",
		"ContextAction",
		frozenList("F"),
		frozenList(),
		frozenList("ButtonY"),
		frozenList("GeneratedActionButton")
	),
	SquadPing = action(
		"SquadPing",
		"SquadPingController",
		"ContextAction",
		frozenList("G"),
		frozenList("MouseButton3"),
		frozenList("DPadUp"),
		frozenList("GeneratedActionButton")
	),
	Revive = action(
		"Revive",
		"OperativeLifeController",
		"ContextAction",
		frozenList("V"),
		frozenList(),
		frozenList("DPadDown"),
		frozenList("GeneratedActionButton")
	),
	Interact = action(
		"Interact",
		"WorldPrompts",
		"EnginePrompt",
		frozenList("E"),
		frozenList(),
		frozenList("ButtonX"),
		frozenList("PromptTap")
	),
	UpgradeChoice = action(
		"UpgradeChoice",
		"HordeHUDController",
		"RawInputAndGui",
		frozenList("One", "Two", "Three", "KeypadOne", "KeypadTwo", "KeypadThree"),
		frozenList("MouseButton1"),
		frozenList(),
		frozenList("GuiButton")
	),
	RelicChoice = action(
		"RelicChoice",
		"RunBuildHUDController",
		"RawInputAndGui",
		frozenList("One", "Two", "Three", "KeypadOne", "KeypadTwo", "KeypadThree"),
		frozenList("MouseButton1"),
		frozenList(),
		frozenList("GuiButton")
	),
	OpenCharacter = action(
		"OpenCharacter",
		"RPGMenuController",
		"RawInputAndGui",
		frozenList("C"),
		frozenList("MouseButton1"),
		frozenList(),
		frozenList("GuiButton")
	),
	OpenInventory = action(
		"OpenInventory",
		"RPGMenuController",
		"RawInputAndGui",
		frozenList("I"),
		frozenList("MouseButton1"),
		frozenList(),
		frozenList("GuiButton")
	),
	CloseRPGModal = action(
		"CloseRPGModal",
		"RPGMenuController",
		"RawInputAndGui",
		frozenList("Escape"),
		frozenList("MouseButton1"),
		frozenList(),
		frozenList("GuiButton")
	),
	CloseHubUI = action(
		"CloseHubUI",
		"HubPreparationController",
		"RawInput",
		frozenList("Escape"),
		frozenList(),
		frozenList(),
		frozenList()
	),
}

local ActionOrder = table.freeze({
	"Move",
	"Jump",
	"CameraLook",
	"Fire",
	"Reload",
	"Sprint",
	"ClassAction",
	"Flashlight",
	"SquadPing",
	"Revive",
	"Interact",
	"UpgradeChoice",
	"RelicChoice",
	"OpenCharacter",
	"OpenInventory",
	"CloseRPGModal",
	"CloseHubUI",
})

local InputActionMapConfig = {
	Version = 1,
	Actions = table.freeze(Actions),
	ActionOrder = ActionOrder,
}

function InputActionMapConfig.get(actionId: string): ActionDefinition?
	return Actions[actionId]
end

return table.freeze(InputActionMapConfig)
