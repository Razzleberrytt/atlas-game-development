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

check(#config.SkillTrees == 3, "temporary run progression must retain three distinct build paths")
check(#config.UpgradeDefinitions == 12, "all existing run powers must remain in the temporary topology")
local roots = 0
local tierFour = 0
for _, definition in config.UpgradeDefinitions do
	check(type(definition.TreeId) == "string", "every run power requires a tree")
	check(type(definition.Icon) == "string", "every run power requires iconography")
	check(type(definition.PrerequisiteIds) == "table", "every run power requires explicit prerequisites")
	if definition.Tier == 1 then
		roots += 1
		check(#definition.PrerequisiteIds == 0, "root run skills must be immediately available")
	elseif definition.Tier == 4 then
		tierFour += 1
		check(#definition.PrerequisiteIds > 0, "run capstones require temporary-run investment")
	end
end
check(roots == 3 and tierFour == 3, "each temporary run tree requires one root and one capstone")
check(string.find(resolver, "hasPrerequisites", 1, true), "server offers must enforce the temporary tree topology")

-- Patch 0.4 separates durable account progression from the temporary run tree.
-- The RPG menu owns the durable map only; HordeHUD remains the contextual owner
-- of offered run-upgrade selection and sends only one server-authored offered ID.
check(string.find(menu, 'topButton(window, "PROGRESSION"', 1, true), "RPG menu must expose durable progression")
check(
	string.find(menu, "OperativeProgressionMapPresentation.rebuild(panel)", 1, true),
	"RPG menu must delegate the durable map to its read-only presenter"
)
check(
	not string.find(menu, "progressionChooseUpgrade", 1, true),
	"durable RPG menu must not submit temporary run choices"
)
check(
	not string.find(menu, "RunProgressionConfig.SkillTrees", 1, true),
	"durable RPG menu must not render run topology"
)
check(not string.find(menu, "FIELD SKILLS", 1, true), "durable RPG menu must not present temporary Field Skills")

check(
	string.find(hud, "progressionChooseUpgradeRemote:FireServer(upgradeId)", 1, true),
	"contextual run HUD must submit one server-offered upgrade ID"
)
check(
	string.find(hud, "LEVEL UP  //  CHOOSE ONE RUN UPGRADE", 1, true),
	"temporary run choices require an explicit contextual run-upgrade label"
)
check(
	string.find(hud, "choiceButtonActionText(familyId, keyTokens, index)", 1, true),
	"temporary run choices require a readable per-device choice action"
)
-- Contextual level-up choices must still instruct the player, but BA-062 resolves
-- that instruction per device family instead of naming keyboard keys outright.
check(
	string.find(hud, "choicePromptText(familyId, keyTokens)", 1, true),
	"contextual level-up choices require a device-resolved instruction"
)
check(
	not string.find(hud, "PRESS 1, 2, OR 3", 1, true),
	"contextual level-up instructions must not hard-code keyboard-only keys"
)
check(string.find(hud, "LK_InputModalOpen", 1, true), "contextual level-up choices must release the cursor")

print("SkillTreeSourceAudit: temporary run topology remains authoritative while RPG menu progression stays durable")
