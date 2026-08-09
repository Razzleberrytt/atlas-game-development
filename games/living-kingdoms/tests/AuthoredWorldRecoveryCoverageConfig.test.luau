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

check(config.Version == "BA-005-RECOVERY-COVERAGE-v1")
check(config.RuntimeEnabled == false)
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceRbxlSha256 == "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16")
check(config.Evidence.WorkspaceIdentityRows == 1775)
check(config.Evidence.DecodedPropertyRows == 1699)
check(config.Evidence.FullPropertyArtifactCommitted == false)
check(config.Evidence.FullPropertyArtifactBytes == 1546379)
check(config.Evidence.FullPropertyArtifactSha256 == "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea")
check(config.Evidence.RecoveredSourceBundleAuthorsResourceGeometry == false)

local recoveredModules = {
	WorldPath = "RecoveredWorldPathConfig.luau",
	DungeonPortal = "RecoveredDungeonPortalConfig.luau",
	QuestBoard = "RecoveredQuestBoardConfig.luau",
	MainWorldArrival = "RecoveredSpawnLocationConfig.luau",
}

for groupId, moduleFile in recoveredModules do
	local group = config.Groups[groupId]
	check(group.disposition == config.Disposition.RecoveredHeld)
	check(group.reconstructionModule ~= nil)
	check(group.newGeometryPromotionAllowed == false)
	check(fs.isFile("games/living-kingdoms/src/shared/Config/" .. moduleFile))
end

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
