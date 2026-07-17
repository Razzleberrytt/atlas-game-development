--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "landmark accent resolver test failed", 2)
	end
end

local path = "games/living-kingdoms/src/client/Presentation/LandmarkAccentPresentationResolver.luau"
local resolver = luau.load(fs.readFile(path), {
	debugName = "LandmarkAccentPresentationResolver",
	injectGlobals = true,
})()

check(resolver.resolve("RangerStation", "RangerStation", true) == resolver.StyleIds.RangerStation)
check(
	resolver.resolve("MilitaryRoadblock", "MilitaryRoadblock", true) == resolver.StyleIds.MilitaryRoadblock
)
check(resolver.resolve("RangerStation", "MilitaryRoadblock", true) == nil, "mismatched identity must hide")
check(resolver.resolve("MilitaryRoadblock", "RangerStation", true) == nil, "mismatched identity must hide")
check(resolver.resolve("RangerStation", "RangerStation", false) == nil, "non-graybox model must hide")
check(resolver.resolve("LookoutTower", "LookoutTower", true) == nil, "objective-area landmark must stay excluded")
check(
	resolver.resolve("ExtractionClearing", "ExtractionClearing", true) == nil,
	"future extraction landmark must stay excluded"
)
check(resolver.resolve(nil, nil, true) == nil, "malformed identity must hide")

check(table.isfrozen(resolver), "resolver must be immutable")
check(table.isfrozen(resolver.StyleIds), "style vocabulary must be immutable")

print("landmark accent resolver tests passed")
