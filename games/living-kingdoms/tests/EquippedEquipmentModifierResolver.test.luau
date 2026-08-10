--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "equipped modifier assertion failed", 2)
	end
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
	},
}
local modifier = {
	resolve = function(affixes)
		local damagePercent = 0
		for _, affix in affixes or {} do
			if affix.EffectId == "DamagePercent" then
				damagePercent += affix.Value
			end
		end
		return table.freeze({ damageMultiplier = 1 + damagePercent / 100 })
	end,
}

local Resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau"),
	{
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
	}
)()

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
	},
	EquippedBySlot = {
		Primary = "rifle_a",
		Secondary = "sidearm_a",
	},
}

local rifle = Resolver.resolveForWeapon(record, "weapon.rifle")
assert(rifle.damageMultiplier == 1.05, "equipped matching rifle contributes its bounded damage affix")
assert(rifle.sourceInstanceId == "rifle_a", "modifier names the authoritative equipped instance")

local shotgun = Resolver.resolveForWeapon(record, "weapon.shotgun")
assert(shotgun.damageMultiplier == 1, "owned but unequipped weapon contributes nothing")
assert(shotgun.sourceInstanceId == nil, "unequipped item is not a modifier source")

local sidearm = Resolver.resolveForWeapon(record, "weapon.sidearm")
assert(sidearm.damageMultiplier == 1, "non-damage affixes stay neutral until their canonical owner is wired")
assert(sidearm.sourceInstanceId == "sidearm_a", "matching equipped item remains identifiable even when neutral")

record.EquippedBySlot.Primary = "rifle_b"
local switched = Resolver.resolveForWeapon(record, "weapon.rifle")
assert(switched.damageMultiplier == 1.09, "changing authoritative equip changes the modifier source")
assert(switched.sourceInstanceId == "rifle_b", "new equipped instance becomes the source")

assert(Resolver.resolveForWeapon(nil, "weapon.rifle").damageMultiplier == 1, "unloaded inventory fails closed")
assert(Resolver.resolveForWeapon(record, "").damageMultiplier == 1, "invalid weapon identity fails closed")

print("EquippedEquipmentModifierResolver fixture passed")
