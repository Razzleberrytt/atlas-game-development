--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredHubArrivalCivicConfig assertion failed", 2)
	end
end

local function checkVector(actual: any, expected: { number }, label: string)
	check(actual ~= nil, label .. " is missing")
	for index, value in expected do
		local key = if index == 1 then "x" elseif index == 2 then "y" else "z"
		check(math.abs(actual[key] - value) <= 1e-8, string.format("%s.%s mismatch", label, key))
	end
end

local staircase =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredGrandStaircaseConfig.luau"), {
		debugName = "RecoveredGrandStaircaseConfig",
		injectGlobals = true,
	})()

check(staircase.Version == "P0.5-GRAND-STAIRCASE-v1")
check(staircase.SourcePath == "Workspace/HubTown/GrandStaircase")
check(staircase.CoordinateSpaceId == "authored-overworld")
check(staircase.SourceHold == true)
check(staircase.RuntimeEnabled == false)
check(staircase.Evidence.SourceRbxlSha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(staircase.Evidence.SourceRbxlBytes == 1808699)
check(staircase.Evidence.IdentityRows == 35)
check(staircase.Evidence.PropertyBackedRows == 34)
check(staircase.Evidence.GeneratedContainerRows == 1)
check(staircase.Evidence.PendingNodeRows == 0)
check(staircase.Evidence.ReviewUnitId == "grand-staircase.review")
check(staircase.Evidence.PropertyBackedRows + staircase.Evidence.GeneratedContainerRows == staircase.Evidence.IdentityRows)

check(staircase.StepProperties.anchored == true)
check(staircase.StepProperties.canCollide == true)
check(staircase.StepProperties.canQuery == true)
check(staircase.StepProperties.canTouch == true)
check(staircase.StepProperties.castShadow == true)
check(staircase.StepProperties.materialEnumValue == 784)
check(staircase.StepProperties.colorBytes.r == 160)
check(staircase.StepProperties.colorBytes.g == 155)
check(staircase.StepProperties.colorBytes.b == 145)
checkVector(staircase.StepSize, { 80.0, 2.0, 8.0 }, "StepSize")

local expectedStepY = {
	57.295631408691406,
	59.295631408691406,
	61.295631408691406,
	63.295631408691406,
	65.2956314086914,
	67.2956314086914,
	69.2956314086914,
	71.29562377929688,
	73.29562377929688,
	75.29562377929688,
}
local expectedStepZ = { -27.75, -19.75, -11.75, -3.75, 4.25, 12.25, 20.25, 28.25, 36.25, 44.25 }
check(#staircase.Steps == 10)
for index, step in staircase.Steps do
	check(step.sourceId == 229 + index)
	check(step.name == "Step" .. tostring(index))
	checkVector(step.position, { 0.0, expectedStepY[index], expectedStepZ[index] }, step.name .. ".position")
end

local expectedRails = {
	{ 240, "Rail-1", -42.0, 66.2956314086914, 4.25, 5.0, 25.0, 85.0 },
	{ 241, "RailGlow-1", -42.0, 78.29562377929688, 4.25, 2.0, 3.0, 85.0 },
	{ 242, "Rail1", 42.0, 66.2956314086914, 4.25, 5.0, 25.0, 85.0 },
	{ 243, "RailGlow1", 42.0, 78.29562377929688, 4.25, 2.0, 3.0, 85.0 },
}
check(#staircase.Rails == 4)
check(staircase.RailProperties.materialEnumValue == 784)
check(staircase.RailProperties.canCollide == true)
for index, rail in staircase.Rails do
	local expected = expectedRails[index]
	check(rail.sourceId == expected[1])
	check(rail.name == expected[2])
	checkVector(rail.position, { expected[3], expected[4], expected[5] }, rail.name .. ".position")
	checkVector(rail.size, { expected[6], expected[7], expected[8] }, rail.name .. ".size")
end

local expectedLanterns = {
	{ 244, 245, "Lantern_L_2", -3.0, 60.295631408691406, -19.75 },
	{ 246, 247, "Lantern_R_2", 3.0, 60.295631408691406, -19.75 },
	{ 248, 249, "Lantern_L_4", -3.0, 64.2956314086914, -3.75 },
	{ 250, 251, "Lantern_R_4", 3.0, 64.2956314086914, -3.75 },
	{ 252, 253, "Lantern_L_6", -3.0, 68.2956314086914, 12.25 },
	{ 254, 255, "Lantern_R_6", 3.0, 68.2956314086914, 12.25 },
	{ 256, 257, "Lantern_L_8", -3.0, 72.29562377929688, 28.25 },
	{ 258, 259, "Lantern_R_8", 3.0, 72.29562377929688, 28.25 },
	{ 260, 261, "Lantern_L_10", -3.0, 76.29562377929688, 44.25 },
	{ 262, 263, "Lantern_R_10", 3.0, 76.29562377929688, 44.25 },
}
check(#staircase.Lanterns == 10)
check(staircase.LanternProperties.materialEnumValue == 288)
check(staircase.LanternProperties.canCollide == true)
checkVector(staircase.LanternProperties.size, { 0.5, 1.5, 0.5 }, "LanternProperties.size")
check(staircase.LanternLightProperties.brightness == 2.0)
check(staircase.LanternLightProperties.range == 12.0)
check(staircase.LanternLightProperties.enabled == true)
check(staircase.LanternLightProperties.shadows == false)
for index, lantern in staircase.Lanterns do
	local expected = expectedLanterns[index]
	check(lantern.sourceId == expected[1])
	check(lantern.lightSourceId == expected[2])
	check(lantern.name == expected[3])
	checkVector(lantern.position, { expected[4], expected[5], expected[6] }, lantern.name .. ".position")
end

local archway = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredHubArchwayConfig.luau"), {
	debugName = "RecoveredHubArchwayConfig",
	injectGlobals = true,
})()

check(archway.Version == "P0.5-HUB-ARCHWAY-v1")
check(archway.SourcePath == "Workspace/HubTown/HubArchway")
check(archway.CoordinateSpaceId == "authored-overworld")
check(archway.SourceHold == true)
check(archway.RuntimeEnabled == false)
check(archway.Evidence.SourceRbxlSha256 == staircase.Evidence.SourceRbxlSha256)
check(archway.Evidence.SourceRbxlBytes == 1808699)
check(archway.Evidence.IdentityRows == 6)
check(archway.Evidence.PropertyBackedRows == 5)
check(archway.Evidence.GeneratedContainerRows == 1)
check(archway.Evidence.PendingNodeRows == 0)
check(archway.Evidence.ReviewUnitId == "hub-archway.review")
check(#archway.Parts == 4)

local partsByName = {}
for _, part in archway.Parts do
	partsByName[part.name] = part
	check(part.flags.anchored == true)
	check(part.flags.canQuery == true)
	check(part.flags.canTouch == true)
	check(part.flags.castShadow == true)
	check(part.flags.rotationId == 2)
end

local left = partsByName.LeftPillar
check(left.sourceId == 383 and left.canCollide == true and left.materialEnumValue == 784 and left.shapeEnumValue == 1)
checkVector(left.position, { -8.0, 7.5, -20.0 }, "LeftPillar.position")
checkVector(left.size, { 2.0, 8.0, 2.0 }, "LeftPillar.size")
check(left.colorBytes.r == 180 and left.colorBytes.g == 170 and left.colorBytes.b == 160)

local right = partsByName.RightPillar
check(right.sourceId == 384 and right.canCollide == true)
checkVector(right.position, { 8.0, 7.5, -20.0 }, "RightPillar.position")

local beam = partsByName.TopBeam
check(beam.sourceId == 385 and beam.materialEnumValue == 784 and beam.shapeEnumValue == 1)
checkVector(beam.position, { 0.0, 12.5, -20.0 }, "TopBeam.position")
checkVector(beam.size, { 20.0, 2.0, 2.0 }, "TopBeam.size")
check(beam.colorBytes.r == 170 and beam.colorBytes.g == 160 and beam.colorBytes.b == 150)

local crystal = partsByName.ArchCrystal
check(crystal.sourceId == 386 and crystal.canCollide == false)
check(crystal.materialEnumValue == 288 and crystal.shapeEnumValue == 0)
checkVector(crystal.position, { 0.0, 14.5, -20.0 }, "ArchCrystal.position")
checkVector(crystal.size, { 1.5, 1.5, 1.5 }, "ArchCrystal.size")
check(crystal.colorBytes.r == 100 and crystal.colorBytes.g == 200 and crystal.colorBytes.b == 255)

check(archway.PointLight.sourceId == 387)
check(archway.PointLight.parent == "ArchCrystal")
check(archway.PointLight.brightness == 2.0)
check(archway.PointLight.range == 15.0)
check(archway.PointLight.enabled == true)
check(archway.PointLight.shadows == false)
