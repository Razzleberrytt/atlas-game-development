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

local contracts = { SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" } }
local config = {
	Definitions = {
		{ Id = "rifle", Slot = "Primary", WeaponId = "weapon.rifle" },
		{ Id = "sidearm", Slot = "Secondary", WeaponId = "weapon.sidearm" },
		{ Id = "armor", Slot = "Armor" },
	},
}
local modifier = {
	resolve = function(affixes)
		local damagePercent, reloadSpeedPercent, maxHealthPercent, moveSpeedPercent = 0, 0, 0, 0
		for _, affix in affixes or {} do
			if affix.EffectId == "DamagePercent" then
				damagePercent += affix.Value
			elseif affix.EffectId == "ReloadSpeedPercent" then
				reloadSpeedPercent += affix.Value
			elseif affix.EffectId == "MaxHealthPercent" then
				maxHealthPercent += affix.Value
			elseif affix.EffectId == "MoveSpeedPercent" then
				moveSpeedPercent += affix.Value
			end
		end
		return table.freeze({
			damageMultiplier = 1 + damagePercent / 100,
			reloadDurationMultiplier = 1 - reloadSpeedPercent / 100,
			maximumHealthMultiplier = 1 + maxHealthPercent / 100,
			movementSpeedMultiplier = 1 + moveSpeedPercent / 100,
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
				end
				if token == CONTRACTS_TOKEN then
					return contracts
				end
				if token == MODIFIER_TOKEN then
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
		sidearm_a = reward("sidearm", "ReloadSpeedPercent", 8),
		armor_health = reward("armor", "MaxHealthPercent", 8),
		armor_move = reward("armor", "MoveSpeedPercent", 6),
	},
	EquippedBySlot = { Primary = "rifle_a", Secondary = "sidearm_a", Armor = "armor_move" },
}

local rifle = Resolver.resolveForWeapon(record, "weapon.rifle")
assertNear(rifle.damageMultiplier, 1.05, "equipped rifle contributes damage")
assert(rifle.movementSpeedMultiplier == 1, "weapon selection must not leak Armor movement")
assert(rifle.sourceInstanceId == "rifle_a", "rifle source must be authoritative equipped instance")

local sidearm = Resolver.resolveForWeapon(record, "weapon.sidearm")
assertNear(sidearm.reloadDurationMultiplier, 0.92, "equipped sidearm contributes reload speed")
assert(sidearm.movementSpeedMultiplier == 1, "sidearm must remain movement neutral")

local armor = Resolver.resolveForSlot(record, "Armor")
assertNear(armor.movementSpeedMultiplier, 1.06, "equipped Armor contributes movement speed")
assert(armor.maximumHealthMultiplier == 1, "movement Armor must not leak maximum health")
assert(armor.damageMultiplier == 1 and armor.reloadDurationMultiplier == 1, "Armor must not leak weapon modifiers")
assert(armor.sourceInstanceId == "armor_move", "Armor source must be authoritative equipped instance")

record.EquippedBySlot.Armor = "armor_health"
local healthArmor = Resolver.resolveForSlot(record, "Armor")
assertNear(healthArmor.maximumHealthMultiplier, 1.08, "health Armor still contributes maximum health")
assert(healthArmor.movementSpeedMultiplier == 1, "health-only Armor remains movement neutral")

record.EquippedBySlot.Armor = nil
local neutralArmor = Resolver.resolveForSlot(record, "Armor")
assert(
	neutralArmor.maximumHealthMultiplier == 1 and neutralArmor.movementSpeedMultiplier == 1,
	"unequipped Armor is neutral"
)
assert(neutralArmor.sourceInstanceId == nil, "unequipped Armor has no source")

local invalid = Resolver.resolveForSlot(record, "NotASlot")
assert(invalid.movementSpeedMultiplier == 1 and invalid.sourceInstanceId == nil, "invalid slot fails closed")

print("EquippedEquipmentModifierResolver weapon/Armor fixture passed")
