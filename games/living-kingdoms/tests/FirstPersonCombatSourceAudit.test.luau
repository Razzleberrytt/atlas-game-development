--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function assertThat(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local project = fs.readFile("games/living-kingdoms/default.project.json")
local camera = fs.readFile("games/living-kingdoms/src/client/Controllers/CameraController.luau")
local weapon = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")

assertThat(contains(project, '"FireIntent"'), "first-person fire remote is missing from the place tree")
assertThat(contains(camera, "Enum.CameraMode.LockFirstPerson"), "camera is not locked to first person")
assertThat(contains(camera, "Enum.MouseBehavior.LockCenter"), "first-person mouse lock is missing")
assertThat(contains(weapon, "Enum.UserInputType.MouseButton1"), "primary-fire mouse input is missing")
assertThat(contains(weapon, "camera.CFrame.LookVector"), "client aim does not follow the center crosshair")
assertThat(contains(combat, 'typeof(aimDirection) ~= "Vector3"'), "server does not type-check client aim")
assertThat(contains(combat, "AIM_CONE_MINIMUM_DOT"), "server aim-cone validation is missing")
assertThat(contains(combat, "hasClearShot"), "server line-of-sight validation was removed")
assertThat(contains(combat, "AutomaticFireResolver.resolve"), "server cadence and ammunition owner was bypassed")
assertThat(not contains(weapon, "DamageIntent"), "client gained a direct damage submission surface")

print("First-person combat source audit passed")
