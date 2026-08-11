--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

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

check(config.Version == "BA-011-v3-mapped-placement-parity")
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
check(config.Rules.MappedTargetPathMustMatchDedicatedProject == true)
check(config.Rules.MappedPlacementDoesNotImplyRuntimeActivation == true)

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

-- Declared placement must agree with the dedicated Main World project. This is
-- the binding that previously did not exist: `main_world.primary_route` claimed
-- a `Routes/Primary` container while the project mapped `Routes/PrimaryRoute`.
local projectSource = fs.readFile("games/living-kingdoms/main-world.project.json")
local project = serde.decode("json", projectSource)

local function nodeAtTargetPath(targetPath: string): any?
	local cursor: any = project.tree
	for segment in string.gmatch(targetPath, "[^/]+") do
		if type(cursor) ~= "table" then
			return nil
		end
		cursor = cursor[segment]
		if cursor == nil then
			return nil
		end
	end
	return cursor
end

local mappedCount = 0
for _, group in config.StreamingGroups do
	local node = nodeAtTargetPath(group.targetPath)
	if group.projectMappingStatus == config.ProjectMappingStatuses.Mapped then
		mappedCount += 1
		check(node ~= nil, `mapped group {group.id} has no node at {group.targetPath}`)
		check(config.isStreamingGroupMapped(group.id) == true, `{group.id} must read as mapped`)
	else
		check(
			group.projectMappingStatus == config.ProjectMappingStatuses.Unmapped,
			`{group.id} has an unknown mapping status`
		)
		-- An unmapped group must be genuinely absent from the place. Admitting
		-- content without updating this status would otherwise let a later scope
		-- consumer believe a family is still unrepresented.
		check(node == nil, `group {group.id} is declared Unmapped but the project maps {group.targetPath}`)
		check(config.isStreamingGroupMapped(group.id) == false, `{group.id} must read as unmapped`)
	end
end

local mappedIds = config.mappedStreamingGroupIds()
check(#mappedIds == mappedCount, "mappedStreamingGroupIds disagrees with the declared statuses")
check(mappedIds[1] == "main_world.hub_core", "hub core must be the first mapped group")
check(mappedIds[2] == "main_world.primary_route", "the bounded primary route must be the second mapped group")
check(#mappedIds == 2, "only the hub core and bounded primary route are mapped today")
check(config.isStreamingGroupMapped("main_world.not_a_group") == false, "an unknown group is never mapped")

-- The route group's container is the same one the render contract maps, so the
-- placement contract and the presentation contract cannot diverge again.
local renderConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MainWorldPrimaryRouteRenderConfig.luau"), {
		debugName = "MainWorldPrimaryRouteRenderConfig",
		injectGlobals = true,
	})()
for _, group in config.StreamingGroups do
	if group.id == renderConfig.StreamingGroupId then
		check(
			group.targetPath == renderConfig.ProjectContainerPath,
			"BA-011 target path and the route render container path must match"
		)
	end
end

-- Mapping content into the dedicated place is not activation.
check(config.RuntimeEnabled == false, "source mapping must not flip the held runtime flag")
check(renderConfig.RuntimeEnabled == false, "the mapped route render contract stays held")

print("MainWorldRepresentationConfig fixture passed")
