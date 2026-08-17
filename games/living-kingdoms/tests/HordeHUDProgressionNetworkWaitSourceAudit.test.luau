--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/HordeHUDController.luau"
local source = fs.readFile(path)

assert(
	string.find(source, 'ReplicatedStorage:WaitForChild("ProgressionNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"HordeHUDController must bound ProgressionNetwork"
)
assert(
	string.find(source, "ProgressionNetwork did not become available before the client bootstrap timeout", 1, true)
		~= nil,
	"HordeHUDController must fail closed when ProgressionNetwork is absent"
)

local function assertBoundedChild(childName: string)
	assert(
		string.find(source, 'progressionNetwork:WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)', 1, true)
			~= nil,
		"HordeHUDController must bound ProgressionNetwork." .. childName
	)
	assert(
		string.find(source, 'progressionNetwork:WaitForChild("' .. childName .. '")', 1, true) == nil,
		"HordeHUDController must not use an unbounded ProgressionNetwork." .. childName .. " wait"
	)
	assert(
		string.find(
			source,
			"ProgressionNetwork." .. childName .. " did not become available before the client bootstrap timeout",
			1,
			true
		) ~= nil,
		"HordeHUDController must fail closed when ProgressionNetwork." .. childName .. " is absent"
	)
end

assertBoundedChild("State")
assertBoundedChild("ReadState")
assertBoundedChild("ChooseUpgrade")

print("HordeHUDProgressionNetworkWaitSourceAudit: ProgressionNetwork waits are bounded")
