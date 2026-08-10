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

local EquippedEquipmentModifierResolver =
	require(ReplicatedStorage.Shared.Equipment.EquippedEquipmentModifierResolver)
local RelicModifierResolver = require(ReplicatedStorage.Shared.RPG.RelicModifierResolver)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local InventoryLiveService = require(script.Parent.InventoryLiveService)
local RunBuildService = require(script.Parent.RunBuildService)

export type RelicModifiers = RelicModifierResolver.RelicModifiers
export type OperativeModifiers = RelicModifiers & {
	equipmentDamageMultiplier: number,
}

type CacheEntry = {
	revision: number,
	modifiers: RelicModifiers,
}

local RelicModifierService = {}

local NEUTRAL_RELIC_MODIFIERS: RelicModifiers = RelicModifierResolver.deriveModifiers({})
local cache: { [Player]: CacheEntry } = {}

local function composeOperativeModifiers(player: Player, relicModifiers: RelicModifiers): OperativeModifiers
	local activeWeaponId = player:GetAttribute("LK_EquippedWeaponId")
	local equipmentModifiers = EquippedEquipmentModifierResolver.resolveForWeapon(
		InventoryLiveService.getRecord(player.UserId),
		activeWeaponId
	)
	local combined = table.clone(relicModifiers) :: any
	combined.equipmentDamageMultiplier = equipmentModifiers.damageMultiplier
	return table.freeze(combined) :: OperativeModifiers
end

--[[
	Returns the operative's current bounded modifier bundle. Relics may be served
	from the build-revision cache; durable equipment is resolved from the current
	authoritative inventory record and server-authored active weapon every read.
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
	cache[player] = { revision = read.revision, modifiers = modifiers }
	return composeOperativeModifiers(player, modifiers)
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
