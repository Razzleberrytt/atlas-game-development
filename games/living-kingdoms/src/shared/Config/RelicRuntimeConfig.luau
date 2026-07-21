--!strict

--[[
	Per-relic runtime tuning for the implemented relics: the RPG-0108 first batch
	(Blood Battery, Grave Momentum, Choir Breaker, Last Light, Emergency Chamber,
	Execution Protocol) and the delivered RPG-0109 weapon-pattern slice (Breach
	Doctrine, Longwatch Doctrine).

	This declares the bounded per-stack contributions each relic feeds through the
	shared RunModifierResolver ceilings. It grants no power on its own: every
	effect is applied by the authoritative combat, reload, and life owners through
	RelicModifierResolver. Every value is asserted within the canonical
	RunRpgConfig.ModifierCeilings so tuning can never drift past a global bound.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)

local RelicIds = RunRpgContracts.RelicIds
local Ceilings = RunRpgConfig.ModifierCeilings

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: number): boolean
	return isFinite(value) and value > 0 and value % 1 == 0
end

-- Blood Battery: every `killThreshold` confirmed kills restores `healAmount`
-- health (bounded, never reviving or exceeding maximum health at runtime).
local BloodBattery = table.freeze({
	killThreshold = 8,
	healAmount = 6,
})

-- Grave Momentum: extends the authoritative kill-chain expiry window.
local GraveMomentum = table.freeze({
	killChainExtensionSeconds = 1.5,
})

-- Choir Breaker: damage bonus against enemies performing interruptible special
-- actions (applied through the special-enemy damage category).
local ChoirBreaker = table.freeze({
	specialEnemyDamageBonus = 0.3,
})

-- Last Light: damage bonus while authoritative reserve ammunition sits at or
-- below `reserveFraction` of the weapon's maximum reserve.
local LastLight = table.freeze({
	conditionalDamageBonus = 0.25,
	reserveFraction = 0.2,
})

-- Emergency Chamber: reduced reload duration for reloads accepted while
-- critically wounded, meaning current health at or below `woundedHealthFraction`
-- of the operative's authoritative maximum health.
local EmergencyChamber = table.freeze({
	reloadDurationReduction = 0.25,
	woundedHealthFraction = 0.35,
})

-- Execution Protocol: damage bonus against enemies at or below `healthFraction`
-- of their maximum health. Shares the global damage ceiling with Cull Protocol.
local ExecutionProtocol = table.freeze({
	conditionalDamageBonus = 0.4,
	healthFraction = 0.3,
})

-- Breach Doctrine: raises shotgun cone-cleave secondary damage toward full
-- primary damage. It shares the pattern ceiling with the Pattern Amplifier
-- upgrade, so a maxed build reaches the cap sooner rather than exceeding it.
local BreachDoctrine = table.freeze({
	patternDamageBonus = 0.4,
})

-- Longwatch Doctrine: raises sniper line-pierce secondary damage and every
-- sniper impact against special enemies.
local LongwatchDoctrine = table.freeze({
	patternDamageBonus = 0.35,
	specialEnemyDamageBonus = 0.25,
})

-- Salvager's Mark: every collected ammunition drop yields extra whole rounds,
-- still capped by the weapon's authoritative maximum reserve.
local SalvagersMark = table.freeze({
	lootRoundsAdditiveBonus = 4,
})

-- Suppression Engine: once an automatic weapon has fired `shotThreshold` rounds
-- without reloading, the remainder of that magazine fires faster and hits harder.
-- Reloading, holstering a different weapon, or losing combat rights resets it.
local SuppressionEngine = table.freeze({
	shotThreshold = 6,
	cadenceReduction = 0.15,
	damageBonus = 0.2,
})

local RuntimeByRelicId = table.freeze({
	[RelicIds.BloodBattery] = BloodBattery,
	[RelicIds.GraveMomentum] = GraveMomentum,
	[RelicIds.ChoirBreaker] = ChoirBreaker,
	[RelicIds.LastLight] = LastLight,
	[RelicIds.EmergencyChamber] = EmergencyChamber,
	[RelicIds.ExecutionProtocol] = ExecutionProtocol,
	[RelicIds.BreachDoctrine] = BreachDoctrine,
	[RelicIds.LongwatchDoctrine] = LongwatchDoctrine,
	[RelicIds.SalvagersMark] = SalvagersMark,
	[RelicIds.SuppressionEngine] = SuppressionEngine,
})

