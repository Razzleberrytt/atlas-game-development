--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassActionController.luau")
local timeout = "NETWORK_WAIT_SECONDS"

local function requireBoundedWait(receiver: string, childName: string)
	local expected = string.format('%s:WaitForChild("%s", %s)', receiver, childName, timeout)
	assert(
		string.find(source, expected, 1, true) ~= nil,
		string.format("%s.%s must use the bounded client network timeout", receiver, childName)
	)
end

requireBoundedWait("ReplicatedStorage", "ClassNetwork")
requireBoundedWait("classNetwork", "ActionIntent")
requireBoundedWait("classNetwork", "State")
requireBoundedWait("classNetwork", "ReadState")

for _, childName in { "ActionIntent", "State", "ReadState" } do
	local unbounded = string.format('classNetwork:WaitForChild("%s")', childName)
	assert(
		string.find(source, unbounded, 1, true) == nil,
		string.format("%s must never regress to an unbounded module-scope wait", childName)
	)
end

for _, snippet in {
	'assert(classNetwork ~= nil, "ClassNetwork did not become available before the client bootstrap timeout")',
	'assert(stateRemote ~= nil, "ClassNetwork.State did not become available before the client bootstrap timeout")',
	'assert(readStateFunction ~= nil, "ClassNetwork.ReadState did not become available before the client bootstrap timeout")',
} do
	assert(string.find(source, snippet, 1, true) ~= nil, "missing ClassAction bootstrap assertion: " .. snippet)
end

assert(
	string.find(source, "ClassNetwork.ActionIntent did not become available before the client bootstrap timeout", 1, true) ~= nil,
	"ActionIntent must fail closed when the remote is absent"
)

print("ClassActionNetworkWaitSourceAudit: ClassNetwork and all required children are bounded")
