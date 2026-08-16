--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/MatchResultController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, "local function cardSection", 1, true) ~= nil,
	"MatchResultController must group dense debrief information into raised cards"
)
assert(
	string.find(source, "InterfaceTheme.Palette.PanelRaised", 1, true) ~= nil,
	"MatchResultController cards must use the shared raised-surface token"
)
assert(
	string.find(source, "InterfaceTheme.surfaceGradient", 1, true) ~= nil,
	"MatchResultController cards must use the shared surface treatment"
)
assert(
	string.find(source, "InterfaceTheme.Opacity.RaisedTransparency", 1, true) ~= nil,
	"MatchResultController cards must use centralized opacity"
)
assert(
	string.find(source, "frame.Size = UDim2.fromOffset(720, 540)", 1, true) ~= nil,
	"MatchResultController debrief must retain the polished breathing-room dimensions"
)
assert(
	string.find(source, 'cardSection(frame, "Events"', 1, true) ~= nil,
	"MatchResultController operation facts must remain visually grouped"
)
assert(
	string.find(source, 'cardSection(frame, "Contributions"', 1, true) ~= nil,
	"MatchResultController squad contribution must remain visually grouped"
)
assert(
	string.find(source, 'cardSection(frame, "Build"', 1, true) ~= nil,
	"MatchResultController build summary must remain visually grouped"
)

print("MatchResultVisualHierarchySourceAudit: debrief hierarchy is canonical")
