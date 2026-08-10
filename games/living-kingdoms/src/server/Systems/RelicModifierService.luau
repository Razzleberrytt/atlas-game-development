--!strict

--[[
	Server-side per-operative modifier adapter.

	The authoritative combat, reload, and life owners need one operative's bounded
	modifier bundle many times per evaluation. Relic facts are derived from the
	existing RunBuildService owner and cached against its server-owned revision.
	Durable-equipment facts are joined from the authoritative inventory record on
	each read so an equip change cannot be hidden behind the relic cache.

	This adapter owns no relic or inventory state, creates no connections, and adds
	no network surface. It is the server composition seam between independently
	owned build facts and the existing gameplay owners that consume them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Equipment is an additive Patch 0.3 composition seam. Full production builds
-- contain both modules; narrow resolver fixtures and partial runtimes may omit
-- them. Missing composition dependencies therefore fail closed to neutral
-- multipliers instead of crashing unrelated relic behavior.
local equippedEquipmentModifierResolverModule = if ReplicatedStorage.Shared.Equipment == nil
	then nil
	else ReplicatedStorage.Shared.Equipment.EquippedEquipmentModifierResolver
local EquippedEquipmentModifierResolver = if equippedEquipmentModifierResolverModule == nil
	then nil
	else require(equippedEquipmentModifierResolverModule)
local RelicModifierResolver = require(ReplicatedStorage.Shared.RPG.RelicModifierResolver)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local inventoryLiveServiceModule = script.Parent.InventoryLiveService
local InventoryLiveService = if EquippedEquipmentModifierResolver == nil or inventoryLiveServiceModule == nil
	then nil
	else require(inventoryLiveServiceModule)
local RunBuildService = require(script.Parent.RunBuildService)

export type RelicModifiers = RelicModifierResolver.RelicModifiers
export type OperativeModifiers = RelicModifiers & {
	equipmentDamageMultiplier: number,
	equipmentReloadDurationMultiplier: number,
	equipmentMaximumHealthMultiplier: number,
	equipmentMovementSpeedMultiplier: number,
}

type CacheEntry = {
	revision: number,
	modifiers: RelicModifiers,
	partialRuntimeModifiers: OperativeModifiers?,
}

local RelicModifierService = {}

local NEUTRAL_RELIC_MODIFIERS: RelicModifiers = RelicModifierResolver.deriveModifiers({})
local cache: { [Player]: CacheEntry } = {}

local function canComposeEquipment(player: Player): boolean
	local playerAsAny = player :: any
	return EquippedEquipmentModifierResolver ~= nil
		and InventoryLiveService ~= nil
		and type(playerAsAny.GetAttribute) == "function"
end

local function composeOperativeModifiers(player: Player, relicModifiers: RelicModifiers): OperativeModifiers
	local combined = table.clone(relicModifiers) :: any
	combined.equipmentDamageMultiplier = 1
	combined.equipmentReloadDurationMultiplier = 1
	combined.equipmentMaximumHealthMultiplier = 1
	combined.equipmentMovementSpeedMultiplier = 1
	if not canComposeEquipment(player) then
		return table.freeze(combined) :: OperativeModifiers
	end
	local record = InventoryLiveService.getRecord(player.UserId)
	local activeWeaponId = player:GetAttribute("LK_EquippedWeaponId")
	local weaponModifiers = EquippedEquipmentModifierResolver.resolveForWeapon(record, activeWeaponId)
	combined.equipmentDamageMultiplier = weaponModifiers.damageMultiplier
	combined.equipmentReloadDurationMultiplier = weaponModifiers.reloadDurationMultiplier
	local resolverAsAny = EquippedEquipmentModifierResolver :: any
	if type(resolverAsAny.resolveForSlot) == "function" then
		local armorModifiers = resolverAsAny.resolveForSlot(record, "Armor")
		if type(armorModifiers) == "table" then
			if type(armorModifiers.maximumHealthMultiplier) == "number" then
				combined.equipmentMaximumHealthMultiplier = armorModifiers.maximumHealthMultiplier
			end
			if type(armorModifiers.movementSpeedMultiplier) == "number" then
				combined.equipmentMovementSpeedMultiplier = armorModifiers.movementSpeedMultiplier
			end
		end
	end
	return table.freeze(combined) :: OperativeModifiers
end

--[[
	Returns the operative's current bounded modifier bundle. Relics may be served
	from the build-revision cache; durable equipment is resolved from the current
	authoritative inventory record and server-authored active weapon every read.

	Partial runtimes that omit equipment composition reuse one neutral composed
	bundle per relic revision. Full production runtimes deliberately do not cache
	the composed equipment result, because durable equip changes have an authority
	revision independent from the temporary run-build revision.
]]
function RelicModifierService.read(player: Player): OperativeModifiers
	local read = RunBuildService.readEquippedRelicIds(player)
	if read == nil then
		cache[player] = nil
		return composeOperativeModifiers(player, NEUTRAL_RELIC_MODIFIERS)
	end
	local cached = cache[player]
	if cached ~= nil and cached.revision == read.revision then
		if not canComposeEquipment(player) then
			if cached.partialRuntimeModifiers == nil then
				cached.partialRuntimeModifiers = composeOperativeModifiers(player, cached.modifiers)
			end
			return cached.partialRuntimeModifiers
		end
		return composeOperativeModifiers(player, cached.modifiers)
	end
	local modifiers = RelicModifierResolver.deriveModifiers(read.relicIds)
	local composed = composeOperativeModifiers(player, modifiers)
	cache[player] = {
		revision = read.revision,
		modifiers = modifiers,
		partialRuntimeModifiers = if canComposeEquipment(player) then nil else composed,
	}
	return composed
end

--[[
	Advances Blood Battery's confirmed-kill counter in its equipped slot and
	returns how many times it triggered. Returns zero when the relic is not
	equipped, when the operation is stopped, or when the kill count is not a whole
	positive number; the caller commits the healing through the authoritative life
	boundary.
]]
function RelicModifierService.advanceBloodBatteryKills(player: Player, kills: number, killThreshold: number): number
	if
		type(kills) ~= "number"
		or kills ~= kills
		or kills <= 0
		or kills % 1 ~= 0
		or type(killThreshold) ~= "number"
		or killThreshold <= 0
	then
		return 0
	end
	local advance =
		RunBuildService.advanceRelicCounter(player, RunRpgContracts.RelicIds.BloodBattery, kills, killThreshold)
	return if advance == nil then 0 else advance.triggerCount
end

--[[
	Suppression Engine's sustained-shot progress. The counter saturates in the
	equipped relic slot, so it survives nothing the relic is not equipped for and
	is released with the operation like every other slot fact. Reading an
	unequipped relic returns zero and resetting it is a no-op.
]]
function RelicModifierService.readSustainedShots(player: Player): number
	local counter = RunBuildService.readRelicCounter(player, RunRpgContracts.RelicIds.SuppressionEngine)
	return if type(counter) == "number" then counter else 0
end

function RelicModifierService.recordSustainedShot(player: Player)
	local counter = RunBuildService.readRelicCounter(player, RunRpgContracts.RelicIds.SuppressionEngine)
	if type(counter) ~= "number" then
		return
	end
	RunBuildService.setRelicCounter(player, RunRpgContracts.RelicIds.SuppressionEngine, counter + 1)
end

function RelicModifierService.resetSustainedShots(player: Player)
	RunBuildService.setRelicCounter(player, RunRpgContracts.RelicIds.SuppressionEngine, 0)
end

--[[
	Spends Second Wind's single operation charge. Returns false when the relic is
	not equipped or already spent, so the reprieve cannot repeat.
]]
function RelicModifierService.consumeSecondWindCharge(player: Player): boolean
	return RunBuildService.consumeRelicCharge(player, RunRpgContracts.RelicIds.SecondWind)
end

function RelicModifierService.forget(player: Player)
	cache[player] = nil
end

function RelicModifierService.clear()
	table.clear(cache)
end

return table.freeze(RelicModifierService)