local FirstBatchRelicIds = table.freeze({
	RelicIds.BloodBattery,
	RelicIds.GraveMomentum,
	RelicIds.ChoirBreaker,
	RelicIds.LastLight,
	RelicIds.EmergencyChamber,
	RelicIds.ExecutionProtocol,
})

-- RPG-0109 weapon and cooperation relics, delivered in slices as each effect's
-- authoritative owner becomes available.
local SecondBatchRelicIds = table.freeze({
	RelicIds.BreachDoctrine,
	RelicIds.LongwatchDoctrine,
	RelicIds.SalvagersMark,
	RelicIds.SuppressionEngine,
})

local Config = {
	Version = "RPG-0109-weapon-batch-tuning",
	BloodBattery = BloodBattery,
	GraveMomentum = GraveMomentum,
	ChoirBreaker = ChoirBreaker,
	LastLight = LastLight,
	EmergencyChamber = EmergencyChamber,
	ExecutionProtocol = ExecutionProtocol,
	BreachDoctrine = BreachDoctrine,
	LongwatchDoctrine = LongwatchDoctrine,
	SalvagersMark = SalvagersMark,
	SuppressionEngine = SuppressionEngine,
	RuntimeByRelicId = RuntimeByRelicId,
	FirstBatchRelicIds = FirstBatchRelicIds,
	SecondBatchRelicIds = SecondBatchRelicIds,
}

assert(
	isPositiveInteger(BloodBattery.killThreshold),
	"Blood Battery must restore health on a whole positive kill count"
)
assert(
	isFinite(BloodBattery.healAmount)
		and BloodBattery.healAmount > 0
		and BloodBattery.healAmount <= Ceilings.maximumAutomaticHealingPerTrigger,
	"Blood Battery healing must be positive and within the automatic healing ceiling"
)
assert(
	isFinite(GraveMomentum.killChainExtensionSeconds)
		and GraveMomentum.killChainExtensionSeconds > 0
		and GraveMomentum.killChainExtensionSeconds <= Ceilings.maximumKillChainExtensionSeconds,
	"Grave Momentum extension must be positive and within the kill-chain ceiling"
)
assert(
	isFinite(ChoirBreaker.specialEnemyDamageBonus)
		and ChoirBreaker.specialEnemyDamageBonus > 0
		and 1 + ChoirBreaker.specialEnemyDamageBonus <= Ceilings.maximumSpecialEnemyDamageMultiplier,
	"Choir Breaker special-enemy damage must be positive and within the special-enemy ceiling"
)
assert(
	isFinite(LastLight.conditionalDamageBonus)
		and LastLight.conditionalDamageBonus > 0
		and 1 + LastLight.conditionalDamageBonus <= Ceilings.maximumConditionalDamageMultiplier,
	"Last Light damage must be positive and within the conditional damage ceiling"
)
assert(
	isFinite(LastLight.reserveFraction) and LastLight.reserveFraction > 0 and LastLight.reserveFraction <= 0.25,
	"Last Light reserve threshold must be a small positive fraction"
)
assert(
	isFinite(EmergencyChamber.reloadDurationReduction)
		and EmergencyChamber.reloadDurationReduction > 0
		and 1 - EmergencyChamber.reloadDurationReduction >= Ceilings.minimumReloadDurationMultiplier,
	"Emergency Chamber reduction must be positive and preserve the reload floor"
)
assert(
	isFinite(EmergencyChamber.woundedHealthFraction)
		and EmergencyChamber.woundedHealthFraction > 0
		and EmergencyChamber.woundedHealthFraction <= 0.5,
	"Emergency Chamber must only reward genuinely wounded operatives"
)
assert(
	isFinite(ExecutionProtocol.conditionalDamageBonus)
		and ExecutionProtocol.conditionalDamageBonus > 0
		and 1 + ExecutionProtocol.conditionalDamageBonus <= Ceilings.maximumConditionalDamageMultiplier,
	"Execution Protocol damage must be positive and within the conditional damage ceiling"
)
assert(
	isFinite(ExecutionProtocol.healthFraction)
		and ExecutionProtocol.healthFraction > 0
		and ExecutionProtocol.healthFraction < 1,
	"Execution Protocol threshold must be a health fraction below full"
)

