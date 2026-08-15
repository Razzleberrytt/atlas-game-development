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
local camera = fs.readFile("games/living-kingdoms/src/client/Controllers/Input/CameraController.luau")

for _, source in { enemy, harness } do
	assertThat(contains(source, "billboard.AlwaysOnTop = false"), "enemy labels must respect world occlusion")
	assertThat(contains(source, "billboard.MaxDistance = 70"), "enemy labels need a short readability range")
	assertThat(
		contains(source, "billboard.Enabled = fixture.isAlive") or contains(source, "entry.isAlive"),
		"enemy labels must disable at death"
	)
	assertThat(not contains(source, "Health: %d"), "large two-line debug health labels must stay removed")
end

assertThat(
	contains(enemy, "billboard.Enabled = entry.isAlive and entry.eliteAffixId ~= nil"),
	"persistent world labels must be reserved for living elites"
)
assertThat(
	not contains(enemy, "entry.healthState.currentHealth < entry.maximumHealth or entry.eliteAffixId ~= nil"),
	"damaging an ordinary horde must not create persistent nameplate clutter"
)
assertThat(contains(classSelection, "currentPanel.Visible = false"), "locked class picker must leave combat view")
assertThat(contains(weaponSelection, "panel.Visible = false"), "locked loadout picker must leave combat view")
assertThat(contains(hordeHud, "#Players:GetPlayers() > 1"), "solo play must not reserve a squad panel")
assertThat(contains(hordeHud, "Enum.CoreGuiType.PlayerList"), "the duplicate Roblox player list must stay hidden")
assertThat(contains(hordeHud, "overlay.BackgroundTransparency = 1"), "upgrade choices must not dim all combat")
assertThat(contains(hordeHud, "UDim2.fromOffset(470, 350)"), "upgrade choices must remain a compact readable card")
assertThat(contains(hordeHud, 'Instance.new("UIGradient")'), "HUD panels need a restrained depth treatment")
assertThat(contains(hordeHud, 'accent.Name = "Accent"'), "HUD panels need a consistent hierarchy accent")
assertThat(contains(hordeHud, "hasUpgradeChoices and not relicChoiceVisible"), "only one reward choice may show")
assertThat(
	not contains(hordeHud, "FIELD LEVEL %02d — CHOOSE AN UPGRADE"),
	"the upgrade card must not duplicate its call to action over combat"
)
assertThat(contains(massacre, "isBlockingChoiceVisible"), "crescendo must detect blocking choice UI")
assertThat(contains(massacre, "not isBlockingChoiceVisible()"), "crescendo must yield while choices are visible")
assertThat(contains(massacre, 'FindFirstChild("RelicReward")'), "crescendo must also yield to relic choices")
assertThat(contains(massacre, "UDim2.fromOffset(460, 82)"), "crescendo must remain a compact combat toast")
assertThat(contains(runBuildHud, "UDim2.fromOffset(430, 330)"), "relic choices must remain a compact side card")
assertThat(contains(runBuildHud, "Enum.FillDirection.Vertical"), "relic choices must stack without crossing the HUD")
assertThat(contains(camera, "LockFirstPerson"), "combat must use the authored first-person camera policy")
assertThat(contains(camera, "MouseBehavior.LockCenter"), "FPS mouse-look must keep the desktop cursor centered")
assertThat(contains(camera, "LK_InputModalOpen"), "blocking choices must temporarily release the FPS cursor")
assertThat(contains(camera, "FIRST_PERSON_FIELD_OF_VIEW = 78"), "FPS field of view must remain readable")

print("Combat presentation clutter and death-label lifecycle audit passed")
