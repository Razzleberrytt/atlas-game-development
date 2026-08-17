--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/WeaponController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"WeaponController must bound PlayerGui acquisition during client startup"
)
assert(
	string.find(source, 'localPlayer:WaitForChild("PlayerGui")', 1, true) == nil,
	"WeaponController must not use an unbounded PlayerGui wait during client startup"
)
assert(
	string.find(source, "PlayerGui unavailable after bounded wait", 1, true) ~= nil,
	"WeaponController must fail closed when PlayerGui is absent after the timeout"
)

print("WeaponPlayerGuiWaitSourceAudit: PlayerGui startup wait is bounded")
