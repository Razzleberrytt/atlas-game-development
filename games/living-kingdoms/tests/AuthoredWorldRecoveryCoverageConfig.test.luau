--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then error(message or "AuthoredWorldRecoveryCoverageConfig assertion failed", 2) end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/AuthoredWorldRecoveryCoverageConfig.luau"), { debugName = "AuthoredWorldRecoveryCoverageConfig", injectGlobals = true })()

check(config.Version == "BA-005-RECOVERY-COVERAGE-v2")
check(config.RuntimeEnabled == false)
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceRbxlSha256 == "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16")
check(config.LatestAuthoredRevisionSha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(config.Evidence.WorkspaceIdentityRows == 1775 and config.Evidence.DecodedPropertyRows == 1699)
check(config.Evidence.FullPropertyArtifactCommitted == false and config.Evidence.FullPropertyArtifactBytes == 1546379)
check(config.Evidence.FullPropertyArtifactSha256 == "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea")
check(config.Evidence.RecoveredSourceBundleAuthorsResourceGeometry == false)

local historical = config.SourceRevisions.HistoricalRecovery
check(historical.sourceRbxlSha256 == config.SourceRbxlSha256)
check(historical.workspaceIdentityRows == 1775 and historical.decodedPropertyRows == 1699)
local current = config.SourceRevisions.AuthoredRevision20260810
check(current.sourceRbxlSha256 == config.LatestAuthoredRevisionSha256)
check(current.sourceRbxlBytes == 1808699 and current.declaredInstances == 2342 and current.parsedInstances == 2342)
check(current.reviewEvidenceCommitted == true)

local recoveredModules = {
	WorldPath = "RecoveredWorldPathConfig.luau",
	DungeonPortal = "RecoveredDungeonPortalConfig.luau",
	QuestBoard = "RecoveredQuestBoardConfig.luau",
	MainWorldArrival = "RecoveredSpawnLocationConfig.luau",
	CentralFountain = "RecoveredCentralFountainConfig.luau",
}
for groupId, moduleFile in recoveredModules do
	local group = config.Groups[groupId]
	check(group.disposition == config.Disposition.RecoveredHeld)
	check(group.reconstructionModule ~= nil and group.newGeometryPromotionAllowed == false)
	check(fs.isFile("games/living-kingdoms/src/shared/Config/" .. moduleFile))
end
check(config.Groups.CentralFountain.evidenceRevision == "AuthoredRevision20260810")
check(config.Groups.CentralFountain.sourcePath == "Workspace/HubTown/CentralFountain")

for _, groupId in { "Resources", "WorldStructures" } do
	local group = config.Groups[groupId]
	check(group.disposition == config.Disposition.PartialSampleOnly and group.reconstructionModule == nil)
	check(config.canPromoteNewGeometry(groupId) == false)
end
check(config.Groups.Atmosphere.disposition == config.Disposition.HierarchyOnly and config.Groups.Atmosphere.reconstructionModule == nil)
check(config.canPromoteNewGeometry("Atmosphere") == false and config.canPromoteNewGeometry("Unknown") == false)
check(#config.ResumeRequirements == 3)

local worldPathConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredWorldPathConfig.luau"), { debugName = "RecoveredWorldPathConfig", injectGlobals = true })()
check(worldPathConfig.Version == "BA-005-WORLDPATH-v1" and worldPathConfig.RuntimeEnabled == false and worldPathConfig.Evidence.SegmentCount == 189)
local firstSegment = worldPathConfig.segmentCenter(1); check(firstSegment.z == worldPathConfig.Route.StartCenter.z)
local lastSegment = worldPathConfig.segmentCenter(189); check(math.abs(lastSegment.z - worldPathConfig.Route.EndCenter.z) < 0.0001)

local dungeonPortalConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau"), { debugName = "RecoveredDungeonPortalConfig", injectGlobals = true })()
check(dungeonPortalConfig.Version == "BA-005-DUNGEON-PORTAL-v2" and dungeonPortalConfig.RuntimeEnabled == false)
check(dungeonPortalConfig.Interaction.LegacyGameplayAuthority == false and dungeonPortalConfig.Interaction.CanonicalAuthority == "ExpeditionLobbyService")
check(#dungeonPortalConfig.Parts == 3 and #dungeonPortalConfig.PointLights == 2)
check(dungeonPortalConfig.Evidence.PropertyBackedRows == 9 and dungeonPortalConfig.Evidence.IdentityRows == 10)

local fountainConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredCentralFountainConfig.luau"), { debugName = "RecoveredCentralFountainConfig", injectGlobals = true })()
check(fountainConfig.RuntimeEnabled == false and fountainConfig.SourceHold == true)
check(fountainConfig.Evidence.SourceRbxlSha256 == config.LatestAuthoredRevisionSha256)
check(fountainConfig.Evidence.IdentityRows == 11 and fountainConfig.Evidence.PropertyBackedRows == 10)
