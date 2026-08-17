--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/MatchResultController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("MissionNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"MatchResultController must bound MissionNetwork"
)
assert(
	string.find(source, "MissionNetwork did not become available before the client bootstrap timeout", 1, true) ~= nil,
	"MatchResultController must fail closed when MissionNetwork is absent"
)
assert(
	string.find(source, 'missionNetwork:WaitForChild("Result", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"MatchResultController must bound MissionNetwork.Result"
)
assert(
	string.find(source, 'missionNetwork:WaitForChild("Result")', 1, true) == nil,
	"MatchResultController must not use an unbounded MissionNetwork.Result wait"
)
assert(
	string.find(source, "MissionNetwork.Result did not become available before the client bootstrap timeout", 1, true)
		~= nil,
	"MatchResultController must fail closed when MissionNetwork.Result is absent"
)

print("MatchResultNetworkWaitSourceAudit: MissionNetwork waits are bounded")
