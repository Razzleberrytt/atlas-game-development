--!strict

-- Focused Patch 0.3 AbilityPowerPercent authority audit. Pure percentage
-- arithmetic and Relic-slot selection are covered by their resolver fixtures;
-- this pins the server-owned composition, activation snapshot, and consequence
-- path without introducing a generic client-authored ability-power authority.
local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local affix = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")
local equipped = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau")
local composition = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local classService = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")

assert(contains(affix, 'ABILITY_POWER_EFFECT_ID = "AbilityPowerPercent"'), "ability power affix is not translated")
assert(
	contains(affix, "abilityPowerMultiplier = math.min(ABILITY_POWER_MULTIPLIER_CEILING"),
	"ability power must be converted into one bounded generic consequence multiplier"
)
assert(
	contains(equipped, "abilityPowerMultiplier = modifiers.abilityPowerMultiplier"),
	"equipped resolver must expose the bounded ability power fact"
)
assert(
	contains(composition, 'resolveForSlot(record, "Relic")')
		and contains(composition, "combined.equipmentAbilityPowerMultiplier = relicEquipmentModifiers.abilityPowerMultiplier"),
	"server composition must derive ability power from the authoritative equipped Relic"
)
assert(
	contains(classService, "entry.actionPowerMultiplier = effectiveAbilityPowerMultiplier(player)"),
	"ClassService must snapshot server-derived ability power when a class action activates"
)
assert(
	contains(classService, "entry.actionPowerMultiplier = nil"),
	"ClassService must release the activation power snapshot when action continuity ends"
)
assert(
	contains(classService, "healingAmount = ClassConfig.Actions.FieldTreatment.healAmount * abilityPowerMultiplier"),
	"Field Treatment must derive stronger healing from the configured server base"
)
assert(
	contains(classService, "ClassConfig.Actions.FieldResupply.roundsPerCharge * abilityPowerMultiplier"),
	"Field Resupply must derive stronger ammunition grant from the configured server base"
)
assert(
	contains(classService, "1 - (1 - baseMultiplier) * powerMultiplier"),
	"Brace must scale the configured cadence benefit rather than replacing combat cadence authority"
)
assert(not contains(affix, "RemoteEvent"), "pure affix adapter must not add network authority")
assert(not contains(composition, "OnServerEvent"), "equipment composition must not add client ability authority")
assert(
	not contains(classService, "payload.abilityPower")
		and not contains(classService, "payload.healingAmount")
		and not contains(classService, "payload.roundsPerCharge"),
	"ClassService must not accept client-authored ability power or consequence values"
)

print("EquipmentAbilityPowerIntegration: equipped Relic -> snapshotted server class consequence route passed")
