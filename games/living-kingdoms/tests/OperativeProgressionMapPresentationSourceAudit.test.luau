--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local presentationSource =
	fs.readFile("games/living-kingdoms/src/client/Presentation/OperativeProgressionMapPresentation.luau")
local menuSource = fs.readFile("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")

assertThat(
	presentationSource:find("OperativeProgressionConfig", 1, true) ~= nil,
	"durable progression map must consume the canonical authored rank config"
)
assertThat(
	presentationSource:find('WaitForChild("OperativeProgressionNetwork")', 1, true) ~= nil,
	"durable progression map must consume the server-owned progression surface"
)
assertThat(
	presentationSource:find("progressionReadState:InvokeServer()", 1, true) ~= nil,
	"durable progression map must read server-derived account progression"
)
assertThat(
	presentationSource:find(":FireServer", 1, true) == nil,
	"durable progression map must expose no client-authored mutation path"
)
assertThat(
	presentationSource:find("OperativeProgressionConfig.Ranks", 1, true) ~= nil,
	"durable progression map must render authored milestones rather than duplicating rank data"
)
assertThat(
	presentationSource:find("OPERATIVE PROGRESSION  //  DURABLE", 1, true) ~= nil,
	"durable map must distinguish account progression from temporary run progression"
)
for _, statusId in { "EARNED", "CURRENT", "NEXT", "LOCKED" } do
	assertThat(
		presentationSource:find(statusId, 1, true) ~= nil,
		"durable progression map must expose milestone state " .. statusId
	)
end
assertThat(
	presentationSource:find("Temporary Field XP and run upgrades reset each run", 1, true) ~= nil,
	"durable map must explain the temporary-versus-durable boundary"
)

assertThat(
	menuSource:find('topButton(window, "PROGRESSION"', 1, true) ~= nil,
	"existing RPG menu must expose the durable progression surface"
)
assertThat(
	menuSource:find("skillsTab = progressionTab", 1, true) ~= nil,
	"existing hidden Skills surface should be reused rather than creating a parallel menu"
)
assertThat(
	menuSource:find("OperativeProgressionMapPresentation.rebuild(panel)", 1, true) ~= nil,
	"RPG menu should delegate durable map rendering to the dedicated presenter"
)
assertThat(
	menuSource:find("RunProgressionConfig.SkillTrees", 1, true) == nil,
	"RPG menu must not relabel temporary run-upgrade topology as durable progression"
)
assertThat(
	menuSource:find("progressionChooseUpgrade", 1, true) == nil,
	"RPG menu durable progression surface must not retain the old run-upgrade mutation remote"
)
assertThat(menuSource:find("FIELD SKILLS", 1, true) == nil, "old run-only skill-tree copy must be removed from RPG menu")
