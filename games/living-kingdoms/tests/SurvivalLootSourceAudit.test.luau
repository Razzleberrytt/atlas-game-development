--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/SurvivalLootConfig.luau"), {
	debugName = "SurvivalLootConfig",
	injectGlobals = true,
})()

assert(config.InventoryCapacity == 30, "default pack must provide thirty slots")
assert(config.ChestCount == 14, "the opening world needs a meaningful chest population")
assert(config.ChestWeaponChancePercent >= 10, "chest weapons must be realistically discoverable")
assert(config.GuaranteedWeaponByOpenedChest <= 4, "a weapon must be guaranteed early in exploration")
assert(config.Campfire.StartingFuel > 0 and config.Campfire.FuelPerWood > 0, "the home fire requires bounded fuel")

local server = fs.readFile("games/living-kingdoms/src/server/Systems/SurvivalLootService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local client = fs.readFile("games/living-kingdoms/src/client/Controllers/SurvivalHUDController.luau")

for _, token in
	{
		'addPrompt(core, "Feed 1 Wood", "HOME FIRE")',
		'addPrompt(lid, "Open Chest", "SUPPLY CHEST")',
		'addPrompt(bundle, "Take Wood", "FIREWOOD")',
		"grantFoundAmmunition",
		"equipFoundWeapon",
		"InventoryCapacity",
	}
do
	assert(string.find(server, token, 1, true) ~= nil, "survival runtime missing " .. token)
end
assert(string.find(bootstrap, "SurvivalLootService.start()", 1, true) ~= nil, "survival loot must bootstrap")
assert(string.find(client, "HOME FIRE", 1, true) ~= nil, "survival HUD must disclose home-fire fuel")
assert(string.find(client, "PACK", 1, true) ~= nil, "survival HUD must disclose inventory capacity")
assert(
	string.find(client, "SEARCH THE NEAREST SUPPLY CHEST", 1, true) ~= nil,
	"survival HUD must guide the opening loop"
)

print("SurvivalLootSourceAudit: campfire, chests, wood, weapons, ammo, and large pack passed")
