--!strict

local fs = require("@lune/fs")

local expeditionSource = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionHUDController.luau")
local survivalSource = fs.readFile("games/living-kingdoms/src/client/Controllers/SurvivalHUDController.luau")

local function assertContains(source: string, token: string, message: string)
	assert(string.find(source, token, 1, true) ~= nil, message)
end

assertContains(expeditionSource, 'Instance.new("UISizeConstraint")', "expedition HUD must cap its responsive width")
assertContains(expeditionSource, "PANEL_HORIZONTAL_MARGIN", "expedition HUD must preserve horizontal viewport margins")
assertContains(expeditionSource, "PANEL_MAX_WIDTH", "expedition HUD must preserve its desktop maximum width")
assertContains(survivalSource, 'Instance.new("UISizeConstraint")', "survival toast must cap its responsive width")
assertContains(survivalSource, "TOAST_HORIZONTAL_MARGIN", "survival toast must preserve horizontal viewport margins")
assertContains(survivalSource, "TOAST_MAX_WIDTH", "survival toast must preserve its desktop maximum width")

print("ResponsiveHUDWidthsSource.test.luau passed")
