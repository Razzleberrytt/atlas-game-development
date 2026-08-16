--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionResultController.luau")

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("ExpeditionResultNetwork", NETWORK_WAIT_SECONDS)', 1, true)
		~= nil,
	"ExpeditionResultController must bound ExpeditionResultNetwork"
)

for _, childName in { "State", "ReadState" } do
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		"ExpeditionResultController must bound ExpeditionResultNetwork." .. childName
	)
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"ExpeditionResultController must not use an unbounded ExpeditionResultNetwork." .. childName .. " wait"
	)
end

for _, message in
	{
		"ExpeditionResultNetwork did not become available before the client bootstrap timeout",
		"ExpeditionResultNetwork.State did not become available before the client bootstrap timeout",
		"ExpeditionResultNetwork.ReadState did not become available before the client bootstrap timeout",
	}
do
	assert(string.find(source, message, 1, true) ~= nil, "missing expedition result bootstrap assertion: " .. message)
end

print("ExpeditionResultNetworkWaitSourceAudit: ExpeditionResultNetwork startup waits are bounded")
