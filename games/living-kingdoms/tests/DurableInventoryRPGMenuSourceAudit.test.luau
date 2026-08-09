--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")

local function contains(needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains('ReplicatedStorage:WaitForChild("InventoryNetwork")'),
	"RPG menu must consume the owner inventory network"
)
assert(contains('inventoryNetwork:WaitForChild("ReadOwnInventory")'), "RPG menu must read the sanitized owner snapshot")
assert(contains('inventoryNetwork:WaitForChild("EquipOwnedItem")'), "RPG menu must use the owner-only equip intent")
assert(contains("latestDurableInventory"), "RPG menu must retain the latest sanitized durable snapshot")
assert(contains("latestDurableInventory.Items"), "durable inventory cards must come from sanitized snapshot items")
assert(contains('durableEquippedItem("Primary")'), "character panel must display durable primary equipment")
assert(contains('durableEquippedItem("Secondary")'), "character panel must display durable sidearm equipment")
assert(contains('durableEquippedItem("Armor")'), "character panel must display durable armor equipment")
assert(contains('durableEquippedItem("Relic")'), "character panel must display durable relic equipment")

assert(contains("slot.Activated:Connect(function()"), "durable equip must use device-neutral GUI activation")
assert(
	contains("inventoryEquipOwnedItem:InvokeServer(instanceId)"),
	"client equip request must submit only the owned instance id"
)
assert(
	not contains("inventoryEquipOwnedItem:InvokeServer(instanceId,"),
	"equip request must not append slot or item stats"
)
assert(not contains("inventoryEquipOwnedItem:InvokeServer(item.Slot"), "client must not author the equipment slot")
assert(not contains("inventoryEquipOwnedItem:InvokeServer(item.WeaponId"), "client must not author a combat WeaponId")
assert(contains('created.Name = "RPGMenu"'), "durable inventory must reuse the existing RPG menu surface")

print(
	"DurableInventoryRPGMenuSourceAudit: sanitized durable gear, existing menu, and device-neutral owner-only equip passed"
)
