--!strict

-- Locks the authoritative route for the durable-equipment ReloadSpeedPercent
-- effect: authored affix -> pure bounded translation -> server modifier
-- composition -> the existing ReloadResolver commitment. There must be no
-- equipment reload service, no second reload path, and no client-supplied
-- multiplier or duration.

local fs = require("@lune/fs")

local affixAdapter = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")
local equippedResolver =
	fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau")
local modifierService = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local reloadResolver = fs.readFile("games/living-kingdoms/src/server/Systems/ReloadResolver.luau")
local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains(affixAdapter, 'local RELOAD_SPEED_EFFECT_ID = "ReloadSpeedPercent"'),
	"the shared affix adapter must own the reload effect vocabulary"
)
assert(
	contains(affixAdapter, "reloadDurationReduction = reloadSpeedPercent / PERCENT_SCALE"),
	"reload affixes must translate into the canonical run-modifier contribution, not bespoke arithmetic"
)
assert(
	contains(affixAdapter, "reloadDurationMultiplier = bounded.reloadDurationMultiplier"),
	"the published reload multiplier must be the globally bounded value"
)

assert(
	contains(equippedResolver, "reloadDurationMultiplier = modifiers.reloadDurationMultiplier"),
	"only the equipped instance's resolved affixes may become a reload fact"
)

assert(
	contains(
		modifierService,
		"combined.equipmentReloadDurationMultiplier = equipmentModifiers.reloadDurationMultiplier"
	),
	"durable equipment must join the existing per-operative modifier bundle exactly once"
)
assert(
	not contains(modifierService, "OnServerEvent") and not contains(modifierService, "InvokeClient"),
	"reload composition must not add a client-to-server authority surface"
)

assert(
	contains(reloadResolver, "equipmentReloadDurationMultiplier: number?"),
	"the reload owner must expose a backward-compatible optional equipment multiplier"
)
assert(
	contains(reloadResolver, "local RELOAD_DURATION_FLOOR = 0.5"),
	"the existing reload-duration floor must be preserved"
)
assert(
	contains(reloadResolver, "math.clamp(value * relicMultiplier * equipmentMultiplier, RELOAD_DURATION_FLOOR, 1)"),
	"squad, relic, and equipment reductions must compose inside the existing floor clamp"
)
assert(
	contains(reloadResolver, "local function boundedContextMultiplier(value: unknown): number"),
	"the reload owner must independently reject malformed caller-supplied multipliers"
)

assert(
	contains(combatRuntime, "reloadDurationContext(player)"),
	"the combat owner must supply the composed reload-duration context"
)
assert(
	contains(combatRuntime, "modifiers.equipmentReloadDurationMultiplier"),
	"the reload context must read equipment facts from the server modifier bundle"
)
assert(
	not contains(combatRuntime, "InventoryNetwork"),
	"the combat runtime must not read durable gear through the client inventory network"
)

for _, path in
	{
		"games/living-kingdoms/src/server/Systems/EquipmentReloadService.luau",
		"games/living-kingdoms/src/server/Systems/ReloadSpeedService.luau",
	}
do
	assert(not fs.isFile(path), "reload speed must route through ReloadResolver, not a parallel equipment service")
end

print("LiveEquipmentReloadAffixSourceAudit: authoritative equip -> bounded reload multiplier -> ReloadResolver passed")
