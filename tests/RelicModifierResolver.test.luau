--!strict

-- RPG-0108 (part 1) per-operative relic modifiers resolve within the shared
-- ceilings, ignore later-batch relics, fail closed on unknown relics, and the
-- Blood Battery kill counter advances deterministically.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
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

local MODIFIER_RPGCONFIG_TOKEN = {}
local runModifierResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunModifierResolver.luau"), {
		debugName = "RunModifierResolver",
		environment = {
			script = { Parent = { Parent = { Config = { RunRpgConfig = MODIFIER_RPGCONFIG_TOKEN } } } },
			require = function(token: unknown)
				assertThat(token == MODIFIER_RPGCONFIG_TOKEN, "unexpected RunModifierResolver dependency")
				return rpgConfig
			end,
		},
		injectGlobals = true,
	})()

local function loadWithReplicatedStorage(path: string, debugName: string, moduleByName)
	local tokens = {}
	local sharedRPG = {}
	local sharedConfig = {}
	local sharedProgression = {}
	local replicatedStorage = { Shared = { RPG = sharedRPG, Config = sharedConfig, Progression = sharedProgression } }
	local function bind(container, leaf: string, module)
		local token = {}
		container[leaf] = token
		tokens[token] = module
	end
	bind(sharedRPG, "RunRpgContracts", contracts)
	bind(sharedConfig, "RelicRuntimeConfig", moduleByName.RelicRuntimeConfig)
	bind(sharedProgression, "RunModifierResolver", runModifierResolver)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					assertThat(serviceName == "ReplicatedStorage", debugName .. " may only require replicated modules")
					return replicatedStorage
				end,
			},
			require = function(token: unknown)
				local module = tokens[token]
				if module ~= nil then
					return module
				end
				error("unexpected " .. debugName .. " dependency", 2)
			end,
		},
		injectGlobals = true,
	})()
end

-- RelicRuntimeConfig needs its own replicated env (contracts + rpg config).
local R_CONTRACTS_TOKEN = {}
local R_RPGCONFIG_TOKEN = {}
local relicRuntimeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RelicRuntimeConfig.luau"), {
	debugName = "RelicRuntimeConfig",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "relic tuning may only require replicated modules")
				return {
					Shared = {
						RPG = { RunRpgContracts = R_CONTRACTS_TOKEN },
						Config = { RunRpgConfig = R_RPGCONFIG_TOKEN },
					},
				}
			end,
		},
		require = function(token: unknown)
			if token == R_CONTRACTS_TOKEN then
				return contracts
			elseif token == R_RPGCONFIG_TOKEN then
				return rpgConfig
			end
			error("unexpected RelicRuntimeConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local resolver = loadWithReplicatedStorage(
	"games/living-kingdoms/src/shared/RPG/RelicModifierResolver.luau",
	"RelicModifierResolver",
	{ RelicRuntimeConfig = relicRuntimeConfig }
)

local RelicIds = contracts.RelicIds
local Ceilings = rpgConfig.ModifierCeilings

-- No relics -> everything neutral.
local neutral = resolver.deriveModifiers({})
assertThat(neutral.killChainExtensionSeconds == 0, "neutral kill-chain must be zero")
assertThat(neutral.specialEnemyDamageMultiplier == 1, "neutral special-enemy damage must be one")
assertThat(
	neutral.lowReserveDamageMultiplier == 1 and neutral.lowReserveFraction == 0,
	"neutral Last Light must be off"
)
assertThat(neutral.woundedReloadDurationMultiplier == 1, "neutral reload must be one")
assertThat(
	neutral.executionDamageMultiplier == 1 and neutral.executionHealthFraction == 0,
	"neutral execution must be off"
)
assertThat(
	neutral.bloodBatteryKillThreshold == 0 and neutral.bloodBatteryHealAmount == 0,
	"neutral Blood Battery must be off"
)

-- Each relic produces its expected clamped modifier.
local grave = resolver.deriveModifiers({ RelicIds.GraveMomentum })
assertThat(
	approx(grave.killChainExtensionSeconds, relicRuntimeConfig.GraveMomentum.killChainExtensionSeconds),
	"Grave Momentum window drifted"
)
assertThat(
	grave.killChainExtensionSeconds <= Ceilings.maximumKillChainExtensionSeconds,
	"Grave Momentum exceeded the ceiling"
)

local choir = resolver.deriveModifiers({ RelicIds.ChoirBreaker })
assertThat(
	approx(choir.specialEnemyDamageMultiplier, 1 + relicRuntimeConfig.ChoirBreaker.specialEnemyDamageBonus),
	"Choir Breaker damage drifted"
)
assertThat(
	choir.specialEnemyDamageMultiplier <= Ceilings.maximumSpecialEnemyDamageMultiplier,
	"Choir Breaker exceeded the ceiling"
)

