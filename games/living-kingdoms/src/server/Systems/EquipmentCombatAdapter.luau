--!strict

--[[
	Narrow server-only adapter between durable equipment and the authoritative
	combat owner. Durable inventory remains the source of truth: callers provide
	only an owned instance id, or request the preferred equipped weapon. Weapon
	identity is resolved from the resident server record plus authored config and
	then handed to OperativeCombatRuntimeService.equipFoundWeapon.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local EquippedWeaponResolver = require(ReplicatedStorage.Shared.Equipment.EquippedWeaponResolver)
local InventoryLiveService = require(script.Parent.InventoryLiveService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

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

local function activateWeaponId(player: Player, weaponId: string, successReasonId: string): (boolean, string)
	if not OperativeLifeService.isCombatAllowed(player) then
		return false, "CombatNotAllowed"
	end
	if not OperativeCombatRuntimeService.equipFoundWeapon(player, weaponId) then
		-- EquipmentRewardConfig validates every durable weapon identity against
		-- FirearmConfig. Once life permits combat, rejection therefore means the
		-- player's combat runtime state has not mounted yet rather than a reason
		-- to trust a client-authored fallback.
		return false, "CombatRuntimeNotReady"
	end
	return true, successReasonId
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
	return activateWeaponId(player, resolved.WeaponId, "CombatWeaponActivated")
end

function Service.activatePreferredOrDefault(player: Player): (boolean, string)
	local record = InventoryLiveService.getRecord(player.UserId)
	if record == nil then
		return false, "InventoryNotLoaded"
	end
	local resolved = EquippedWeaponResolver.resolvePreferred(record, lookupDefinition)
	if resolved.Accepted and resolved.WeaponId ~= nil then
		return activateWeaponId(player, resolved.WeaponId, "PreferredCombatWeaponActivated")
	end
	if resolved.ReasonId ~= "NoEquippedWeapon" then
		return false, resolved.ReasonId
	end
	return activateWeaponId(player, FirearmConfig.DefaultSelectableWeaponId, "DefaultCombatWeaponActivated")
end

return table.freeze(Service)
