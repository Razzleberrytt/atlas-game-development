--!strict

-- Applies one server-owned durable equipment choice to the fresh combat runtime.
-- The inventory record names the equipped instance, the owned instance names an
-- authored equipment definition, and that definition alone names the combat
-- weapon. No client-authored slot, definition, power, or WeaponId enters here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local EquippedWeaponResolver = require(ReplicatedStorage.Shared.Equipment.EquippedWeaponResolver)
local InventoryLiveService = require(script.Parent.InventoryLiveService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)

local Service = {}

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function lookupDefinition(definitionId: string): any
	return definitionsById[definitionId]
end

local function result(accepted: boolean, reasonId: string, weaponId: string?): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, WeaponId = weaponId })
end

function Service.applyForPlayer(player: Player): any
	local record = InventoryLiveService.getRecord(player.UserId)
	if record == nil then
		return result(false, "InventoryNotLoaded", nil)
	end

	local resolved = EquippedWeaponResolver.resolvePreferred(record, lookupDefinition)
	if not resolved.Accepted then
		if resolved.ReasonId == "NoEquippedWeapon" then
			return result(false, "NoEquippedDurableWeapon", nil)
		end
		-- Preserve this service's pre-existing public failure vocabulary while
		-- delegating all ownership/slot/definition validation to the shared pure
		-- resolver used by live equipment activation.
		return result(false, "InvalidEquippedDurableItem", nil)
	end
	if resolved.WeaponId == nil then
		return result(false, "InvalidEquippedDurableItem", nil)
	end

	if not OperativeCombatRuntimeService.equipFoundWeapon(player, resolved.WeaponId) then
		return result(false, "CombatEquipRejected", nil)
	end
	return result(true, "DurableStartingWeaponApplied", resolved.WeaponId)
end

return table.freeze(Service)
