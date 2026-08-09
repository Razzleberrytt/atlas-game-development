--!strict

-- Applies one server-owned durable equipment choice to the fresh combat runtime.
-- The inventory record names the equipped instance, the owned instance names an
-- authored equipment definition, and that definition alone names the combat
-- weapon. No client-authored slot, definition, power, or WeaponId enters here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local EquipmentRewardContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)
local InventoryLiveService = require(script.Parent.InventoryLiveService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)

local Service = {}
local SlotIds = EquipmentRewardContracts.SlotIds

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function result(accepted: boolean, reasonId: string, weaponId: string?): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, WeaponId = weaponId })
end

local function resolveEquippedWeapon(record: any, slotId: string): (string?, string?)
	local instanceId = record.EquippedBySlot[slotId]
	if instanceId == nil then
		return nil, nil
	end
	if type(instanceId) ~= "string" or instanceId == "" then
		return nil, "InvalidEquippedDurableItem"
	end
	local item = record.InventoryByInstanceId[instanceId]
	if type(item) ~= "table" or item.Slot ~= slotId or type(item.DefinitionId) ~= "string" then
		return nil, "InvalidEquippedDurableItem"
	end
	local definition = definitionsById[item.DefinitionId]
	if
		type(definition) ~= "table"
		or definition.Slot ~= slotId
		or type(definition.WeaponId) ~= "string"
		or definition.WeaponId == ""
	then
		return nil, "InvalidEquippedDurableItem"
	end
	return definition.WeaponId, nil
end

function Service.applyForPlayer(player: Player): any
	local record = InventoryLiveService.getRecord(player.UserId)
	if record == nil then
		return result(false, "InventoryNotLoaded", nil)
	end

	-- The current combat slice carries one firearm. Prefer a durable primary when
	-- both slots are equipped; otherwise a saved sidearm is the starting option.
	local weaponId, primaryError = resolveEquippedWeapon(record, SlotIds.Primary)
	if primaryError ~= nil then
		return result(false, primaryError, nil)
	end
	if weaponId == nil then
		local secondaryError: string?
		weaponId, secondaryError = resolveEquippedWeapon(record, SlotIds.Secondary)
		if secondaryError ~= nil then
			return result(false, secondaryError, nil)
		end
	end
	if weaponId == nil then
		return result(false, "NoEquippedDurableWeapon", nil)
	end

	if not OperativeCombatRuntimeService.equipFoundWeapon(player, weaponId) then
		return result(false, "CombatEquipRejected", nil)
	end
	return result(true, "DurableStartingWeaponApplied", weaponId)
end

return table.freeze(Service)
