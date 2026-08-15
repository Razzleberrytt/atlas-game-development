--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local inventoryContracts = fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau")
local inventoryLive = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")
local inventoryNetwork = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
local combatAdapter = fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentCombatAdapter.luau")
local weaponResolver = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedWeaponResolver.luau")
local modifierService = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local comparisonResolver = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentComparisonResolver.luau")
local rewardService = fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentRewardService.luau")

assertThat(string.find(inventoryContracts, "InventoryByInstanceId", 1, true) ~= nil, "inventory must index unique instances")
assertThat(string.find(inventoryContracts, "EquippedBySlot", 1, true) ~= nil, "inventory must serialize equipment slots")
assertThat(string.find(inventoryContracts, "AppliedRewardGrantIds", 1, true) ~= nil, "reward grants must remain idempotent")

assertThat(string.find(inventoryLive, "requesterId ~= ownerId", 1, true) ~= nil, "inventory mutations must reject cross-player access")
assertThat(string.find(inventoryLive, "SessionLeaseRequired", 1, true) ~= nil, "inventory mutations must require the live lease")
assertThat(string.find(inventoryLive, "function Service.unequipOwnedSlot", 1, true) ~= nil, "authoritative unequip service missing")
assertThat(string.find(inventoryLive, "isKnownSlot(slotId)", 1, true) ~= nil, "unequip must validate authored slots")
assertThat(string.find(inventoryLive, "record.EquippedBySlot[slotId] == nil", 1, true) ~= nil, "unequip must be idempotent")
assertThat(string.find(inventoryLive, "write.Status ~= StorageResults.WriteStatuses.Committed", 1, true) ~= nil, "unequip must advance memory only after durable commit")

assertThat(string.find(inventoryNetwork, 'unequipOwnedSlot.Name = "UnequipOwnedSlot"', 1, true) ~= nil, "unequip remote missing")
assertThat(string.find(inventoryNetwork, "type(instanceId) ~= \"string\"", 1, true) ~= nil, "equip payload must remain instance-id intent")
assertThat(string.find(inventoryNetwork, "InventoryLiveService.equipOwnedItem(player.UserId, player.UserId, instanceId", 1, true) ~= nil, "equip owner must come from invoking player")
assertThat(string.find(inventoryNetwork, "InventoryLiveService.unequipOwnedSlot(player.UserId, player.UserId, slotId", 1, true) ~= nil, "unequip owner must come from invoking player")
for _, forbidden in { "payload.Damage", "payload.Rarity", "payload.Affixes", "payload.Power", "payload.WeaponId" } do
	assertThat(not string.find(inventoryNetwork, forbidden, 1, true), "inventory network must not trust " .. forbidden)
end

assertThat(string.find(combatAdapter, "InventoryLiveService.getRecord(player.UserId)", 1, true) ~= nil, "combat adapter must resolve server-owned inventory")
assertThat(string.find(combatAdapter, "EquippedWeaponResolver.resolveInstance", 1, true) ~= nil, "combat adapter must validate equipped instance")
assertThat(string.find(combatAdapter, "OperativeCombatRuntimeService.equipFoundWeapon", 1, true) ~= nil, "equipment must use Agent 1 authoritative equip seam")
assertThat(string.find(weaponResolver, "ItemNotOwned", 1, true) ~= nil, "forged instances must fail closed")
assertThat(string.find(weaponResolver, "ItemNotEquipped", 1, true) ~= nil, "unequipped instances must not drive combat")
assertThat(string.find(weaponResolver, "definition.WeaponId", 1, true) ~= nil, "weapon id must come from authored definition")

assertThat(string.find(modifierService, "EquippedEquipmentModifierResolver.resolve", 1, true) ~= nil, "equipped affixes must resolve from durable record")
assertThat(string.find(modifierService, "definition.WeaponId == weaponId", 1, true) ~= nil, "weapon affixes must match the active authored weapon")
assertThat(string.find(combatRuntime, "RelicModifierService.getDamageMultiplier", 1, true) ~= nil, "authoritative damage must consume equipment modifiers")
assertThat(string.find(combatRuntime, "RelicModifierService.getReloadDurationMultiplier", 1, true) ~= nil, "authoritative reload must consume equipment modifiers")

assertThat(string.find(comparisonResolver, "candidateScore", 1, true) ~= nil, "informational comparison score must remain available")
assertThat(string.find(rewardService, "GenerateGUID", 1, true) ~= nil, "generated durable rewards must receive unique instance identity")
