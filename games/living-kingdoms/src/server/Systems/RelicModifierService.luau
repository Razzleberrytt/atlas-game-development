--!strict

--[[
	Server-side per-operative modifier adapter.

	The authoritative combat, reload, life, and class-action owners need one
	operative's bounded modifier bundle many times per evaluation. Relic facts are
	derived from the existing RunBuildService owner and cached against its
	server-owned revision. Durable-equipment facts are joined from the authoritative
	inventory record on each read so an equip change cannot be hidden behind the
	relic cache.

	Wave 2 character stats are composed here because this is already the server
	boundary consumed by damage, life, movement, reload, and cooldown owners. The
	central stat read excludes Equipment so legacy authoritative item multipliers
	remain single-applied until Agent 3 elects to move those sources into StatService.
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
local CharacterStatConfig = require(ReplicatedStorage.Shared.Config.CharacterStatConfig)
local CharacterStatService = require(script.Parent.CharacterStatService)
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
	equipmentAbilityCooldownDurationMultiplier: number,
	equipmentAbilityPowerMultiplier: number,
}

type CacheEntry = {
	revision: number,
	modifiers: RelicModifiers,
}

local RelicModifierService = {}

local NEUTRAL_RELIC_MODIFIERS: RelicModifiers = RelicModifierResolver.deriveModifiers({})
local cache: { [Player]: CacheEntry } = {}

-- These match the defensive bounds already expected by the authoritative
-- gameplay owners. Composition clamps here so a valid progression+equipment
-- combination never trips a downstream malformed-data fallback back to neutral.
local DAMAGE_MULTIPLIER_MINIMUM = 0.1
local DAMAGE_MULTIPLIER_MAXIMUM = 5
local LIFE_MULTIPLIER_MINIMUM = 1
local LIFE_MULTIPLIER_MAXIMUM = 2
local COOLDOWN_MULTIPLIER_MINIMUM = 0.5
local COOLDOWN_MULTIPLIER_MAXIMUM = 2

local function canComposeEquipment(player: Player): boolean
	local playerAsAny = player :: any
	return EquippedEquipmentModifierResolver ~= nil
		and InventoryLiveService ~= nil
		and type(playerAsAny.GetAttribute) == "function"
end

local function characterStatRatio(player: Player, statId: string): number
	local definition = CharacterStatConfig.Stats[statId]
	if type(definition) ~= "table" or type(definition.BaseValue) ~= "number" or definition.BaseValue <= 0 then
		return 1
	end
	local resolved = CharacterStatService.getResolvedStatExcludingSourceCategory(
		player,
		statId,
		CharacterStatConfig.SourceCategories.Equipment
	)
	if type(resolved) ~= "number" or resolved ~= resolved or resolved == math.huge or resolved == -math.huge then
		return 1
	end
	return math.clamp(resolved / definition.BaseValue, 0.1, 5)
end

local function applyCharacterStats(player: Player, combined: any)
	combined.equipmentDamageMultiplier *= characterStatRatio(player, CharacterStatConfig.StatIds.DamageMultiplier)
	combined.equipmentMaximumHealthMultiplier *= characterStatRatio(player, CharacterStatConfig.StatIds.MaxHealth)
	combined.equipmentMovementSpeedMultiplier *= characterStatRatio(player, CharacterStatConfig.StatIds.MovementSpeed)
	combined.equipmentAbilityCooldownDurationMultiplier *=
		characterStatRatio(player, CharacterStatConfig.StatIds.CooldownDurationMultiplier)

	combined.equipmentDamageMultiplier = math.clamp(
		combined.equipmentDamageMultiplier,
		DAMAGE_MULTIPLIER_MINIMUM,
		DAMAGE_MULTIPLIER_MAXIMUM
	)
	combined.equipmentMaximumHealthMultiplier = math.clamp(
		combined.equipmentMaximumHealthMultiplier,
		LIFE_MULTIPLIER_MINIMUM,
		LIFE_MULTIPLIER_MAXIMUM
	)
	combined.equipmentMovementSpeedMultiplier = math.clamp(
		combined.equipmentMovementSpeedMultiplier,
		LIFE_MULTIPLIER_MINIMUM,
		LIFE_MULTIPLIER_MAXIMUM
	)
	combined.equipmentAbilityCooldownDurationMultiplier = math.clamp(
		combined.equipmentAbilityCooldownDurationMultiplier,
		COOLDOWN_MULTIPLIER_MINIMUM,
		COOLDOWN_MULTIPLIER_MAXIMUM
	)
end

local function composeOperativeModifiers(player: Player, relicModifiers: RelicModifiers): OperativeModifiers
	local combined = table.clone(relicModifiers) :: any
	combined.equipmentDamageMultiplier = 1
	combined.equipmentReloadDurationMultiplier = 1
	combined.equipmentMaximumHealthMultiplier = 1
	combined.equipmentMovementSpeedMultiplier = 1
	combined.equipmentAbilityCooldownDurationMultiplier = 1
	combined.equipmentAbilityPowerMultiplier = 1
	if not canComposeEquipment(player) then
		applyCharacterStats(player, combined)
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
		local relicEquipmentModifiers = resolverAsAny.resolveForSlot(record, "Relic")
		if type(relicEquipmentModifiers) == "table" then
			if type(relicEquipmentModifiers.abilityCooldownDurationMultiplier) == "number" then
				combined.equipmentAbilityCooldownDurationMultiplier =
					relicEquipmentModifiers.abilityCooldownDurationMultiplier
			end
			if type(relicEquipmentModifiers.abilityPowerMultiplier) == "number" then
				combined.equipmentAbilityPowerMultiplier = relicEquipmentModifiers.abilityPowerMultiplier
			end
		end
	end
	applyCharacterStats(player, combined)
	return table.freeze(combined) :: OperativeModifiers
end

--[[
	Returns the operative's current bounded modifier bundle. Relics may be served
	from the build-revision cache; durable equipment and character stats are
	resolved from their current authoritative state every read because their
	revisions are independent from the temporary run-build revision.
]]
function RelicModifierService.read(player: Player): OperativeModifiers
	local read = RunBuildService.readEquippedRelicIds(player)
	if read == nil then
		cache[player] = nil
		return composeOperativeModifiers(player, NEUTRAL_RELIC_MODIFIERS)
	end
	local cached = cache[player]
	if cached ~= nil and cached.revision == read.revision then
		return composeOperativeModifiers(player, cached.modifiers)
	end
	local modifiers = RelicModifierResolver.deriveModifiers(read.relicIds)
	local composed = composeOperativeModifiers(player, modifiers)
	cache[player] = {
		revision = read.revision,
		modifiers = modifiers,
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
