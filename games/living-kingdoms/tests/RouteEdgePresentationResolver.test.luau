--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/client/Presentation/RouteEdgePresentationResolver.luau"), {
	debugName = "RouteEdgePresentationResolver",
	injectGlobals = true,
})()

local road = resolver.resolve({
	segmentName = "LoggingRoad3",
	widthStuds = 26,
	heightStuds = 1,
})
assertThat(road.styleId == "Road", "logging road must use road style")
assertThat(road.leftOffsetX == -14.1 and road.rightOffsetX == 14.1, "road edge offsets drifted")
assertThat(road.markerHeight == 1.9, "road guide height drifted")
assertThat(road.markerCenterY == 1.5, "road guide vertical placement drifted")

local trail = resolver.resolve({
	segmentName = "SwitchbackTrail6",
	widthStuds = 9,
	heightStuds = 0.7,
})
assertThat(trail.styleId == "Trail", "switchback must use trail style")
assertThat(trail.leftOffsetX == -5.3 and trail.rightOffsetX == 5.3, "trail edge offsets drifted")
assertThat(trail.markerWidth == 0.9 and trail.markerDepth == 0.9, "trail guide footprint drifted")
assertThat(trail.markerCenterY == 0.97, "trail guide vertical placement drifted")

for _, facts in {
	{ segmentName = "Creek1", widthStuds = 15, heightStuds = 0.5 },
	{ segmentName = "ExtractionClearing", widthStuds = 20, heightStuds = 1 },
	{ segmentName = "", widthStuds = 26, heightStuds = 1 },
	{ segmentName = "LoggingRoad1", widthStuds = 0, heightStuds = 1 },
	{ segmentName = "SwitchbackTrail1", widthStuds = 9, heightStuds = 0 / 0 },
} do
	local hidden = resolver.resolve(facts)
	assertThat(hidden.styleId == "Hidden", "non-route or malformed facts must remain hidden")
end

local frozen = resolver.resolve({ segmentName = "LoggingRoad1", widthStuds = 26, heightStuds = 1 })
local didMutate = pcall(function()
	frozen.styleId = "Hidden"
end)
assertThat(not didMutate, "route resolver output must remain immutable")

print("RouteEdgePresentationResolver: authored-route mapping and hidden-information exclusions passed")
