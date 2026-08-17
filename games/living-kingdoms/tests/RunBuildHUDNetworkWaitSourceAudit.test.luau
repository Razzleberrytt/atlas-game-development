--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/RunBuildHUDController.luau"
local source = fs.readFile(path)

local requiredSnippets = {
	'ReplicatedStorage:WaitForChild("RunBuildNetwork", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork missing after bounded wait",
	'runBuildNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.ReadState missing after bounded wait",
	'runBuildNetwork:WaitForChild("ClaimPlot", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.ClaimPlot missing after bounded wait",
	'runBuildNetwork:WaitForChild("SaveBuild", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.SaveBuild missing after bounded wait",
	'runBuildNetwork:WaitForChild("LoadBuild", NETWORK_WAIT_SECONDS)',
	"RunBuildNetwork.LoadBuild missing after bounded wait",
	'localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS)',
	"PlayerGui missing after bounded wait",
}

for _, snippet in requiredSnippets do
	if string.find(source, snippet, 1, true) == nil then
		error("RunBuildHUDController is missing bounded bootstrap evidence: " .. snippet, 2)
	end
end

local forbiddenSnippets = {
	'ReplicatedStorage:WaitForChild("RunBuildNetwork")',
	'runBuildNetwork:WaitForChild("ReadState")',
	'runBuildNetwork:WaitForChild("ClaimPlot")',
	'runBuildNetwork:WaitForChild("SaveBuild")',
	'runBuildNetwork:WaitForChild("LoadBuild")',
	'localPlayer:WaitForChild("PlayerGui")',
}

for _, snippet in forbiddenSnippets do
	if string.find(source, snippet, 1, true) ~= nil then
		error("RunBuildHUDController regressed to an unbounded dependency wait: " .. snippet, 2)
	end
end

print("RunBuildHUDNetworkWaitSourceAudit: run-build dependency waits are bounded and fail closed")
