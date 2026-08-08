--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "environment visual assertion failed", 2)
	end
end

local builder = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionEnvironmentBuilder.luau")
local placement = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")
local controller =
	fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionEnvironmentAnimationController.luau")

assert(
	builder:find("Random.new%(seed %+ placement.Index %* 7919%)") ~= nil,
	"dressing must be deterministic per seed and room"
)
assert(builder:find("ParticleEmitter", 1, true) ~= nil, "dressing should include bounded environmental particles")
assert(builder:find('roleId == "Boss"', 1, true) ~= nil, "boss rooms need distinct visual treatment")
assert(builder:find("EnvironmentVisuals", 1, true) ~= nil, "all dressing should share a cleanup folder")
assert(
	placement:find("ExpeditionEnvironmentBuilder.decorate", 1, true) ~= nil,
	"room placement must mount environment dressing"
)
assert(controller:find("MAX_TRACKED = 96", 1, true) ~= nil, "animation work must remain bounded")
assert(
	controller:find("RemoteEvent", 1, true) == nil and controller:find("InvokeServer", 1, true) == nil,
	"visual animation cannot send gameplay requests"
)
assert(controller:find("RenderStepped", 1, true) ~= nil, "visuals should use one shared animation loop")

print("ExpeditionEnvironmentVisuals.test.luau passed")
