--!strict

-- RPG-0108 (part 1) first-batch relic tuning stays within the shared RPG
-- ceilings and matches the canonical relic catalog.

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

local R_CONTRACTS_TOKEN = {}
local R_RPGCONFIG_TOKEN = {}
local replicatedStorage = {
	Shared = {
		RPG = { RunRpgContracts = R_CONTRACTS_TOKEN },
		Config = { RunRpgConfig = R_RPGCONFIG_TOKEN },
	},
}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RelicRuntimeConfig.luau"), {
	debugName = "RelicRuntimeConfig",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "relic tuning may only require replicated modules")
				return replicatedStorage
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

local Ceilings = rpgConfig.ModifierCeilings

assertThat(config.Version == "RPG-0108-part1-first-batch-tuning", "relic tuning version drifted")
assertThat(#config.FirstBatchRelicIds == 6, "the first relic batch must contain six relics")

-- Every runtime tuning value must sit within the shared ceilings.
assertThat(
	config.BloodBattery.healAmount > 0 and config.BloodBattery.healAmount <= Ceilings.maximumAutomaticHealingPerTrigger,
	"Blood Battery healing must respect the automatic healing ceiling"
)
assertThat(
	config.GraveMomentum.killChainExtensionSeconds <= Ceilings.maximumKillChainExtensionSeconds,
	"Grave Momentum must respect the kill-chain ceiling"
)
assertThat(
	1 + config.ChoirBreaker.specialEnemyDamageBonus <= Ceilings.maximumSpecialEnemyDamageMultiplier,
	"Choir Breaker must respect the special-enemy damage ceiling"
)
assertThat(
	1 + config.LastLight.conditionalDamageBonus <= Ceilings.maximumConditionalDamageMultiplier
		and config.LastLight.reserveFraction > 0
		and config.LastLight.reserveFraction <= 0.25,
	"Last Light must respect the conditional damage ceiling and a small reserve threshold"
)
assertThat(
	1 - config.EmergencyChamber.reloadDurationReduction >= Ceilings.minimumReloadDurationMultiplier,
	"Emergency Chamber must preserve the reload floor"
)
assertThat(
	1 + config.ExecutionProtocol.conditionalDamageBonus <= Ceilings.maximumConditionalDamageMultiplier
		and config.ExecutionProtocol.healthFraction > 0
		and config.ExecutionProtocol.healthFraction < 1,
	"Execution Protocol must respect the conditional damage ceiling and a sub-full health threshold"
)

-- Blood Battery kill threshold must equal its catalog counter.
local bloodBatteryCatalog
for _, definition in rpgConfig.RelicCatalog do
	if definition.relicId == contracts.RelicIds.BloodBattery then
		bloodBatteryCatalog = definition
	end
end
assertThat(
	bloodBatteryCatalog ~= nil and config.BloodBattery.killThreshold == bloodBatteryCatalog.counterThreshold,
	"Blood Battery kill threshold must match its catalog counter"
)

-- Runtime tuning must cover exactly the six known first-batch relics.
local runtimeCount = 0
for relicId in config.RuntimeByRelicId do
	assertThat(contracts.isKnownRelicId(relicId), "relic tuning references an unknown relic")
	runtimeCount += 1
end
assertThat(runtimeCount == 6, "runtime tuning must cover exactly the first six relics")

-- The first batch must remain gameplay-inert until runtime integration: the
-- canonical relic catalog still marks every relic Planned.
for _, definition in rpgConfig.RelicCatalog do
	assertThat(
		definition.implementationStateId == contracts.ImplementationStateIds.Planned,
		"relics must remain Planned until the RPG-0108 runtime integration lands"
	)
end

local frozen = pcall(function()
	config.BloodBattery.healAmount = 999
end)
assertThat(not frozen, "relic tuning must be frozen")

print("RelicRuntimeConfig: first-batch tuning is ceiling-bound, catalog-matched, and still inert")
