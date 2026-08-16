--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local inventoryLive = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")
local inventoryNetwork = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
local combatAdapter = fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentCombatAdapter.luau")
local weaponResolver = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedWeaponResolver.luau")
local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")

assertThat(
	string.find(inventoryLive, "requesterId ~= ownerId", 1, true) ~= nil,
	"inventory mutations must reject cross-player access"
)
assertThat(
	string.find(inventoryLive, "SessionLeaseRequired", 1, true) ~= nil,
	"inventory mutations must require live lease"
)
assertThat(
	string.find(inventoryLive, "function Service.unequipOwnedSlot", 1, true) ~= nil,
	"authoritative unequip missing"
)
assertThat(
	string.find(inventoryLive, "write.Status ~= StorageResults.WriteStatuses.Committed", 1, true) ~= nil,
	"unequip must commit durably before cache advance"
)

assertThat(
	string.find(inventoryNetwork, 'unequipOwnedSlot.Name = "UnequipOwnedSlot"', 1, true) ~= nil,
	"unequip remote missing"
)
assertThat(
	string.find(
		inventoryNetwork,
		"InventoryLiveService.equipOwnedItem(player.UserId, player.UserId, instanceId",
		1,
		true
	) ~= nil,
	"equip owner must derive from player"
)
assertThat(
	string.find(inventoryNetwork, "InventoryLiveService.unequipOwnedSlot(player.UserId, player.UserId, slotId", 1, true)
		~= nil,
	"unequip owner must derive from player"
)
for _, forbidden in { "payload.Damage", "payload.Rarity", "payload.Affixes", "payload.Power", "payload.WeaponId" } do
	assertThat(not string.find(inventoryNetwork, forbidden, 1, true), "inventory network must not trust " .. forbidden)
end

assertThat(
	string.find(combatAdapter, "InventoryLiveService.getRecord(player.UserId)", 1, true) ~= nil,
	"combat adapter must resolve server-owned inventory"
)
assertThat(
	string.find(combatAdapter, "EquippedWeaponResolver.resolveInstance", 1, true) ~= nil,
	"adapter must validate equipped instance"
)
assertThat(
	string.find(combatAdapter, "OperativeCombatRuntimeService.equipFoundWeapon", 1, true) ~= nil,
	"adapter must reuse authoritative combat equip seam"
)
assertThat(string.find(weaponResolver, "ItemNotOwned", 1, true) ~= nil, "forged instances must fail closed")
assertThat(string.find(weaponResolver, "ItemNotEquipped", 1, true) ~= nil, "unequipped instances must not drive combat")
assertThat(
	string.find(weaponResolver, "definition.WeaponId", 1, true) ~= nil,
	"weapon id must come from authored definition"
)
assertThat(
	string.find(combatRuntime, "equipFoundWeapon", 1, true) ~= nil,
	"authoritative combat equip seam must still exist"
)
