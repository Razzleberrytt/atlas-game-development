--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "atmosphere assertion failed", 2) end
end

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionAtmosphereController.luau")
assert(source:find("Workspace:FindFirstChild%(\"ExpeditionRooms\"%)") ~= nil, "atmosphere must follow expedition lifecycle")
assert(source:find("local function restore", 1, true) ~= nil, "original Lighting state must be restorable")
assert(source:find("Atmosphere", 1, true) ~= nil, "expedition atmosphere should be created")
assert(source:find("BloomEffect", 1, true) ~= nil, "expedition bloom should be created")
assert(source:find("ColorCorrectionEffect", 1, true) ~= nil, "expedition color grade should be created")
assert(source:find("DepthOfFieldEffect", 1, true) ~= nil, "expedition depth should be created")
assert(source:find("role == \"Boss\"", 1, true) ~= nil, "boss rooms should intensify the grade")
assert(source:find("InvokeServer", 1, true) == nil and source:find("FireServer", 1, true) == nil, "atmosphere must remain presentation-only")
assert(source:find("NeedsSoundAsset", 1, true) ~= nil, "unverified audio must remain explicitly marked")

print("ExpeditionAtmosphereController.test.luau passed")
