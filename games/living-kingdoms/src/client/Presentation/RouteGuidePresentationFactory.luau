--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local RouteEdgePresentationResolver = require(script.Parent.RouteEdgePresentationResolver)

type RouteEdgePresentation = RouteEdgePresentationResolver.RouteEdgePresentation

export type RouteGuideRig = {
	model: Model,
	posts: { BasePart },
}

local Factory = {}
local ROAD_COLOR = Color3.fromRGB(224, 178, 72)
local TRAIL_COLOR = Color3.fromRGB(134, 143, 128)

local function makePost(
	model: Model,
	segment: BasePart,
	name: string,
	localX: number,
	definition: RouteEdgePresentation
): Part
	local post = Instance.new("Part")
	post.Name = name
	post.Size = Vector3.new(definition.markerWidth, definition.markerHeight, definition.markerDepth)
	post.CFrame = segment.CFrame * CFrame.new(localX, definition.markerCenterY, 0)
	post.Color = if definition.styleId == "Road" then ROAD_COLOR else TRAIL_COLOR
	post.Material = if definition.styleId == "Road" then Enum.Material.Neon else Enum.Material.Slate
	post.Anchored = false
	post.Massless = true
	post.CanCollide = false
	post.CanTouch = false
	post.CanQuery = false
	post.CastShadow = definition.styleId ~= "Road"
	post.TopSurface = Enum.SurfaceType.Smooth
	post.BottomSurface = Enum.SurfaceType.Smooth
	if definition.styleId == "Trail" then
		post.Shape = Enum.PartType.Ball
	end
	post.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = segment
	weld.Part1 = post
	weld.Parent = post
	return post
end

function Factory.create(segment: BasePart, definition: RouteEdgePresentation): RouteGuideRig
	local model = Instance.new("Model")
	model.Name = "RouteGuidePresentation"
	model:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.WorldLoggingRoad)
	model:SetAttribute("VisualStatus", "ProceduralFallback")
	model:SetAttribute("RouteStyleId", definition.styleId)
	model:SetAttribute("TruthSource", "ExistingAuthoredRouteSegment")

	local left = makePost(model, segment, "LeftGuidePost", definition.leftOffsetX, definition)
	local right = makePost(model, segment, "RightGuidePost", definition.rightOffsetX, definition)
	model.PrimaryPart = left
	return table.freeze({
		model = model,
		posts = table.freeze({ left, right }),
	})
end

return table.freeze(Factory)
