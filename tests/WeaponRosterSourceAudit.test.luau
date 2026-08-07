--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local service = fs.readFile("games/living-kingdoms/src/server/Systems/WeaponLoadoutService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponSelectionController.luau")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/WeaponPresentationFactory.luau")
local serverInit = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assert(contains(runtime, "WeaponLoadoutService.read(player)"), "runtime must derive locked loadout from server service")
assert(contains(runtime, 'assignment.selectionStateId ~= "Locked"'), "combat switch must wait for lock")
assert(
	contains(runtime, "resolveWeaponDefinition(assignment.weaponId)"),
	"runtime must resolve the server-selected weapon through configured definitions"
)
assert(contains(service, "selectionIntentRemote.OnServerEvent"), "selection must have one bounded server intent")
assert(contains(service, "MissionDirectorService.read()"), "server must own insertion timing")
assert(not contains(controller, "DamagePerHit ="), "client must not submit weapon damage")
assert(not contains(controller, "CadenceSeconds ="), "client must not submit cadence")
assert(not contains(controller, "MagazineCapacity ="), "client must not submit ammunition state")
assert(contains(factory, "BreachShotgunPresentationFactory.create()"), "shotgun model routing required")
assert(contains(factory, "SniperRiflePresentationFactory.create()"), "sniper model routing required")
assert(contains(factory, "ServicePistolPresentationFactory.create()"), "pistol model routing required")
assert(contains(factory, "SubmachineGunPresentationFactory.create()"), "SMG model routing required")
assert(not contains(factory, "compactRig"), "scaled-box placeholder factory must stay removed")
assert(contains(serverInit, "WeaponLoadoutService.start()"), "server bootstrap must start loadout authority")

for _, prohibited in { "DataStoreService", "MarketplaceService", "Humanoid.Health" } do
	assert(not contains(service, prohibited), "loadout service widened authority: " .. prohibited)
end

print("WeaponRosterSourceAudit: authority, locked application, client boundaries, silhouettes, and bootstrap passed")
