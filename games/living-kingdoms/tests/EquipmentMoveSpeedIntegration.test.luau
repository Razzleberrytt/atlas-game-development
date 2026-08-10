--!strict

-- Focused Patch 0.3 MoveSpeedPercent authority audit. Pure percentage arithmetic
-- and Armor selection are covered by their resolver fixtures; this pins the
-- server-only consequence path and anti-compounding invariant.
local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local affix = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")
local equipped = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau")
local composition = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local life = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local inventory = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")

assert(contains(affix, 'MOVEMENT_SPEED_EFFECT_ID = "MoveSpeedPercent"'), "movement affix is not translated")
assert(
	contains(affix, "movementSpeedBonus = movementSpeedPercent / PERCENT_SCALE"),
	"movement percentage must reuse canonical RunModifierResolver arithmetic"
)
assert(
	contains(equipped, "movementSpeedMultiplier = modifiers.movementSpeedMultiplier"),
	"equipped resolver must expose movement modifier facts"
)
assert(
	contains(composition, 'resolveForSlot(record, "Armor")')
		and contains(composition, "combined.equipmentMovementSpeedMultiplier = armorModifiers.movementSpeedMultiplier"),
	"server composition must derive movement from authoritative equipped Armor"
)
assert(
	contains(life, "local baseWalkSpeed = math.max(binding.walkSpeed or 0, ALIVE_HORIZONTAL_SPEED)")
		and contains(life, "humanoid.WalkSpeed = baseWalkSpeed * effectiveMovementSpeedMultiplier(entry.player)"),
	"life authority must derive effective speed from the stable bound base rather than current Humanoid speed"
)
assert(
	contains(life, "humanoid.WalkSpeed = 0"),
	"incapacitated/dead movement must remain hard disabled"
)
assert(
	contains(life, "function OperativeLifeService.reconcileMovementSpeed(player: Player): boolean")
		and contains(inventory, "OperativeLifeService.reconcileMovementSpeed(player)"),
	"inventory lifecycle must reconcile movement through the existing server character owner"
)
assert(not contains(affix, "Humanoid"), "pure affix adapter must never write Humanoid state")
assert(not contains(composition, "OnServerEvent"), "movement composition must not add client combat authority")

print("EquipmentMoveSpeedIntegration: authoritative Armor movement route and anti-compounding path passed")
