--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "Patch 0.9 gear archetype audit failed", 2) end
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local rewards = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")
local affixes = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentAffixConfig.luau")
local modifiers = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")

assert(contains(rewards, '"scout-harness"'), "mobile armor archetype must exist")
assert(contains(rewards, '{ "armor", "mobility" }'), "scout harness must carry mobility identity")
assert(contains(rewards, '"storm-catalyst"'), "offensive relic archetype must exist")
assert(contains(rewards, '{ "relic", "ability", "offense" }'), "storm catalyst must carry offensive ability identity")
assert(contains(affixes, '"skirmisher"'), "mobility armor needs a role-specific movement roll")
assert(contains(affixes, '"flex-weave"'), "mobility armor needs a second bounded role roll")
assert(contains(affixes, '"surge-tuned"'), "offensive relic needs a role-specific power roll")
assert(contains(affixes, '"rapid-channel"'), "offensive relic needs a role-specific haste roll")
assert(contains(affixes, "for _, itemDefinition in EquipmentRewardConfig.Definitions do\n\tassert(hasRoleAwareAffix"), "every durable item must be differentiated")
assert(contains(modifiers, "movementSpeedMultiplier"), "armor movement affixes must reach an existing runtime modifier")
assert(contains(modifiers, "abilityPowerMultiplier"), "relic power affixes must reach an existing runtime modifier")
assert(contains(modifiers, "abilityCooldownDurationMultiplier"), "relic haste affixes must reach an existing runtime modifier")

print("Patch09GearArchetypeCoverageSourceAudit.test.luau passed")
