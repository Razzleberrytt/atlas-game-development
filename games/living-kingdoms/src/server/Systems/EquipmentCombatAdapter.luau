--!strict

--[[
	Narrow server-only adapter between durable equipment and the combat owner.
	Inventory remains the source of truth: callers provide only an owned
	instance id (or ask for the preferred equipped weapon), this module resolves
	the authored WeaponId from the resident server record, then uses the existing
	authoritative combat equip API.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local EquippedWeaponResolver = require(ReplicatedStorage.Shared.Equipment.EquippedWeaponResolver)
local InventoryLiveService = require(script.Parent.InventoryLiveService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function lookupDefinition(definitionId: string): any
	return definitionsById[definitionId]
end

local Service = {}

function Service.isWeaponSlot(slotId: unknown): boolean
	return EquippedWeaponResolver.isWeaponSlot(slotId)
end

function Service.activateOwnedEquippedWeapon(player: Player, instanceId: unknown): (boolean, string)
	local record = InventoryLiveService.getRecord(player.UserId)
	if record == nil then
		return false, "InventoryNotLoaded"
	end
	local resolved = EquippedWeaponResolver.resolveInstance(record, instanceId, lookupDefinition)
	if not resolved.Accepted or resolved.WeaponId == nil then
		return false, resolved.ReasonId
	end
	if not OperativeCombatRuntimeService.equipFoundWeapon(player, resolved.WeaponId) then
		return false, "CombatWeaponRejected"
	end
	return true, "CombatWeaponActivated"
end

function Service.activatePreferredOrDefault(player: Player): (boolean, string)
	local record = InventoryLiveService.getRecord(player.UserId)
	if record == nil then
		return false, "InventoryNotLoaded"
	end
	local resolved = EquippedWeaponResolver.resolvePreferred(record, lookupDefinition)
	local weaponId = if resolved.Accepted and resolved.WeaponId ~= nil
		then resolved.WeaponId
		else FirearmConfig.DefaultSelectableWeaponId
	if not OperativeCombatRuntimeService.equipFoundWeapon(player, weaponId) then
		return false, "CombatWeaponRejected"
	end
	return true, if resolved.Accepted then "PreferredCombatWeaponActivated" else "DefaultCombatWeaponActivated"
end

return table.freeze(Service)
