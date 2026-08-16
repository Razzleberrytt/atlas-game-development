--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionLobbyController.luau")

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("ExpeditionLobbyNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"ExpeditionLobbyController must bound ExpeditionLobbyNetwork"
)

for _, childName in { "Request", "State", "ReadState" } do
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		"ExpeditionLobbyController must bound ExpeditionLobbyNetwork." .. childName
	)
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"ExpeditionLobbyController must not use an unbounded ExpeditionLobbyNetwork." .. childName .. " wait"
	)
end

for _, message in
	{
		"ExpeditionLobbyNetwork did not become available before the client bootstrap timeout",
		"ExpeditionLobbyNetwork.Request did not become available before the client bootstrap timeout",
		"ExpeditionLobbyNetwork.State did not become available before the client bootstrap timeout",
		"ExpeditionLobbyNetwork.ReadState did not become available before the client bootstrap timeout",
	}
do
	assert(
		string.find(source, message, 1, true) ~= nil,
		"missing expedition lobby bootstrap assertion: " .. message
	)
end

print("ExpeditionLobbyNetworkWaitSourceAudit: ExpeditionLobbyNetwork startup waits are bounded")
