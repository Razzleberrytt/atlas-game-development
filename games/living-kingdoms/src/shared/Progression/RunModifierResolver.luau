--!strict

--[[
	Central bounded arithmetic for operation-scoped RPG modifiers. Callers own
	the facts that produce contributions; this module only validates, combines
	neutral defaults, and applies the canonical RunRpgConfig safety ceilings.
]]

local RunRpgConfig = require(script.Parent.Parent.Config.RunRpgConfig)

local Ceilings = RunRpgConfig.ModifierCeilings

export type Contributions = {
	damageBonus: number?,
	cadenceReduction: number?,
	ammunitionConservationChance: number?,
	cullDamageBonus: number?,
	incomingDamageReduction: number?,
	fieldXpBonus: number?,
	reloadDurationReduction: number?,
	patternDamageBonus: number?,
	specialEnemyDamageBonus: number?,
	magazineCapacityBonus: number?,
	lootPickupRadiusBonusStuds: number?,
	conditionalDamageBonus: number?,
	movementSpeedBonus: number?,
	automaticHealingPerTrigger: number?,
	temporaryArmorFractionOfMaximumHealth: number?,
	lootChanceAdditiveBonus: number?,
	killChainExtensionSeconds: number?,
	generalProcChance: number?,
}

export type ResolvedModifiers = {
	damageMultiplier: number,
	cadenceMultiplier: number,
	ammunitionConservationChance: number,
	cullDamageMultiplier: number,
	incomingDamageMultiplier: number,
	fieldXpMultiplier: number,
	reloadDurationMultiplier: number,
	patternDamageMultiplier: number,
	specialEnemyDamageMultiplier: number,
	magazineCapacityMultiplier: number,
	lootPickupRadiusBonusStuds: number,
	conditionalDamageMultiplier: number,
	movementSpeedMultiplier: number,
	automaticHealingPerTrigger: number,
	temporaryArmorFractionOfMaximumHealth: number,
	lootChanceAdditiveBonus: number,
	killChainExtensionSeconds: number,
	generalProcChance: number,
}

local RunModifierResolver = {}

local knownContributionKeys = table.freeze({
	damageBonus = true,
	cadenceReduction = true,
	ammunitionConservationChance = true,
	cullDamageBonus = true,
	incomingDamageReduction = true,
	fieldXpBonus = true,
	reloadDurationReduction = true,
	patternDamageBonus = true,
	specialEnemyDamageBonus = true,
	magazineCapacityBonus = true,
	lootPickupRadiusBonusStuds = true,
	conditionalDamageBonus = true,
	movementSpeedBonus = true,
	automaticHealingPerTrigger = true,
	temporaryArmorFractionOfMaximumHealth = true,
	lootChanceAdditiveBonus = true,
	killChainExtensionSeconds = true,
	generalProcChance = true,
})

local function neutralModifiers(): ResolvedModifiers
	return table.freeze({
		damageMultiplier = 1,
		cadenceMultiplier = 1,
		ammunitionConservationChance = 0,
		cullDamageMultiplier = 1,
		incomingDamageMultiplier = 1,
		fieldXpMultiplier = 1,
		reloadDurationMultiplier = 1,
		patternDamageMultiplier = 1,
		specialEnemyDamageMultiplier = 1,
		magazineCapacityMultiplier = 1,
		lootPickupRadiusBonusStuds = 0,
		conditionalDamageMultiplier = 1,
		movementSpeedMultiplier = 1,
		automaticHealingPerTrigger = 0,
		temporaryArmorFractionOfMaximumHealth = 0,
		lootChanceAdditiveBonus = 0,
		killChainExtensionSeconds = 0,
		generalProcChance = 0,
	})
end

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function validateContributions(contributions: Contributions): boolean
	if type(contributions) ~= "table" then
		return false
	end
	for key, value in contributions do
		if type(key) ~= "string" or not knownContributionKeys[key] or not isFiniteNonnegative(value) then
			return false
		end
	end
	return true
end

function RunModifierResolver.resolve(contributions: Contributions): ResolvedModifiers
	if not validateContributions(contributions) then
		return neutralModifiers()
	end

	return table.freeze({
		damageMultiplier = math.clamp(1 + (contributions.damageBonus or 0), 1, Ceilings.maximumDamageMultiplier),
		cadenceMultiplier = math.clamp(1 - (contributions.cadenceReduction or 0), Ceilings.minimumCadenceMultiplier, 1),
		ammunitionConservationChance = math.clamp(
			contributions.ammunitionConservationChance or 0,
			0,
			Ceilings.maximumAmmunitionConservationChance
		),
		cullDamageMultiplier = math.clamp(
			1 + (contributions.cullDamageBonus or 0),
			1,
			Ceilings.maximumDamageMultiplier
		),
		incomingDamageMultiplier = 1
			- math.clamp(contributions.incomingDamageReduction or 0, 0, Ceilings.maximumIncomingDamageReduction),
		fieldXpMultiplier = math.clamp(1 + (contributions.fieldXpBonus or 0), 1, Ceilings.maximumFieldXpMultiplier),
		reloadDurationMultiplier = math.clamp(
			1 - (contributions.reloadDurationReduction or 0),
			Ceilings.minimumReloadDurationMultiplier,
			1
		),
		patternDamageMultiplier = math.clamp(
			1 + (contributions.patternDamageBonus or 0),
			1,
			Ceilings.maximumPatternDamageMultiplier
		),
		specialEnemyDamageMultiplier = math.clamp(
			1 + (contributions.specialEnemyDamageBonus or 0),
			1,
			Ceilings.maximumSpecialEnemyDamageMultiplier
		),
		magazineCapacityMultiplier = math.clamp(
			1 + (contributions.magazineCapacityBonus or 0),
			1,
			Ceilings.maximumMagazineCapacityMultiplier
		),
		lootPickupRadiusBonusStuds = math.clamp(
			contributions.lootPickupRadiusBonusStuds or 0,
			0,
			Ceilings.maximumLootPickupRadiusBonusStuds
		),
		conditionalDamageMultiplier = math.clamp(
			1 + (contributions.conditionalDamageBonus or 0),
			1,
			Ceilings.maximumConditionalDamageMultiplier
		),
		movementSpeedMultiplier = math.clamp(
			1 + (contributions.movementSpeedBonus or 0),
			1,
			Ceilings.maximumMovementSpeedMultiplier
		),
		automaticHealingPerTrigger = math.clamp(
			contributions.automaticHealingPerTrigger or 0,
			0,
			Ceilings.maximumAutomaticHealingPerTrigger
		),
		temporaryArmorFractionOfMaximumHealth = math.clamp(
			contributions.temporaryArmorFractionOfMaximumHealth or 0,
			0,
			Ceilings.maximumTemporaryArmorFractionOfMaximumHealth
		),
		lootChanceAdditiveBonus = math.clamp(
			contributions.lootChanceAdditiveBonus or 0,
			0,
			Ceilings.maximumLootChanceAdditiveBonus
		),
		killChainExtensionSeconds = math.clamp(
			contributions.killChainExtensionSeconds or 0,
			0,
			Ceilings.maximumKillChainExtensionSeconds
		),
		generalProcChance = math.clamp(contributions.generalProcChance or 0, 0, Ceilings.maximumGeneralProcChance),
	})
end

function RunModifierResolver.neutral(): ResolvedModifiers
	return neutralModifiers()
end

return table.freeze(RunModifierResolver)
