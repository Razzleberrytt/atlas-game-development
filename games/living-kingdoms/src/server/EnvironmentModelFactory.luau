--!strict

--[[
	Procedural, repository-owned presentation models for the Living Kingdoms
	environment asset kit. These models deliberately own no gameplay authority:
	all generated geometry is anchored and excluded from collision/touch/query.

	The semantic asset IDs come from EnvironmentAssetKitRegistry so authored meshes
	can replace these primitives later without changing placement or gameplay code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentAssetKitRegistry = require(ReplicatedStorage.Shared.Config.EnvironmentAssetKitRegistry)

local EnvironmentModelFactory = {}

local ROCK_DARK = Color3.fromRGB(77, 83, 78)
local ROCK_MID = Color3.fromRGB(96, 102, 92)
local ROCK_LIGHT = Color3.fromRGB(116, 119, 103)
local MOSS = Color3.fromRGB(72, 91, 57)
local DEAD_WOOD = Color3.fromRGB(65, 49, 40)
local DEAD_WOOD_LIGHT = Color3.fromRGB(89, 66, 49)
local CORRUPTION = Color3.fromRGB(116, 67, 136)
local TIMBER = Color3.fromRGB(83, 61, 43)
local TIMBER_LIGHT = Color3.fromRGB(111, 82, 53)
local IRON = Color3.fromRGB(65, 68, 66)
local CHARCOAL = Color3.fromRGB(38, 34, 31)
local EMBER = Color3.fromRGB(170, 74, 38)

local registryById = {}
for _, definition in EnvironmentAssetKitRegistry.Definitions do
	registryById[definition.id] = definition
end

type Builder = (Model) -> ()

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape ~= nil then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function makeBeam(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	local delta = toPosition - fromPosition
	local length = delta.Magnitude
	local midpoint = fromPosition:Lerp(toPosition, 0.5)
	return makePart(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt(midpoint, toPosition),
		color,
		material,
		nil
	)
end

local function buildFrontierBoulder(model: Model)
	makePart(
		model,
		"Core",
		Vector3.new(10.8, 6.1, 8.2),
		CFrame.new(0, 2.7, 0) * CFrame.Angles(math.rad(-8), math.rad(18), math.rad(5)),
		ROCK_MID,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	makePart(
		model,
		"Shoulder",
		Vector3.new(6.8, 4.5, 6.2),
		CFrame.new(-3.8, 2.0, 1.9) * CFrame.Angles(math.rad(12), math.rad(-24), math.rad(-7)),
		ROCK_DARK,
		Enum.Material.Rock,
		Enum.PartType.Ball
	)
	makePart(
		model,
		"Crown",
		Vector3.new(5.4, 3.3, 4.8),
		CFrame.new(2.6, 4.0, -1.4) * CFrame.Angles(math.rad(-13), math.rad(31), math.rad(9)),
		ROCK_LIGHT,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	local moss = makePart(
		model,
		"MossShelf",
		Vector3.new(5.8, 0.35, 3.5),
		CFrame.new(-0.7, 5.25, -0.15) * CFrame.Angles(math.rad(4), math.rad(14), math.rad(-3)),
		MOSS,
		Enum.Material.Grass,
		nil
	)
	moss.CastShadow = false
end

local function buildCorruptedDeadPine(model: Model)
	makePart(
		model,
		"LowerTrunk",
		Vector3.new(13.5, 2.5, 2.5),
		CFrame.new(0, 6.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		DEAD_WOOD,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"UpperTrunk",
		Vector3.new(12.2, 1.7, 1.7),
		CFrame.new(0.45, 18.6, -0.25) * CFrame.Angles(math.rad(2), math.rad(-4), math.rad(87)),
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)

	local branches = {
		{ Vector3.new(0.1, 8.4, 0), Vector3.new(-6.0, 12.0, 1.7), 0.72 },
		{ Vector3.new(0.2, 11.1, 0), Vector3.new(5.1, 14.2, -2.3), 0.65 },
		{ Vector3.new(0.35, 15.0, -0.1), Vector3.new(-4.1, 18.5, -3.5), 0.56 },
		{ Vector3.new(0.45, 18.4, -0.2), Vector3.new(3.7, 21.3, 2.4), 0.48 },
		{ Vector3.new(0.45, 21.6, -0.2), Vector3.new(-2.8, 24.0, 1.7), 0.38 },
	}
	for index, branch in branches do
		makeBeam(
			model,
			string.format("DeadBranch%02d", index),
			branch[1] :: Vector3,
			branch[2] :: Vector3,
			branch[3] :: number,
			DEAD_WOOD_LIGHT,
			Enum.Material.Wood
		)
	end

	for index, corruptionSpec in {
		{ Vector3.new(-0.85, 5.0, 0.65), Vector3.new(0.55, 2.0, 0.55), -16 },
		{ Vector3.new(0.75, 12.8, -0.65), Vector3.new(0.42, 1.55, 0.42), 21 },
		{ Vector3.new(-0.4, 18.0, 0.55), Vector3.new(0.35, 1.2, 0.35), -8 },
	} do
		local shard = makePart(
			model,
			string.format("CorruptionShard%02d", index),
			corruptionSpec[2] :: Vector3,
			CFrame.new(corruptionSpec[1] :: Vector3) * CFrame.Angles(0, 0, math.rad(corruptionSpec[3] :: number)),
			CORRUPTION,
			Enum.Material.Neon,
			nil
		)
		shard.CastShadow = false
	end
end

local function buildMineSupport(model: Model)
	makePart(
		model,
		"LeftPost",
		Vector3.new(2.1, 13.0, 2.1),
		CFrame.new(-6.0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(-2)),
		TIMBER,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(
		model,
		"RightPost",
		Vector3.new(2.1, 13.0, 2.1),
		CFrame.new(6.0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(2)),
		TIMBER,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(
		model,
		"Header",
		Vector3.new(15.2, 2.2, 2.5),
		CFrame.new(0, 13.0, 0) * CFrame.Angles(0, 0, math.rad(-1)),
		TIMBER_LIGHT,
		Enum.Material.WoodPlanks,
		nil
	)
	makeBeam(model, "LeftBrace", Vector3.new(-5.5, 3.0, 0.7), Vector3.new(-1.6, 11.9, 0.7), 1.0, TIMBER_LIGHT, Enum.Material.WoodPlanks)
	makeBeam(model, "RightBrace", Vector3.new(5.5, 3.0, -0.7), Vector3.new(1.6, 11.9, -0.7), 1.0, TIMBER_LIGHT, Enum.Material.WoodPlanks)

	for _, x in { -5.7, 5.7 } do
		makePart(
			model,
			"IronBand",
			Vector3.new(2.55, 0.45, 2.55),
			CFrame.new(x, 11.35, 0),
			IRON,
			Enum.Material.Metal,
			nil
		)
	end

	local lanternHook = makeBeam(
		model,
		"LanternHook",
		Vector3.new(2.25, 12.25, 0),
		Vector3.new(2.25, 10.4, 0),
		0.18,
		IRON,
		Enum.Material.Metal
	)
	lanternHook.CastShadow = false
end

local function buildAbandonedFireRing(model: Model)
	local stoneCount = 10
	for index = 1, stoneCount do
		local angle = ((index - 1) / stoneCount) * math.pi * 2
		local radius = 3.05
		local position = Vector3.new(math.cos(angle) * radius, 0.55, math.sin(angle) * radius)
		makePart(
			model,
			string.format("RingStone%02d", index),
			Vector3.new(1.65, 1.0 + ((index % 3) * 0.12), 1.35),
			CFrame.new(position) * CFrame.Angles(math.rad(index % 2 == 0 and 7 or -5), -angle, math.rad((index % 4) - 2)),
			index % 2 == 0 and ROCK_MID or ROCK_DARK,
			Enum.Material.Rock,
			Enum.PartType.Ball
		)
	end

	makeBeam(model, "CharredLogA", Vector3.new(-2.2, 0.7, -1.65), Vector3.new(2.2, 0.7, 1.65), 0.7, CHARCOAL, Enum.Material.Wood)
	makeBeam(model, "CharredLogB", Vector3.new(-2.2, 0.72, 1.65), Vector3.new(2.2, 0.72, -1.65), 0.7, CHARCOAL, Enum.Material.Wood)
	local embers = makePart(
		model,
		"ColdEmbers",
		Vector3.new(0.22, 3.5, 3.5),
		CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		EMBER,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	embers.Transparency = 0.4
	embers.CastShadow = false
end

local builders: { [string]: Builder } = {
	["env.rock.frontier.boulder_a"] = buildFrontierBoulder,
	["env.tree.corrupted.dead_pine_a"] = buildCorruptedDeadPine,
	["env.structure.industry.mine_support_a"] = buildMineSupport,
	["env.camp.frontier.abandoned_fire_ring_a"] = buildAbandonedFireRing,
}

function EnvironmentModelFactory.Build(parent: Instance, assetId: string, placement: CFrame): Model
	local definition = registryById[assetId]
	assert(definition ~= nil, string.format("Unknown environment asset id: %s", assetId))
	assert(definition.presentationOnly == true, string.format("Environment asset %s must be presentation-only", assetId))

	local builder = builders[assetId]
	assert(builder ~= nil, string.format("No procedural builder registered for environment asset: %s", assetId))

	local model = Instance.new("Model")
	model.Name = definition.variantId
	model:SetAttribute("EnvironmentAssetId", assetId)
	model:SetAttribute("EnvironmentAssetKitVersion", EnvironmentAssetKitRegistry.Version)
	model:SetAttribute("EnvironmentAssetFamily", definition.family)
	model:SetAttribute("EnvironmentPresentationOnly", true)

	builder(model)
	model:PivotTo(placement)
	model.Parent = parent
	return model
end

function EnvironmentModelFactory.Supports(assetId: string): boolean
	return builders[assetId] ~= nil and registryById[assetId] ~= nil
end

return table.freeze(EnvironmentModelFactory)
