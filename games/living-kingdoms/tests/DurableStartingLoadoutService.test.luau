--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local INVENTORY_TOKEN = {}
local COMBAT_TOKEN = {}

local record: any = nil
local equippedWeaponIds = {}

local config = table.freeze({
	Definitions = table.freeze({
		table.freeze({ Id = "primary", Slot = "Primary", WeaponId = "weapon.sniper" }),
		table.freeze({ Id = "secondary", Slot = "Secondary", WeaponId = "weapon.pistol" }),
		table.freeze({ Id = "armor", Slot = "Armor", WeaponId = nil }),
	}),
})
local contracts = table.freeze({
	SlotIds = table.freeze({ Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" }),
})
local inventory = table.freeze({
	getRecord = function(_playerId: number)
		return record
	end,
})
local combat = table.freeze({
	equipFoundWeapon = function(_player: any, weaponId: string)
		table.insert(equippedWeaponIds, weaponId)
		return weaponId ~= "weapon.rejected"
	end,
})

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/DurableStartingLoadoutService.luau"), {
	debugName = "DurableStartingLoadoutService",
	environment = {
		game = {
			GetService = function(_self: any, name: string)
				assert(name == "ReplicatedStorage")
				return {
					Shared = {
						Config = { EquipmentRewardConfig = CONFIG_TOKEN },
						Equipment = { EquipmentRewardContracts = CONTRACTS_TOKEN },
					},
				}
			end,
		},
		script = { Parent = { InventoryLiveService = INVENTORY_TOKEN, OperativeCombatRuntimeService = COMBAT_TOKEN } },
		require = function(token: unknown)
			if token == CONFIG_TOKEN then
				return config
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == INVENTORY_TOKEN then
				return inventory
			elseif token == COMBAT_TOKEN then
				return combat
			end
			error("unexpected dependency")
		end,
	},
	injectGlobals = true,
})()

local player = { UserId = 7 }

local function reset(nextRecord: any)
	record = nextRecord
	table.clear(equippedWeaponIds)
end

reset(nil)
assert(service.applyForPlayer(player).ReasonId == "InventoryNotLoaded")
assert(#equippedWeaponIds == 0)

reset({ EquippedBySlot = {}, InventoryByInstanceId = {} })
assert(service.applyForPlayer(player).ReasonId == "NoEquippedDurableWeapon")
assert(#equippedWeaponIds == 0)

reset({
	EquippedBySlot = { Secondary = "item-secondary" },
	InventoryByInstanceId = {
		["item-secondary"] = { DefinitionId = "secondary", Slot = "Secondary" },
	},
})
local secondary = service.applyForPlayer(player)
assert(secondary.Accepted and secondary.WeaponId == "weapon.pistol")
assert(#equippedWeaponIds == 1 and equippedWeaponIds[1] == "weapon.pistol")

reset({
	EquippedBySlot = { Primary = "item-primary", Secondary = "item-secondary" },
	InventoryByInstanceId = {
		["item-primary"] = { DefinitionId = "primary", Slot = "Primary" },
		["item-secondary"] = { DefinitionId = "secondary", Slot = "Secondary" },
	},
})
local primary = service.applyForPlayer(player)
assert(primary.Accepted and primary.WeaponId == "weapon.sniper")
assert(#equippedWeaponIds == 1 and equippedWeaponIds[1] == "weapon.sniper", "primary must win over sidearm")

reset({
	EquippedBySlot = { Primary = "missing", Secondary = "item-secondary" },
	InventoryByInstanceId = {
		["item-secondary"] = { DefinitionId = "secondary", Slot = "Secondary" },
	},
})
assert(service.applyForPlayer(player).ReasonId == "InvalidEquippedDurableItem", "malformed primary must fail closed")
assert(#equippedWeaponIds == 0, "invalid preferred gear must not silently fall back")

reset({
	EquippedBySlot = { Armor = "item-armor" },
	InventoryByInstanceId = {
		["item-armor"] = { DefinitionId = "armor", Slot = "Armor" },
	},
})
assert(service.applyForPlayer(player).ReasonId == "NoEquippedDurableWeapon", "non-weapon slots cannot drive combat")
assert(#equippedWeaponIds == 0)

print(
	"DurableStartingLoadoutService: primary preference, sidearm fallback, authored WeaponId, and fail-closed state passed"
)
