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
assert(
	string.find(bootstrap, 'collectItem.Name = "CollectItem"', 1, true) == nil,
	"world-owned E collection must not retain the click-only item remote"
)
assert(string.find(server, "pendingLoot", 1, true) ~= nil, "opening a chest must stage loot before collection")
assert(string.find(server, "collectChestLoot", 1, true) ~= nil, "server must own E-triggered chest collection")
assert(
	string.find(server, "collectItemRemote", 1, true) == nil,
	"survival loot must not accept click-authored item identity"
)
assert(
	string.find(server, "not isNear(player, item.worldPosition", 1, true) ~= nil,
	"the server must reject loot collection outside the chest radius"
)
assert(
	string.find(server, "prompt.KeyboardKeyCode = Enum.KeyCode.E", 1, true) ~= nil,
	"every survival world interaction must expose keyboard E"
)
assert(
	string.find(server, "collectChestLoot(player, chestId, position)", 1, true) ~= nil,
	"the chest E prompt must collect its server-staged loot"
)
assert(
	string.find(client, 'toast.Name = "ContextToast"', 1, true) ~= nil,
	"survival feedback must use one contextual toast"
)
assert(string.find(client, "TextButton", 1, true) == nil, "survival HUD must not require clickable loot cards")
assert(string.find(client, "CHEST LOOT", 1, true) == nil, "large chest overlay must remain removed")
assert(string.find(client, "BACKPACK", 1, true) == nil, "always-on backpack overlay must remain removed")

print("SurvivalLootSourceAudit: server-owned E looting and contextual survival feedback passed")
