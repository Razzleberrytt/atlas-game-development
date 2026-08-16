--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/UI/InterfaceTheme.luau"
local source = fs.readFile(path)

local requiredTokens = {
	"PanelDeep",
	"PanelRaised",
	"PanelHighlight",
	"AccentBright",
	"TextFaint",
	"BackdropTransparency",
	"PanelTransparency",
	"TextStrokeTransparency",
}

for _, token in requiredTokens do
	assert(string.find(source, token, 1, true) ~= nil, "InterfaceTheme missing visual hierarchy token: " .. token)
end

assert(
	string.find(source, "function InterfaceTheme.surfaceGradient", 1, true) ~= nil,
	"InterfaceTheme must own shared surface gradient styling"
)
assert(
	string.find(source, 'gradient.Name = "SurfaceGradient"', 1, true) ~= nil,
	"InterfaceTheme surface gradients must remain identifiable"
)
assert(
	string.find(source, "InterfaceTheme.surfaceGradient(frame)", 1, true) ~= nil,
	"InterfaceTheme panels must use the canonical depth gradient"
)
assert(
	string.find(source, "InterfaceTheme.Opacity.TextStrokeTransparency", 1, true) ~= nil,
	"InterfaceTheme labels must use centralized text-edge opacity"
)
assert(
	string.find(source, "InterfaceTheme.Opacity.BackdropTransparency", 1, true) ~= nil,
	"InterfaceTheme backdrops must use centralized opacity"
)

print("InterfaceThemeVisualHierarchySourceAudit: shared visual hierarchy is canonical")
