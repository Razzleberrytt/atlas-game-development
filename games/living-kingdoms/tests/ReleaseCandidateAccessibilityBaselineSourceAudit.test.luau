--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then error(message, 2) end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local config = fs.readFile("games/living-kingdoms/src/shared/Config/PresentationAccessibilityConfig.luau")
local state = fs.readFile("games/living-kingdoms/src/client/Presentation/PresentationAccessibilityState.luau")
local panel = fs.readFile("games/living-kingdoms/src/client/Controllers/PresentationSettingsController.luau")

for _, setting in { "CameraShake", "Blood", "FlashIntensity", "FloatingCombatText" } do
	assertThat(contains(config, setting), "RC comfort catalog is missing " .. setting)
	assertThat(contains(panel, "SettingIds." .. setting), "RC settings panel does not expose " .. setting)
end

for _, level in { "Full", "Reduced", "Off" } do
	assertThat(contains(config, level), "RC comfort level model is missing " .. level)
end

assertThat(contains(panel, "configured comfort setting is unreachable"), "panel must fail when config grows without a reachable control")
assertThat(contains(state, "PresentationAccessibilityConfig.Settings"), "state must derive its setting catalog from config")
assertThat(not contains(state, "FireServer"), "comfort state must remain client-local")
assertThat(not contains(panel, "FireServer"), "comfort panel must own no gameplay/network authority")

print("RC 1.0 accessibility baseline: comfort catalog is bounded, client-local, and player-reachable")
