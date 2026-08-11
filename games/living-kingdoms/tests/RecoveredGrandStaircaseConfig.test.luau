--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredGrandStaircaseConfig assertion failed", 2)
	end
end

local function close(actual: number, expected: number, label: string)
	check(
		math.abs(actual - expected) <= 1e-8,
		string.format("%s mismatch: %.17g ~= %.17g", label, actual, expected)
	)
end

local function checkVector(actual: any, expected: { number }, label: string)
	close(actual.x, expected[1], label .. ".x")
	close(actual.y, expected[2], label .. ".y")
	close(actual.z, expected[3], label .. ".z")
end

local config =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredGrandStaircaseConfig.luau"), {
		debugName = "RecoveredGrandStaircaseConfig",
		injectGlobals = true,
	})()

check(config.Version == "P0.5-GRAND-STAIRCASE-v1")
check(config.SourcePath == "Workspace/HubTown/GrandStaircase")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SemanticContentId == "main_world.hub_core.grand_staircase")
check(config.StreamingGroupId == "main_world.hub_core")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.HubTownSourceId == 118)
check(config.RootModelSourceId == 229)
check(config.Evidence.SourceRbxlSha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(config.Evidence.SourceRbxlBytes == 1808699)
check(config.Evidence.IdentityRows == 35)
check(config.Evidence.PropertyBackedRows == 35)
check(config.Evidence.RootModelRows == 1)
check(config.Evidence.EvidenceArtifactName == "grand-staircase.review.json")
check(fs.isFile("games/living-kingdoms/imports/studio-2026-08-10/" .. config.Evidence.EvidenceArtifactName))
check(#config.Parts == 24)
check(#config.PointLights == 10)

local partsById = {}
for _, part in config.Parts do
	partsById[part.sourceId] = part
end

local expectedSteps = {
	{ id = 230, name = "Step1", position = { 0.0, 57.295631408691406, -27.75 } },
	{ id = 231, name = "Step2", position = { 0.0, 59.295631408691406, -19.75 } },
	{ id = 232, name = "Step3", position = { 0.0, 61.295631408691406, -11.75 } },
	{ id = 233, name = "Step4", position = { 0.0, 63.295631408691406, -3.75 } },
	{ id = 234, name = "Step5", position = { 0.0, 65.2956314086914, 4.25 } },
	{ id = 235, name = "Step6", position = { 0.0, 67.2956314086914, 12.25 } },
	{ id = 236, name = "Step7", position = { 0.0, 69.2956314086914, 20.25 } },
	{ id = 237, name = "Step8", position = { 0.0, 71.29562377929688, 28.25 } },
	{ id = 238, name = "Step9", position = { 0.0, 73.29562377929688, 36.25 } },
	{ id = 239, name = "Step10", position = { 0.0, 75.29562377929688, 44.25 } },
}

for _, expected in expectedSteps do
	local part = partsById[expected.id]
	check(part ~= nil)
	check(part.name == expected.name)
	check(part.parentSourceId == 229)
	checkVector(part.position, expected.position, expected.name .. ".position")
	checkVector(part.size, { 80.0, 2.0, 8.0 }, expected.name .. ".size")
	check(part.style.materialEnumValue == 784)
	check(part.style.colorBytes.r == 160 and part.style.colorBytes.g == 155 and part.style.colorBytes.b == 145)
	check(part.style.canCollide == true)
	check(part.style.castShadow == true)
end

local expectedRails = {
	{ id = 240, name = "Rail-1", position = { -42.0, 66.2956314086914, 4.25 }, size = { 5.0, 25.0, 85.0 } },
	{ id = 241, name = "RailGlow-1", position = { -42.0, 78.29562377929688, 4.25 }, size = { 2.0, 3.0, 85.0 } },
	{ id = 242, name = "Rail1", position = { 42.0, 66.2956314086914, 4.25 }, size = { 5.0, 25.0, 85.0 } },
	{ id = 243, name = "RailGlow1", position = { 42.0, 78.29562377929688, 4.25 }, size = { 2.0, 3.0, 85.0 } },
}

for _, expected in expectedRails do
	local part = partsById[expected.id]
	check(part ~= nil)
	check(part.name == expected.name)
	checkVector(part.position, expected.position, expected.name .. ".position")
	checkVector(part.size, expected.size, expected.name .. ".size")
	check(part.style.materialEnumValue == 784)
	check(part.style.canCollide == true)
	check(part.style.castShadow == true)
end

local expectedLanterns = {
	{ id = 244, name = "Lantern_L_2", position = { -3.0, 60.295631408691406, -19.75 } },
	{ id = 246, name = "Lantern_R_2", position = { 3.0, 60.295631408691406, -19.75 } },
	{ id = 248, name = "Lantern_L_4", position = { -3.0, 64.2956314086914, -3.75 } },
	{ id = 250, name = "Lantern_R_4", position = { 3.0, 64.2956314086914, -3.75 } },
	{ id = 252, name = "Lantern_L_6", position = { -3.0, 68.2956314086914, 12.25 } },
	{ id = 254, name = "Lantern_R_6", position = { 3.0, 68.2956314086914, 12.25 } },
	{ id = 256, name = "Lantern_L_8", position = { -3.0, 72.29562377929688, 28.25 } },
	{ id = 258, name = "Lantern_R_8", position = { 3.0, 72.29562377929688, 28.25 } },
	{ id = 260, name = "Lantern_L_10", position = { -3.0, 76.29562377929688, 44.25 } },
	{ id = 262, name = "Lantern_R_10", position = { 3.0, 76.29562377929688, 44.25 } },
}

for _, expected in expectedLanterns do
	local part = partsById[expected.id]
	check(part ~= nil)
	check(part.name == expected.name)
	checkVector(part.position, expected.position, expected.name .. ".position")
	checkVector(part.size, { 0.5, 1.5, 0.5 }, expected.name .. ".size")
	check(part.style.materialEnumValue == 288)
	check(part.style.colorBytes.r == 255 and part.style.colorBytes.g == 200 and part.style.colorBytes.b == 100)
	check(part.style.canCollide == true)
	check(part.style.castShadow == true)
end

local expectedLightParents = {
	[245] = 244,
	[247] = 246,
	[249] = 248,
	[251] = 250,
	[253] = 252,
	[255] = 254,
	[257] = 256,
	[259] = 258,
	[261] = 260,
	[263] = 262,
}

for _, light in config.PointLights do
	check(expectedLightParents[light.sourceId] == light.parentSourceId)
	check(partsById[light.parentSourceId] ~= nil)
	check(light.parent == partsById[light.parentSourceId].name)
	check(light.name == "PointLight")
	check(light.brightness == 2.0)
	check(light.enabled == true)
	check(light.range == 12.0)
	check(light.shadows == false)
	close(light.color.r, 1.0, "PointLight.color.r")
	close(light.color.g, 0.7843137383460999, "PointLight.color.g")
	close(light.color.b, 0.3921568691730499, "PointLight.color.b")
end
