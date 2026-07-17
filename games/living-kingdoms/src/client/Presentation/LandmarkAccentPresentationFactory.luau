--!strict

local Resolver = require(script.Parent.LandmarkAccentPresentationResolver)

type StyleId = Resolver.StyleId

local Factory = {}

Factory.PresentationModelName = "LandmarkSilhouettePresentation"
Factory.MaximumPresentationParts = 10

local COLORS = table.freeze({
	RangerMetal = Color3.fromRGB(183, 197, 187),
	RangerSignal = Color3.fromRGB(215, 167, 72),
	RoadblockMetal = Color3.fromRGB(184, 184, 161),
	RoadblockSignal = Color3.fromRGB(213, 113, 56),
})

local function makeAccent(
	parent: Model,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = anchor.CFrame * offset
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Name = "LandmarkAccentWeld"
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function basePart(model: Model, name: string): BasePart?
	local candidate = model:FindFirstChild(name, true)
	return if candidate ~= nil and candidate:IsA("BasePart") then candidate else nil
end

local function createRangerStation(model: Model): Model?
	local roof = basePart(model, "Roof")
	local mast = basePart(model, "RadioMast")
	if roof == nil or mast == nil then
		return nil
	end
	local presentation = Instance.new("Model")
	presentation.Name = Factory.PresentationModelName
	presentation:SetAttribute("LandmarkAccentStyle", Resolver.StyleIds.RangerStation)
	makeAccent(
		presentation,
		roof,
		"RoofEdgeNorth",
		Vector3.new(38, 0.35, 0.45),
		CFrame.new(0, 1.15, -13.4),
		COLORS.RangerMetal,
		Enum.Material.Metal
	)
	makeAccent(
		presentation,
		roof,
		"RoofEdgeSouth",
		Vector3.new(38, 0.35, 0.45),
		CFrame.new(0, 1.15, 13.4),
		COLORS.RangerMetal,
		Enum.Material.Metal
	)
	makeAccent(
		presentation,
		mast,
		"MastBandLower",
		Vector3.new(3.2, 3.2, 0.32),
		CFrame.new(0, 0, -7),
		COLORS.RangerSignal,
		Enum.Material.Neon
	)
	makeAccent(
		presentation,
		mast,
		"MastBandUpper",
		Vector3.new(3.2, 3.2, 0.32),
		CFrame.new(0, 0, 8),
		COLORS.RangerSignal,
		Enum.Material.Neon
	)
	presentation.Parent = model
	return presentation
end

local function createMilitaryRoadblock(model: Model): Model?
	local cabin = basePart(model, "CheckpointCabin")
	local lamp = basePart(model, "RoadblockEmergencyLight")
	if cabin == nil or lamp == nil then
		return nil
	end
	local presentation = Instance.new("Model")
	presentation.Name = Factory.PresentationModelName
	presentation:SetAttribute("LandmarkAccentStyle", Resolver.StyleIds.MilitaryRoadblock)
	makeAccent(
		presentation,
		cabin,
		"CabinHeader",
		Vector3.new(13.5, 0.45, 0.5),
		CFrame.new(0, 4.15, -6.1),
		COLORS.RoadblockMetal,
		Enum.Material.Metal
	)
	makeAccent(
		presentation,
		cabin,
		"CabinFooter",
		Vector3.new(13.5, 0.45, 0.5),
		CFrame.new(0, -3.8, -6.1),
		COLORS.RoadblockMetal,
		Enum.Material.Metal
	)
	makeAccent(
		presentation,
		cabin,
		"CabinStripeLeft",
		Vector3.new(0.5, 7.4, 0.5),
		CFrame.new(-6.2, 0, -6.1),
		COLORS.RoadblockSignal,
		Enum.Material.Neon
	)
	makeAccent(
		presentation,
		cabin,
		"CabinStripeRight",
		Vector3.new(0.5, 7.4, 0.5),
		CFrame.new(6.2, 0, -6.1),
		COLORS.RoadblockSignal,
		Enum.Material.Neon
	)
	makeAccent(
		presentation,
		lamp,
		"LampFinHorizontal",
		Vector3.new(3.4, 0.28, 0.45),
		CFrame.identity,
		COLORS.RoadblockSignal,
		Enum.Material.Neon
	)
	makeAccent(
		presentation,
		lamp,
		"LampFinVertical",
		Vector3.new(0.28, 3.4, 0.45),
		CFrame.identity,
		COLORS.RoadblockSignal,
		Enum.Material.Neon
	)
	presentation.Parent = model
	return presentation
end

function Factory.create(model: Model, styleId: StyleId): Model?
	if styleId == Resolver.StyleIds.RangerStation then
		return createRangerStation(model)
	end
	if styleId == Resolver.StyleIds.MilitaryRoadblock then
		return createMilitaryRoadblock(model)
	end
	return nil
end

return table.freeze(Factory)
