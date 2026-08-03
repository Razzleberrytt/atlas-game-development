--!strict

local fs = require("@lune/fs")

local function check(value: unknown, message: string)
	if not value then
		error(message, 2)
	end
end

local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

check(string.find(controller, '"C   CHARACTER"', 1, true), "character button must always be available")
check(string.find(controller, '"I   INVENTORY"', 1, true), "inventory button must always be available")
check(string.find(controller, 'view.Name = "CharacterBody"', 1, true), "character screen requires a body preview")
check(string.find(controller, 'equipmentSlot(equipment, "Head"', 1, true), "paper doll requires a head slot")
check(string.find(controller, 'equipmentSlot(equipment, "Chest"', 1, true), "paper doll requires a chest slot")
check(string.find(controller, 'equipmentSlot(equipment, "Primary"', 1, true), "paper doll requires a primary slot")
check(string.find(controller, 'equipmentSlot(equipment, "Sidearm"', 1, true), "paper doll requires a sidearm slot")
check(string.find(controller, 'equipmentSlot(equipment, "Melee"', 1, true), "paper doll requires a melee slot")
check(string.find(controller, 'equipmentSlot(equipment, "Relic"', 1, true), "paper doll requires a relic slot")
check(string.find(controller, '"SURVIVOR STATS"', 1, true), "character screen requires a visible stat sheet")
check(string.find(controller, "latestProgression.runStats", 1, true), "stats must use authoritative progression state")
check(
	string.find(controller, "latestSurvival.inventoryItems", 1, true),
	"inventory must use authoritative survival state"
)
check(string.find(controller, "survivalReadState:InvokeServer()", 1, true), "inventory must request its initial state")
check(string.find(controller, "progressionReadState:InvokeServer()", 1, true), "stats must request their initial state")
check(string.find(bootstrap, "RPGMenuController.start()", 1, true), "RPG menu must bootstrap")

print("RPGMenuSourceAudit: buttons, paper doll, equipment, inventory, live stats, and bootstrap passed")
