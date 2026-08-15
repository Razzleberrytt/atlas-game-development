--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "responsive panel scale assertion failed", 2)
	end
end

local ResponsivePanelScale = luau.load(
	fs.readFile("games/living-kingdoms/src/client/Presentation/ResponsivePanelScale.luau"),
	{ debugName = "ResponsivePanelScale", injectGlobals = true }
)()

local desktop = ResponsivePanelScale.calculate(1920, 1080, 680, 430, 24)
assert(desktop == 1, "large viewports must preserve authored panel size")

local portrait = ResponsivePanelScale.calculate(375, 667, 680, 430, 24)
assert(portrait < 1, "narrow portrait viewports must shrink the panel")
assert(680 * portrait <= 375 - 48, "portrait panel width must fit inside viewport margin")
assert(430 * portrait <= 667 - 48, "portrait panel height must fit inside viewport margin")

local landscape = ResponsivePanelScale.calculate(667, 375, 680, 430, 24)
assert(landscape < 1, "short landscape viewports must shrink the panel")
assert(680 * landscape <= 667 - 48, "landscape panel width must fit inside viewport margin")
assert(430 * landscape <= 375 - 48, "landscape panel height must fit inside viewport margin")

local rotated = ResponsivePanelScale.calculate(667, 375, 680, 430, 24)
assert(rotated ~= portrait, "viewport orientation changes must produce a fresh scale")

print("ResponsivePanelScale.test.luau passed")
