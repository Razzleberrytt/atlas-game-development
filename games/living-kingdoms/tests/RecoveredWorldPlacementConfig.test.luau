--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredWorldPlacementConfig assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredWorldPlacementConfig.luau"), {
	debugName = "RecoveredWorldPlacementConfig",
	injectGlobals = true,
})()

check(config.Version == "BA-005-PLACEMENT-v1")
check(config.PolicyId == "separate-authored-overworld")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.AuthoredOverworld.PreserveAbsoluteCoordinates == true)
check(config.AuthoredOverworld.UniformScale == 1.0)
check(config.ModernOperation.PlayableHalfExtentStuds == 640)
check(config.ModernOperation.RelationshipToAuthoredOverworld == "separate-runtime-space")
check(config.Transition.DedicatedOverworldLifecycleRequired == true)
check(config.Transition.RuntimeEnabled == false)
check(config.Rules.NeverScaleAuthoredWorldToFitOperation == true)
check(config.Rules.NeverTranslateAuthoredWorldToFitOperation == true)
check(config.Rules.NeverParentRecoveredWorldUnderOperationFoundation == true)
check(config.Rules.LegacyHubTownIsPresentationContentNotGameplayAuthority == true)
check(config.Rules.ForwardOperationsHubIsTemporaryBridge == true)

for _, path in
	{
		"Workspace/HubTown",
		"Workspace/HubTown/DungeonPortal/PortalFrame",
		"Workspace/Resources/IronOre/IronOre_1/OreRock",
		"Workspace/WorldPath/PathSegment_189",
		"Workspace/WorldStructures/DestinyMonolith/CoreTower",
		"Workspace/SpawnLocation",
		"Workspace/AmbientFireflies/Attachment",
		"Workspace/WorldClouds/CloudEmitter",
	}
do
	check(config.coordinateSpaceForPath(path) == "authored-overworld", "unexpected coordinate space for " .. path)
end

check(config.coordinateSpaceForPath("Workspace/LivingKingdomsWorld/Landmarks/RangerStation") == nil)
check(config.coordinateSpaceForPath("Workspace/BootstrapSafetyFloor") == nil)

local monolith = config.authoredPointToCanonical({ x = 0.0, y = 200.0, z = -1500.0 })
check(monolith.x == 0.0)
check(monolith.y == 200.0)
check(monolith.z == -1500.0)

local tower = config.authoredPointToCanonical({ x = 1500.0, y = 15.0, z = 0.0 })
check(tower.x == 1500.0)
check(tower.y == 15.0)
check(tower.z == 0.0)

local bounds = config.AuthoredOverworld.RecoveredBounds
check(bounds.min.x < -1800)
check(bounds.min.z < -3100)
check(bounds.max.x > 2800)
check(bounds.max.y == 1400.0)
check(bounds.max.z > 1800)
