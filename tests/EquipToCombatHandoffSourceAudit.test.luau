--!strict

--[[
	Blueprint v2.0 queue item 2 — structural audit of the equip-to-combat handoff
	(v1.9 Ticket 142). Runtime behavior lives in WeaponSwapAmmunitionResolver.test
	and OperativeCombatRuntimeService.test; these assertions guard the wiring that
	cannot be exercised outside Studio.
]]

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local equipmentConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")

-- The equipment-to-weapon link is authored content, not a service-local table,
-- so a new item cannot silently equip and drive nothing.
assert(contains(equipmentConfig, "WeaponId = weaponId"), "definitions must carry an authored weapon link")
assert(contains(equipmentConfig, "must name the weapon it equips"), "weapon slots must assert a weapon link")
assert(contains(equipmentConfig, "must name no weapon"), "non-weapon slots must assert the absence of a link")
assert(contains(equipmentConfig, "names an unknown weapon"), "authored links must resolve to a real weapon")

-- Prevent combat refill exploits: equipping must route ammunition through the
-- conservation resolver instead of handing over a fresh magazine.
assert(contains(combatRuntime, "WeaponSwapAmmunitionResolver"), "equipping must use the swap resolver")
assert(contains(combatRuntime, "WeaponSwapAmmunitionResolver.resolve"), "the swap resolver must actually be invoked")

--[[
	Invalidate reload correctly and reject old weapons: `equipFoundWeapon` bumps
	the state generation, and reload completion is gated on the generation it
	started under, so an in-flight reload cannot finish onto the new weapon.
	Selected target and processed shot ids are cleared for the same reason.
]]
local equipStart = string.find(combatRuntime, "function OperativeCombatRuntimeService.equipFoundWeapon", 1, true)
assert(equipStart ~= nil, "the equip entry point must exist")
local equipBody = string.sub(combatRuntime :: string, equipStart :: number, (equipStart :: number) + 2200)
assert(contains(equipBody, "playerState.generation += 1"), "equipping must invalidate in-flight combat work")
assert(contains(equipBody, "playerState.selectedTargetEntityId = nil"), "equipping must drop the selected target")
assert(contains(equipBody, "table.clear(playerState.processedShotIds)"), "equipping must clear processed shots")
assert(contains(equipBody, "WeaponSwapAmmunitionResolver.resolve"), "equipping must carry ammunition, not refill it")
assert(not contains(equipBody, "PrototypeInitialLoadedRounds"), "equipping must not seed a fresh magazine")

assert(
	contains(combatRuntime, "playerState.generation ~= expectedGeneration"),
	"reload completion must be gated on the generation it began under"
)

print("EquipToCombatHandoffSourceAudit.test.luau passed")
