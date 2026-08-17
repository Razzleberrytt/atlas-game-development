--!strict

local fs = require("@lune/fs")

local path = "games/living-kingdoms/src/client/Controllers/RPGMenuController.luau"
local source = fs.readFile(path)

local requiredSnippets = {
	'ReplicatedStorage:WaitForChild("SurvivalNetwork", NETWORK_WAIT_SECONDS)',
	"SurvivalNetwork did not become available before the client bootstrap timeout",
	'ReplicatedStorage:WaitForChild("ProgressionNetwork", NETWORK_WAIT_SECONDS)',
	"ProgressionNetwork did not become available before the client bootstrap timeout",
	'ReplicatedStorage:WaitForChild("InventoryNetwork", NETWORK_WAIT_SECONDS)',
	"InventoryNetwork did not become available before the client bootstrap timeout",
	'survivalNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS)',
	"SurvivalNetwork.State did not become available before the client bootstrap timeout",
	'survivalNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)',
	"SurvivalNetwork.ReadState did not become available before the client bootstrap timeout",
	'progressionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS)',
	"ProgressionNetwork.State did not become available before the client bootstrap timeout",
	'progressionNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)',
	"ProgressionNetwork.ReadState did not become available before the client bootstrap timeout",
	'inventoryNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS)',
	"InventoryNetwork.State did not become available before the client bootstrap timeout",
	'inventoryNetwork:WaitForChild("ReadOwnInventory", NETWORK_WAIT_SECONDS)',
	"InventoryNetwork.ReadOwnInventory did not become available before the client bootstrap timeout",
	'inventoryNetwork:WaitForChild("EquipOwnedItem", NETWORK_WAIT_SECONDS)',
	"InventoryNetwork.EquipOwnedItem did not become available before the client bootstrap timeout",
	'player:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS)',
	"PlayerGui did not become available before the client bootstrap timeout",
}

for _, snippet in requiredSnippets do
	if string.find(source, snippet, 1, true) == nil then
		error("RPGMenuController is missing bounded network bootstrap evidence: " .. snippet, 2)
	end
end

local forbiddenSnippets = {
	'ReplicatedStorage:WaitForChild("SurvivalNetwork")',
	'ReplicatedStorage:WaitForChild("ProgressionNetwork")',
	'ReplicatedStorage:WaitForChild("InventoryNetwork")',
	'survivalNetwork:WaitForChild("State")',
	'survivalNetwork:WaitForChild("ReadState")',
	'progressionNetwork:WaitForChild("State")',
	'progressionNetwork:WaitForChild("ReadState")',
	'inventoryNetwork:WaitForChild("State")',
	'inventoryNetwork:WaitForChild("ReadOwnInventory")',
	'inventoryNetwork:WaitForChild("EquipOwnedItem")',
	'player:WaitForChild("PlayerGui")',
}

for _, snippet in forbiddenSnippets do
	if string.find(source, snippet, 1, true) ~= nil then
		error("RPGMenuController regressed to an unbounded network dependency wait: " .. snippet, 2)
	end
end

print("RPGMenuNetworkWaitSourceAudit: RPG menu network dependency waits are bounded and fail closed")
