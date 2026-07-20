--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "HROI-0105 run upgrade resolver assertion failed", 2)
	end
end

local function close(actual: number, expected: number): boolean
	return math.abs(actual - expected) < 1e-9
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()

local CONFIG_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunUpgradeResolver.luau"), {
	debugName = "RunUpgradeResolver",
	environment = {
		script = {
			Parent = {
				Parent = {
					Config = { RunProgressionConfig = CONFIG_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assert(token == CONFIG_TOKEN, "unexpected upgrade resolver dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

local firstChoices = resolver.generateChoices({}, 1, 5)
assert(#firstChoices == 3, "each level should offer exactly three choices")
assert(firstChoices[1] ~= firstChoices[2] and firstChoices[1] ~= firstChoices[3] and firstChoices[2] ~= firstChoices[3])
assert(table.isfrozen(firstChoices), "generated choices must be immutable")

local repeatedChoices = resolver.generateChoices({}, 1, 5)
for index = 1, 3 do
	assert(firstChoices[index] == repeatedChoices[index], "offer generation must be deterministic")
end

local selectedId = firstChoices[1]
local accepted = resolver.applyChoice({}, firstChoices, selectedId)
assert(accepted.didApply and accepted.upgradeId == selectedId and accepted.stackAfter == 1)
assert(accepted.stacksAfter[selectedId] == 1, "accepted choice should increment exactly one stack")
assert(table.isfrozen(accepted) and table.isfrozen(accepted.stacksAfter), "choice results must be immutable")

local spoofed = resolver.applyChoice({}, firstChoices, "upgrade.not_offered")
assert(not spoofed.didApply and spoofed.rejectionReasonId == "UpgradeNotOffered")
assert(next(spoofed.stacksAfter) == nil, "spoofed choices must not mutate stacks")

local maximumOverpressure = { ["upgrade.overpressure_rounds"] = 4 }
local choicesWithoutMaximum = resolver.generateChoices(maximumOverpressure, 2, 10)
for _, upgradeId in choicesWithoutMaximum do
	assert(upgradeId ~= "upgrade.overpressure_rounds", "maxed upgrades must leave the offer pool")
end

local modifiers = resolver.deriveCombatModifiers({
	["upgrade.overpressure_rounds"] = 2,
	["upgrade.hair_trigger"] = 2,
	["upgrade.echo_chamber"] = 2,
	["upgrade.cull_protocol"] = 1,
})
assert(close(modifiers.damageMultiplier, 1.4), "overpressure stacks should scale base damage")
assert(close(modifiers.cadenceMultiplier, 0.76), "hair trigger stacks should shorten cadence")
assert(close(modifiers.ammoConservationChance, 0.3), "echo chamber stacks should conserve bounded ammo")
assert(close(modifiers.cullDamageMultiplier, 1.35), "cull stacks should scale wounded-target damage")
assert(modifiers.cullHealthThreshold == 30, "cull threshold must remain server configured")

local capped = resolver.deriveCombatModifiers({
	["upgrade.overpressure_rounds"] = 4,
	["upgrade.hair_trigger"] = 4,
	["upgrade.echo_chamber"] = 3,
	["upgrade.cull_protocol"] = 3,
})
assert(capped.damageMultiplier <= config.MaximumDamageMultiplier)
assert(capped.cadenceMultiplier >= config.MinimumCadenceMultiplier)
assert(capped.ammoConservationChance <= config.MaximumAmmoConservationChance)
assert(capped.cullDamageMultiplier <= config.MaximumDamageMultiplier)

local defensive = resolver.deriveCombatModifiers({
	["upgrade.trauma_plating"] = 2,
	["upgrade.field_discipline"] = 2,
	["upgrade.combat_loader"] = 2,
	["upgrade.pattern_amplifier"] = 2,
})
assert(close(defensive.incomingDamageMultiplier, 0.8), "trauma plating stacks should reduce incoming enemy damage")
assert(close(defensive.xpGainMultiplier, 1.3), "field discipline stacks should raise Field XP gain")
assert(close(defensive.reloadDurationMultiplier, 0.76), "combat loader stacks should shorten reload duration")
assert(close(defensive.patternDamageMultiplier, 1.3), "pattern amplifier stacks should raise secondary damage")

local defensiveCapped = resolver.deriveCombatModifiers({
	["upgrade.trauma_plating"] = 3,
	["upgrade.field_discipline"] = 3,
	["upgrade.combat_loader"] = 3,
	["upgrade.pattern_amplifier"] = 3,
})
assert(defensiveCapped.incomingDamageMultiplier >= 1 - config.MaximumIncomingDamageReduction)
assert(close(defensiveCapped.incomingDamageMultiplier, 0.7), "trauma plating reduction must respect the configured floor")
assert(defensiveCapped.xpGainMultiplier <= config.MaximumXpGainMultiplier)
assert(close(defensiveCapped.xpGainMultiplier, 1.45), "field discipline must respect the configured economy ceiling")
assert(defensiveCapped.reloadDurationMultiplier >= config.MinimumReloadDurationMultiplier)
assert(close(defensiveCapped.reloadDurationMultiplier, 0.64), "combat loader must respect the configured reload floor")
assert(defensiveCapped.patternDamageMultiplier <= config.MaximumPatternDamageMultiplier)
assert(close(defensiveCapped.patternDamageMultiplier, 1.45), "pattern amplifier must respect the configured ceiling")

local invalid = resolver.deriveCombatModifiers({ ["upgrade.unknown"] = 1 })
assert(invalid.damageMultiplier == 1 and invalid.cadenceMultiplier == 1)
assert(invalid.ammoConservationChance == 0 and invalid.cullDamageMultiplier == 1)
assert(invalid.incomingDamageMultiplier == 1 and invalid.xpGainMultiplier == 1)
assert(invalid.reloadDurationMultiplier == 1 and invalid.patternDamageMultiplier == 1)

print("RunUpgradeResolver: deterministic offers, spoof rejection, stack caps, and combat modifiers passed")
