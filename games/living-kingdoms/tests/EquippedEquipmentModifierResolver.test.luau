--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "equipped modifier assertion failed", 2)
	end
end

local function assertNear(actual: number, expected: number, message: string)
	assert(math.abs(actual - expected) < 1e-9, message)
end

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local MODIFIER_TOKEN = {}

local contracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
}
local config = {
	Definitions = {
		{ Id = "rifle", Slot = "Primary", WeaponId = "weapon.rifle" },
		{ Id = "shotgun", Slot = "Primary", WeaponId = "weapon.shotgun" },
		{ Id = "sidearm", Slot = "Secondary", WeaponId = "weapon.sidearm" },
		{ Id = "armor", Slot = "Armor" },
	},
}
local modifier = {
	resolve = function(affixes)
		local damagePercent = 0
		local reloadSpeedPercent = 0
		local maxHealthPercent = 0
		for _, affix in affixes or {} do
			if affix.EffectId == "DamagePercent" then
				damagePercent += affix.Value
			elseif affix.EffectId == "ReloadSpeedPercent" then
				reloadSpeedPercent += affix.Value
			elseif affix.EffectId == "MaxHealthPercent" then
				maxHealthPercent += affix.Value
			end
		end
		return table.freeze({
			damageMultiplier = 1 + damagePercent / 100,
			reloadDurationMultiplier = 1 - reloadSpeedPercent / 100,
			maximumHealthMultiplier = 1 + maxHealthPercent / 100,
		})
	end,
}

local Resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau"), {
		debugName = "EquippedEquipmentModifierResolver",
		environment = {
			script = {
				Parent = {
					Parent = { Config = { EquipmentRewardConfig = CONFIG_TOKEN } },
					EquipmentRewardContracts = CONTRACTS_TOKEN,
					EquipmentAffixModifierResolver = MODIFIER_TOKEN,
				},
			},
			require = function(token: unknown)
				if token == CONFIG_TOKEN then
					return config
				elseif token == CONTRACTS_TOKEN then
					return contracts
				elseif token == MODIFIER_TOKEN then
					return modifier
				end
				error("unexpected equipped modifier dependency")
			end,
		},
		injectGlobals = true,
	})()

local function reward(definitionId: string, effectId: string?, value: number?)
	local affixes = {}
	if effectId ~= nil and value ~= nil then
		table.insert(affixes, { EffectId = effectId, Value = value })
	end
	return { DefinitionId = definitionId, Affixes = affixes }
end

local record = {
	InventoryByInstanceId = {
		rifle_a = reward("rifle", "DamagePercent", 5),
		rifle_b = reward("rifle", "DamagePercent", 9),
		shotgun_a = reward("shotgun", "DamagePercent", 7),
		sidearm_a = reward("sidearm", "ReloadSpeedPercent", 8),
		armor_a = reward("armor", "MaxHealthPercent", 8),
	},
	EquippedBySlot = {
		Primary = "rifle_a",
		Secondary = "sidearm_a",
		Armor = "armor_a",
	},
}

local rifle = Resolver.resolveForWeapon(record, "weapon.rifle")
assertNear(rifle.damageMultiplier, 1.05, "equipped matching rifle contributes its bounded damage affix")
assert(rifle.reloadDurationMultiplier == 1, "damage-only rifle remains reload neutral")
assert(rifle.maximumHealthMultiplier == 1, "weapon selection must not leak Armor health")
assert(rifle.sourceInstanceId == "rifle_a", "modifier names the authoritative equipped instance")

local shotgun = Resolver.resolveForWeapon(record, "weapon.shotgun")
assert(shotgun.damageMultiplier == 1, "owned but unequipped weapon contributes no damage")
assert(shotgun.reloadDurationMultiplier == 1, "owned but unequipped weapon contributes no reload speed")
assert(shotgun.maximumHealthMultiplier == 1, "owned but unequipped weapon contributes no maximum health")
assert(shotgun.sourceInstanceId == nil, "unequipped item is not a modifier source")

local sidearm = Resolver.resolveForWeapon(record, "weapon.sidearm")
assert(sidearm.damageMultiplier == 1, "reload-speed sidearm remains damage neutral")
assertNear(sidearm.reloadDurationMultiplier, 0.92, "equipped matching sidearm contributes reload speed")
assert(sidearm.maximumHealthMultiplier == 1, "sidearm selection must remain max-health neutral")
assert(sidearm.sourceInstanceId == "sidearm_a", "matching equipped item remains the authoritative source")

local armor = Resolver.resolveForSlot(record, "Armor")
assert(armor.damageMultiplier == 1 and armor.reloadDurationMultiplier == 1, "Armor must not leak weapon modifiers")
assertNear(armor.maximumHealthMultiplier, 1.08, "equipped Armor contributes maximum health")
assert(armor.sourceInstanceId == "armor_a", "Armor slot names its authoritative equipped instance")

record.EquippedBySlot.Primary = "rifle_b"
local switched = Resolver.resolveForWeapon(record, "weapon.rifle")
assertNear(switched.damageMultiplier, 1.09, "changing authoritative equip changes the damage modifier source")
assert(switched.reloadDurationMultiplier == 1, "switching damage-only rifles remains reload neutral")
assert(switched.maximumHealthMultiplier == 1, "switching weapons remains max-health neutral")
assert(switched.sourceInstanceId == "rifle_b", "new equipped instance becomes the source")

record.EquippedBySlot.Armor = nil
local unequippedArmor = Resolver.resolveForSlot(record, "Armor")
assert(unequippedArmor.maximumHealthMultiplier == 1, "owned but unequipped Armor must be neutral")
assert(unequippedArmor.sourceInstanceId == nil, "unequipped Armor must not remain a source")

local unloaded = Resolver.resolveForWeapon(nil, "weapon.rifle")
assert(
	unloaded.damageMultiplier == 1 and unloaded.reloadDurationMultiplier == 1 and unloaded.maximumHealthMultiplier == 1,
	"unloaded inventory fails closed"
)
local invalid = Resolver.resolveForWeapon(record, "")
assert(
	invalid.damageMultiplier == 1 and invalid.reloadDurationMultiplier == 1 and invalid.maximumHealthMultiplier == 1,
	"invalid weapon identity fails closed"
)
local invalidSlot = Resolver.resolveForSlot(record, "NotASlot")
assert(invalidSlot.maximumHealthMultiplier == 1 and invalidSlot.sourceInstanceId == nil, "invalid slot fails closed")

print("EquippedEquipmentModifierResolver weapon/slot fixture passed")
