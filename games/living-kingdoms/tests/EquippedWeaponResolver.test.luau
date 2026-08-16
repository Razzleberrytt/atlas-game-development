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
		forged = { InstanceId = "forged", DefinitionId = "missing-definition", Slot = "Primary" },
	},
	EquippedBySlot = {
		Primary = "primary",
		Secondary = "secondary",
		Armor = "armor",
	},
}

local primary = resolver.resolveInstance(record, "primary", lookupDefinition)
assertThat(primary.Accepted, "owned equipped primary weapon must resolve")
assertThat(primary.WeaponId == "weapon.sniper_rifle", "weapon identity must come from authored definition")
assertThat(primary.SlotId == "Primary", "resolved slot must match durable item state")

local preferred = resolver.resolvePreferred(record, lookupDefinition)
assertThat(preferred.Accepted and preferred.InstanceId == "primary", "primary must win deterministic preference")

local secondaryRecord = {
	InventoryByInstanceId = record.InventoryByInstanceId,
	EquippedBySlot = { Secondary = "secondary" },
}
local secondary = resolver.resolvePreferred(secondaryRecord, lookupDefinition)
assertThat(secondary.Accepted and secondary.WeaponId == "weapon.service_pistol", "secondary must be valid fallback")

local notOwned = resolver.resolveInstance(record, "invented-client-item", lookupDefinition)
assertThat(not notOwned.Accepted and notOwned.ReasonId == "ItemNotOwned", "invented instance ids must fail closed")

local notEquippedRecord = {
	InventoryByInstanceId = record.InventoryByInstanceId,
	EquippedBySlot = { Primary = "other" },
}
local notEquipped = resolver.resolveInstance(notEquippedRecord, "primary", lookupDefinition)
assertThat(
	not notEquipped.Accepted and notEquipped.ReasonId == "ItemNotEquipped",
	"owned but unequipped item must not drive combat"
)

local armor = resolver.resolveInstance(record, "armor", lookupDefinition)
assertThat(
	not armor.Accepted and armor.ReasonId == "ItemIsNotWeaponEquipment",
	"non-weapon equipment must not resolve a weapon"
)

local forgedDefinitionRecord = {
	InventoryByInstanceId = { forged = record.InventoryByInstanceId.forged },
	EquippedBySlot = { Primary = "forged" },
}
local forged = resolver.resolveInstance(forgedDefinitionRecord, "forged", lookupDefinition)
assertThat(
	not forged.Accepted and forged.ReasonId == "UnknownEquipmentDefinition",
	"unknown definitions must fail closed"
)

local slotMismatchDefinitions = {
	["frontier-rifle"] = { Id = "frontier-rifle", Slot = "Secondary", WeaponId = "weapon.sniper_rifle" },
}
local slotMismatch = resolver.resolveInstance(record, "primary", function(definitionId: string): any
	return slotMismatchDefinitions[definitionId]
end)
assertThat(
	not slotMismatch.Accepted and slotMismatch.ReasonId == "InvalidWeaponDefinition",
	"definition slot mismatch must fail closed"
)

local empty = resolver.resolvePreferred({ InventoryByInstanceId = {}, EquippedBySlot = {} }, lookupDefinition)
assertThat(not empty.Accepted and empty.ReasonId == "NoEquippedWeapon", "empty equipment must resolve no weapon")
