--!strict

--[[
	RPG-0108 (part 1) per-relic runtime tuning for the first relic batch:
	Blood Battery, Grave Momentum, Choir Breaker, Last Light, Emergency Chamber,
	and Execution Protocol.

	This declares the bounded per-stack contributions each relic will feed through
	the shared RunModifierResolver ceilings. It grants no power on its own: the
	relics remain gameplay-inert (RunRpgConfig marks them Planned) until the
	RPG-0108 runtime integration wires these values into the authoritative combat,
	reload, and life passes. Every value is asserted within the canonical
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
-- critically wounded.
local EmergencyChamber = table.freeze({
	reloadDurationReduction = 0.25,
})

-- Execution Protocol: damage bonus against enemies at or below `healthFraction`
-- of their maximum health. Shares the global damage ceiling with Cull Protocol.
local ExecutionProtocol = table.freeze({
	conditionalDamageBonus = 0.4,
	healthFraction = 0.3,
})

local RuntimeByRelicId = table.freeze({
	[RelicIds.BloodBattery] = BloodBattery,
	[RelicIds.GraveMomentum] = GraveMomentum,
	[RelicIds.ChoirBreaker] = ChoirBreaker,
	[RelicIds.LastLight] = LastLight,
	[RelicIds.EmergencyChamber] = EmergencyChamber,
	[RelicIds.ExecutionProtocol] = ExecutionProtocol,
})

local FirstBatchRelicIds = table.freeze({
	RelicIds.BloodBattery,
	RelicIds.GraveMomentum,
	RelicIds.ChoirBreaker,
	RelicIds.LastLight,
	RelicIds.EmergencyChamber,
	RelicIds.ExecutionProtocol,
})

local Config = {
	Version = "RPG-0108-part1-first-batch-tuning",
	BloodBattery = BloodBattery,
	GraveMomentum = GraveMomentum,
	ChoirBreaker = ChoirBreaker,
	LastLight = LastLight,
	EmergencyChamber = EmergencyChamber,
	ExecutionProtocol = ExecutionProtocol,
	RuntimeByRelicId = RuntimeByRelicId,
	FirstBatchRelicIds = FirstBatchRelicIds,
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

local runtimeRelicCount = 0
for relicId in RuntimeByRelicId do
	assert(RunRpgContracts.isKnownRelicId(relicId), "relic runtime tuning references an unknown relic")
	runtimeRelicCount += 1
end
assert(runtimeRelicCount == #FirstBatchRelicIds, "the runtime tuning map must cover exactly the first relic batch")
assert(#FirstBatchRelicIds == 6, "the RPG-0108 first batch contains six relics")

return table.freeze(Config)
