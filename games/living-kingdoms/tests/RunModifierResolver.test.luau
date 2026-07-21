--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local CONFIG_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunModifierResolver.luau"), {
	debugName = "RunModifierResolver",
	environment = {
		script = { Parent = { Parent = { Config = { RunRpgConfig = CONFIG_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == CONFIG_TOKEN, "unexpected RunModifierResolver dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

local neutral = resolver.resolve({})
assertThat(table.isfrozen(neutral), "resolved modifiers must be immutable")
assertThat(neutral.damageMultiplier == 1 and neutral.cadenceMultiplier == 1, "combat defaults must be neutral")
assertThat(
	neutral.ammunitionConservationChance == 0 and neutral.magazineCapacityMultiplier == 1,
	"ammunition defaults must be neutral"
)
assertThat(
	neutral.reloadDurationMultiplier == 1 and neutral.movementSpeedMultiplier == 1,
	"duration and movement defaults must be neutral"
)
assertThat(
	neutral.automaticHealingPerTrigger == 0 and neutral.temporaryArmorFractionOfMaximumHealth == 0,
	"survivability defaults must grant no power"
)
assertThat(neutral.lootChanceAdditiveBonus == 0 and neutral.fieldXpMultiplier == 1, "economy defaults must be neutral")

local ceilings = config.ModifierCeilings
local capped = resolver.resolve({
	damageBonus = 99,
	cadenceReduction = 99,
	ammunitionConservationChance = 99,
	cullDamageBonus = 99,
	incomingDamageReduction = 99,
	fieldXpBonus = 99,
	reloadDurationReduction = 99,
	patternDamageBonus = 99,
	specialEnemyDamageBonus = 99,
	magazineCapacityBonus = 99,
	lootPickupRadiusBonusStuds = 99,
	conditionalDamageBonus = 99,
	movementSpeedBonus = 99,
	automaticHealingPerTrigger = 99,
	temporaryArmorFractionOfMaximumHealth = 99,
	lootChanceAdditiveBonus = 99,
	lootRoundsAdditiveBonus = 99,
	killChainExtensionSeconds = 99,
	generalProcChance = 99,
})
assertThat(capped.damageMultiplier == ceilings.maximumDamageMultiplier, "damage ceiling must be fixture-locked")
assertThat(capped.cadenceMultiplier == ceilings.minimumCadenceMultiplier, "cadence floor must be fixture-locked")
assertThat(
	capped.ammunitionConservationChance == ceilings.maximumAmmunitionConservationChance,
	"ammunition conservation ceiling must be fixture-locked"
)
assertThat(capped.cullDamageMultiplier == ceilings.maximumDamageMultiplier, "cull damage must share the damage ceiling")
assertThat(
	capped.incomingDamageMultiplier == 1 - ceilings.maximumIncomingDamageReduction,
	"incoming damage reduction ceiling must be fixture-locked"
)
assertThat(capped.fieldXpMultiplier == ceilings.maximumFieldXpMultiplier, "Field XP ceiling must be fixture-locked")
assertThat(
	capped.reloadDurationMultiplier == ceilings.minimumReloadDurationMultiplier,
	"reload floor must be fixture-locked"
)
assertThat(
	capped.patternDamageMultiplier == ceilings.maximumPatternDamageMultiplier,
	"pattern damage ceiling must be fixture-locked"
)
assertThat(
	capped.specialEnemyDamageMultiplier == ceilings.maximumSpecialEnemyDamageMultiplier,
	"special-enemy damage ceiling must be fixture-locked"
)
assertThat(
	capped.magazineCapacityMultiplier == ceilings.maximumMagazineCapacityMultiplier,
	"magazine capacity ceiling must be fixture-locked"
)
assertThat(
	capped.lootPickupRadiusBonusStuds == ceilings.maximumLootPickupRadiusBonusStuds,
	"pickup radius ceiling must be fixture-locked"
)
assertThat(
	capped.conditionalDamageMultiplier == ceilings.maximumConditionalDamageMultiplier,
	"conditional damage ceiling must be fixture-locked"
)
assertThat(
	capped.movementSpeedMultiplier == ceilings.maximumMovementSpeedMultiplier,
	"movement ceiling must be fixture-locked"
)
assertThat(
	capped.automaticHealingPerTrigger == ceilings.maximumAutomaticHealingPerTrigger,
	"healing ceiling must be fixture-locked"
)
assertThat(
	capped.temporaryArmorFractionOfMaximumHealth == ceilings.maximumTemporaryArmorFractionOfMaximumHealth,
	"temporary armor ceiling must be fixture-locked"
)
assertThat(
	capped.lootChanceAdditiveBonus == ceilings.maximumLootChanceAdditiveBonus,
	"loot chance ceiling must be fixture-locked"
)
assertThat(
	capped.lootRoundsAdditiveBonus == ceilings.maximumLootRoundsAdditiveBonus,
	"salvaged rounds ceiling must be fixture-locked"
)
assertThat(
	resolver.resolve({ lootRoundsAdditiveBonus = 2.7 }).lootRoundsAdditiveBonus == 2,
	"salvaged rounds must be granted as whole rounds"
)
assertThat(
	capped.killChainExtensionSeconds == ceilings.maximumKillChainExtensionSeconds,
	"kill-chain ceiling must be fixture-locked"
)
assertThat(capped.generalProcChance == ceilings.maximumGeneralProcChance, "proc ceiling must be fixture-locked")

local invalidUnknown = resolver.resolve({ forgedContribution = 1 })
local invalidNegative = resolver.resolve({ damageBonus = -1 })
local invalidInfinite = resolver.resolve({ movementSpeedBonus = math.huge })
local invalidNan = resolver.resolve({ lootChanceAdditiveBonus = 0 / 0 })
for _, invalid in { invalidUnknown, invalidNegative, invalidInfinite, invalidNan } do
	assertThat(invalid.damageMultiplier == 1, "malformed contributions must fail closed")
	assertThat(invalid.movementSpeedMultiplier == 1, "malformed contributions must not grant movement")
	assertThat(invalid.automaticHealingPerTrigger == 0, "malformed contributions must not grant healing")
	assertThat(table.isfrozen(invalid), "fail-closed results must remain immutable")
end

local explicitNeutral = resolver.neutral()
assertThat(explicitNeutral.damageMultiplier == 1 and explicitNeutral.generalProcChance == 0)
assertThat(table.isfrozen(explicitNeutral), "explicit neutral results must be immutable")

print("RunModifierResolver: neutral defaults, validation, immutability, and every canonical ceiling passed")
