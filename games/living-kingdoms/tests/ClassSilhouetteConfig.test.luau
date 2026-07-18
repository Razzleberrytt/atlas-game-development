--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassContracts.luau"), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Visual/ClassSilhouetteConfig.luau"), {
	debugName = "ClassSilhouetteConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Classes = { ClassContracts = CONTRACTS_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected class silhouette dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local knownShapes = { Block = true, Cylinder = true, Ball = true }
local knownMaterials = { Metal = true, SmoothPlastic = true }
local knownPalettes = {
	BaseArmor = true,
	BaseTrim = true,
	Specialist = true,
	Medic = true,
	Engineer = true,
	Signal = true,
}

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validatePart(part: any, seenNames: { [string]: boolean })
	assertThat(type(part.name) == "string" and part.name ~= "", "silhouette parts require stable names")
	assertThat(not seenNames[part.name], "silhouette part names must be unique within one operative kit")
	seenNames[part.name] = true
	assertThat(knownShapes[part.shapeId] == true, "unknown silhouette shape")
	assertThat(knownMaterials[part.materialId] == true, "unknown silhouette material")
	assertThat(knownPalettes[part.paletteId] == true, "unknown silhouette palette")
	for _, vector in { part.size, part.offset, part.rotationDegrees } do
		assertThat(
			isFinite(vector.x) and isFinite(vector.y) and isFinite(vector.z),
			"silhouette vectors must be finite"
		)
	end
	assertThat(part.size.x > 0 and part.size.y > 0 and part.size.z > 0, "silhouette sizes must be positive")
end

assertThat(config.Version == "VIS-0104-v1", "silhouette config version drifted")
assertThat(config.MaximumPartsPerOperative == 10, "procedural fallback part budget drifted")
assertThat(#config.SharedParts == 4, "shared operative armor must use four parts")

local cueSet = {}
local modelNameSet = {}
for _, classId in contracts.ClassIds do
	local definition = config.DefinitionsByClassId[classId]
	assertThat(definition ~= nil and definition.classId == classId, "missing starting-class silhouette")
	assertThat(#definition.parts == 6, "each class kit must use six geometry-distinct parts")
	assertThat(not cueSet[definition.readabilityCue], "readability cues must be class-distinct")
	assertThat(not modelNameSet[definition.modelName], "class model names must be unique")
	cueSet[definition.readabilityCue] = true
	modelNameSet[definition.modelName] = true
	local seenNames = {}
	for _, part in config.SharedParts do
		validatePart(part, seenNames)
	end
	for _, part in definition.parts do
		validatePart(part, seenNames)
	end
	assertThat(#config.SharedParts + #definition.parts <= config.MaximumPartsPerOperative, "part budget exceeded")
end

local configMutationSucceeded = pcall(function()
	config.MaximumPartsPerOperative = 999
end)
assertThat(not configMutationSucceeded, "top-level silhouette config must be immutable")
local partMutationSucceeded = pcall(function()
	config.SharedParts[1].name = "mutated"
end)
assertThat(not partMutationSucceeded, "silhouette parts must be immutable")
local classMutationSucceeded = pcall(function()
	config.DefinitionsByClassId[contracts.ClassIds.Medic].parts[1].name = "mutated"
end)
assertThat(not classMutationSucceeded, "class-specific silhouette definitions must be immutable")

print("ClassSilhouetteConfig: three distinct ten-part immutable operative kits passed")
