--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then error(message or "RecoveredCentralFountainConfig assertion failed", 2) end
end

local function checkVector(actual: any, expected: { number }, label: string)
	check(actual ~= nil, label .. " is missing")
	for index, value in expected do
		local key = if index == 1 then "x" elseif index == 2 then "y" else "z"
		check(math.abs(actual[key] - value) <= 1e-8, string.format("%s.%s mismatch", label, key))
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredCentralFountainConfig.luau"), { debugName = "RecoveredCentralFountainConfig", injectGlobals = true })()

check(config.Version == "P0.5-CENTRAL-FOUNTAIN-v1")
check(config.SourcePath == "Workspace/HubTown/CentralFountain")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SemanticContentId == "main_world.hub_core.central_fountain")
check(config.StreamingGroupId == "main_world.hub_core")
check(config.SourceHold == true and config.RuntimeEnabled == false)
check(config.Evidence.SourceRbxlSha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(config.Evidence.SourceRbxlBytes == 1808699)
check(config.Evidence.IdentityRows == 11 and config.Evidence.PropertyBackedRows == 10)
check(config.Evidence.GeneratedContainerRows == 1 and config.Evidence.PendingNodeRows == 0)
check(config.Evidence.PropertyBackedRows + config.Evidence.GeneratedContainerRows == config.Evidence.IdentityRows)
check(fs.isFile(config.Evidence.EvidenceArtifact))
check(#config.Parts == 4 and #config.PointLights == 3 and #config.Attachments == 1 and #config.ParticleEmitters == 2)

local partsByName = {}
for _, definition in config.Parts do
	partsByName[definition.name] = definition
	check(definition.flags.Anchored and definition.flags.CanQuery and definition.flags.CanTouch and definition.flags.CastShadow)
end
local base = partsByName.FountainBase
check(base.sourceId == 271); checkVector(base.position, { 0.0, 19.00001335144043, 5.0 }, "FountainBase.position"); checkVector(base.size, { 40.0, 2.0, 40.0 }, "FountainBase.size"); check(base.materialEnumValue == 784); check(base.colorBytes.r == 180 and base.colorBytes.g == 175 and base.colorBytes.b == 165)
local center = partsByName.FountainCenter
check(center.sourceId == 277); checkVector(center.position, { 0.0, 34.00001525878906, 5.0 }, "FountainCenter.position"); check(center.materialEnumValue == 1072); check(math.abs(center.reflectance - 0.4000000059604645) <= 1e-8)
local crystal = partsByName.FountainCrystal
check(crystal.sourceId == 278 and crystal.rotationId == 0 and #crystal.rotationMatrix == 9); check(math.abs(crystal.rotationMatrix[1] - 0.6830126643180847) <= 1e-8); checkVector(crystal.position, { 0.0, 53.00000762939453, 5.0 }, "FountainCrystal.position")
local water = partsByName.FountainWater
check(water.sourceId == 272); checkVector(water.size, { 36.0, 1.0, 36.0 }, "FountainWater.size"); check(water.materialEnumValue == 1568); check(math.abs(water.transparency - 0.30000001192092896) <= 1e-8)

local lightsByKey = {}
for _, definition in config.PointLights do lightsByKey[definition.parent .. "/" .. definition.name] = definition end
check(lightsByKey["FountainCrystal/CrystalGlow"].sourceId == 280 and lightsByKey["FountainCrystal/CrystalGlow"].range == 20.0)
check(lightsByKey["FountainCrystal/PointLight"].sourceId == 279 and lightsByKey["FountainCrystal/PointLight"].range == 80.0)
check(lightsByKey["FountainWater/PointLight"].sourceId == 273 and lightsByKey["FountainWater/PointLight"].brightness == 2.0 and lightsByKey["FountainWater/PointLight"].range == 40.0)

local attachment = config.Attachments[1]
check(attachment.name == "WaterParticleAttach" and attachment.sourceId == 275 and attachment.parent == "FountainWater" and attachment.rotationId == 2 and attachment.visible == false)
checkVector(attachment.position, { 0.0, 0.0, 0.0 }, "WaterParticleAttach.position")

local emittersByName = {}
for _, definition in config.ParticleEmitters do emittersByName[definition.name] = definition end
local mist = emittersByName.ParticleEmitter
check(mist.sourceId == 274 and mist.parent == "FountainWater" and mist.texture == "rbxassetid://243660364" and mist.rate == 50.0)
check(mist.lifetime.min == 2.0 and mist.lifetime.max == 4.0 and mist.speed.min == 5.0 and mist.speed.max == 10.0)
local splash = emittersByName.WaterSplash
check(splash.sourceId == 276 and splash.parent == "WaterParticleAttach" and splash.texture == "rbxassetid://241876674" and splash.rate == 30.0)
check(splash.lifetime.min == 1.0 and splash.lifetime.max == 2.0 and splash.speed.min == 2.0 and splash.speed.max == 4.0)
checkVector(splash.acceleration, { 0.0, -8.0, 0.0 }, "WaterSplash.acceleration")
