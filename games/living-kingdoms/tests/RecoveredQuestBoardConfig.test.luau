--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredQuestBoardConfig assertion failed", 2)
	end
end

local function checkVector(actual: any, x: number, y: number, z: number, label: string)
	check(actual ~= nil, label .. " is missing")
	check(math.abs(actual.x - x) <= 1e-8, label .. ".x mismatch")
	check(math.abs(actual.y - y) <= 1e-8, label .. ".y mismatch")
	check(math.abs(actual.z - z) <= 1e-8, label .. ".z mismatch")
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredQuestBoardConfig.luau"), {
	debugName = "RecoveredQuestBoardConfig",
	injectGlobals = true,
})()

check(config.Version == "BA-005-QUEST-BOARD-v1")
check(config.SourcePath == "Workspace/HubTown/quest_board")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)

check(config.Interaction.LegacyQuestServiceAuthority == false)
check(config.Interaction.RecoveredShortcutTextIsPresentationOnly == true)
check(config.Interaction.RecoveredPromptExists == false)
check(config.Interaction.FuturePrelaunchSelectionContractRequired == true)
check(config.Interaction.DirectMissionDirectorClientMutationAllowed == false)
check(config.Interaction.MissionDirectorRemainsOperationRuntimeAuthority == true)
check(config.Interaction.CanonicalExpeditionAuthority == "ExpeditionLobbyService")
check(config.Interaction.RuntimeEnabled == false)

check(config.Evidence.IdentityRows == 16)
check(config.Evidence.PropertyBackedRows == 15)
check(config.Evidence.GeneratedContainerRows == 1)
check(config.Evidence.PendingNodeRows == 0)
check(config.Evidence.KnownVisualPropertyOmissions == 3)
check(config.Evidence.PropertyBackedRows + config.Evidence.GeneratedContainerRows == config.Evidence.IdentityRows)

check(#config.Parts == 5)
check(#config.Posts.Instances == 4)
check(#config.PointLights == 1)
check(#config.SurfaceGuis == 1)
check(#config.BillboardGuis == 1)
check(#config.TextLabels == 3)
check(#config.KnownVisualPropertyOmissions == 3)
check(5 + 4 + 1 + 1 + 1 + 3 == config.Evidence.PropertyBackedRows)

local partsByName = {}
for _, definition in config.Parts do
	partsByName[definition.name] = definition
	check(definition.rotationId == 2)
	check(definition.flags.Anchored == true)
	check(definition.flags.CanQuery == true)
	check(definition.flags.CanTouch == true)
	check(definition.flags.CastShadow == true)
end

local floor = partsByName.StallFloor
checkVector(floor.position, 0.0, 0.5, -38.0, "StallFloor.position")
checkVector(floor.size, 8.0, 1.0, 6.0, "StallFloor.size")
check(floor.materialEnumValue == 528)
check(floor.colorBytes.r == 80 and floor.colorBytes.g == 60 and floor.colorBytes.b == 30)

local canopy = partsByName.Canopy
checkVector(canopy.position, 0.0, 8.0, -38.0, "Canopy.position")
checkVector(canopy.size, 8.0, 0.5, 6.0, "Canopy.size")
check(canopy.materialEnumValue == 1312)

local sign = partsByName.Sign
checkVector(sign.position, 0.0, 9.0, -38.0, "Sign.position")
check(sign.transparency == 1.0)
check(sign.canCollide == false)

local board = partsByName.Board
checkVector(board.position, 0.0, 3.5, -38.0, "Board.position")
checkVector(board.size, 4.0, 3.0, 0.30000001192092896, "Board.size")
check(board.materialEnumValue == 528)

checkVector(config.Posts.Appearance.size, 0.5, 7.0, 0.5, "Posts.Appearance.size")
check(config.Posts.Appearance.materialEnumValue == 512)
local expectedPostPositions = {
	{ -3.5, 4.5, -35.5 },
	{ 3.5, 4.5, -35.5 },
	{ -3.5, 4.5, -40.5 },
	{ 3.5, 4.5, -40.5 },
}
for index, post in config.Posts.Instances do
	local expected = expectedPostPositions[index]
	check(post.sourceId == 188 + index)
	checkVector(post.position, expected[1], expected[2], expected[3], post.name .. ".position")
end

local light = config.PointLights[1]
check(light.sourceId == 187)
check(light.parent == "StallFloor")
check(light.brightness == 1.5)
check(light.range == 12.0)
check(light.enabled == true)
check(light.shadows == false)

local surface = config.SurfaceGuis[1]
check(surface.sourceId == 199)
check(surface.parent == "Board")
check(surface.canvasSize.x == 800.0 and surface.canvasSize.y == 600.0)
check(surface.faceEnumValue == 5)
check(surface.pixelsPerStud == 50.0)

local billboard = config.BillboardGuis[1]
check(billboard.sourceId == 195)
check(billboard.parent == "Sign")
check(billboard.adorneeSourceId == nil)
check(billboard.alwaysOnTop == true)
check(billboard.enabled == true)
check(billboard.maxDistance == math.huge)
check(billboard.size.x.scale == 0.0 and billboard.size.x.offset == 200)
check(billboard.size.y.scale == 0.0 and billboard.size.y.offset == 50)
checkVector(billboard.studsOffset, 0.0, 2.0, 0.0, "NPCLabel.studsOffset")

local labelsBySourceId = {}
for _, label in config.TextLabels do
	labelsBySourceId[label.sourceId] = label
	check(label.backgroundTransparency == 1.0)
	check(label.textScaled == true)
	check(label.textWrapped == true)
	check(label.visible == true)
end

local boardText = labelsBySourceId[200]
check(boardText.text == "ADVENTURER'S BOARD\n[B] to view bounties")
check(boardText.parent == "SurfaceGui")
check(boardText.size.x.scale == 1.0 and boardText.size.y.scale == 1.0)

local npcName = labelsBySourceId[196]
check(npcName.text == "Adventurer's Board")
check(npcName.parent == "NPCLabel")
check(npcName.size.y.scale == 0.0 and npcName.size.y.offset == 25)

local actionHint = labelsBySourceId[197]
check(actionHint.text == "[G] Quest Board")
check(actionHint.parent == "NPCLabel")
check(actionHint.position.y.scale == 0.5 and actionHint.position.y.offset == 1)
check(actionHint.size.y.scale == 0.5 and actionHint.size.y.offset == -2)

for _, omission in config.KnownVisualPropertyOmissions do
	check(omission.propertyName == "FontFace")
	check(omission.typeId == 0x20)
	check(omission.sourceId == 196 or omission.sourceId == 197 or omission.sourceId == 200)
end
