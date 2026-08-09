--!strict

local fs = require("@lune/fs")

local function read(path: string): string
	return fs.readFile(path)
end

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local modeService = read("games/living-kingdoms/src/server/Systems/PrimaryCombatModeService.luau")
local combatRuntime = read("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local lootConfig = read("games/living-kingdoms/src/shared/Config/SurvivalLootConfig.luau")
local lootService = read("games/living-kingdoms/src/server/Systems/SurvivalLootService.luau")
local weaponPresentation = read("games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau")
local meleePresentation = read("games/living-kingdoms/src/client/Controllers/MeleePresentationController.luau")
local lifecycle = read("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau")

assert(contains(modeService, "setAttribute(player, ModeIds.Melee)"), "fresh players must start in melee mode")
assert(contains(modeService, "function Service.resetAllToMelee"), "replay must have a melee reset seam")
assert(not contains(modeService, "OnServerEvent"), "clients cannot request a combat-mode switch")

assert(
	contains(combatRuntime, "PrimaryCombatModeService.readMode(player) == PrimaryCombatModeIds.Firearm"),
	"firearm runtime needs one server-owned mode predicate"
)
assert(
	contains(combatRuntime, "if not firearmModeActive(player) then"),
	"firearm evaluation and intent paths must reject melee mode"
)
assert(
	contains(combatRuntime, "if not firearmModeActive(player) then\n\t\tif isFiring == false then"),
	"a melee-mode stop intent may clear stale firing but cannot arm firearm fire"
)
assert(
	contains(combatRuntime, "or not firearmModeActive(player)"),
	"reload requests must be rejected outside firearm mode"
)
assert(
	contains(combatRuntime, "PrimaryCombatModeService.setMode(player, PrimaryCombatModeIds.Firearm)"),
	"retained or recovered firearms must restore firearm mode server-side"
)
assert(
	contains(combatRuntime, "weaponId == FirearmConfig.DefaultSelectableWeaponId"),
	"the recovered Service Pistol must be accepted by the found-weapon handoff"
)
assert(contains(combatRuntime, "function OperativeCombatRuntimeService.resetForReplay()"), "replay must reset hidden firearm runtime state")

assert(contains(lootConfig, "OpeningRecoveryWeaponId = FirearmConfig.DefaultSelectableWeaponId"), "opening recovery must use the humble Service Pistol")
assert(contains(lootConfig, "OpeningRecoveryByOpenedChest = 1"), "first personal chest must guarantee firearm recovery")
assert(
	contains(lootService, "state.openedChests == Config.OpeningRecoveryByOpenedChest"),
	"first-chest recovery must be driven by each player's opened-chest count"
)
assert(
	contains(lootService, "player:GetAttribute(PrimaryCombatModeAttributeName) == PrimaryCombatModeIds.Melee"),
	"opening pistol must only be staged while the player still needs a firearm"
)
assert(
	contains(lootService, "if item.weaponId ~= Config.OpeningRecoveryWeaponId then"),
	"recovering the pistol cannot consume the later stronger-weapon discovery opportunity"
)
assert(
	contains(lootService, "local weapons = Config.DiscoverableWeaponIds"),
	"stronger firearm discovery pool must remain active after pistol recovery"
)
assert(contains(lootService, "function Service.resetForReplay()"), "survival loot/chests must reset for deliberate replay")

assert(
	contains(weaponPresentation, "player:GetAttribute(PRIMARY_COMBAT_MODE_ATTRIBUTE) == PrimaryCombatModeIds.Melee"),
	"firearm rigs must be suppressed while the server mode is melee"
)
assert(
	contains(weaponPresentation, "combatModeAttributeConnection"),
	"firearm presentation must reconcile when recovery flips the mode"
)
assert(contains(meleePresentation, 'FIRST_PERSON_MODEL_NAME = "FirstPersonMelee"'), "local melee opening must show a first-person hatchet")
assert(contains(meleePresentation, 'MODEL_NAME = "MeleePresentation"'), "squadmates in melee mode need a readable third-person hatchet")
assert(not contains(meleePresentation, "FireServer"), "melee presentation cannot own combat intent")
assert(not contains(meleePresentation, "EnemyDirector"), "melee presentation cannot own damage/target authority")

assert(contains(lifecycle, "PrimaryCombatModeService.resetAllToMelee()"), "replay must restore the melee opening")
assert(contains(lifecycle, "OperativeCombatRuntimeService.resetForReplay()"), "replay must clear carried firearm runtime state")
assert(contains(lifecycle, "SurvivalLootService.resetForReplay()"), "replay must restore recoverable survival loot")

print("MeleeOpeningRecoverySourceAudit: melee-first recovery and replay authority passed")
