--!strict

--[[
	Adds a bounded, source-managed readability pass after WorldFoundationService
	creates the operation world. These props are presentation-only: they do not
	collide, participate in queries, emit dynamic light, or own navigation truth.

	The goal is cheap route legibility in dawn/night conditions without increasing
	the local-light budget. Authored meshes can replace this layer later without
	changing any gameplay contract.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

local DRESSING_FOLDER_NAME = "ReadabilityDressing"

local function makePresentationPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
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
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildTrailReflector(parent: Instance, index: number, position: Vector3)
	local marker = Instance.new("Model")
	marker.Name = string.format("TrailReflector%02d", index)
	marker:SetAttribute("EnvironmentPresentationOnly", true)
	marker.Parent = parent

	makePresentationPart(
		marker,
		"Post",
		Vector3.new(0.5, 3.2, 0.5),
		CFrame.new(position),
		Color3.fromRGB(72, 77, 70),
		Enum.Material.Metal
	)

	-- Neon is intentionally emissive-only. A physical cap + post silhouette keeps
	-- the cue readable even when color fidelity is poor, without a PointLight.
	makePresentationPart(
		marker,
		"ReflectiveCap",
		Vector3.new(0.9, 0.45, 0.9),
		CFrame.new(position + Vector3.new(0, 1.7, 0)),
		Color3.fromRGB(230, 220, 167),
		Enum.Material.Neon
	)

	makePresentationPart(
		marker,
		"ReflectiveBand",
		Vector3.new(0.68, 0.24, 0.68),
		CFrame.new(position + Vector3.new(0, 0.72, 0)),
		Color3.fromRGB(201, 194, 150),
		Enum.Material.Neon
	)
end

local function applyDressing(worldRoot: Instance)
	local existing = worldRoot:FindFirstChild(DRESSING_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local dressing = Instance.new("Folder")
	dressing.Name = DRESSING_FOLDER_NAME
	dressing:SetAttribute("WorldDressingVersion", Config.Dressing.Version)
	dressing:SetAttribute("EnvironmentPresentationOnly", true)
	dressing.Parent = worldRoot

	for index, position in Config.Dressing.TrailReflectorPositions do
		buildTrailReflector(dressing, index, position)
	end

	worldRoot:SetAttribute("WorldDressingVersion", Config.Dressing.Version)
end

local worldRoot = Workspace:WaitForChild(Config.WorldRootName)
assert(worldRoot:IsA("Folder"), Config.WorldRootName .. " must be a Folder")

-- Waiting for Landmarks makes this pass deterministic relative to the synchronous
-- world builder without polling or adding a recurring server loop.
worldRoot:WaitForChild("Landmarks")
applyDressing(worldRoot)

print("[Living Kingdoms] World visual dressing ready: " .. Config.Dressing.Version)
