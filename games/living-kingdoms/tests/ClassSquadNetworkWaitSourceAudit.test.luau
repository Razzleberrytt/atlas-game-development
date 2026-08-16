local source = assert(fs.readFile("games/living-kingdoms/src/client/Controllers/ClassSquadPresentationController.luau"))

local requiredSnippets = {
	'ReplicatedStorage:WaitForChild("ClassNetwork", NETWORK_WAIT_SECONDS)',
	'classNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS)',
	'classNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)',
	'assert(classNetwork ~= nil, "ClassNetwork did not become available before the client bootstrap timeout")',
	'assert(stateRemote ~= nil, "ClassNetwork.State did not become available before the client bootstrap timeout")',
	'assert(readStateFunction ~= nil, "ClassNetwork.ReadState did not become available before the client bootstrap timeout")',
}

for _, snippet in requiredSnippets do
	assert(string.find(source, snippet, 1, true) ~= nil, "missing bounded ClassSquad network contract: " .. snippet)
end

local forbiddenSnippets = {
	'classNetwork:WaitForChild("State")',
	'classNetwork:WaitForChild("ReadState")',
}

for _, snippet in forbiddenSnippets do
	assert(string.find(source, snippet, 1, true) == nil, "unbounded ClassSquad child wait regressed: " .. snippet)
end

print("ClassSquad network wait source audit passed")
