--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Patch 0.9 acceptance audit failed", 2)
	end
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local acceptance = fs.readFile("docs/roadmap/PATCH-0.9-ACCEPTANCE.md")
local pipeline = fs.readFile("docs/roadmap/PATCH-0.9-CONTENT-PIPELINE.md")
local firearm = fs.readFile("games/living-kingdoms/src/shared/Config/FirearmConfig.luau")
local equipment = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")
local affixes = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentAffixConfig.luau")
local encounters = fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionServerBootstrap.luau")

assert(
	contains(acceptance, "SOURCE COMPLETE — CONSOLIDATED STUDIO/DEVICE VERIFICATION PENDING"),
	"acceptance must not claim runtime verification"
)
assert(contains(acceptance, "PRs #508–#512"), "accepted source sequence must remain explicit")
assert(
	contains(acceptance, "New class/archetype | DEFERRED"),
	"speculative class breadth must remain recorded as deferred"
)
assert(
	contains(acceptance, "New enemy family | DEFERRED"),
	"speculative enemy breadth must remain recorded as deferred"
)
assert(contains(acceptance, "Second boss | DEFERRED"), "speculative boss breadth must remain recorded as deferred")
assert(
	contains(acceptance, "Crafting / resource system | DEFERRED"),
	"unvalidated crafting must remain recorded as deferred"
)
assert(contains(acceptance, "Release Candidate 1.0 — Production Readiness"), "next roadmap lane must be explicit")

assert(contains(pipeline, "Reachability"), "content production gate must retain reachability law")
assert(contains(pipeline, "Maintenance"), "content production gate must retain maintenance law")
assert(contains(firearm, "DiscoverableWeaponIds"), "firearm discovery roster must remain explicit")
assert(
	contains(equipment, "for _, weaponId in FirearmConfig.DiscoverableWeaponIds do"),
	"durable weapon coverage must remain enforced"
)
assert(contains(equipment, '"scout-harness"'), "accepted armor expansion must exist")
assert(contains(equipment, '"storm-catalyst"'), "accepted relic expansion must exist")
assert(contains(affixes, "assert(hasRoleAwareAffix(itemDefinition)"), "accepted differentiation invariant must exist")
assert(
	contains(encounters, "for _, definition in RoomAssemblyConfig.Rooms do\n\tvalidateEncounter"),
	"complete room-content coverage must remain enforced"
)
assert(
	contains(bootstrap, "FirstDungeonContentConfig.Encounters[record.RoomId]"),
	"runtime must retain assembled-room content lookup"
)

print("Patch09AcceptanceSourceAudit.test.luau passed")
