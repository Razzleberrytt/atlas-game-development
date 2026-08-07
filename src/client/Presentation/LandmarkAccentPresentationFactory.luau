--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MaterialLanguage = require(ReplicatedStorage.Shared.Config.WorldMaterialLanguageConfig)
local Resolver = require(script.Parent.LandmarkAccentPresentationResolver)

type StyleId = Resolver.StyleId

local Factory = {}

Factory.PresentationModelName = "LandmarkSilhouettePresentation"
Factory.MaximumPresentationParts = 22

local Roles = MaterialLanguage.Roles

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

local function newPresentation(model: Model, styleId: StyleId): Model
	local presentation = Instance.new("Model")
	presentation.Name = Factory.PresentationModelName
	presentation:SetAttribute("LandmarkAccentStyle", styleId)
	presentation.Parent = model
	return presentation
end

local function createRangerStation(model: Model): Model?
	local roof = basePart(model, "Roof")
	local mast = basePart(model, "RadioMast")
	if roof == nil or mast == nil then
		return nil
	end
	local presentation = newPresentation(model, Resolver.StyleIds.RangerStation)
	makeAccent(
		presentation,
		roof,
		"RoofEdgeNorth",
		Vector3.new(38, 0.35, 0.45),
		CFrame.new(0, 1.15, -13.4),
		Roles.InfrastructureMetal.color,
		Roles.InfrastructureMetal.material
	)
	makeAccent(
		presentation,
		roof,
		"RoofEdgeSouth",
		Vector3.new(38, 0.35, 0.45),
		CFrame.new(0, 1.15, 13.4),
		Roles.InfrastructureMetal.color,
		Roles.InfrastructureMetal.material
	)
	makeAccent(
		presentation,
		mast,
		"MastBandLower",
		Vector3.new(3.2, 3.2, 0.32),
		CFrame.new(0, 0, -7),
		Roles.InfrastructureSignal.color,
		Roles.InfrastructureSignal.material
	)
	makeAccent(
		presentation,
		mast,
		"MastBandUpper",
		Vector3.new(3.2, 3.2, 0.32),
		CFrame.new(0, 0, 8),
		Roles.InfrastructureSignal.color,
		Roles.InfrastructureSignal.material
	)
	return presentation
end

local function createMilitaryRoadblock(model: Model): Model?
	local cabin = basePart(model, "CheckpointCabin")
	local lamp = basePart(model, "RoadblockEmergencyLight")
	if cabin == nil or lamp == nil then
		return nil
	end
	local presentation = newPresentation(model, Resolver.StyleIds.MilitaryRoadblock)
	makeAccent(
		presentation,
		cabin,
		"CabinHeader",
		Vector3.new(13.5, 0.45, 0.5),
		CFrame.new(0, 4.15, -6.1),
		Roles.SecurityMetal.color,
		Roles.SecurityMetal.material
	)
	makeAccent(
		presentation,
		cabin,
		"CabinFooter",
		Vector3.new(13.5, 0.45, 0.5),
		CFrame.new(0, -3.8, -6.1),
		Roles.SecurityMetal.color,
		Roles.SecurityMetal.material
	)
	makeAccent(
		presentation,
		cabin,
		"CabinStripeLeft",
		Vector3.new(0.5, 7.4, 0.5),
		CFrame.new(-6.2, 0, -6.1),
		Roles.SecuritySignal.color,
		Roles.SecuritySignal.material
	)
	makeAccent(
		presentation,
		cabin,
		"CabinStripeRight",
		Vector3.new(0.5, 7.4, 0.5),
		CFrame.new(6.2, 0, -6.1),
		Roles.SecuritySignal.color,
		Roles.SecuritySignal.material
	)
	makeAccent(
		presentation,
		lamp,
		"LampFinHorizontal",
		Vector3.new(3.4, 0.28, 0.45),
		CFrame.identity,
		Roles.SecuritySignal.color,
		Roles.SecuritySignal.material
	)
	makeAccent(
		presentation,
		lamp,
		"LampFinVertical",
		Vector3.new(0.28, 3.4, 0.45),
		CFrame.identity,
		Roles.SecuritySignal.color,
		Roles.SecuritySignal.material
	)
	return presentation
end

