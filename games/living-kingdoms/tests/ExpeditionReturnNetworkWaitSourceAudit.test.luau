--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionReturnController.luau")

for _, networkName in { "ExpeditionResultNetwork", "ExpeditionLobbyNetwork" } do
	assert(
		string.find(
			source,
			'ReplicatedStorage:WaitForChild("' .. networkName .. '", NETWORK_WAIT_SECONDS)',
			1,
			true
		) ~= nil,
		"ExpeditionReturnController must bound " .. networkName
	)
end

for _, wait in
	{
		{ receiver = "resultNetwork", child = "State" },
		{ receiver = "resultNetwork", child = "ReadState" },
		{ receiver = "lobbyNetwork", child = "Request" },
		{ receiver = "lobbyNetwork", child = "State" },
	}
do
	assert(
		string.find(
			source,
			wait.receiver .. ':WaitForChild("' .. wait.child .. '", NETWORK_WAIT_SECONDS)',
			1,
			true
		) ~= nil,
		"ExpeditionReturnController must bound " .. wait.receiver .. "." .. wait.child
	)
	assert(
		string.find(source, wait.receiver .. ':WaitForChild("' .. wait.child .. '")', 1, true) == nil,
		"ExpeditionReturnController must not use an unbounded " .. wait.receiver .. "." .. wait.child .. " wait"
	)
end

for _, message in
	{
		"ExpeditionResultNetwork did not become available before the client bootstrap timeout",
		"ExpeditionResultNetwork.State did not become available before the client bootstrap timeout",
		"ExpeditionResultNetwork.ReadState did not become available before the client bootstrap timeout",
		"ExpeditionLobbyNetwork did not become available before the client bootstrap timeout",
		"ExpeditionLobbyNetwork.Request did not become available before the client bootstrap timeout",
		"ExpeditionLobbyNetwork.State did not become available before the client bootstrap timeout",
	}
do
	assert(string.find(source, message, 1, true) ~= nil, "missing expedition return bootstrap assertion: " .. message)
end

print("ExpeditionReturnNetworkWaitSourceAudit: expedition return startup waits are bounded")
