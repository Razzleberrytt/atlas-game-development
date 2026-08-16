--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local presentation = fs.readFile("games/living-kingdoms/src/server/Systems/ModularDungeonRoomPresentation.luau")
local roomPlacement = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")

for _, token in
	{
		'RoleIds.Entry] = "dungeon.room.empty.a"',
		'RoleIds.Traversal] = "dungeon.corridor.straight.a"',
		'RoleIds.Combat] = "dungeon.room.combat.a"',
		'RoleIds.Elite] = "dungeon.room.combat.a"',
		'RoleIds.Boss] = "dungeon.arena.boss.a"',
		'RoleIds.Secret] = "dungeon.room.secret.a"',
		"ModularAssetProductionCatalog.Dungeon.Modules",
		"catalogDungeonAssetIds[definition.id] = true",
		"catalogDungeonAssetIds[assetId] == true",
		"ASSET_READY_WAIT_SECONDS = 0.75",
		"local readinessWaitSpent = false",
		"ModularAssetResolver.WaitForGeneratedAssetById",
		"ModularAssetResolver.GetGeneratedRoot",
		"ModularAssetResolver.CloneByAssetId",
		"descendant.CanCollide = false",
		"descendant.CanTouch = false",
		"descendant.CanQuery = false",
		'descendant:IsA("Attachment")',
		'descendant:IsA("ProximityPrompt")',
		'descendant:IsA("Script")',
		"ModularAssetProductionCatalog.Dungeon.WallHeightStuds",
		"local scaleX = size.x / root.Size.X",
		"local scaleY = size.y / ModularAssetProductionCatalog.Dungeon.WallHeightStuds",
		"local scaleZ = size.z / root.Size.Z",
		'descendant.Name == "ArenaWall"',
		"root.CFrame:PointToObjectSpace(descendant.Position)",
		"math.abs(localPosition.Z) > math.abs(localPosition.X)",
		'{ "Floor", "WestWall", "EastWall" }',
		'graybox:SetAttribute("GameplayCollisionRetained", true)',
		'graybox:SetAttribute("ModularVisualProxy", true)',
		'GameplayCollisionOwnedByGraybox", true',
		'ModularDungeonVisualStatus", MODULAR_STATUS',
		'ModularDungeonVisualStatus", FALLBACK_STATUS',
	}
do
	assert(contains(presentation, token), "modular dungeon presentation missing contract token " .. token)
end

for _, token in
	{
		"RoomPlacementPlanner.plan",
		"value.CanCollide = true",
		'part("EntranceConnector"',
		'part("ExitConnector"',
		'doorwayFixture("EntranceReveal"',
		'doorwayFixture("ExitReveal"',
		"ExpeditionEnvironmentBuilder.decorate(model, placement, seed)",
		"ModularDungeonRoomPresentation.apply(model, placement)",
		'bridge:SetAttribute("ConnectorIndex", index)',
	}
do
	assert(contains(roomPlacement, token), "authoritative room-placement contract missing " .. token)
end

local decorateStart =
	assert(string.find(roomPlacement, "ExpeditionEnvironmentBuilder.decorate(model, placement, seed)", 1, true))
local modularStart =
	assert(string.find(roomPlacement, "ModularDungeonRoomPresentation.apply(model, placement)", 1, true))
assert(
	decorateStart < modularStart,
	"authored room decoration must exist before the modular presentation shell is applied"
)

for _, prohibited in
	{
		"dungeon.corridor.curved.a",
		"dungeon.corridor.broken.a",
		"RoomPlacementPlanner",
		"RemoteEvent",
		"RemoteFunction",
		"FireServer",
		"FireClient",
		"DamageResolver",
		"EnemyDirector",
		"EncounterCoordinator",
	}
do
	assert(
		not contains(presentation, prohibited),
		"modular dungeon presentation gained misleading/authoritative token " .. prohibited
	)
end

assert(not contains(presentation, "graybox.CanCollide = false"))
assert(not contains(presentation, "graybox.CanQuery = false"))
assert(not contains(presentation, "graybox.CanTouch = false"))

print("ModularDungeonRoomPresentationSourceAudit: live shell mapping, fit, fallback, and authority boundaries passed")
