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

-- Passive inventory/life reconciliation must not grant the default firearm to a
-- player with no durable weapon. That would skip the intentional melee-to-first-
-- pistol recovery loop. No durable weapon is therefore an accepted no-op here.
function Service.activatePreferredEquippedWeapon(player: Player): (boolean, string)
	local record = InventoryLiveService.getRecord(player.UserId)
	if record == nil then
		return false, "InventoryNotLoaded"
	end
	local resolved = EquippedWeaponResolver.resolvePreferred(record, lookupDefinition)
	if not resolved.Accepted then
		if resolved.ReasonId == "NoEquippedWeapon" then
			return true, "NoEquippedWeapon"
		end
		return false, resolved.ReasonId
	end
	if resolved.WeaponId == nil then
		return false, "InvalidWeaponDefinition"
	end
	return activateWeaponId(player, resolved.WeaponId, "PreferredCombatWeaponActivated")
end

-- An explicit weapon-slot unequip is different from passive reconciliation: the
-- current durable firearm must stop driving combat. Prefer any remaining durable
-- weapon; with none left, swap through the canonical default firearm identity.
-- Combat's swap resolver carries existing ammunition forward, so this fallback
-- does not mint ammunition on equip/unequip churn.
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
