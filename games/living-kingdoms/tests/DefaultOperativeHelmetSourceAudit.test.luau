--!strict

local fs = require("@lune/fs")

local configPath = "games/living-kingdoms/src/shared/Visual/OperativeHelmetConfig.luau"
local controllerPath = "games/living-kingdoms/src/client/Controllers/OperativeHelmetController.luau"
local bootstrapPath = "games/living-kingdoms/src/client/init.client.luau"

local config = fs.readFile(configPath)
local controller = fs.readFile(controllerPath)
local bootstrap = fs.readFile(bootstrapPath)

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

assert(contains(config, 'Version = "VIS-0106-v1-default-army-helmet"'), "helmet version is missing")
assert(contains(config, 'PresentationModelName = "OperativeDefaultArmyHelmet"'), "helmet model name drifted")
assert(contains(config, 'HeadPartName = "Head"'), "helmet must attach to the character head")
assert(contains(config, "MaximumPartsPerHelmet = 3"), "helmet part ceiling drifted")
assert(contains(config, '"HelmetShell"'), "helmet shell is missing")
assert(contains(config, '"HelmetFrontBrim"'), "helmet front brim is missing")
assert(contains(config, '"HelmetRearRim"'), "helmet rear rim is missing")

assert(contains(controller, 'Instance.new("WeldConstraint")'), "helmet parts must be welded")
assert(contains(controller, "weld.Part0 = head"), "helmet weld must anchor to the head")
assert(contains(controller, "part.Massless = true"), "helmet parts must be massless")
assert(contains(controller, "part.CanCollide = false"), "helmet parts must not collide")
assert(contains(controller, "part.CanTouch = false"), "helmet parts must not generate touches")
assert(contains(controller, "part.CanQuery = false"), "helmet parts must not affect queries")
assert(contains(controller, "Players.PlayerAdded:Connect"), "late-joining players must receive helmets")
assert(contains(controller, "player.CharacterAdded:Connect"), "respawned characters must receive helmets")

for _, prohibited in {
	'Instance.new("RemoteEvent")',
	'Instance.new("RemoteFunction")',
	"FireServer",
	"OnServerEvent",
	"SetNetworkOwner",
	"ApplyDescription",
	"LoadCharacter",
	"DataStoreService",
	"WalkSpeed",
	"JumpPower",
	"Health =",
} do
	assert(not contains(controller, prohibited), "helmet controller contains prohibited gameplay API: " .. prohibited)
end

assert(
	contains(bootstrap, "local OperativeHelmetController = require(script.Controllers.OperativeHelmetController)"),
	"helmet controller is not required by client bootstrap"
)
assert(contains(bootstrap, "OperativeHelmetController.start()"), "helmet controller is not started")

print("Default operative helmet source audit passed")
