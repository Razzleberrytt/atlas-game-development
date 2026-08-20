--!strict

local fs = require("@lune/fs")

local modifierService = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local damageResolver = fs.readFile("games/living-kingdoms/src/server/Systems/DamageResolver.luau")
local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

--[[
	The adapter must compose the shared equipped-item resolver out of
	ReplicatedStorage.Shared.Equipment. It used to reach that module by dotted
	index, which raises in the engine when the folder is absent, so the lookup is
	now a FindFirstChild pair. Name both halves of the path rather than one dotted
	literal: the guarantee is which module is composed and where it comes from,
	not how the reference happens to be spelled.
]]
assert(
	contains(modifierService, 'ReplicatedStorage.Shared:FindFirstChild("Equipment")')
		and contains(modifierService, 'FindFirstChild("EquippedEquipmentModifierResolver")'),
	"server modifier adapter must use the shared equipped-item resolver"
)
assert(
	not contains(modifierService, "ReplicatedStorage.Shared.Equipment."),
	"the equipment seam must not be reached by dotted index: a missing child raises rather than returning nil"
)
assert(
	contains(modifierService, "InventoryLiveService.getRecord(player.UserId)"),
	"equipment modifier source must be the authoritative server inventory record"
)
assert(
	contains(modifierService, 'player:GetAttribute("LK_EquippedWeaponId")'),
	"equipment modifier must be gated by the server-authored active weapon"
)
assert(
	contains(modifierService, "resolveForWeapon(record, activeWeaponId)")
		and contains(modifierService, "combined.equipmentDamageMultiplier = weaponModifiers.damageMultiplier"),
	"durable equipment must join the existing per-operative modifier bundle exactly once"
)
assert(
	not contains(modifierService, "OnServerEvent"),
	"modifier composition must not add a client-to-server combat authority surface"
)
assert(not contains(modifierService, "InvokeClient"), "modifier composition must not ask a client for equipment facts")

assert(
	contains(damageResolver, "equipmentDamageMultiplier: number?"),
	"damage boundary must expose a backward-compatible optional equipment multiplier"
)
assert(
	contains(damageResolver, "local equipmentDamageMultiplier = relic.equipmentDamageMultiplier or 1"),
	"legacy/no-affix bundles must remain neutral"
)
assert(
	contains(damageResolver, "not isBoundedMultiplier(equipmentDamageMultiplier)"),
	"authoritative damage must independently reject malformed equipment multipliers"
)
assert(
	contains(damageResolver, "local multiplier = equipmentDamageMultiplier"),
	"bounded equipment damage must enter the same capped damage multiplication path"
)
assert(
	contains(damageResolver, "math.min(multiplier, RELIC_COMBINED_MULTIPLIER_CEILING)"),
	"combined per-operative build damage must retain the existing hard ceiling"
)
assert(
	contains(damageResolver, "configured * 3"),
	"final firearm damage must retain the configured-times-three hard cap"
)

assert(
	contains(combatRuntime, "relicModifiers = RelicModifierService.read(player)"),
	"existing combat runtime must consume the composed server modifier bundle"
)
assert(
	not contains(combatRuntime, "InventoryNetwork"),
	"combat runtime must not read durable gear through the client inventory network"
)

print("LiveEquipmentDamageAffixSourceAudit: authoritative equip -> bounded modifier -> canonical damage passed")
