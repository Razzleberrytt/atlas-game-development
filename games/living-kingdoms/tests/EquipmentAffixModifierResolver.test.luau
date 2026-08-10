--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function assertNear(actual: number, expected: number, message: string)
	assertThat(math.abs(actual - expected) < 1e-9, message)
end

local RUN_CONFIG_TOKEN = {}
local runConfig = {
	ModifierCeilings = {
		maximumDamageMultiplier = 3,
		minimumCadenceMultiplier = 0.25,
		maximumAmmunitionConservationChance = 0.75,
		maximumIncomingDamageReduction = 0.75,
		maximumFieldXpMultiplier = 3,
		minimumReloadDurationMultiplier = 0.25,
		maximumPatternDamageMultiplier = 2,
		maximumSpecialEnemyDamageMultiplier = 2,
		maximumMagazineCapacityMultiplier = 3,
		maximumLootPickupRadiusBonusStuds = 40,
		maximumConditionalDamageMultiplier = 2,
		maximumMovementSpeedMultiplier = 2,
		maximumAutomaticHealingPerTrigger = 100,
		maximumTemporaryArmorFractionOfMaximumHealth = 1,
		maximumLootChanceAdditiveBonus = 1,
		maximumLootRoundsAdditiveBonus = 100,
		maximumKillChainExtensionSeconds = 30,
		maximumGeneralProcChance = 1,
	},
}
local runModifierResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunModifierResolver.luau"), {
		debugName = "RunModifierResolver",
		environment = {
			script = { Parent = { Parent = { Config = { RunRpgConfig = RUN_CONFIG_TOKEN } } } },
			require = function(token: unknown)
				assertThat(token == RUN_CONFIG_TOKEN, "unexpected run-modifier dependency")
				return runConfig
			end,
		},
		injectGlobals = true,
	})()

