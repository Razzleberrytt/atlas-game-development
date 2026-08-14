--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionLobbyController.luau")

local function assertContains(token: string, message: string)
	assert(string.find(source, token, 1, true) ~= nil, message)
end

assertContains("ResponsivePanelScale", "lobby must use the shared responsive panel scale helper")
assertContains('Instance.new("UIScale")', "lobby must scale its fixed-design panel")
assertContains("ViewportProbe", "lobby must measure the rendered viewport")
assertContains('GetPropertyChangedSignal("AbsoluteSize")', "lobby must react when viewport dimensions change")
assertContains("PANEL_VIEWPORT_MARGIN", "lobby must retain a viewport safety margin")

print("ExpeditionLobbyResponsiveSource.test.luau passed")
