--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredHubArchwayConfig assertion failed", 2)
	end
end

local function checkVector(actual: any, expected: { number }, label: string)
	check(math.abs(actual.x - expected[1]) <= 1e-8, label .. ".x mismatch")
	check(math.abs(actual.y - expected[2]) <= 1e-8, label .. ".y mismatch")
	check(math.abs(actual.z - expected[3]) <= 1e-8, label .. ".z mismatch")
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredHubArchwayConfig.luau"), {
	debugName = "RecoveredHubArchwayConfig",
	injectGlobals = true,
})()

check(config.Version == "P0.5-HUB-ARCHWAY-v1")
check(config.SourcePath == "Workspace/HubTown/HubArchway")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SemanticContentId == "main_world.hub_core.archway")
check(config.StreamingGroupId == "main_world.hub_core")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.HubTownSourceId == 118)
check(config.RootModelSourceId == 382)
check(config.Evidence.SourceRbxlSha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(config.Evidence.SourceRbxlBytes == 1808699)
check(config.Evidence.IdentityRows == 6)
check(config.Evidence.PropertyBackedRows == 5)
check(config.Evidence.GeneratedContainerRows == 1)
check(config.Evidence.PendingNodeRows == 0)
check(config.Evidence.EvidenceArtifactName == "hub-civic-geometry-summary.json")
check(fs.isFile("games/living-kingdoms/imports/studio-2026-08-10/" .. config.Evidence.EvidenceArtifactName))
check(#config.Parts == 4)

local partsById = {}
for _, part in config.Parts do
	partsById[part.sourceId] = part
	check(part.parentSourceId == 382)
	check(part.flags.anchored == true)
	check(part.flags.canQuery == true)
	check(part.flags.canTouch == true)
	check(part.flags.castShadow == true)
	check(part.flags.rotationId == 2)
end

local left = partsById[383]
check(left.name == "LeftPillar")
checkVector(left.position, { -8.0, 7.5, -20.0 }, "LeftPillar.position")
checkVector(left.size, { 2.0, 8.0, 2.0 }, "LeftPillar.size")
check(left.materialEnumValue == 784)
check(left.shapeEnumValue == 1)
check(left.canCollide == true)
check(left.colorBytes.r == 180 and left.colorBytes.g == 170 and left.colorBytes.b == 160)

local right = partsById[384]
check(right.name == "RightPillar")
checkVector(right.position, { 8.0, 7.5, -20.0 }, "RightPillar.position")
checkVector(right.size, { 2.0, 8.0, 2.0 }, "RightPillar.size")
check(right.materialEnumValue == 784)
check(right.canCollide == true)

local beam = partsById[385]
check(beam.name == "TopBeam")
checkVector(beam.position, { 0.0, 12.5, -20.0 }, "TopBeam.position")
checkVector(beam.size, { 20.0, 2.0, 2.0 }, "TopBeam.size")
check(beam.materialEnumValue == 784)
check(beam.colorBytes.r == 170 and beam.colorBytes.g == 160 and beam.colorBytes.b == 150)

local crystal = partsById[386]
check(crystal.name == "ArchCrystal")
checkVector(crystal.position, { 0.0, 14.5, -20.0 }, "ArchCrystal.position")
checkVector(crystal.size, { 1.5, 1.5, 1.5 }, "ArchCrystal.size")
check(crystal.materialEnumValue == 288)
check(crystal.shapeEnumValue == 0)
check(crystal.canCollide == false)
check(crystal.colorBytes.r == 100 and crystal.colorBytes.g == 200 and crystal.colorBytes.b == 255)

local light = config.PointLight
check(light.sourceId == 387)
check(light.parentSourceId == 386)
check(light.parent == "ArchCrystal")
check(light.name == "PointLight")
check(light.brightness == 2.0)
check(light.enabled == true)
check(light.range == 15.0)
check(light.shadows == false)
check(math.abs(light.color.r - 0.3921568691730499) <= 1e-8)
check(math.abs(light.color.g - 0.7843137383460999) <= 1e-8)
check(light.color.b == 1.0)