-- Every relic with runtime tuning must be a known relic, and its Blood Battery
-- kill threshold must match the counter declared in the canonical relic catalog.
local bloodBatteryCatalog: any = nil
for _, definition in RunRpgConfig.RelicCatalog do
	if definition.relicId == RelicIds.BloodBattery then
		bloodBatteryCatalog = definition
	end
end
assert(
	bloodBatteryCatalog ~= nil and BloodBattery.killThreshold == bloodBatteryCatalog.counterThreshold,
	"Blood Battery kill threshold must match its declared catalog counter"
)

assert(
	isFinite(BreachDoctrine.patternDamageBonus)
		and BreachDoctrine.patternDamageBonus > 0
		and 1 + BreachDoctrine.patternDamageBonus <= Ceilings.maximumPatternDamageMultiplier,
	"Breach Doctrine pattern damage must be positive and within the pattern ceiling"
)
assert(
	isFinite(LongwatchDoctrine.patternDamageBonus)
		and LongwatchDoctrine.patternDamageBonus > 0
		and 1 + LongwatchDoctrine.patternDamageBonus <= Ceilings.maximumPatternDamageMultiplier,
	"Longwatch Doctrine pattern damage must be positive and within the pattern ceiling"
)
assert(
	isFinite(LongwatchDoctrine.specialEnemyDamageBonus)
		and LongwatchDoctrine.specialEnemyDamageBonus > 0
		and 1 + LongwatchDoctrine.specialEnemyDamageBonus <= Ceilings.maximumSpecialEnemyDamageMultiplier,
	"Longwatch Doctrine special-enemy damage must be positive and within the special-enemy ceiling"
)

assert(
	isFinite(SalvagersMark.lootRoundsAdditiveBonus)
		and SalvagersMark.lootRoundsAdditiveBonus > 0
		and SalvagersMark.lootRoundsAdditiveBonus % 1 == 0
		and SalvagersMark.lootRoundsAdditiveBonus <= Ceilings.maximumLootRoundsAdditiveBonus,
	"Salvager's Mark must grant whole positive rounds within the salvage ceiling"
)

assert(
	isPositiveInteger(SuppressionEngine.shotThreshold) and SuppressionEngine.shotThreshold <= 12,
	"Suppression Engine must ramp over a whole, reachable number of shots"
)
assert(
	isFinite(SuppressionEngine.cadenceReduction)
		and SuppressionEngine.cadenceReduction > 0
		and 1 - SuppressionEngine.cadenceReduction >= Ceilings.minimumCadenceMultiplier,
	"Suppression Engine cadence must be positive and preserve the cadence floor"
)
assert(
	isFinite(SuppressionEngine.damageBonus)
		and SuppressionEngine.damageBonus > 0
		and 1 + SuppressionEngine.damageBonus <= Ceilings.maximumConditionalDamageMultiplier,
	"Suppression Engine damage must be positive and within the conditional damage ceiling"
)

local runtimeRelicCount = 0
for relicId in RuntimeByRelicId do
	assert(RunRpgContracts.isKnownRelicId(relicId), "relic runtime tuning references an unknown relic")
	runtimeRelicCount += 1
end
assert(
	runtimeRelicCount == #FirstBatchRelicIds + #SecondBatchRelicIds,
	"the runtime tuning map must cover exactly the implemented relic batches"
)
assert(#FirstBatchRelicIds == 6, "the RPG-0108 first batch contains six relics")
assert(#SecondBatchRelicIds == 4, "the delivered RPG-0109 slices contain the four weapon-facing relics")

return table.freeze(Config)
