--!strict

local fs = require("@lune/fs")

local inventoryService = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")
local inventoryNetwork = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
local loadoutService = fs.readFile("games/living-kingdoms/src/server/Systems/DurableStartingLoadoutService.luau")
local lobby = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local survival = fs.readFile("games/living-kingdoms/src/server/Systems/SurvivalLootService.luau")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains(
		inventoryService,
		"function Service.equipOwnedItem(requesterId: number, ownerId: number, instanceId: any, nowUnix: number)"
	),
	"inventory owner needs one owner-derived durable equip mutation"
)
assert(contains(inventoryService, "requesterId ~= ownerId"), "cross-player durable equip must be rejected")
assert(
	contains(inventoryService, "leases:hasLease(ownerId, nowUnix)"),
	"durable equip must require the live session lease"
)
assert(
	contains(inventoryService, "local item = record.InventoryByInstanceId[instanceId]"),
	"equip must resolve an owned item"
)
assert(
	contains(inventoryService, "persistence:equip(ownerId, item.Slot, instanceId, nowUnix)"),
	"equip slot must be derived from the server-owned item record"
)

assert(
	contains(inventoryNetwork, 'equipOwnedItem.Name = "EquipOwnedItem"'),
	"inventory network must expose the equip intent"
)
assert(
	contains(
		inventoryNetwork,
		"InventoryLiveService.equipOwnedItem(player.UserId, player.UserId, instanceId, os.time())"
	),
	"network must derive both inventory identities from the invoking player"
)
assert(
	contains(inventoryNetwork, "equipOwnedItem.OnServerInvoke = function(player: Player, instanceId: any)"),
	"equip intent must accept only the owned instance identity"
)
assert(not contains(inventoryNetwork, "weaponId: any"), "inventory client cannot author a combat WeaponId")
assert(
	not contains(inventoryNetwork, "equipOwnedItem.OnServerInvoke = function(player: Player, slotId"),
	"inventory client cannot author the equip slot"
)
assert(
	contains(inventoryNetwork, "unequipOwnedSlot.OnServerInvoke = function(player: Player, slotId: any)"),
	"unequip may accept only a bounded slot-removal intent"
)
assert(
	contains(inventoryService, "not isKnownSlot(slotId)"),
	"unequip slot intent must be restricted to authored equipment slots"
)

assert(
	contains(loadoutService, "EquippedWeaponResolver.resolvePreferred(record, lookupDefinition)"),
	"starting weapon must use the same canonical resolver as live equipment activation"
)
assert(
	not contains(loadoutService, "local function resolveEquippedWeapon"),
	"launch-time loadout must not maintain a second weapon-resolution implementation"
)
assert(contains(loadoutService, "resolved.WeaponId"), "authored equipment definition must be the WeaponId source")
assert(
	contains(loadoutService, "OperativeCombatRuntimeService.equipFoundWeapon(player, resolved.WeaponId)"),
	"durable starting gear must reuse canonical combat equip authority"
)

local prepareIndex = assert(string.find(lobby, "OperationLifecycleService.prepareForLaunch()", 1, true))
local durableIndex = assert(string.find(lobby, "applyDurableStartingLoadouts(consumed.Snapshot.Members)", 1, true))
local pressureIndex = assert(string.find(lobby, "MissionDirectorService.armPressure()", 1, true))
assert(
	prepareIndex < durableIndex and durableIndex < pressureIndex,
	"durable weapon must apply after reset and before pressure"
)

assert(
	contains(survival, "player:GetAttribute(PrimaryCombatModeAttributeName) == PrimaryCombatModeIds.Melee"),
	"first-chest pistol recovery must remain melee-only so durable firearms are not overwritten"
)

print(
	"DurableStartingWeaponSourceAudit: owner-only equip, bounded unequip, shared resolver, launch ordering, and melee-only recovery passed"
)
