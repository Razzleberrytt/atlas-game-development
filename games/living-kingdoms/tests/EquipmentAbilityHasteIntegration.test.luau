--!strict

-- Focused Patch 0.3 AbilityHastePercent authority audit. Pure percentage
-- arithmetic and Relic-slot selection are covered by their resolver fixtures;
-- this pins the server-owned composition, activation snapshot, and class-action
-- cooldown consequence path without requiring a parallel ability timer.
local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local affix = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")
local equipped = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau")
local composition = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local classService = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local brace = fs.readFile("games/living-kingdoms/src/server/Systems/BraceResolver.luau")
local treatment = fs.readFile("games/living-kingdoms/src/server/Systems/FieldTreatmentResolver.luau")
local resupply = fs.readFile("games/living-kingdoms/src/server/Systems/FieldResupplyResolver.luau")

assert(contains(affix, 'ABILITY_HASTE_EFFECT_ID = "AbilityHastePercent"'), "ability haste affix is not translated")
assert(
	contains(affix, "abilityCooldownDurationMultiplier = boundedAbilityDuration.reloadDurationMultiplier"),
	"ability haste must reuse canonical bounded duration arithmetic"
)
assert(
	contains(equipped, "abilityCooldownDurationMultiplier = modifiers.abilityCooldownDurationMultiplier"),
	"equipped resolver must expose the bounded ability cooldown fact"
)
assert(
	contains(composition, 'resolveForSlot(record, "Relic")')
		and contains(composition, "combined.equipmentAbilityCooldownDurationMultiplier"),
	"server composition must derive ability haste from authoritative equipped Relic"
)
assert(
	contains(
		classService,
		"entry.actionCooldownDurationMultiplier = effectiveAbilityCooldownDurationMultiplier(player)"
	),
	"ClassService must snapshot server-derived haste when the class action activates"
)
assert(
	contains(classService, "entry.actionCooldownDurationMultiplier = nil"),
	"ClassService must release the activation haste snapshot when action continuity ends"
)
assert(
	contains(
		classService,
		"FieldTreatmentResolver.resolveEffectRejected(state, serverTimestamp, cooldownDurationMultiplier)"
	)
		and contains(
			classService,
			"FieldResupplyResolver.resolveEffectRejected(state, serverTimestamp, cooldownDurationMultiplier)"
		),
	"effect-rejection cooldowns must consume the same activation snapshot"
)
assert(
	contains(brace, "ClassConfig.Actions.Brace.cooldownSeconds * multiplier"),
	"Brace cooldown must apply the server snapshot to configured base duration"
)
assert(
	contains(treatment, "ClassConfig.Actions.FieldTreatment.cooldownSeconds * multiplier"),
	"Field Treatment cooldown must apply the server snapshot to configured base duration"
)
assert(
	contains(resupply, "ClassConfig.Actions.FieldResupply.cooldownSeconds * multiplier"),
	"Field Resupply cooldown must apply the server snapshot to configured base duration"
)
assert(not contains(affix, "RemoteEvent"), "pure affix adapter must not add network authority")
assert(not contains(composition, "OnServerEvent"), "equipment composition must not add client ability authority")
assert(
	not contains(classService, "payload.ability") and not contains(classService, "payload.cooldown"),
	"ClassService must not accept client-authored ability multiplier or cooldown facts"
)

print("EquipmentAbilityHasteIntegration: equipped Relic -> snapshotted server class cooldown route passed")
