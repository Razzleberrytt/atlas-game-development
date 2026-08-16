--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/OperativeProgressionPresentationController.luau"
local source = fs.readFile(path)

local function assertBoundedParent(parentName: string)
	assert(
		string.find(
			source,
			'ReplicatedStorage:WaitForChild("' .. parentName .. '", NETWORK_WAIT_SECONDS)',
			1,
			true
		) ~= nil,
		"OperativeProgressionPresentationController must bound " .. parentName
	)
	assert(
		string.find(source, parentName .. " did not become available before the client bootstrap timeout", 1, true)
			~= nil,
		"OperativeProgressionPresentationController must fail closed when " .. parentName .. " is absent"
	)
end

local function assertBoundedChild(receiver: string, childName: string, fullName: string)
	assert(
		string.find(
			source,
			receiver .. ':WaitForChild("' .. childName .. '", NETWORK_WAIT_SECONDS)',
			1,
			true
		) ~= nil,
		"OperativeProgressionPresentationController must bound " .. fullName
	)
	assert(
		string.find(source, receiver .. ':WaitForChild("' .. childName .. '")', 1, true) == nil,
		"OperativeProgressionPresentationController must not use an unbounded " .. fullName .. " wait"
	)
	assert(
		string.find(source, fullName .. " did not become available before the client bootstrap timeout", 1, true)
			~= nil,
		"OperativeProgressionPresentationController must fail closed when " .. fullName .. " is absent"
	)
end

assertBoundedParent("OperativeProgressionNetwork")
assertBoundedChild("progressionNetwork", "ReadState", "OperativeProgressionNetwork.ReadState")
assertBoundedParent("InventoryNetwork")
assertBoundedChild("inventoryNetwork", "State", "InventoryNetwork.State")

print("OperativeProgressionPresentationNetworkWaitSourceAudit: network waits are bounded")
