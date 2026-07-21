--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local enemy = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local harness = fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticCombatDevelopmentHarness.luau")
local classSelection = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassSelectionController.luau")
local weaponSelection = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponSelectionController.luau")
local hordeHud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local massacre = fs.readFile("games/living-kingdoms/src/client/Controllers/MassacreCrescendoController.luau")
local runBuildHud = fs.readFile("games/living-kingdoms/src/client/Controllers/RunBuildHUDController.luau")

for _, source in { enemy, harness } do
	assertThat(contains(source, "billboard.AlwaysOnTop = false"), "enemy labels must respect world occlusion")
	assertThat(contains(source, "billboard.MaxDistance = 70"), "enemy labels need a short readability range")
	assertThat(
		contains(source, "billboard.Enabled = fixture.isAlive") or contains(source, "billboard.Enabled = entry.isAlive"),
		"enemy labels must disable at death"
	)
	assertThat(not contains(source, "Health: %d"), "large two-line debug health labels must stay removed")
end

assertThat(
	contains(enemy, "entry.healthState.currentHealth < entry.maximumHealth"),
	"standard labels should remain hidden until damaged"
)
assertThat(contains(classSelection, "currentPanel.Visible = false"), "locked class picker must leave combat view")
assertThat(contains(weaponSelection, "panel.Visible = false"), "locked loadout picker must leave combat view")
assertThat(contains(hordeHud, "#Players:GetPlayers() > 1"), "solo play must not reserve a squad panel")
assertThat(contains(hordeHud, "Enum.CoreGuiType.PlayerList"), "the duplicate Roblox player list must stay hidden")
assertThat(contains(hordeHud, "overlay.BackgroundTransparency = 1"), "upgrade choices must not dim all combat")
assertThat(contains(hordeHud, "UDim2.fromOffset(430, 330)"), "upgrade choices must remain a compact side card")
assertThat(contains(hordeHud, "hasUpgradeChoices and not relicChoiceVisible"), "only one reward choice may show")
assertThat(contains(massacre, "isBlockingChoiceVisible"), "crescendo must detect blocking choice UI")
assertThat(contains(massacre, "not isBlockingChoiceVisible()"), "crescendo must yield while choices are visible")
assertThat(contains(massacre, 'FindFirstChild("RelicReward")'), "crescendo must also yield to relic choices")
assertThat(contains(runBuildHud, "UDim2.fromOffset(430, 300)"), "relic choices must remain a compact side card")
assertThat(contains(runBuildHud, "Enum.FillDirection.Vertical"), "relic choices must stack without crossing the HUD")

print("Combat presentation clutter and death-label lifecycle audit passed")
