--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedWeaponResolver.luau"), {
	debugName = "EquippedWeaponResolver",
	injectGlobals = true,
})()

local definitions = {
	["frontier-rifle"] = { Id = "frontier-rifle", Slot = "Primary", WeaponId = "weapon.sniper_rifle" },
	["warden-sidearm"] = { Id = "warden-sidearm", Slot = "Secondary", WeaponId = "weapon.service_pistol" },
	["delver-plate"] = { Id = "delver-plate", Slot = "Armor", WeaponId = nil },
}

local function lookupDefinition(definitionId: string): any
	return definitions[definitionId]
end

local record = {
	InventoryByInstanceId = {
		primary = { InstanceId = "primary", DefinitionId = "frontier-rifle", Slot = "Primary" },
		secondary = { InstanceId = "secondary", DefinitionId = "warden-sidearm", Slot = "Secondary" },
		armor = { InstanceId = "armor", DefinitionId = "delver-plate", Slot = "Armor" },
	},
	EquippedBySlot = {
		Primary = "primary",
		Secondary = "secondary",
		Armor = "armor",
	},
}

local primary = resolver.resolveInstance(record, "primary", lookupDefinition)
assertThat(primary.Accepted and primary.WeaponId == "weapon.sniper_rifle", "equipped primary must resolve authored weapon")

local preferred = resolver.resolvePreferred(record, lookupDefinition)
assertThat(preferred.Accepted and preferred.InstanceId == "primary", "primary must win deterministic preference")

local notOwned = resolver.resolveInstance(record, "invented-client-item", lookupDefinition)
assertThat(not notOwned.Accepted and notOwned.ReasonId == "ItemNotOwned", "invented instance ids must fail closed")

local notEquipped = resolver.resolveInstance({ InventoryByInstanceId = record.InventoryByInstanceId, EquippedBySlot = {} }, "primary", lookupDefinition)
assertThat(not notEquipped.Accepted and notEquipped.ReasonId == "ItemNotEquipped", "unequipped item must not drive combat")

local armor = resolver.resolveInstance(record, "armor", lookupDefinition)
assertThat(not armor.Accepted and armor.ReasonId == "ItemIsNotWeaponEquipment", "non-weapon equipment must fail closed")

local empty = resolver.resolvePreferred({ InventoryByInstanceId = {}, EquippedBySlot = {} }, lookupDefinition)
assertThat(not empty.Accepted and empty.ReasonId == "NoEquippedWeapon", "empty equipment must resolve no weapon")
