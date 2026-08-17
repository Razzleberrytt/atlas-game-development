--!strict

--[[
	Pure bridge from durable inventory equipment to a combat weapon identity.
	The caller supplies an authoritative inventory record and authored definition
	lookup; this resolver never accepts client-authored weapon ids or stat values.
]]

export type Resolution = {
	Accepted: boolean,
	ReasonId: string,
	InstanceId: string?,
	SlotId: string?,
	WeaponId: string?,
}

local Resolver = {}
local WEAPON_SLOT_ORDER = table.freeze({ "Primary", "Secondary" })

local function result(
	accepted: boolean,
	reasonId: string,
	instanceId: string?,
	slotId: string?,
	weaponId: string?
): Resolution
	return table.freeze({
		Accepted = accepted,
		ReasonId = reasonId,
		InstanceId = instanceId,
		SlotId = slotId,
		WeaponId = weaponId,
	})
end

local function isWeaponSlot(slotId: unknown): boolean
	return slotId == "Primary" or slotId == "Secondary"
end

function Resolver.isWeaponSlot(slotId: unknown): boolean
	return isWeaponSlot(slotId)
end

function Resolver.resolveInstance(record: any, instanceId: unknown, lookupDefinition: (string) -> any): Resolution
	if type(record) ~= "table" or type(lookupDefinition) ~= "function" then
		return result(false, "InvalidInventoryRecord", nil, nil, nil)
	end
	if type(instanceId) ~= "string" or instanceId == "" then
		return result(false, "InvalidInstanceId", nil, nil, nil)
	end
	if type(record.InventoryByInstanceId) ~= "table" or type(record.EquippedBySlot) ~= "table" then
		return result(false, "InvalidInventoryRecord", nil, nil, nil)
	end

	local item = record.InventoryByInstanceId[instanceId]
	if type(item) ~= "table" then
		return result(false, "ItemNotOwned", nil, nil, nil)
	end
	local slotId = item.Slot
	if not isWeaponSlot(slotId) then
		return result(false, "ItemIsNotWeaponEquipment", instanceId, slotId, nil)
	end
	if record.EquippedBySlot[slotId] ~= instanceId then
		return result(false, "ItemNotEquipped", instanceId, slotId, nil)
	end
	if type(item.DefinitionId) ~= "string" or item.DefinitionId == "" then
		return result(false, "InvalidEquipmentDefinition", instanceId, slotId, nil)
	end

	local definition = lookupDefinition(item.DefinitionId)
	if type(definition) ~= "table" then
		return result(false, "UnknownEquipmentDefinition", instanceId, slotId, nil)
	end
	if definition.Slot ~= slotId or type(definition.WeaponId) ~= "string" or definition.WeaponId == "" then
		return result(false, "InvalidWeaponDefinition", instanceId, slotId, nil)
	end

	return result(true, "EquippedWeaponResolved", instanceId, slotId, definition.WeaponId)
end

function Resolver.resolvePreferred(record: any, lookupDefinition: (string) -> any): Resolution
	if type(record) ~= "table" or type(record.EquippedBySlot) ~= "table" then
		return result(false, "InvalidInventoryRecord", nil, nil, nil)
	end
	for _, slotId in WEAPON_SLOT_ORDER do
		local instanceId = record.EquippedBySlot[slotId]
		if type(instanceId) == "string" and instanceId ~= "" then
			local resolved = Resolver.resolveInstance(record, instanceId, lookupDefinition)
			if resolved.Accepted then
				return resolved
			end
			return resolved
		end
	end
	return result(false, "NoEquippedWeapon", nil, nil, nil)
end

return table.freeze(Resolver)
