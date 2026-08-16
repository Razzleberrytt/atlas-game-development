--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/PersonalFlashlightController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("FlashlightNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"PersonalFlashlightController must bound FlashlightNetwork"
)
assert(
	string.find(source, "FlashlightNetwork did not become available before the client bootstrap timeout", 1, true) ~= nil,
	"PersonalFlashlightController must fail closed when FlashlightNetwork is absent"
)

local function assertBoundedChild(childName: string)
	assert(
		string.find(source, 'flashlightNetwork:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		"PersonalFlashlightController must bound FlashlightNetwork." .. childName
	)
	assert(
		string.find(source, 'flashlightNetwork:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"PersonalFlashlightController must not use an unbounded FlashlightNetwork." .. childName .. " wait"
	)
	assert(
		string.find(
			source,
			"FlashlightNetwork." .. childName .. " did not become available before the client bootstrap timeout",
			1,
			true
		) ~= nil,
		"PersonalFlashlightController must fail closed when FlashlightNetwork." .. childName .. " is absent"
	)
end

assertBoundedChild("ToggleIntent")
assertBoundedChild("State")

print("PersonalFlashlightNetworkWaitSourceAudit: FlashlightNetwork waits are bounded")
