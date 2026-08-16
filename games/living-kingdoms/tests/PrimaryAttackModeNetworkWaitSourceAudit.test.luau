--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/PrimaryAttackModeController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("MeleeNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"PrimaryAttackModeController must bound MeleeNetwork"
)
assert(
	string.find(source, "MeleeNetwork did not become available before the client bootstrap timeout", 1, true) ~= nil,
	"PrimaryAttackModeController must fail closed when MeleeNetwork is absent"
)
assert(
	string.find(source, 'meleeNetwork:WaitForChild("StrikeIntent", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"PrimaryAttackModeController must bound MeleeNetwork.StrikeIntent"
)
assert(
	string.find(source, 'meleeNetwork:WaitForChild("StrikeIntent")', 1, true) == nil,
	"PrimaryAttackModeController must not use an unbounded MeleeNetwork.StrikeIntent wait"
)
assert(
	string.find(source, "MeleeNetwork.StrikeIntent did not become available before the client bootstrap timeout", 1, true)
		~= nil,
	"PrimaryAttackModeController must fail closed when MeleeNetwork.StrikeIntent is absent"
)

print("PrimaryAttackModeNetworkWaitSourceAudit: MeleeNetwork waits are bounded")
