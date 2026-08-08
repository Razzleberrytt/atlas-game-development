--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredWorldPathConfig assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredWorldPathConfig.luau"), {
	debugName = "RecoveredWorldPathConfig",
	injectGlobals = true,
})()

check(config.Version == "BA-005-WORLDPATH-v1")
check(config.SourceContentId == "route.world.primary")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.Evidence.SegmentCount == 189)
check(config.Route.RotationId == 2)
check(config.Route.MaterialEnumValue == 880)
check(config.Route.ColorBytes.r == 100)
check(config.Route.ColorBytes.g == 95)
check(config.Route.ColorBytes.b == 90)
check(config.Route.Anchored == true)
check(config.Route.CanCollide == true)
check(config.Route.CanQuery == true)
check(config.Route.CanTouch == true)
check(config.Route.CastShadow == true)

local recoveredSamples = {
	[1] = -2.9629626274108887,
	[2] = -10.925925254821777,
	[3] = -18.888891220092773,
	[10] = -74.62963104248047,
	[20] = -154.25926208496094,
	[40] = -313.5185241699219,
	[60] = -472.7778015136719,
	[80] = -632.0370483398438,
	[100] = -791.2963256835938,
	[120] = -950.5556030273438,
	[140] = -1109.8148193359375,
	[160] = -1269.0740966796875,
	[180] = -1428.3333740234375,
	[189] = -1500.0,
}

for index, recoveredZ in recoveredSamples do
	local center = config.segmentCenter(index)
	check(center.x == 0.0)
	check(math.abs(center.y - 0.10000000149011612) <= 1e-8)
	local drift = math.abs(center.z - recoveredZ)
	check(
		drift <= config.Evidence.MaximumCanonicalizationDriftStuds,
		string.format("segment %d drift %.9f exceeds evidence tolerance", index, drift)
	)
end

local first = config.segmentCenter(1)
local last = config.segmentCenter(189)
check(math.abs(first.z - config.Route.StartCenter.z) <= 1e-9)
check(math.abs(last.z - config.Route.EndCenter.z) <= 1e-9)

local okLow = pcall(function()
	config.segmentCenter(0)
end)
local okHigh = pcall(function()
	config.segmentCenter(190)
end)
local okFraction = pcall(function()
	config.segmentCenter(1.5)
end)
check(not okLow)
check(not okHigh)
check(not okFraction)
