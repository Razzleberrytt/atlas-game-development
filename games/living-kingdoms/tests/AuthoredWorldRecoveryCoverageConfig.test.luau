--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "AuthoredWorldRecoveryCoverageConfig assertion failed", 2)
	end
end

local config =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/AuthoredWorldRecoveryCoverageConfig.luau"), {
		debugName = "AuthoredWorldRecoveryCoverageConfig",
		injectGlobals = true,
	})()

check(config.Version == "BA-005-RECOVERY-COVERAGE-v2")
check(config.RuntimeEnabled == false)
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceRbxlSha256 == "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16")
check(config.LatestAuthoredRevisionSha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(config.Evidence.WorkspaceIdentityRows == 1775)
check(config.Evidence.DecodedPropertyRows == 1699)
check(config.Evidence.FullPropertyArtifactCommitted == false)
check(config.Evidence.FullPropertyArtifactBytes == 1546379)
check(config.Evidence.FullPropertyArtifactSha256 == "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea")
check(config.Evidence.RecoveredSourceBundleAuthorsResourceGeometry == false)

local historical = config.SourceRevisions.HistoricalRecovery
check(historical.sourceRbxlSha256 == config.SourceRbxlSha256)
check(historical.workspaceIdentityRows == 1775)
check(historical.decodedPropertyRows == 1699)

local current = config.SourceRevisions.AuthoredRevision20260810
check(current.sourceRbxlSha256 == config.LatestAuthoredRevisionSha256)
check(current.sourceRbxlBytes == 1808699)
check(current.declaredInstances == 2342)
check(current.parsedInstances == 2342)
check(current.reviewEvidenceCommitted == true)

local recoveredModules = {
	WorldPath = "RecoveredWorldPathConfig.luau",
	DungeonPortal = "RecoveredDungeonPortalConfig.luau",
	QuestBoard = "RecoveredQuestBoardConfig.luau",
	MainWorldArrival = "RecoveredSpawnLocationConfig.luau",
	CentralFountain = "RecoveredCentralFountainConfig.luau",
	GrandStaircase = "RecoveredGrandStaircaseConfig.luau",
	HubArchway = "RecoveredHubArchwayConfig.luau",
}

for groupId, moduleFile in recoveredModules do
	local group = config.Groups[groupId]
	check(group.disposition == config.Disposition.RecoveredHeld)
	check(group.reconstructionModule ~= nil)
	check(group.newGeometryPromotionAllowed == false)
	check(fs.isFile("games/living-kingdoms/src/shared/Config/" .. moduleFile))
end

check(config.Groups.CentralFountain.evidenceRevision == "AuthoredRevision20260810")
check(config.Groups.CentralFountain.sourcePath == "Workspace/HubTown/CentralFountain")
check(config.Groups.GrandStaircase.evidenceRevision == "AuthoredRevision20260810")
check(config.Groups.GrandStaircase.sourcePath == "Workspace/HubTown/GrandStaircase")
check(config.Groups.HubArchway.evidenceRevision == "AuthoredRevision20260810")
check(config.Groups.HubArchway.sourcePath == "Workspace/HubTown/HubArchway")

for _, groupId in { "Resources", "WorldStructures" } do
	local group = config.Groups[groupId]
	check(group.disposition == config.Disposition.PartialSampleOnly)
	check(group.reconstructionModule == nil)
	check(config.canPromoteNewGeometry(groupId) == false)
end

check(config.Groups.Atmosphere.disposition == config.Disposition.HierarchyOnly)
check(config.Groups.Atmosphere.reconstructionModule == nil)
check(config.canPromoteNewGeometry("Atmosphere") == false)
check(config.canPromoteNewGeometry("Unknown") == false)
check(#config.ResumeRequirements == 3)

local worldPathConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredWorldPathConfig.luau"), {
		debugName = "RecoveredWorldPathConfig",
		injectGlobals = true,
	})()

check(worldPathConfig.Version == "BA-005-WORLDPATH-v1")
check(worldPathConfig.RuntimeEnabled == false)
check(worldPathConfig.Evidence.SegmentCount == 189)
local firstSegment = worldPathConfig.segmentCenter(1)
check(firstSegment.z == worldPathConfig.Route.StartCenter.z)
local lastSegment = worldPathConfig.segmentCenter(189)
check(math.abs(lastSegment.z - worldPathConfig.Route.EndCenter.z) < 0.0001)

local dungeonPortalConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau"), {
		debugName = "RecoveredDungeonPortalConfig",
		injectGlobals = true,
	})()

check(dungeonPortalConfig.Version == "BA-005-DUNGEON-PORTAL-v2")
check(dungeonPortalConfig.RuntimeEnabled == false)
check(dungeonPortalConfig.Interaction.LegacyGameplayAuthority == false)
check(dungeonPortalConfig.Interaction.CanonicalAuthority == "ExpeditionLobbyService")
check(#dungeonPortalConfig.Parts == 3)
check(#dungeonPortalConfig.PointLights == 2)
check(dungeonPortalConfig.Evidence.PropertyBackedRows == 9)
check(dungeonPortalConfig.Evidence.IdentityRows == 10)

local fountainConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredCentralFountainConfig.luau"), {
		debugName = "RecoveredCentralFountainConfig",
		injectGlobals = true,
	})()

check(fountainConfig.RuntimeEnabled == false)
check(fountainConfig.SourceHold == true)
check(fountainConfig.Evidence.SourceRbxlSha256 == config.LatestAuthoredRevisionSha256)
check(fountainConfig.Evidence.IdentityRows == 11)
check(fountainConfig.Evidence.PropertyBackedRows == 10)

local staircaseConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredGrandStaircaseConfig.luau"), {
		debugName = "RecoveredGrandStaircaseConfig",
		injectGlobals = true,
	})()

check(staircaseConfig.RuntimeEnabled == false)
check(staircaseConfig.SourceHold == true)
check(staircaseConfig.Evidence.SourceRbxlSha256 == config.LatestAuthoredRevisionSha256)
check(staircaseConfig.Evidence.IdentityRows == 35)
check(staircaseConfig.Evidence.PropertyBackedRows == 35)

local archwayConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredHubArchwayConfig.luau"), {
	debugName = "RecoveredHubArchwayConfig",
	injectGlobals = true,
})()

check(archwayConfig.RuntimeEnabled == false)
check(archwayConfig.SourceHold == true)
check(archwayConfig.Evidence.SourceRbxlSha256 == config.LatestAuthoredRevisionSha256)
check(archwayConfig.Evidence.IdentityRows == 6)
check(archwayConfig.Evidence.PropertyBackedRows == 5)
check(archwayConfig.Evidence.GeneratedContainerRows == 1)
