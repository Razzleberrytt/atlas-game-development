--!strict

local fs = require("@lune/fs")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/MeleeContracts.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/MeleeCombatConfig.luau")
local resolver = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeStrikeResolver.luau")
local service = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")

assert(contains(contracts, 'FieldHatchet = "weapon.field-hatchet"'), "melee needs a stable non-firearm weapon id")
assert(contains(config, 'DisplayName = "Field Hatchet"'), "opening melee tool must be explicit")
assert(contains(config, "DamagePerHit = 34"), "melee damage must remain config-owned")
assert(contains(config, "RangeStuds = 8"), "melee range must remain close and config-owned")

assert(contains(resolver, "function Resolver.selectTarget"), "melee target choice must live in a pure resolver")
assert(not contains(resolver, "Workspace"), "pure melee resolver cannot inspect Workspace")
assert(not contains(resolver, "RemoteEvent"), "pure melee resolver cannot own networking")
assert(not contains(resolver, "Ammunition"), "pure melee resolver cannot inherit firearm ammunition state")
assert(not contains(resolver, "Reload"), "pure melee resolver cannot inherit firearm reload state")

assert(contains(service, "OperativeLifeService.isCombatAllowed(player)"), "melee must revalidate server life eligibility")
assert(contains(service, "EnemyDirectorService.readEnemyCombatFacts()"), "melee must derive targets from server enemy facts")
assert(contains(service, "MeleeStrikeResolver.selectTarget"), "melee service must reuse the canonical resolver")
assert(contains(service, "Workspace:Raycast"), "melee must reject strikes through blocking geometry")
assert(contains(service, "EnemyDirectorService.readHealthState"), "melee must read the revisioned enemy health boundary")
assert(contains(service, "EnemyDirectorService.commitHealthState"), "melee must commit through canonical enemy health/death ownership")
assert(contains(service, "MatchResultService.recordDamageDealt"), "committed melee damage must count in match results")
assert(contains(service, "MatchResultService.recordKills"), "committed melee kills must count in match results")
assert(not contains(service, "FireIntent"), "melee cannot reuse the firearm intent remote")
assert(not contains(service, "ReloadIntent"), "melee cannot reuse reload networking")
assert(not contains(service, "FirearmConfig"), "melee cannot masquerade as a firearm definition")
assert(not contains(service, "reserveRounds"), "melee cannot own reserve ammunition")
assert(not contains(service, "loadedRounds"), "melee cannot own loaded ammunition")
assert(not contains(service, 'Instance.new("RemoteEvent")'), "foundation must not invent a client remote")

print("Melee combat foundation: independent authority and no fake firearm state passed")
