--!strict

-- The shared client design-token system. Locks the token invariants that keep the
-- interface coherent — a descending type scale, an ascending spacing scale, a
-- readable palette — and audits that the surfaces which adopted it consume it
-- rather than re-hard-coding their own colours.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

-- The module builds its palette from Color3.fromRGB and its fonts from Enum.Font
-- at load, so stub just enough of the Roblox globals to capture the values.
local function color3(r: number, g: number, b: number)
	return { r = r, g = g, b = b, _isColor3 = true }
end

local theme = luau.load(fs.readFile("games/living-kingdoms/src/client/UI/InterfaceTheme.luau"), {
	debugName = "InterfaceTheme",
	environment = {
		Color3 = { fromRGB = color3 },
		Enum = setmetatable({}, {
			__index = function(_self, _key)
				return setmetatable({}, {
					__index = function(_inner, name)
						return "enum:" .. tostring(name)
					end,
				})
			end,
		}),
		UDim = {
			new = function(scale: number, offset: number)
				return { scale = scale, offset = offset }
			end,
		},
	},
	injectGlobals = true,
})()

-- The module and every token table are frozen, so a screen cannot mutate a shared
-- token and corrupt every other surface.
assertThat(table.isfrozen(theme), "the theme module must be frozen")
for _, tokenGroup in { "Palette", "Font", "TextSize", "Spacing", "Radius", "Stroke" } do
	assertThat(table.isfrozen(theme[tokenGroup]), tokenGroup .. " must be frozen")
end

-- Every palette entry is a real colour, and the values are in range.
local requiredColors =
	{ "Void", "Panel", "PanelRaised", "Accent", "AccentDim", "Danger", "TextPrimary", "TextMuted", "Ink", "Line" }
for _, name in requiredColors do
	local colour = theme.Palette[name]
	assertThat(type(colour) == "table" and colour._isColor3 == true, "palette entry must be a colour: " .. name)
	for _, channel in { colour.r, colour.g, colour.b } do
		assertThat(
			type(channel) == "number" and channel >= 0 and channel <= 255 and channel % 1 == 0,
			"palette channel out of range: " .. name
		)
	end
end

-- Readability: primary text must sit far from the panel it reads on, and the
-- accent must be clearly warmer/brighter than the panel, so neither relies on
-- hue alone. Use simple perceived luminance separation.
local function luminance(colour): number
	return 0.299 * colour.r + 0.587 * colour.g + 0.114 * colour.b
end
assertThat(
	luminance(theme.Palette.TextPrimary) - luminance(theme.Palette.Panel) > 120,
	"primary text must contrast strongly against the panel"
)
assertThat(
	luminance(theme.Palette.Accent) - luminance(theme.Palette.Panel) > 100,
	"the accent must read clearly against the panel"
)
assertThat(
	luminance(theme.Palette.TextMuted) > luminance(theme.Palette.Line),
	"muted text must still be brighter than a neutral separator"
)

-- Exactly three type roles, and a strictly descending type scale so hierarchy is
-- unambiguous.
local roleCount = 0
for _ in theme.Font do
	roleCount += 1
end
assertThat(roleCount == 3, "the interface must keep exactly three type roles")
local scale = {
	theme.TextSize.Display,
	theme.TextSize.Title,
	theme.TextSize.Subtitle,
	theme.TextSize.Body,
	theme.TextSize.Caption,
}
for index = 2, #scale do
	assertThat(type(scale[index]) == "number", "the type scale must be numeric")
	assertThat(scale[index] < scale[index - 1], "the type scale must strictly descend")
end

-- A strictly ascending spacing scale.
local spacing =
	{ theme.Spacing.XSmall, theme.Spacing.Small, theme.Spacing.Medium, theme.Spacing.Large, theme.Spacing.XLarge }
for index = 2, #spacing do
	assertThat(spacing[index] > spacing[index - 1], "the spacing scale must strictly ascend")
end
assertThat(theme.Spacing.XSmall == 4, "the spacing scale is 4-based")

-- Presentation only: the theme must own no gameplay authority or network surface.
local themeSource = fs.readFile("games/living-kingdoms/src/client/UI/InterfaceTheme.luau")
for _, forbidden in { "RemoteEvent", "RemoteFunction", "FireServer", "GetService", "damage", "Health", "task.delay" } do
	assertThat(not contains(themeSource, forbidden), "the theme must be presentation only: " .. forbidden)
end

-- The surfaces that adopted the theme consume it rather than re-hard-coding
-- colours, so a touch-up made in the theme actually reaches them.
for _, controllerName in { "MatchResultController", "RunBuildHUDController" } do
	local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/" .. controllerName .. ".luau")
	assertThat(contains(controller, "InterfaceTheme"), controllerName .. " must consume the shared theme")
	assertThat(
		not contains(controller, "Color3.fromRGB"),
		controllerName .. " must take its colours from the theme, not hard-code them"
	)
end

print(
	"InterfaceThemeConfig: frozen tokens, readable palette, ordered scales, presentation-only, and adopted by its surfaces"
)
