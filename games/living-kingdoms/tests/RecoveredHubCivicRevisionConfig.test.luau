--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "Recovered Hub civic revision assertion failed", 2)
	end
end

local function loadConfig(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local staircase = loadConfig(
	"games/living-kingdoms/src/shared/Config/RecoveredGrandStaircaseConfig.luau",
	"RecoveredGrandStaircaseConfig"
)
local archway = loadConfig(
	"games/living-kingdoms/src/shared/Config/RecoveredHubArchwayConfig.luau",
	"RecoveredHubArchwayConfig"
)

local expectedSha = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b"

check(staircase.Version == "P0.5-GRAND-STAIRCASE-v1")
check(staircase.SourceHold == true)
check(staircase.RuntimeEnabled == false)
check(staircase.Evidence.SourceRbxlSha256 == expectedSha)
check(staircase.Evidence.IdentityRows == 35)
check(staircase.Evidence.PropertyBackedRows == 34)
check(#staircase.Parts == 24)
check(#staircase.PointLights == 10)

check(staircase.Parts[1].name == "Step1")
check(staircase.Parts[1].sourceId == 230)
check(staircase.Parts[1].size.x == 80.0)
check(staircase.Parts[1].position.y == 57.295631408691406)
check(staircase.Parts[10].name == "Step10")
check(staircase.Parts[10].sourceId == 239)
check(staircase.Parts[10].position.y == 75.29562377929688)
check(staircase.Parts[11].name == "Rail-1")
check(staircase.Parts[11].size.x == 5.0)
check(staircase.Parts[11].size.y == 25.0)
check(staircase.Parts[11].size.z == 85.0)
check(staircase.Parts[12].name == "RailGlow-1")
check(staircase.Parts[12].materialEnumValue == 784)
check(staircase.Parts[12].canCollide == true)
check(staircase.Parts[15].name == "Lantern_L_2")
check(staircase.Parts[15].sourceId == 244)
check(staircase.Parts[24].sourceId == 262)
check(staircase.PointLights[1].sourceId == 245)
check(staircase.PointLights[10].sourceId == 263)
check(staircase.PointLights[1].range == 12.0)

check(archway.Version == "P0.5-HUB-ARCHWAY-v1")
check(archway.SourceHold == true)
check(archway.RuntimeEnabled == false)
check(archway.Evidence.SourceRbxlSha256 == expectedSha)
check(archway.Evidence.IdentityRows == 6)
check(archway.Evidence.PropertyBackedRows == 5)
check(#archway.Parts == 4)
check(#archway.PointLights == 1)
check(archway.Parts[1].name == "LeftPillar")
check(archway.Parts[1].position.x == -8.0)
check(archway.Parts[2].position.x == 8.0)
check(archway.Parts[3].name == "TopBeam")
check(archway.Parts[3].size.x == 20.0)
check(archway.Parts[4].name == "ArchCrystal")
check(archway.Parts[4].materialEnumValue == 288)
check(archway.Parts[4].shapeEnumValue == 0)
check(archway.Parts[4].canCollide == false)
check(archway.PointLights[1].sourceId == 387)
check(archway.PointLights[1].range == 15.0)
