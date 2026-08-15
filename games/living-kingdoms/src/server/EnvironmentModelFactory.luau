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
local RUST = Color3.fromRGB(103, 68, 48)
local CHARCOAL = Color3.fromRGB(38, 34, 31)
local EMBER = Color3.fromRGB(170, 74, 38)
local TARP = Color3.fromRGB(86, 91, 72)
local TARP_FADED = Color3.fromRGB(112, 107, 82)
local CRATE = Color3.fromRGB(122, 91, 55)
local CRATE_DARK = Color3.fromRGB(82, 61, 42)

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
	local midpoint = fromPosition:Lerp(toPosition, 0.5)
	return makePart(
		parent,
		name,
		Vector3.new(thickness, thickness, delta.Magnitude),
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
	makeBeam(
		model,
		"DeadBranch01",
		Vector3.new(0.1, 8.4, 0),
		Vector3.new(-6.0, 12.0, 1.7),
		0.72,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"DeadBranch02",
		Vector3.new(0.2, 11.1, 0),
		Vector3.new(5.1, 14.2, -2.3),
		0.65,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"DeadBranch03",
		Vector3.new(0.35, 15.0, -0.1),
		Vector3.new(-4.1, 18.5, -3.5),
		0.56,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"DeadBranch04",
		Vector3.new(0.45, 18.4, -0.2),
		Vector3.new(3.7, 21.3, 2.4),
		0.48,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"DeadBranch05",
		Vector3.new(0.45, 21.6, -0.2),
		Vector3.new(-2.8, 24.0, 1.7),
		0.38,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)

	local shardA = makePart(
		model,
		"CorruptionShard01",
		Vector3.new(0.55, 2.0, 0.55),
		CFrame.new(-0.85, 5.0, 0.65) * CFrame.Angles(0, 0, math.rad(-16)),
		CORRUPTION,
		Enum.Material.Neon,
		nil
	)
	local shardB = makePart(
		model,
		"CorruptionShard02",
		Vector3.new(0.42, 1.55, 0.42),
		CFrame.new(0.75, 12.8, -0.65) * CFrame.Angles(0, 0, math.rad(21)),
		CORRUPTION,
		Enum.Material.Neon,
		nil
	)
	local shardC = makePart(
		model,
		"CorruptionShard03",
		Vector3.new(0.35, 1.2, 0.35),
		CFrame.new(-0.4, 18.0, 0.55) * CFrame.Angles(0, 0, math.rad(-8)),
		CORRUPTION,
		Enum.Material.Neon,
		nil
	)
	shardA.CastShadow = false
	shardB.CastShadow = false
	shardC.CastShadow = false
end

local function buildFallenRootMass(model: Model)
	makeBeam(
		model,
		"RootSpine",
		Vector3.new(-5.8, 1.7, -2.2),
		Vector3.new(5.7, 2.4, 2.0),
		2.5,
		DEAD_WOOD,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"RootForkA",
		Vector3.new(-1.5, 1.8, 0),
		Vector3.new(-6.4, 1.0, 4.2),
		1.35,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"RootForkB",
		Vector3.new(1.1, 2.0, 0.4),
		Vector3.new(6.2, 0.9, -4.0),
		1.2,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"RootForkC",
		Vector3.new(0.2, 1.8, -0.3),
		Vector3.new(-1.2, 0.7, -5.2),
		0.9,
		DEAD_WOOD,
		Enum.Material.Wood
	)
	makePart(
		model,
		"RootKnotA",
		Vector3.new(4.8, 3.8, 4.2),
		CFrame.new(-2.9, 1.9, -0.8),
		DEAD_WOOD,
		Enum.Material.Wood,
		Enum.PartType.Ball
	)
	makePart(
		model,
		"RootKnotB",
		Vector3.new(3.4, 2.9, 3.8),
		CFrame.new(2.4, 1.6, 1.0),
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood,
		Enum.PartType.Ball
	)
	local corruption = makePart(
		model,
		"CorruptionVein",
		Vector3.new(5.4, 0.3, 0.45),
		CFrame.new(0.5, 3.25, 0.2) * CFrame.Angles(0, math.rad(18), 0),
		CORRUPTION,
		Enum.Material.Neon,
		nil
	)
	corruption.CastShadow = false
end

local function buildCorruptedStumpCluster(model: Model)
	makePart(
		model,
		"Stump01",
		Vector3.new(4.8, 2.6, 2.6),
		CFrame.new(-2.4, 1.8, 0.8) * CFrame.Angles(0, 0, math.rad(90)),
		DEAD_WOOD,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"Stump02",
		Vector3.new(3.5, 2.1, 2.1),
		CFrame.new(1.4, 1.3, -1.7) * CFrame.Angles(0, 0, math.rad(90)),
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"Stump03",
		Vector3.new(2.8, 1.7, 1.7),
		CFrame.new(2.7, 0.9, 2.0) * CFrame.Angles(0, 0, math.rad(90)),
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	makeBeam(
		model,
		"SurfaceRootA",
		Vector3.new(-1.8, 0.55, 0.4),
		Vector3.new(-4.7, 0.35, 3.4),
		0.75,
		DEAD_WOOD,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"SurfaceRootB",
		Vector3.new(1.2, 0.45, -1.2),
		Vector3.new(4.0, 0.3, -3.7),
		0.65,
		DEAD_WOOD_LIGHT,
		Enum.Material.Wood
	)
	local shard = makePart(
		model,
		"CorruptionShard",
		Vector3.new(0.45, 1.5, 0.45),
		CFrame.new(-1.4, 4.0, 0.6) * CFrame.Angles(0, 0, math.rad(12)),
		CORRUPTION,
		Enum.Material.Neon,
		nil
	)
	shard.CastShadow = false
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
	makeBeam(
		model,
		"LeftBrace",
		Vector3.new(-5.5, 3.0, 0.7),
		Vector3.new(-1.6, 11.9, 0.7),
		1.0,
		TIMBER_LIGHT,
		Enum.Material.WoodPlanks
	)
	makeBeam(
		model,
		"RightBrace",
		Vector3.new(5.5, 3.0, -0.7),
		Vector3.new(1.6, 11.9, -0.7),
		1.0,
		TIMBER_LIGHT,
		Enum.Material.WoodPlanks
	)
	makePart(
		model,
		"IronBand01",
		Vector3.new(2.55, 0.45, 2.55),
		CFrame.new(-5.7, 11.35, 0),
		IRON,
		Enum.Material.Metal,
		nil
	)
	makePart(
		model,
		"IronBand02",
		Vector3.new(2.55, 0.45, 2.55),
		CFrame.new(5.7, 11.35, 0),
		IRON,
		Enum.Material.Metal,
		nil
	)
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

local function buildBrokenSupport(model: Model)
	makePart(
		model,
		"StandingPost",
		Vector3.new(2.0, 10.5, 2.0),
		CFrame.new(-4.8, 5.2, 0) * CFrame.Angles(0, 0, math.rad(-5)),
		TIMBER,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(
		model,
		"LeaningPost",
		Vector3.new(2.0, 9.2, 2.0),
		CFrame.new(4.2, 4.5, 0.4) * CFrame.Angles(math.rad(3), 0, math.rad(16)),
		TIMBER_LIGHT,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(
		model,
		"BrokenHeader",
		Vector3.new(8.4, 1.9, 2.2),
		CFrame.new(-1.2, 10.1, 0) * CFrame.Angles(0, 0, math.rad(-8)),
		TIMBER_LIGHT,
		Enum.Material.WoodPlanks,
		nil
	)
	makeBeam(
		model,
		"FallenBeam",
		Vector3.new(-4.0, 0.8, -2.7),
		Vector3.new(5.2, 1.1, 3.3),
		1.25,
		TIMBER,
		Enum.Material.WoodPlanks
	)
	makePart(model, "RustPlate", Vector3.new(2.4, 0.35, 2.4), CFrame.new(-4.65, 8.3, 0), RUST, Enum.Material.Metal, nil)
end

local function buildOreCart(model: Model)
	makePart(
		model,
		"CartBody",
		Vector3.new(6.4, 2.5, 4.8),
		CFrame.new(0, 3.2, 0) * CFrame.Angles(math.rad(-3), 0, 0),
		RUST,
		Enum.Material.Metal,
		nil
	)
	makePart(model, "CartLip", Vector3.new(7.0, 0.45, 5.2), CFrame.new(0, 4.55, 0), IRON, Enum.Material.Metal, nil)
	makePart(
		model,
		"Wheel01",
		Vector3.new(0.65, 2.2, 2.2),
		CFrame.new(-2.2, 1.45, -2.3) * CFrame.Angles(0, math.rad(-90), 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"Wheel02",
		Vector3.new(0.65, 2.2, 2.2),
		CFrame.new(2.2, 1.45, -2.3) * CFrame.Angles(0, math.rad(-90), 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"Wheel03",
		Vector3.new(0.65, 2.2, 2.2),
		CFrame.new(-2.2, 1.45, 2.3) * CFrame.Angles(0, math.rad(-90), 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"Wheel04",
		Vector3.new(0.65, 2.2, 2.2),
		CFrame.new(2.2, 1.45, 2.3) * CFrame.Angles(0, math.rad(-90), 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	makeBeam(
		model,
		"HandleA",
		Vector3.new(-2.2, 3.3, 2.1),
		Vector3.new(-2.2, 3.6, 6.2),
		0.35,
		RUST,
		Enum.Material.Metal
	)
	makeBeam(model, "HandleB", Vector3.new(2.2, 3.3, 2.1), Vector3.new(2.2, 3.6, 6.2), 0.35, RUST, Enum.Material.Metal)
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
			CFrame.new(position)
				* CFrame.Angles(math.rad(index % 2 == 0 and 7 or -5), -angle, math.rad((index % 4) - 2)),
			index % 2 == 0 and ROCK_MID or ROCK_DARK,
			Enum.Material.Rock,
			Enum.PartType.Ball
		)
	end
	makeBeam(
		model,
		"CharredLogA",
		Vector3.new(-2.2, 0.7, -1.65),
		Vector3.new(2.2, 0.7, 1.65),
		0.7,
		CHARCOAL,
		Enum.Material.Wood
	)
	makeBeam(
		model,
		"CharredLogB",
		Vector3.new(-2.2, 0.72, 1.65),
		Vector3.new(2.2, 0.72, -1.65),
		0.7,
		CHARCOAL,
		Enum.Material.Wood
	)
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

local function buildTornShelter(model: Model)
	makePart(model, "LeftPost", Vector3.new(0.9, 6.6, 0.9), CFrame.new(-4.2, 3.3, 0), TIMBER, Enum.Material.Wood, nil)
	makePart(
		model,
		"RightPost",
		Vector3.new(0.9, 6.0, 0.9),
		CFrame.new(4.0, 3.0, 0.5) * CFrame.Angles(0, 0, math.rad(4)),
		TIMBER,
		Enum.Material.Wood,
		nil
	)
	makeBeam(
		model,
		"RidgePole",
		Vector3.new(-4.0, 6.4, 0),
		Vector3.new(4.0, 5.9, 0.5),
		0.55,
		TIMBER_LIGHT,
		Enum.Material.Wood
	)
	makePart(
		model,
		"TarpLeft",
		Vector3.new(4.5, 0.22, 7.2),
		CFrame.new(-2.0, 5.0, -0.4) * CFrame.Angles(0, 0, math.rad(-18)),
		TARP,
		Enum.Material.Fabric,
		nil
	)
	makePart(
		model,
		"TarpRight",
		Vector3.new(3.8, 0.22, 6.6),
		CFrame.new(2.0, 4.8, 0.8) * CFrame.Angles(0, 0, math.rad(20)),
		TARP_FADED,
		Enum.Material.Fabric,
		nil
	)
	makeBeam(
		model,
		"GroundStake",
		Vector3.new(3.5, 0.4, -3.2),
		Vector3.new(4.5, 2.0, -2.6),
		0.18,
		TIMBER_LIGHT,
		Enum.Material.Wood
	)
end

local function buildSupplyCrateStack(model: Model)
	makePart(
		model,
		"CrateA",
		Vector3.new(3.8, 3.0, 3.4),
		CFrame.new(-1.7, 1.5, 0) * CFrame.Angles(0, math.rad(-5), 0),
		CRATE,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(
		model,
		"CrateB",
		Vector3.new(3.6, 2.8, 3.2),
		CFrame.new(2.0, 1.4, 0.4) * CFrame.Angles(0, math.rad(8), 0),
		CRATE,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(
		model,
		"CrateC",
		Vector3.new(3.2, 2.5, 3.0),
		CFrame.new(0.2, 4.2, 0.1) * CFrame.Angles(0, math.rad(-11), 0),
		CRATE_DARK,
		Enum.Material.WoodPlanks,
		nil
	)
	makePart(model, "BandA", Vector3.new(0.28, 3.1, 3.5), CFrame.new(-1.7, 1.55, 0), IRON, Enum.Material.Metal, nil)
	makePart(model, "BandB", Vector3.new(3.7, 2.9, 0.28), CFrame.new(2.0, 1.45, 0.4), IRON, Enum.Material.Metal, nil)
end

local builders: { [string]: Builder } = {
	["env.rock.frontier.boulder_a"] = buildFrontierBoulder,
	["env.tree.corrupted.dead_pine_a"] = buildCorruptedDeadPine,
	["env.root.corrupted.fallen_mass_a"] = buildFallenRootMass,
	["env.root.corrupted.stump_cluster_a"] = buildCorruptedStumpCluster,
	["env.structure.industry.mine_support_a"] = buildMineSupport,
	["env.structure.industry.broken_support_a"] = buildBrokenSupport,
	["env.prop.industry.ore_cart_a"] = buildOreCart,
	["env.camp.frontier.abandoned_fire_ring_a"] = buildAbandonedFireRing,
	["env.camp.frontier.torn_shelter_a"] = buildTornShelter,
	["env.prop.frontier.supply_crate_stack_a"] = buildSupplyCrateStack,
}

function EnvironmentModelFactory.Build(parent: Instance, assetId: string, placement: CFrame): Model
	local definition = registryById[assetId]
	assert(definition ~= nil, string.format("Unknown environment asset id: %s", assetId))
	assert(
		definition.presentationOnly == true,
		string.format("Environment asset %s must be presentation-only", assetId)
	)

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
