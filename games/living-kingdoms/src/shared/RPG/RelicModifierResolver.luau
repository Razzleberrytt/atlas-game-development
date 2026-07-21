--!strict

--[[
	RPG-0108 (part 1) pure per-operative relic modifier resolver.

	Derives the bounded combat/reload/life modifiers that an operative's equipped
	relics contribute, delegating every arithmetic clamp to the shared
	RunModifierResolver so relic power can never exceed a canonical global ceiling.
	It owns no state and reads no services beyond the frozen relic tuning.

	Conditional relics (Choir Breaker, Last Light, Execution Protocol) return both
	their multiplier and the condition threshold, mirroring the existing
	RunUpgradeResolver combat-modifier shape: the future runtime evaluates the
	per-shot/per-operative condition and applies the multiplier. Blood Battery's
	kill-counted healing is exposed through a separate pure helper.

	The RPG-0108 part 2 runtime threads these outputs through the authoritative
	passes: RelicModifierService caches one bundle per operative, DamageResolver
	consumes the conditional damage multipliers, and ReloadResolver consumes the
	wounded reload reduction.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RelicRuntimeConfig = require(ReplicatedStorage.Shared.Config.RelicRuntimeConfig)
local RunModifierResolver = require(ReplicatedStorage.Shared.Progression.RunModifierResolver)

local RelicIds = RunRpgContracts.RelicIds

export type RelicModifiers = {
	killChainExtensionSeconds: number,
	specialEnemyDamageMultiplier: number,
	lowReserveDamageMultiplier: number,
	lowReserveFraction: number,
	woundedReloadDurationMultiplier: number,
	woundedHealthFraction: number,
	executionDamageMultiplier: number,
	executionHealthFraction: number,
	bloodBatteryKillThreshold: number,
	bloodBatteryHealAmount: number,
}

export type BloodBatteryResult = {
	counterAfter: number,
	healAmount: number,
}

export type CounterAdvance = {
	counterAfter: number,
	triggerCount: number,
}

local RelicModifierResolver = {}

local function neutralModifiers(): RelicModifiers
	return {
		killChainExtensionSeconds = 0,
		specialEnemyDamageMultiplier = 1,
		lowReserveDamageMultiplier = 1,
		lowReserveFraction = 0,
		woundedReloadDurationMultiplier = 1,
		woundedHealthFraction = 0,
		executionDamageMultiplier = 1,
		executionHealthFraction = 0,
		bloodBatteryKillThreshold = 0,
		bloodBatteryHealAmount = 0,
	}
end

local function isNonnegativeInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value % 1 == 0
end

--[[
	Returns the bounded relic modifier bundle for one operative. `equippedRelicIds`
	is the operative's equipped relic list; unknown entries fail the whole call
	closed to neutral, while known relics without runtime tuning (later batches)
	contribute nothing. Duplicate IDs collapse because relics are non-stackable.
]]
function RelicModifierResolver.deriveModifiers(equippedRelicIds: { string }): RelicModifiers
	local modifiers = neutralModifiers()
	if type(equippedRelicIds) ~= "table" then
		return table.freeze(modifiers)
	end

	local equipped: { [string]: boolean } = {}
	for _, relicId in equippedRelicIds do
		if type(relicId) ~= "string" or not RunRpgContracts.isKnownRelicId(relicId) then
			return table.freeze(neutralModifiers())
		end
		equipped[relicId] = true
	end

	if equipped[RelicIds.BloodBattery] then
		local tuning = RelicRuntimeConfig.BloodBattery
		modifiers.bloodBatteryKillThreshold = tuning.killThreshold
		modifiers.bloodBatteryHealAmount =
			RunModifierResolver.resolve({ automaticHealingPerTrigger = tuning.healAmount }).automaticHealingPerTrigger
	end
	if equipped[RelicIds.GraveMomentum] then
		modifiers.killChainExtensionSeconds = RunModifierResolver.resolve({
			killChainExtensionSeconds = RelicRuntimeConfig.GraveMomentum.killChainExtensionSeconds,
		}).killChainExtensionSeconds
	end
	if equipped[RelicIds.ChoirBreaker] then
		modifiers.specialEnemyDamageMultiplier = RunModifierResolver.resolve({
			specialEnemyDamageBonus = RelicRuntimeConfig.ChoirBreaker.specialEnemyDamageBonus,
		}).specialEnemyDamageMultiplier
	end
	if equipped[RelicIds.LastLight] then
		local tuning = RelicRuntimeConfig.LastLight
		modifiers.lowReserveDamageMultiplier = RunModifierResolver.resolve({
			conditionalDamageBonus = tuning.conditionalDamageBonus,
		}).conditionalDamageMultiplier
		modifiers.lowReserveFraction = tuning.reserveFraction
	end
	if equipped[RelicIds.EmergencyChamber] then
		local tuning = RelicRuntimeConfig.EmergencyChamber
		modifiers.woundedReloadDurationMultiplier = RunModifierResolver.resolve({
			reloadDurationReduction = tuning.reloadDurationReduction,
		}).reloadDurationMultiplier
		modifiers.woundedHealthFraction = tuning.woundedHealthFraction
	end
	if equipped[RelicIds.ExecutionProtocol] then
		local tuning = RelicRuntimeConfig.ExecutionProtocol
		modifiers.executionDamageMultiplier = RunModifierResolver.resolve({
			conditionalDamageBonus = tuning.conditionalDamageBonus,
		}).conditionalDamageMultiplier
		modifiers.executionHealthFraction = tuning.healthFraction
	end

	return table.freeze(modifiers)
end

--[[
	Pure counted-relic advance. Given the counter before, the whole number of
	events to apply, and the trigger threshold, returns the counter remainder and
	how many times the relic triggered. Invalid input leaves the counter unchanged
	and triggers nothing, so a malformed caller can never manufacture an effect.
]]
function RelicModifierResolver.advanceCounter(
	counterBefore: number,
	increment: number,
	threshold: number
): CounterAdvance
	if
		not isNonnegativeInteger(counterBefore)
		or not isNonnegativeInteger(increment)
		or not isNonnegativeInteger(threshold)
		or threshold <= 0
	then
		return table.freeze({
			counterAfter = if isNonnegativeInteger(counterBefore) then counterBefore else 0,
			triggerCount = 0,
		})
	end
	local total = counterBefore + increment
	return table.freeze({
		counterAfter = total % threshold,
		triggerCount = math.floor(total / threshold),
	})
end

--[[
	Pure Blood Battery kill-counter advance. Given the counter before, the whole
	number of confirmed kills to apply, and the tuning threshold/heal amount,
	returns the counter remainder and the total health to restore. The caller
	clamps healing against maximum health and refuses Dead operatives. A
	non-positive threshold (relic not equipped) disables healing.
]]
function RelicModifierResolver.advanceBloodBattery(
	counterBefore: number,
	kills: number,
	killThreshold: number,
	healAmount: number
): BloodBatteryResult
	if type(healAmount) ~= "number" or healAmount ~= healAmount or healAmount < 0 then
		return table.freeze({
			counterAfter = if isNonnegativeInteger(counterBefore) then counterBefore else 0,
			healAmount = 0,
		})
	end
	local advance = RelicModifierResolver.advanceCounter(counterBefore, kills, killThreshold)
	return table.freeze({
		counterAfter = advance.counterAfter,
		healAmount = advance.triggerCount * healAmount,
	})
end

return table.freeze(RelicModifierResolver)
