--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldRepresentationConfig assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MainWorldRepresentationConfig.luau"), {
	debugName = "MainWorldRepresentationConfig",
	injectGlobals = true,
})()

local recoveredArrival =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredSpawnLocationConfig.luau"), {
		debugName = "RecoveredSpawnLocationConfig",
		injectGlobals = true,
	})()

check(config.Version == "BA-011-v2-arrival-contract-link")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.PlaceBoundary.Strategy == "dedicated-main-world-place")
check(config.PlaceBoundary.CurrentOperationProject == "games/living-kingdoms/default.project.json")
check(config.PlaceBoundary.MainWorldPlaceIdStatus == "unassigned")
check(config.Root.Name == "LivingKingdomsMainWorld")
check(config.Root.MayDescendFromOperationRoot == false)
check(config.Anchors.Arrival.contentId == "spawn.main_world.arrival")
check(config.Anchors.Arrival.sourcePath == "Workspace/SpawnLocation")
check(config.Anchors.Arrival.coordinateSpaceId == "authored-overworld")
check(config.Anchors.Arrival.sourceContractModule == "RecoveredSpawnLocationConfig")
check(config.Anchors.Arrival.sourceContractVersion == recoveredArrival.Version)
check(config.Anchors.Arrival.contentId == recoveredArrival.SourceContentId)
check(config.Anchors.Arrival.sourcePath == recoveredArrival.SourcePath)
check(config.Anchors.Arrival.coordinateSpaceId == recoveredArrival.CoordinateSpaceId)
check(config.Anchors.Arrival.position.x == recoveredArrival.Spawn.position.x)
check(config.Anchors.Arrival.position.y == recoveredArrival.Spawn.position.y)
check(config.Anchors.Arrival.position.z == recoveredArrival.Spawn.position.z)
check(config.Anchors.Arrival.propertyEvidenceStatus == "complete-selected-instance")
check(config.Anchors.Arrival.status == "evidence-backed-held")
check(recoveredArrival.SourceHold == true)
check(recoveredArrival.RuntimeEnabled == false)
check(recoveredArrival.Ownership.PlayerMovementAuthority == false)
check(recoveredArrival.Ownership.TeleportAuthority == false)
check(config.Anchors.Return.contentId == "spawn.main_world.return")
check(config.Anchors.Return.positionStatus == "unassigned-pending-return-flow-composition")
check(config.Rules.PreserveAuthoredCoordinatesOneToOne == true)
check(config.Rules.DoNotMapHeldContentIntoOperationProject == true)
check(config.Rules.DoNotCreateOneAtomicModelForEntireWorld == true)
check(config.Rules.StreamOutNeverMeansGameplayCompletion == true)
check(config.Rules.LegacyServicesRemainInert == true)

local expectedGroups = {
	["main_world.hub_core"] = true,
	["main_world.primary_route"] = true,
	["main_world.resources"] = true,
	["main_world.structures"] = true,
	["main_world.atmosphere"] = true,
}

for _, group in config.StreamingGroups do
	check(expectedGroups[group.id] == true, "unexpected streaming group " .. group.id)
	expectedGroups[group.id] = nil
	check(string.sub(group.targetPath, 1, #"Workspace/LivingKingdomsMainWorld") == "Workspace/LivingKingdomsMainWorld")
end

check(next(expectedGroups) == nil, "one or more streaming groups are missing")
check(config.streamingGroupForSourcePath("Workspace/HubTown/DungeonPortal").id == "main_world.hub_core")
check(config.streamingGroupForSourcePath("Workspace/WorldPath/PathSegment_189").id == "main_world.primary_route")
check(config.streamingGroupForSourcePath("Workspace/Resources/IronOre").id == "main_world.resources")
check(config.streamingGroupForSourcePath("Workspace/WorldStructures/DestinyMonolith").id == "main_world.structures")
check(config.streamingGroupForSourcePath("Workspace/WorldClouds/CloudEmitter").id == "main_world.atmosphere")
check(config.streamingGroupForSourcePath("Workspace/LivingKingdomsWorld") == nil)