local function createCampground(model: Model): Model?
	local tentOne = basePart(model, "AbandonedTent1")
	local tentTwo = basePart(model, "AbandonedTent2")
	local deadFire = basePart(model, "DeadFire")
	if tentOne == nil or tentTwo == nil or deadFire == nil then
		return nil
	end
	local presentation = newPresentation(model, Resolver.StyleIds.Campground)
	makeAccent(
		presentation,
		tentOne,
		"TentRidgeOne",
		Vector3.new(0.45, 0.35, 8.2),
		CFrame.new(0, 2.2, 0),
		Roles.CampFabric.color,
		Roles.CampFabric.material
	)
	makeAccent(
		presentation,
		tentTwo,
		"TentRidgeTwo",
		Vector3.new(0.45, 0.35, 8.2),
		CFrame.new(0, 2.2, 0),
		Roles.CampFabric.color,
		Roles.CampFabric.material
	)
	makeAccent(
		presentation,
		deadFire,
		"FireRingBarNorth",
		Vector3.new(4.4, 0.18, 0.24),
		CFrame.new(0, 0.32, -0.58),
		Roles.CampEmber.color,
		Roles.CampEmber.material
	)
	makeAccent(
		presentation,
		deadFire,
		"FireRingBarSouth",
		Vector3.new(4.4, 0.18, 0.24),
		CFrame.new(0, 0.32, 0.58),
		Roles.CampEmber.color,
		Roles.CampEmber.material
	)
	return presentation
end

local function createCreekCrossing(model: Model): Model?
	local warning = basePart(model, "WashedOutWarning")
	local fallenTree = basePart(model, "FallenCreekTree")
	if warning == nil or fallenTree == nil then
		return nil
	end
	local presentation = newPresentation(model, Resolver.StyleIds.CreekCrossing)
	makeAccent(
		presentation,
		warning,
		"WarningBraceLeft",
		Vector3.new(0.45, 3.4, 0.7),
		CFrame.new(-5.7, 0, 0),
		Roles.CrossingWarning.color,
		Roles.CrossingWarning.material
	)
	makeAccent(
		presentation,
		warning,
		"WarningBraceRight",
		Vector3.new(0.45, 3.4, 0.7),
		CFrame.new(5.7, 0, 0),
		Roles.CrossingWarning.color,
		Roles.CrossingWarning.material
	)
	makeAccent(
		presentation,
		fallenTree,
		"FallenTreeBandWest",
		Vector3.new(0.35, 3.4, 3.4),
		CFrame.new(-6, 0, 0),
		Roles.CrossingWood.color,
		Roles.CrossingWood.material
	)
	makeAccent(
		presentation,
		fallenTree,
		"FallenTreeBandEast",
		Vector3.new(0.35, 3.4, 3.4),
		CFrame.new(6, 0, 0),
		Roles.CrossingWood.color,
		Roles.CrossingWood.material
	)
	return presentation
end

local function createRockyOverlook(model: Model): Model?
	local guardRail = basePart(model, "BrokenGuardRail")
	local cliffEdge = basePart(model, "ReadableCliffEdge")
	if guardRail == nil or cliffEdge == nil then
		return nil
	end
	local presentation = newPresentation(model, Resolver.StyleIds.RockyOverlook)
	makeAccent(
		presentation,
		guardRail,
		"GuardRailSleeveNear",
		Vector3.new(1.5, 1.5, 3.2),
		CFrame.new(0, 0, -8),
		Roles.OverlookMetal.color,
		Roles.OverlookMetal.material
	)
	makeAccent(
		presentation,
		guardRail,
		"GuardRailSleeveFar",
		Vector3.new(1.5, 1.5, 3.2),
		CFrame.new(0, 0, 8),
		Roles.OverlookMetal.color,
		Roles.OverlookMetal.material
	)
	makeAccent(
		presentation,
		cliffEdge,
		"CliffEdgeBandWest",
		Vector3.new(3.4, 0.35, 4),
		CFrame.new(0, 1.15, -20),
		Roles.OverlookStone.color,
		Roles.OverlookStone.material
	)
	makeAccent(
		presentation,
		cliffEdge,
		"CliffEdgeBandEast",
		Vector3.new(3.4, 0.35, 4),
		CFrame.new(0, 1.15, 20),
		Roles.OverlookStone.color,
		Roles.OverlookStone.material
	)
	return presentation
end

function Factory.create(model: Model, styleId: StyleId): Model?
	if styleId == Resolver.StyleIds.RangerStation then
		return createRangerStation(model)
	end
	if styleId == Resolver.StyleIds.MilitaryRoadblock then
		return createMilitaryRoadblock(model)
	end
	if styleId == Resolver.StyleIds.Campground then
		return createCampground(model)
	end
	if styleId == Resolver.StyleIds.CreekCrossing then
		return createCreekCrossing(model)
	end
	if styleId == Resolver.StyleIds.RockyOverlook then
		return createRockyOverlook(model)
	end
	return nil
end

return table.freeze(Factory)
