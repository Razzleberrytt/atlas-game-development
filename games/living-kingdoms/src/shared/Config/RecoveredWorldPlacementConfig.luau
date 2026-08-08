--!strict

-- BA-005 placement policy for recovered Studio-authored world content.
--
-- The original authored world and the current operation forest are separate
-- coordinate spaces. Recovered content must not be scaled or translated into
-- the operation map merely to make it fit. This contract is inert until a
-- dedicated overworld lifecycle/place boundary is implemented.

local Config = {
	Version = "BA-005-PLACEMENT-v1",
	PolicyId = "separate-authored-overworld",
	SourceHold = true,
	RuntimeEnabled = false,
	AuthoredOverworld = table.freeze({
		CoordinateSpaceId = "authored-overworld",
		PreserveAbsoluteCoordinates = true,
		UniformScale = 1.0,
		Translation = table.freeze({ x = 0.0, y = 0.0, z = 0.0 }),
		RotationDegrees = table.freeze({ x = 0.0, y = 0.0, z = 0.0 }),
		SourceRoots = table.freeze({
			"Workspace/HubTown",
			"Workspace/Resources",
			"Workspace/WorldPath",
			"Workspace/WorldStructures",
			"Workspace/SpawnLocation",
			"Workspace/AmbientFireflies",
			"Workspace/WorldClouds",
		}),
		RecoveredBounds = table.freeze({
			min = table.freeze({ x = -1844.2164306640625, y = 0.0, z = -3184.34619140625 }),
			max = table.freeze({ x = 2831.502685546875, y = 1400.0, z = 1899.7440185546875 }),
		}),
	}),
	ModernOperation = table.freeze({
		CoordinateSpaceId = "operation-forest",
		PlayableHalfExtentStuds = 640,
		RelationshipToAuthoredOverworld = "separate-runtime-space",
	}),
	Transition = table.freeze({
		Intent = "overworld-to-expedition",
		CanonicalAuthority = "ExpeditionLobbyService",
		DedicatedOverworldLifecycleRequired = true,
		RuntimeEnabled = false,
	}),
	Rules = table.freeze({
		NeverScaleAuthoredWorldToFitOperation = true,
		NeverTranslateAuthoredWorldToFitOperation = true,
		NeverParentRecoveredWorldUnderOperationFoundation = true,
		LegacyHubTownIsPresentationContentNotGameplayAuthority = true,
		ForwardOperationsHubIsTemporaryBridge = true,
	}),
}

function Config.coordinateSpaceForPath(path: string): string?
	for _, rootPath in Config.AuthoredOverworld.SourceRoots do
		if path == rootPath or string.sub(path, 1, #rootPath + 1) == rootPath .. "/" then
			return Config.AuthoredOverworld.CoordinateSpaceId
		end
	end
	return nil
end

function Config.authoredPointToCanonical(point: { x: number, y: number, z: number }): { x: number, y: number, z: number }
	assert(Config.AuthoredOverworld.UniformScale == 1.0, "authored overworld scale policy changed")
	local translation = Config.AuthoredOverworld.Translation
	assert(translation.x == 0 and translation.y == 0 and translation.z == 0, "authored overworld translation policy changed")
	return { x = point.x, y = point.y, z = point.z }
end

return table.freeze(Config)
