--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Patch 0.9 durable weapon coverage audit failed", 2)
	end
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local equipment = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")
local firearm = fs.readFile("games/living-kingdoms/src/shared/Config/FirearmConfig.luau")

assert(contains(equipment, "blackwater-support-lmg"), "LMG must be represented in durable rewards")
assert(contains(equipment, "WeaponIds.LightMachineGun"), "LMG durable item must drive the authoritative firearm")
assert(contains(equipment, "razor-compact-smg"), "SMG must be represented in durable rewards")
assert(contains(equipment, "WeaponIds.SubmachineGun"), "SMG durable item must drive the authoritative firearm")
assert(
	contains(equipment, "for _, weaponId in FirearmConfig.DiscoverableWeaponIds do"),
	"durable rewards must cover the discoverable firearm roster"
)
assert(
	contains(equipment, "FirearmConfig.isKnownWeaponId"),
	"equipment weapon links must resolve through firearm definitions"
)
assert(contains(firearm, "DiscoverableWeaponIds"), "firearm discoverability must remain an explicit authored roster")

print("Patch09DurableWeaponCoverageSourceAudit.test.luau passed")
