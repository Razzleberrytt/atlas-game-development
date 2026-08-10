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
assertThat(missing.damageMultiplier == 1, "legacy missing affixes must keep damage neutral")
assertThat(missing.reloadDurationMultiplier == 1, "legacy missing affixes must keep reload neutral")
local empty = resolver.resolve({})
assertThat(empty.damageMultiplier == 1, "empty affixes must keep damage neutral")
assertThat(empty.reloadDurationMultiplier == 1, "empty affixes must keep reload neutral")

local damageOnly = resolver.resolve({ affix("DamagePercent", 7) })
assertNear(damageOnly.damageMultiplier, 1.07, "damage percent must translate")
assertThat(damageOnly.reloadDurationMultiplier == 1, "damage must not leak into reload duration")
assertNear(
	resolver.resolve({ affix("DamagePercent", 7), affix("DamagePercent", 5) }).damageMultiplier,
	1.12,
	"multiple damage rolls must aggregate"
)

local reloadOnly = resolver.resolve({ affix("ReloadSpeedPercent", 8) })
assertThat(reloadOnly.damageMultiplier == 1, "reload speed must not leak into damage")
assertNear(reloadOnly.reloadDurationMultiplier, 0.92, "reload speed percent must reduce reload duration")
assertNear(
	resolver.resolve({ affix("ReloadSpeedPercent", 7), affix("ReloadSpeedPercent", 5) }).reloadDurationMultiplier,
	0.88,
	"multiple reload-speed rolls must aggregate"
)

local mixed = resolver.resolve({ affix("DamagePercent", 5), affix("ReloadSpeedPercent", 10) })
assertNear(mixed.damageMultiplier, 1.05, "mixed bundle must preserve damage")
assertNear(mixed.reloadDurationMultiplier, 0.9, "mixed bundle must preserve reload speed")

local futureEffect = resolver.resolve({ affix("MoveSpeedPercent", 15), affix("DamagePercent", 5) })
assertNear(futureEffect.damageMultiplier, 1.05, "live damage must survive unresolved effects")
assertThat(futureEffect.reloadDurationMultiplier == 1, "unresolved movement effect must stay reload-neutral")

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

for _, malformed in {
	{ { EffectId = "DamagePercent", Value = -1 } },
	{ { EffectId = "", Value = 5 } },
	{ { EffectId = "ReloadSpeedPercent", Value = 0 / 0 } },
} do
	local result = resolver.resolve(malformed :: any)
	assertThat(result.damageMultiplier == 1, "malformed bundles must fail damage closed")
	assertThat(result.reloadDurationMultiplier == 1, "malformed bundles must fail reload closed")
end

assertThat(
	table.isfrozen(resolver.resolve({ affix("ReloadSpeedPercent", 5) })),
	"resolved modifier bundle must be immutable"
)

print("EquipmentAffixModifierResolver: bounded damage/reload translation and fail-closed behavior passed")
