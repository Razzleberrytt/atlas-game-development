--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/RemoteMeleeSwingPresentationController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("MeleeNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"RemoteMeleeSwingPresentationController must bound MeleeNetwork"
)
assert(
	string.find(source, "MeleeNetwork did not become available before the client bootstrap timeout", 1, true) ~= nil,
	"RemoteMeleeSwingPresentationController must fail closed when MeleeNetwork is absent"
)
assert(
	string.find(source, 'meleeNetwork:WaitForChild("Presentation", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"RemoteMeleeSwingPresentationController must bound MeleeNetwork.Presentation"
)
assert(
	string.find(source, 'meleeNetwork:WaitForChild("Presentation")', 1, true) == nil,
	"RemoteMeleeSwingPresentationController must not use an unbounded MeleeNetwork.Presentation wait"
)
assert(
	string.find(
		source,
		"MeleeNetwork.Presentation did not become available before the client bootstrap timeout",
		1,
		true
	) ~= nil,
	"RemoteMeleeSwingPresentationController must fail closed when MeleeNetwork.Presentation is absent"
)

print("RemoteMeleeSwingPresentationNetworkWaitSourceAudit: MeleeNetwork waits are bounded")
