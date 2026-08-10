--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local controllerSource =
	fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeProgressionPresentationController.luau")
local bootstrapSource = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assertThat(
	controllerSource:find('WaitForChild("OperativeProgressionNetwork")', 1, true) ~= nil,
	"presentation must consume the dedicated server-owned durable progression read surface"
)
assertThat(
	controllerSource:find("progressionReadState:InvokeServer()", 1, true) ~= nil,
	"presentation must request server-derived rank facts"
)
assertThat(
	controllerSource:find(":FireServer", 1, true) == nil,
	"durable progression presentation must expose no client mutation path"
)
assertThat(
	controllerSource:find('FindFirstChild("CharacterPanel", true)', 1, true) ~= nil,
	"rank presentation must mount into the existing RPG Character surface"
)
assertThat(
	controllerSource:find('created.Name = "OperativeProgressionCard"', 1, true) ~= nil,
	"durable rank needs one bounded card rather than a parallel menu"
)
assertThat(
	controllerSource:find('title.Text = "OPERATIVE RANK  //  DURABLE"', 1, true) ~= nil,
	"rank presentation must distinguish durable progression from run level"
)
assertThat(
	controllerSource:find('modal:GetPropertyChangedSignal("Visible")', 1, true) ~= nil,
	"opening the RPG menu must refresh durable progression after completed runs"
)
assertThat(
	controllerSource:find("inventoryStateRemote.OnClientEvent", 1, true) ~= nil,
	"initial inventory load should trigger a durable rank refresh"
)

local menuStart = bootstrapSource:find("RPGMenuController.start()", 1, true)
local progressionStart = bootstrapSource:find("OperativeProgressionPresentationController.start()", 1, true)
assertThat(menuStart ~= nil and progressionStart ~= nil, "client bootstrap must mount both RPG menu and rank presentation")
assertThat(menuStart < progressionStart, "RPG menu must exist before its rank card mounts")
