--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "Patch 0.9 content pipeline audit failed", 2) end
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local firearm = fs.readFile("games/living-kingdoms/src/shared/Config/FirearmConfig.luau")
local equipment = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")
local affixes = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentAffixConfig.luau")
local modifiers = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")
local rooms = fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau")
local encounters = fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionServerBootstrap.luau")
local placement = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")
local environment = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionEnvironmentBuilder.luau")

-- Weapons must be reachable beyond one run.
assert(contains(firearm, "DiscoverableWeaponIds"), "firearm discovery needs an explicit authored roster")
assert(contains(equipment, "for _, weaponId in FirearmConfig.DiscoverableWeaponIds do"), "discoverable firearms must be durable-covered")
assert(contains(equipment, "FirearmConfig.isKnownWeaponId"), "equipment weapon links must resolve through the firearm registry")
assert(contains(equipment, '"blackwater-support-lmg"'), "Patch 0.9 LMG reward must remain reachable")
assert(contains(equipment, '"razor-compact-smg"'), "Patch 0.9 SMG reward must remain reachable")

-- Equipment identities must alter the existing affix choice space rather than
-- merely renaming the same generic item.
assert(contains(equipment, '"scout-harness"'), "Patch 0.9 mobile armor must remain in the durable pool")
assert(contains(equipment, '"storm-catalyst"'), "Patch 0.9 offensive relic must remain in the durable pool")
assert(contains(affixes, "catalogTags[requiredTag] == true"), "affix required tags must exist in the durable catalog")
assert(contains(affixes, "assert(hasRoleAwareAffix(itemDefinition)"), "every durable item must have a role-aware affix path")
for _, runtimeField in { "damageMultiplier", "reloadDurationMultiplier", "maximumHealthMultiplier", "movementSpeedMultiplier", "abilityCooldownDurationMultiplier", "abilityPowerMultiplier" } do
	assert(contains(modifiers, runtimeField), "affix effect must retain an existing runtime consequence: " .. runtimeField)
end

-- A seed may only select rooms that already have complete authored encounter content.
assert(contains(rooms, "RoomAssemblyConfig.Rooms"), "room assembly pool must remain explicit")
assert(contains(encounters, "for _, definition in RoomAssemblyConfig.Rooms do\n\tvalidateEncounter"), "every selectable room must be encounter-covered")
assert(contains(encounters, "encounter content targets a room outside the assembly pool"), "stale room content must fail")
assert(contains(bootstrap, "FirstDungeonContentConfig.Encounters[record.RoomId]"), "runtime must resolve content from assembled room identity")

-- Ordinary room breadth must remain reusable rather than creating a per-room runtime owner.
assert(contains(placement, "ExpeditionEnvironmentBuilder.decorate(model, placement, seed)"), "room placement must delegate to the reusable environment builder")
assert(contains(environment, "local roleId = placement.RoleId"), "environment production must remain role-driven")
assert(not contains(environment, 'placement.RoomId == "flooded-passage"'), "ordinary rooms must not require id-specific environment branches")
assert(not contains(environment, 'placement.RoomId == "fungal-vault"'), "ordinary rooms must not require id-specific environment branches")

print("Patch09ContentPipelineSourceAudit.test.luau passed")
