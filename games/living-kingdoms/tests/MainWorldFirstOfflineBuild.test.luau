--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldFirstOfflineBuild assertion failed", 2)
	end
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local modelPath = "games/living-kingdoms/assets/recovered-world/models/CentralFountain.model.json"
local projectPath = "games/living-kingdoms/main-world.project.json"
local model = serde.decode("json", fs.readFile(modelPath))
local project = serde.decode("json", fs.readFile(projectPath))
local fountain = loadConfig("RecoveredCentralFountainConfig")
local composition = loadConfig("MainWorldHubCoreCompositionConfig")
local bootstrap = loadConfig("MainWorldBootstrapAllowlistConfig")

local function flatten(node: any, path: string, output: { any })
	table.insert(output, {
		path = path,
		className = node.ClassName,
		node = node,
	})
	for _, child in node.Children or {} do
		local childPath = if path == "" then child.Name else path .. "/" .. child.Name
		flatten(child, childPath, output)
	end
end

local rows = {}
flatten(model, "", rows)
check(model.ClassName == "Model")
check(#rows == fountain.Evidence.IdentityRows, "model identity count must match checksum-pinned fountain evidence")
check(#rows == 11)

local byPath = {}
for _, row in rows do
	byPath[row.path] = row
end

check(byPath[""].className == "Model")
check(byPath.FountainBase.className == "Part")
check(byPath.FountainCenter.className == "Part")
check(byPath.FountainCrystal.className == "Part")
check(byPath.FountainWater.className == "Part")
check(byPath["FountainCrystal/CrystalGlow"].className == "PointLight")
check(byPath["FountainCrystal/PointLight"].className == "PointLight")
check(byPath["FountainWater/ParticleEmitter"].className == "ParticleEmitter")
check(byPath["FountainWater/PointLight"].className == "PointLight")
check(byPath["FountainWater/WaterParticleAttach"].className == "Attachment")
check(byPath["FountainWater/WaterParticleAttach/WaterSplash"].className == "ParticleEmitter")

local base = byPath.FountainBase.node.Properties
check(base.Anchored == true and base.CanCollide == true)
check(base.CFrame[1] == 0.0 and base.CFrame[2] == 19.00001335144043 and base.CFrame[3] == 5.0)
check(base.Size[1] == 40.0 and base.Size[2] == 2.0 and base.Size[3] == 40.0)
check(base.Material.Enum == 784)
check(base.Shape.Enum == 1)

local crystal = byPath.FountainCrystal.node.Properties
check(crystal.CFrame[1] == 0.0 and crystal.CFrame[2] == 53.00000762939453 and crystal.CFrame[3] == 5.0)
check(crystal.CFrame[4] == 0.6830126643180847)
check(crystal.CFrame[12] == 0.6830126643180847)
check(crystal.Material.Enum == 288)
check(crystal.Size[1] == 8.0 and crystal.Size[2] == 20.0 and crystal.Size[3] == 8.0)

local water = byPath.FountainWater.node.Properties
check(water.Material.Enum == 1568)
check(water.Transparency == 0.30000001192092896)
check(water.Size[1] == 36.0 and water.Size[2] == 1.0 and water.Size[3] == 36.0)

local splash = byPath["FountainWater/WaterParticleAttach/WaterSplash"].node.Properties
check(splash.Texture == "rbxassetid://241876674")
check(splash.Rate == 30.0)
check(splash.Acceleration[2] == -8.0)
check(splash.Lifetime[1] == 1.0 and splash.Lifetime[2] == 2.0)

check(project.name == "LivingKingdomsMainWorld")
check(project.placeId == nil and project.gameId == nil and project.servePlaceIds == nil)
check(
	project.tree.Workspace.LivingKingdomsMainWorld.HubCore.Civic.CentralFountain["$path"]
		== "assets/recovered-world/models/CentralFountain.model.json"
)
check(project.tree.ReplicatedStorage.Shared["$path"] == bootstrap.SharedSourceRoot:gsub("games/living%-kingdoms/", ""))
check(project.tree.ServerScriptService.MainWorldServer["$path"] == "src/main-world/server/MainWorldServer.server.luau")
check(
	project.tree.StarterPlayer.StarterPlayerScripts.MainWorldClient["$path"]
		== "src/main-world/client/MainWorldClient.client.luau"
)

local projectText = fs.readFile(projectPath)
check(string.find(projectText, "legacy%-src", 1) == nil)
check(string.find(projectText, '"src/server', 1, true) == nil)
check(string.find(projectText, '"src/client', 1, true) == nil)
check(string.find(projectText, "imports", 1, true) == nil)

local central = composition.componentById("main_world.hub_core.central_fountain")
check(central ~= nil)
check(central.sourcePath == fountain.SourcePath)
check(composition.RuntimeEnabled == false)
check(bootstrap.RuntimeEnabled == false)
