--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionLifecycleVisibilityController.luau")

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("ExpeditionNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"ExpeditionLifecycleVisibilityController must bound ExpeditionNetwork"
)

for _, childName in { "State", "ReadState" } do
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		"ExpeditionLifecycleVisibilityController must bound ExpeditionNetwork." .. childName
	)
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"ExpeditionLifecycleVisibilityController must not use an unbounded ExpeditionNetwork." .. childName .. " wait"
	)
end

for _, message in
	{
		"ExpeditionNetwork did not become available before the client bootstrap timeout",
		"ExpeditionNetwork.State did not become available before the client bootstrap timeout",
		"ExpeditionNetwork.ReadState did not become available before the client bootstrap timeout",
	}
do
	assert(
		string.find(source, message, 1, true) ~= nil,
		"missing expedition lifecycle bootstrap assertion: " .. message
	)
end

print("ExpeditionLifecycleNetworkWaitSourceAudit: ExpeditionNetwork startup waits are bounded")
