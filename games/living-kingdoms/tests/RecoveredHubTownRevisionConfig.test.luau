--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredHubTownRevisionConfig assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredHubTownRevisionConfig.luau"), {
	debugName = "RecoveredHubTownRevisionConfig",
	injectGlobals = true,
})()

check(config.Version == "RBXL-HUB-CENTRAL-FOUNTAIN-2026-08-10-v1")
check(config.Source.Sha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(config.Source.SizeBytes == 1808699)
check(config.Source.SourcePath == "Workspace/HubTown/CentralFountain")
check(config.Source.SourceId == 270)
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.Authority.GameplayCodeCanonicalSource == "games/living-kingdoms/src")
check(config.Authority.EmbeddedPlaceGameplayCodeCanonical == false)
check(config.Authority.LegacyGameplayAuthorityEnabled == false)
check(config.Evidence.PreservedInstanceRows == 11)
check(config.Evidence.FullSupportedPropertyRowsCommitted == true)
check(#config.Instances == 11)

local bySourceId = {}
for _, definition in config.Instances do
	check(bySourceId[definition.sourceId] == nil, "duplicate source id")
	bySourceId[definition.sourceId] = definition
end

check(bySourceId[270].properties.Name == "CentralFountain")
check(bySourceId[271].properties.Name == "FountainBase")
check(bySourceId[271].properties.size[1] == 40.0)
check(bySourceId[271].properties.size[2] == 2.0)
check(bySourceId[271].properties.size[3] == 40.0)
check(bySourceId[272].properties.size[1] == 36.0)
check(bySourceId[274].properties.Acceleration[2] == 0.0)
check(bySourceId[275].parentSourceId == 272)
check(bySourceId[277].properties.size[2] == 30.0)
check(bySourceId[278].properties.Name == "FountainCrystal")
check(bySourceId[278].properties.Material == 288)
check(bySourceId[278].properties.size[2] == 20.0)
check(bySourceId[279].properties.Range == 80.0)
check(bySourceId[280].properties.Range == 20.0)
