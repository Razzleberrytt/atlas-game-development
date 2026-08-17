--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionHUDController.luau")

for _, childName in { "State", "ReadState" } do
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		"ExpeditionNetwork." .. childName .. " must use the bounded client bootstrap timeout"
	)
	assert(
		string.find(source, 'network:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"ExpeditionNetwork." .. childName .. " must never regress to an unbounded wait"
	)
end

for _, message in
	{
		"ExpeditionNetwork did not become available before the client bootstrap timeout",
		"ExpeditionNetwork.State did not become available before the client bootstrap timeout",
		"ExpeditionNetwork.ReadState did not become available before the client bootstrap timeout",
	}
do
	assert(string.find(source, message, 1, true) ~= nil, "missing ExpeditionHUD bootstrap assertion: " .. message)
end

print("ExpeditionHUDNetworkWaitSourceAudit: ExpeditionNetwork and required children are bounded")