local lastLight = resolver.deriveModifiers({ RelicIds.LastLight })
assertThat(
	approx(lastLight.lowReserveDamageMultiplier, 1 + relicRuntimeConfig.LastLight.conditionalDamageBonus),
	"Last Light damage drifted"
)
assertThat(
	approx(lastLight.lowReserveFraction, relicRuntimeConfig.LastLight.reserveFraction),
	"Last Light threshold drifted"
)
assertThat(
	lastLight.lowReserveDamageMultiplier <= Ceilings.maximumConditionalDamageMultiplier,
	"Last Light exceeded the ceiling"
)

local emergency = resolver.deriveModifiers({ RelicIds.EmergencyChamber })
assertThat(
	approx(emergency.woundedReloadDurationMultiplier, 1 - relicRuntimeConfig.EmergencyChamber.reloadDurationReduction),
	"Emergency Chamber drifted"
)
assertThat(
	emergency.woundedReloadDurationMultiplier >= Ceilings.minimumReloadDurationMultiplier,
	"Emergency Chamber undercut the reload floor"
)

local execution = resolver.deriveModifiers({ RelicIds.ExecutionProtocol })
assertThat(
	approx(execution.executionDamageMultiplier, 1 + relicRuntimeConfig.ExecutionProtocol.conditionalDamageBonus),
	"Execution Protocol damage drifted"
)
assertThat(
	approx(execution.executionHealthFraction, relicRuntimeConfig.ExecutionProtocol.healthFraction),
	"Execution Protocol threshold drifted"
)
assertThat(
	execution.executionDamageMultiplier <= Ceilings.maximumConditionalDamageMultiplier,
	"Execution Protocol exceeded the ceiling"
)

local blood = resolver.deriveModifiers({ RelicIds.BloodBattery })
assertThat(
	blood.bloodBatteryKillThreshold == relicRuntimeConfig.BloodBattery.killThreshold,
	"Blood Battery threshold drifted"
)
assertThat(blood.bloodBatteryHealAmount == relicRuntimeConfig.BloodBattery.healAmount, "Blood Battery healing drifted")
assertThat(
	blood.bloodBatteryHealAmount <= Ceilings.maximumAutomaticHealingPerTrigger,
	"Blood Battery exceeded the healing ceiling"
)

-- A full first-batch loadout composes each relic's modifier.
local full = resolver.deriveModifiers({
	RelicIds.GraveMomentum,
	RelicIds.ChoirBreaker,
	RelicIds.LastLight,
	RelicIds.EmergencyChamber,
	RelicIds.ExecutionProtocol,
	RelicIds.BloodBattery,
})
assertThat(
	full.killChainExtensionSeconds > 0 and full.specialEnemyDamageMultiplier > 1,
	"composed loadout lost a modifier"
)
assertThat(
	full.lowReserveDamageMultiplier > 1 and full.executionDamageMultiplier > 1,
	"composed loadout lost a conditional"
)
assertThat(
	full.bloodBatteryKillThreshold > 0 and full.woundedReloadDurationMultiplier < 1,
	"composed loadout lost a relic"
)

-- A later-batch relic (not yet tuned) contributes nothing but does not fail.
local laterBatch = resolver.deriveModifiers({ RelicIds.BreachDoctrine })
assertThat(
	laterBatch.killChainExtensionSeconds == 0 and laterBatch.specialEnemyDamageMultiplier == 1,
	"an untuned relic must contribute nothing"
)

-- Duplicates collapse (relics are non-stackable).
local duplicated = resolver.deriveModifiers({ RelicIds.ChoirBreaker, RelicIds.ChoirBreaker })
assertThat(
	approx(duplicated.specialEnemyDamageMultiplier, choir.specialEnemyDamageMultiplier),
	"duplicate relic must not stack"
)

-- Unknown relic fails the whole call closed to neutral.
local forged = resolver.deriveModifiers({ RelicIds.ChoirBreaker, "relic.forged" })
assertThat(forged.specialEnemyDamageMultiplier == 1, "an unknown relic must fail closed to neutral")
local notATable = resolver.deriveModifiers("nope" :: any)
assertThat(notATable.specialEnemyDamageMultiplier == 1, "a non-table loadout must fail closed to neutral")

-- Blood Battery kill counter advances deterministically.
local partial = resolver.advanceBloodBattery(6, 1, 8, 6)
assertThat(partial.counterAfter == 7 and partial.healAmount == 0, "sub-threshold kills must not heal")
local oneTrigger = resolver.advanceBloodBattery(6, 3, 8, 6)
assertThat(oneTrigger.counterAfter == 1 and oneTrigger.healAmount == 6, "crossing the threshold must heal once")
local multiTrigger = resolver.advanceBloodBattery(0, 20, 8, 6)
assertThat(multiTrigger.counterAfter == 4 and multiTrigger.healAmount == 12, "two thresholds must heal twice")
local disabled = resolver.advanceBloodBattery(5, 10, 0, 6)
assertThat(disabled.counterAfter == 5 and disabled.healAmount == 0, "a zero threshold must disable healing")
local malformed = resolver.advanceBloodBattery(-1, 3, 8, 6)
assertThat(malformed.counterAfter == 0 and malformed.healAmount == 0, "malformed counter must fail closed")

print("RelicModifierResolver: bounded per-relic modifiers, exclusion, fail-closed, and deterministic Blood Battery")
