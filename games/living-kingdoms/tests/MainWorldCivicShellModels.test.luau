--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldCivicShellModels assertion failed", 2)
	end
end

local function near(actual: number, expected: number, label: string)
	check(math.abs(actual - expected) <= 1e-8, label .. " mismatch")
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local function loadModel(name: string)
	return serde.decode(
		"json",
		fs.readFile("games/living-kingdoms/assets/recovered-world/models/" .. name .. ".model.json")
	)
end

local function flatten(node: any, path: string, output: { any })
	table.insert(output, { path = path, node = node })
	for _, child in node.Children or {} do
		local childPath = if path == "" then child.Name else path .. "/" .. child.Name
		flatten(child, childPath, output)
	end
end

local function rowsByPath(model: any): ({ [string]: any }, number)
	local rows = {}
	flatten(model, "", rows)
	local byPath = {}
	for _, row in rows do
		byPath[row.path] = row.node
	end
	return byPath, #rows
end

local function checkColor(properties: any, bytes: any, label: string)
	near(properties.Color[1], bytes.r / 255, label .. ".Color.r")
	near(properties.Color[2], bytes.g / 255, label .. ".Color.g")
	near(properties.Color[3], bytes.b / 255, label .. ".Color.b")
end

local function checkPart(node: any, definition: any, style: any, label: string)
	check(node ~= nil and node.ClassName == "Part", label .. " missing Part")
	local properties = node.Properties
	near(properties.CFrame[1], definition.position.x, label .. ".x")
	near(properties.CFrame[2], definition.position.y, label .. ".y")
	near(properties.CFrame[3], definition.position.z, label .. ".z")
	near(properties.Size[1], definition.size.x, label .. ".size.x")
	near(properties.Size[2], definition.size.y, label .. ".size.y")
	near(properties.Size[3], definition.size.z, label .. ".size.z")
	check(
		properties.CFrame[4] == 1 and properties.CFrame[8] == 1 and properties.CFrame[12] == 1,
		label .. " rotation drift"
	)
	check(properties.Anchored == style.anchored, label .. " Anchored drift")
	check(
		properties.CanCollide == definition.canCollide or properties.CanCollide == style.canCollide,
		label .. " CanCollide drift"
	)
	check(properties.CanQuery == style.canQuery, label .. " CanQuery drift")
	check(properties.CanTouch == style.canTouch, label .. " CanTouch drift")
	check(properties.CastShadow == style.castShadow, label .. " CastShadow drift")
	check(properties.Material.Enum == style.materialEnumValue, label .. " Material drift")
	check(properties.Shape.Enum == style.shapeEnumValue, label .. " Shape drift")
	near(properties.Reflectance, style.reflectance, label .. ".Reflectance")
	near(properties.Transparency, style.transparency, label .. ".Transparency")
	checkColor(properties, style.colorBytes, label)
end

local staircase = loadConfig("RecoveredGrandStaircaseConfig")
local staircaseModel = loadModel("GrandStaircase")
local staircaseRows, staircaseCount = rowsByPath(staircaseModel)
check(staircaseModel.ClassName == "Model")
check(staircaseCount == staircase.Evidence.IdentityRows)
check(staircaseCount == 35)

for _, definition in staircase.Parts do
	checkPart(staircaseRows[definition.name], definition, definition.style, "GrandStaircase/" .. definition.name)
end
for _, definition in staircase.PointLights do
	local node = staircaseRows[definition.parent .. "/" .. definition.name]
	check(node ~= nil and node.ClassName == "PointLight", definition.parent .. "/PointLight missing")
	local properties = node.Properties
	near(properties.Brightness, definition.brightness, definition.parent .. ".Brightness")
	near(properties.Color[1], definition.color.r, definition.parent .. ".Color.r")
	near(properties.Color[2], definition.color.g, definition.parent .. ".Color.g")
	near(properties.Color[3], definition.color.b, definition.parent .. ".Color.b")
	check(properties.Enabled == definition.enabled, definition.parent .. " Enabled drift")
	near(properties.Range, definition.range, definition.parent .. ".Range")
	check(properties.Shadows == definition.shadows, definition.parent .. " Shadows drift")
end

local archway = loadConfig("RecoveredHubArchwayConfig")
local archwayModel = loadModel("HubArchway")
local archwayRows, archwayCount = rowsByPath(archwayModel)
check(archwayModel.ClassName == "Model")
check(archwayCount == archway.Evidence.IdentityRows)
check(archwayCount == 6)

for _, definition in archway.Parts do
	local style = {
		anchored = definition.flags.anchored,
		canCollide = definition.canCollide,
		canQuery = definition.flags.canQuery,
		canTouch = definition.flags.canTouch,
		castShadow = definition.flags.castShadow,
		materialEnumValue = definition.materialEnumValue,
		shapeEnumValue = definition.shapeEnumValue,
		reflectance = definition.flags.reflectance,
		transparency = definition.flags.transparency,
		colorBytes = definition.colorBytes,
	}
	checkPart(archwayRows[definition.name], definition, style, "HubArchway/" .. definition.name)
end

local archLight = archwayRows[archway.PointLight.parent .. "/" .. archway.PointLight.name]
check(archLight ~= nil and archLight.ClassName == "PointLight")
near(archLight.Properties.Brightness, archway.PointLight.brightness, "HubArchway light Brightness")
near(archLight.Properties.Color[1], archway.PointLight.color.r, "HubArchway light Color.r")
near(archLight.Properties.Color[2], archway.PointLight.color.g, "HubArchway light Color.g")
near(archLight.Properties.Color[3], archway.PointLight.color.b, "HubArchway light Color.b")
near(archLight.Properties.Range, archway.PointLight.range, "HubArchway light Range")
check(archLight.Properties.Enabled == archway.PointLight.enabled)
check(archLight.Properties.Shadows == archway.PointLight.shadows)

local project = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
local civic = project.tree.Workspace.LivingKingdomsMainWorld.HubCore.Civic
check(civic.GrandStaircase["$path"] == "assets/recovered-world/models/GrandStaircase.model.json")
check(civic.HubArchway["$path"] == "assets/recovered-world/models/HubArchway.model.json")
check(project.placeId == nil and project.gameId == nil and project.servePlaceIds == nil)
