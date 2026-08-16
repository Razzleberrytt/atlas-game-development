--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/HubPreparationController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("ExpeditionNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"HubPreparationController must bound ExpeditionNetwork"
)
assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("ExpeditionNetwork")', 1, true) == nil,
	"HubPreparationController must not use an unbounded ExpeditionNetwork wait"
)
assert(
	string.find(source, "ExpeditionNetwork did not become available before the client bootstrap timeout", 1, true)
		~= nil,
	"HubPreparationController must fail closed when ExpeditionNetwork is absent"
)

local function assertBoundedChild(childName: string)
	assert(
		string.find(source, 'expeditionNetwork:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true)
			~= nil,
		"HubPreparationController must bound ExpeditionNetwork." .. childName
	)
	assert(
		string.find(source, 'expeditionNetwork:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"HubPreparationController must not use an unbounded ExpeditionNetwork." .. childName .. " wait"
	)
	assert(
		string.find(
			source,
			"ExpeditionNetwork." .. childName .. " did not become available before the client bootstrap timeout",
			1,
			true
		) ~= nil,
		"HubPreparationController must fail closed when ExpeditionNetwork." .. childName .. " is absent"
	)
end

assertBoundedChild("State")
assertBoundedChild("ReadState")

print("HubPreparationNetworkWaitSourceAudit: ExpeditionNetwork waits are bounded")
