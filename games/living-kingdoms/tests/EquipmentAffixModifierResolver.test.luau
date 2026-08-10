--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
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

assertThat(resolver.resolve(nil).damageMultiplier == 1, "legacy missing affixes must stay neutral")
assertThat(resolver.resolve({}).damageMultiplier == 1, "empty affixes must stay neutral")
assertThat(resolver.resolve({ affix("DamagePercent", 7) }).damageMultiplier == 1.07, "damage percent must translate")
assertThat(
	resolver.resolve({ affix("DamagePercent", 7), affix("DamagePercent", 5) }).damageMultiplier == 1.12,
	"multiple damage rolls must aggregate"
)
assertThat(
	resolver.resolve({ affix("MoveSpeedPercent", 15), affix("DamagePercent", 5) }).damageMultiplier == 1.05,
	"well-formed effects without a live owner must remain inert"
)
assertThat(
	resolver.resolve({ affix("DamagePercent", 500) }).damageMultiplier
		== runConfig.ModifierCeilings.maximumDamageMultiplier,
	"damage affixes must inherit the canonical global ceiling"
)
assertThat(
	resolver.resolve({ { EffectId = "DamagePercent", Value = -1 } }).damageMultiplier == 1,
	"negative values fail closed"
)
assertThat(
	resolver.resolve({ { EffectId = "", Value = 5 } }).damageMultiplier == 1,
	"missing effect identity fails closed"
)
assertThat(
	resolver.resolve({ { EffectId = "DamagePercent", Value = 0 / 0 } }).damageMultiplier == 1,
	"NaN fails closed"
)
assertThat(
	table.isfrozen(resolver.resolve({ affix("DamagePercent", 5) })),
	"resolved modifier bundle must be immutable"
)

print("EquipmentAffixModifierResolver: bounded damage translation and fail-closed behavior passed")
