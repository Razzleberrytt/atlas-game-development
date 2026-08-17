--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/RunBuildHUDController.luau"
local source = fs.readFile(path)

local requiredSnippets = {
	'ReplicatedStorage:WaitForChild("RunBuildNetwork", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork did not become available before the client bootstrap timeout",
	'runBuildNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.State did not become available before the client bootstrap timeout",
	'runBuildNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.ReadState did not become available before the client bootstrap timeout",
	'runBuildNetwork:WaitForChild("SubmitRelicChoice", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.SubmitRelicChoice did not become available before the client bootstrap timeout",
	'runBuildNetwork:WaitForChild("SubmitRelicReplacement", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.SubmitRelicReplacement did not become available before the client bootstrap timeout",
	'Players.LocalPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS)',
	"PlayerGui did not become available before the client bootstrap timeout",
}

for _, snippet in requiredSnippets do
	if string.find(source, snippet, 1, true) == nil then
		error("RunBuildHUDController is missing bounded bootstrap evidence: " .. snippet, 2)
	end
end

local forbiddenSnippets = {
	'ReplicatedStorage:WaitForChild("RunBuildNetwork")',
	'runBuildNetwork:WaitForChild("State")',
	'runBuildNetwork:WaitForChild("ReadState")',
	'runBuildNetwork:WaitForChild("SubmitRelicChoice")',
	'runBuildNetwork:WaitForChild("SubmitRelicReplacement")',
	'Players.LocalPlayer:WaitForChild("PlayerGui")',
}

for _, snippet in forbiddenSnippets do
	if string.find(source, snippet, 1, true) ~= nil then
		error("RunBuildHUDController regressed to an unbounded dependency wait: " .. snippet, 2)
	end
end

print("RunBuildHUDNetworkWaitSourceAudit: run-build dependency waits are bounded and fail closed")
