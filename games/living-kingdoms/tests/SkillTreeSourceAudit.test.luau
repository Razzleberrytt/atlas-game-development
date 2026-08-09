--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(value: unknown, message: string)
	if not value then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()
local resolver = fs.readFile("games/living-kingdoms/src/shared/Progression/RunUpgradeResolver.luau")
local menu = fs.readFile("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")

check(#config.SkillTrees == 3, "the RPG menu requires three distinct build paths")
check(#config.UpgradeDefinitions == 12, "all existing powers must appear in the trees")
local roots = 0
local tierFour = 0
for _, definition in config.UpgradeDefinitions do
	check(type(definition.TreeId) == "string", "every power requires a tree")
	check(type(definition.Icon) == "string", "every power requires iconography")
	check(type(definition.PrerequisiteIds) == "table", "every power requires explicit prerequisites")
	if definition.Tier == 1 then
		roots += 1
		check(#definition.PrerequisiteIds == 0, "root skills must be immediately available")
	elseif definition.Tier == 4 then
		tierFour += 1
		check(#definition.PrerequisiteIds > 0, "capstone skills require investment")
	end
end
check(roots == 3 and tierFour == 3, "each tree requires one root and one capstone")
check(string.find(resolver, "hasPrerequisites", 1, true), "server offers must enforce the tree topology")
check(not string.find(menu, '"K   SKILLS"', 1, true), "the premature persistent Skills button must stay paused")
check(not string.find(menu, 'toggleTab("Skills")', 1, true), "the premature Skills hotkey must stay paused")
check(string.find(menu, "progressionChooseUpgrade:FireServer", 1, true), "available nodes must use validated choices")
check(string.find(menu, '"AVAILABLE — CHOOSE"', 1, true), "available nodes require a readable state")
check(string.find(menu, '"MASTERED"', 1, true), "max-rank nodes require a readable state")
check(string.find(menu, '"REQUIRES "', 1, true), "locked nodes must explain prerequisites")
check(string.find(hud, "PRESS 1, 2, OR 3", 1, true), "contextual level-up choices require keyboard instructions")
check(string.find(hud, "LK_InputModalOpen", 1, true), "contextual level-up choices must release the cursor")

print("SkillTreeSourceAudit: topology stays authoritative while premature tree navigation remains paused")