local EQUIPMENT_TOKEN = {}
local RUN_MODIFIER_TOKEN = {}
local equipmentContracts = {}
local resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau"), {
		debugName = "EquipmentAffixModifierResolver",
		environment = {
			script = {
				Parent = {
					EquipmentRewardContracts = EQUIPMENT_TOKEN,
					Parent = { Progression = { RunModifierResolver = RUN_MODIFIER_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == EQUIPMENT_TOKEN then
					return equipmentContracts
				end
				assertThat(token == RUN_MODIFIER_TOKEN, "unexpected affix-modifier dependency")
				return runModifierResolver
			end,
		},
		injectGlobals = true,
	})()

local function affix(effectId: string, value: number): any
	return { Id = effectId, Version = "1", DisplayName = effectId, EffectId = effectId, Value = value }
end

local missing = resolver.resolve(nil)
assertThat(missing.damageMultiplier == 1, "missing affixes must keep damage neutral")
assertThat(missing.reloadDurationMultiplier == 1, "missing affixes must keep reload neutral")
assertThat(missing.maximumHealthMultiplier == 1, "missing affixes must keep max health neutral")
assertThat(missing.movementSpeedMultiplier == 1, "missing affixes must keep movement neutral")
assertThat(missing.abilityCooldownDurationMultiplier == 1, "missing affixes must keep ability cooldown neutral")

local damageOnly = resolver.resolve({ affix("DamagePercent", 7) })
assertNear(damageOnly.damageMultiplier, 1.07, "damage percent must translate")
assertThat(damageOnly.movementSpeedMultiplier == 1, "damage must not leak into movement")
assertThat(damageOnly.abilityCooldownDurationMultiplier == 1, "damage must not leak into ability cooldown")

local reloadOnly = resolver.resolve({ affix("ReloadSpeedPercent", 8) })
assertNear(reloadOnly.reloadDurationMultiplier, 0.92, "reload speed percent must reduce reload duration")
assertThat(reloadOnly.movementSpeedMultiplier == 1, "reload speed must not leak into movement")
assertThat(reloadOnly.abilityCooldownDurationMultiplier == 1, "reload speed must not leak into ability cooldown")

local maxHealthOnly = resolver.resolve({ affix("MaxHealthPercent", 8) })
assertNear(maxHealthOnly.maximumHealthMultiplier, 1.08, "max health percent must translate")
assertThat(maxHealthOnly.movementSpeedMultiplier == 1, "max health must not leak into movement")
assertThat(maxHealthOnly.abilityCooldownDurationMultiplier == 1, "max health must not leak into ability cooldown")

local movementOnly = resolver.resolve({ affix("MoveSpeedPercent", 6) })
assertThat(movementOnly.damageMultiplier == 1, "movement speed must not leak into damage")
assertThat(movementOnly.reloadDurationMultiplier == 1, "movement speed must not leak into reload")
assertThat(movementOnly.maximumHealthMultiplier == 1, "movement speed must not leak into max health")
assertNear(movementOnly.movementSpeedMultiplier, 1.06, "movement speed percent must translate")
assertThat(movementOnly.abilityCooldownDurationMultiplier == 1, "movement speed must not leak into ability cooldown")
assertNear(
	resolver.resolve({ affix("MoveSpeedPercent", 3), affix("MoveSpeedPercent", 6) }).movementSpeedMultiplier,
	1.09,
	"multiple movement-speed rolls must aggregate"
)

local abilityHasteOnly = resolver.resolve({ affix("AbilityHastePercent", 10) })
assertNear(
	abilityHasteOnly.abilityCooldownDurationMultiplier,
	0.9,
	"ability haste percent must reduce cooldown duration"
)
assertThat(abilityHasteOnly.reloadDurationMultiplier == 1, "ability haste must not leak into reload")
assertThat(abilityHasteOnly.damageMultiplier == 1, "ability haste must not leak into damage")
assertNear(
	resolver.resolve({ affix("AbilityHastePercent", 5), affix("AbilityHastePercent", 10) }).abilityCooldownDurationMultiplier,
	0.85,
	"multiple ability-haste rolls must aggregate"
)

local mixed = resolver.resolve({
	affix("DamagePercent", 5),
	affix("ReloadSpeedPercent", 10),
	affix("MaxHealthPercent", 8),
	affix("MoveSpeedPercent", 6),
	affix("AbilityHastePercent", 10),
})
assertNear(mixed.damageMultiplier, 1.05, "mixed bundle must preserve damage")
assertNear(mixed.reloadDurationMultiplier, 0.9, "mixed bundle must preserve reload speed")
assertNear(mixed.maximumHealthMultiplier, 1.08, "mixed bundle must preserve maximum health")
assertNear(mixed.movementSpeedMultiplier, 1.06, "mixed bundle must preserve movement speed")
assertNear(mixed.abilityCooldownDurationMultiplier, 0.9, "mixed bundle must preserve ability haste")

local futureEffect = resolver.resolve({ affix("AbilityPowerPercent", 15), affix("AbilityHastePercent", 5) })
assertNear(
	futureEffect.abilityCooldownDurationMultiplier,
	0.95,
	"live ability haste must survive unresolved ability effects"
)
assertThat(futureEffect.damageMultiplier == 1, "unresolved ability effect must stay damage-neutral")

assertThat(
	resolver.resolve({ affix("DamagePercent", 500) }).damageMultiplier
		== runConfig.ModifierCeilings.maximumDamageMultiplier,
	"damage affixes must inherit the canonical global ceiling"
)
assertThat(
	resolver.resolve({ affix("ReloadSpeedPercent", 500) }).reloadDurationMultiplier
		== runConfig.ModifierCeilings.minimumReloadDurationMultiplier,
	"reload affixes must inherit the canonical global floor"
)
assertThat(
	resolver.resolve({ affix("AbilityHastePercent", 500) }).abilityCooldownDurationMultiplier
		== runConfig.ModifierCeilings.minimumReloadDurationMultiplier,
	"ability haste must inherit the canonical bounded duration floor"
)
assertThat(
	resolver.resolve({ affix("MaxHealthPercent", 500) }).maximumHealthMultiplier == 2,
	"max-health affixes must inherit their bounded ceiling"
)
assertThat(
	resolver.resolve({ affix("MoveSpeedPercent", 500) }).movementSpeedMultiplier
		== runConfig.ModifierCeilings.maximumMovementSpeedMultiplier,
	"movement affixes must inherit the canonical global ceiling"
)

for _, malformed in
	{
		{ { EffectId = "DamagePercent", Value = -1 } },
		{ { EffectId = "", Value = 5 } },
		{ { EffectId = "MoveSpeedPercent", Value = 0 / 0 } },
	}
do
	local result = resolver.resolve(malformed :: any)
	assertThat(result.damageMultiplier == 1, "malformed bundles must fail damage closed")
	assertThat(result.reloadDurationMultiplier == 1, "malformed bundles must fail reload closed")
	assertThat(result.maximumHealthMultiplier == 1, "malformed bundles must fail max health closed")
	assertThat(result.movementSpeedMultiplier == 1, "malformed bundles must fail movement closed")
	assertThat(result.abilityCooldownDurationMultiplier == 1, "malformed bundles must fail ability cooldown closed")
end

assertThat(table.isfrozen(resolver.resolve({ affix("AbilityHastePercent", 5) })), "resolved bundle must be immutable")

print("EquipmentAffixModifierResolver: bounded damage/reload/max-health/movement/ability-haste translation passed")
