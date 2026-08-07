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
	string.find(bootstrap, 'collectItem.Name = "CollectItem"', 1, true) ~= nil,
	"loot requires an explicit take-item remote"
)
assert(string.find(server, "pendingLoot", 1, true) ~= nil, "opening a chest must stage loot before collection")
assert(string.find(server, "collectPendingLoot", 1, true) ~= nil, "server must own explicit item collection")
assert(
	string.find(server, "collectItemRemote.OnServerEvent:Connect(collectPendingLoot)", 1, true) ~= nil,
	"tappable loot requests must terminate at the server-owned collection path"
)
assert(
	string.find(server, "not isNear(player, item.worldPosition", 1, true) ~= nil,
	"the server must reject remote loot collection outside the chest radius"
)
assert(string.find(client, "HOME FIRE", 1, true) ~= nil, "survival HUD must disclose home-fire fuel")
assert(string.find(client, "PACK", 1, true) ~= nil, "survival HUD must disclose inventory capacity")
assert(string.find(client, "CHEST LOOT", 1, true) ~= nil, "opened loot requires a visible RPG loot panel")
assert(
	string.find(client, "card.Activated:Connect", 1, true) ~= nil,
	"every loot card must support mouse and touch activation"
)
assert(
	string.find(client, "collectItemRemote:FireServer(item.itemId)", 1, true) ~= nil,
	"loot cards may request only item identity"
)
assert(string.find(client, "BACKPACK", 1, true) ~= nil, "collected resources require a visible backpack surface")
assert(string.find(client, '"MELEE", "EMPTY SLOT"', 1, true) ~= nil, "inventory must reserve a readable melee slot")
assert(
	string.find(client, "SEARCH THE NEAREST SUPPLY CHEST", 1, true) ~= nil,
	"survival HUD must guide the opening loop"
)

print("SurvivalLootSourceAudit: campfire, chests, wood, weapons, ammo, and large pack passed")
