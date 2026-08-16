--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassSelectionController.luau")
local timeout = "NETWORK_WAIT_SECONDS"

local function requireBoundedWait(receiver: string, childName: string)
	local expected = string.format('%s:WaitForChild("%s", %s)', receiver, childName, timeout)
	assert(
		string.find(source, expected, 1, true) ~= nil,
		string.format("%s.%s must use the bounded client network timeout", receiver, childName)
	)
end

requireBoundedWait("ReplicatedStorage", "ClassNetwork")
requireBoundedWait("classNetwork", "SelectionIntent")
requireBoundedWait("classNetwork", "State")
requireBoundedWait("classNetwork", "ReadState")

assert(
	string.find(source, 'classNetwork:WaitForChild("SelectionIntent")', 1, true) == nil,
	"SelectionIntent must never regress to an unbounded module-scope wait"
)
assert(
	string.find(source, 'classNetwork:WaitForChild("State")', 1, true) == nil,
	"State must never regress to an unbounded module-scope wait"
)
assert(
	string.find(source, 'classNetwork:WaitForChild("ReadState")', 1, true) == nil,
	"ReadState must never regress to an unbounded module-scope wait"
)

print("ClassSelectionNetworkWaitSourceAudit: ClassNetwork and all required children are bounded")
