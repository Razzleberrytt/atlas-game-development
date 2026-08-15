--!strict

--[[
	Source-managed operation environment assembly. WorldFoundationService remains
	the deterministic terrain/landmark generator; this script composes its visual
	finish: themed water, sky/profile activation, route dressing, ambient mist,
	and a tiny landmark-light budget. Everything added here is presentation-only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnvironmentProfileService = require(script.Parent.Systems.EnvironmentProfileService)
local WorldFoundationService = require(script.Parent.Systems.WorldFoundationService)

local PRESENTATION_FOLDER_NAME = "EnvironmentPresentation"
local MIST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

type PointSpec = { x: number, y: number, z: number }
type RgbSpec = { r: number, g: number, b: number }

local function toVector3(spec: PointSpec): Vector3
	return Vector3.new(spec.x, spec.y, spec.z)
end

local function toColor3(spec: RgbSpec): Color3
	return Color3.fromRGB(spec.r, spec.g, spec.b)
end

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

local function configureWater(worldRoot: Folder)
	local water = Config.Environment.Water
	local terrain = Workspace.Terrain
	terrain.WaterColor = toColor3(water.Color)
	terrain.WaterTransparency = water.Transparency
	terrain.WaterReflectance = water.Reflectance
	terrain.WaterWaveSize = water.WaveSize
	terrain.WaterWaveSpeed = water.WaveSpeed

	local terrainFoundation = worldRoot:FindFirstChild("TerrainFoundation")
	if terrainFoundation == nil then
		return
	end
	for _, descendant in terrainFoundation:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^Creek%d+$") ~= nil then
			descendant.Material = Enum.Material.Glass
			descendant.Color = toColor3(water.Color)
			descendant.Transparency = water.Transparency
			descendant.Reflectance = water.Reflectance
		end
	end
end

local function buildMist(parent: Instance)
	local mist = Config.Environment.Mist
	for index, positionSpec in mist.Anchors do
		local anchor = makePresentationPart(
			parent,
			string.format("MistAnchor%02d", index),
			Vector3.new(18, 1, 18),
			CFrame.new(toVector3(positionSpec)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		anchor.Transparency = 1

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "LowMist"
		emitter.Texture = MIST_TEXTURE
		emitter.Color = ColorSequence.new(toColor3(mist.Color))
		emitter.LightInfluence = 0.7
		emitter.Rate = mist.Rate
		emitter.Lifetime = NumberRange.new(mist.LifetimeMin, mist.LifetimeMax)
		emitter.Speed = NumberRange.new(mist.SpeedMin, mist.SpeedMax)
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Rotation = NumberRange.new(-180, 180)
		emitter.RotSpeed = NumberRange.new(-4, 4)
		emitter.Acceleration = Vector3.new(0, 0.08, 0)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Orientation = Enum.ParticleOrientation.FacingCamera
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 6),
			NumberSequenceKeypoint.new(0.65, 12),
			NumberSequenceKeypoint.new(1, 17),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.7, 0.95),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = anchor
	end
end

local function buildAccentLights(parent: Instance)
	for index, spec in Config.Environment.AccentLights do
		local position = toVector3(spec.position)
		local cframe = CFrame.new(position)
		if spec.kind == "Spot" and spec.target ~= nil then
			cframe = CFrame.lookAt(position, toVector3(spec.target))
		end

		local anchor = makePresentationPart(
			parent,
			string.format("LandmarkAccent%02d", index),
			Vector3.new(1, 1, 1),
			cframe,
			toColor3(spec.color),
			Enum.Material.SmoothPlastic
		)
		anchor.Transparency = 1

		if spec.kind == "Point" then
			local light = Instance.new("PointLight")
			light.Name = "WarmPracticalAccent"
			light.Color = toColor3(spec.color)
			light.Brightness = spec.brightness
			light.Range = spec.range
			light.Shadows = false
			light.Parent = anchor
		elseif spec.kind == "Spot" then
			local light = Instance.new("SpotLight")
			light.Name = "OrientationAccent"
			light.Face = Enum.NormalId.Front
			light.Color = toColor3(spec.color)
			light.Brightness = spec.brightness
			light.Range = spec.range
			light.Angle = spec.angle
			light.Shadows = false
			light.Parent = anchor
		end
	end
end

local function buildPresentation(worldRoot: Folder)
	local oldDressing = worldRoot:FindFirstChild("ReadabilityDressing")
	if oldDressing ~= nil then
		oldDressing:Destroy()
	end

	local existing = worldRoot:FindFirstChild(PRESENTATION_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local presentation = Instance.new("Folder")
	presentation.Name = PRESENTATION_FOLDER_NAME
	presentation:SetAttribute("EnvironmentVersion", Config.Environment.Version)
	presentation:SetAttribute("WorldDressingVersion", Config.Dressing.Version)
	presentation:SetAttribute("EnvironmentPresentationOnly", true)
	presentation.Parent = worldRoot

	local routeDressing = Instance.new("Folder")
	routeDressing.Name = "RouteDressing"
	routeDressing.Parent = presentation
	for index, positionSpec in Config.Dressing.TrailReflectorPositions do
		buildTrailReflector(routeDressing, index, toVector3(positionSpec))
	end

	local ambience = Instance.new("Folder")
	ambience.Name = "AmbientVFX"
	ambience.Parent = presentation
	buildMist(ambience)

	local accents = Instance.new("Folder")
	accents.Name = "LandmarkAccents"
	accents.Parent = presentation
	buildAccentLights(accents)

	worldRoot:SetAttribute("EnvironmentVersion", Config.Environment.Version)
	worldRoot:SetAttribute("WorldDressingVersion", Config.Dressing.Version)
end

WorldFoundationService.start()

local worldRoot = Workspace:WaitForChild(Config.WorldRootName)
if not worldRoot:IsA("Folder") then
	error(Config.WorldRootName .. " must be a Folder")
end

local landmarks = worldRoot:WaitForChild("Landmarks")
if not landmarks:IsA("Folder") then
	error("Landmarks must be a Folder")
end

EnvironmentProfileService.start()
configureWater(worldRoot)
buildPresentation(worldRoot)

print("[Living Kingdoms] Environment builder ready: " .. Config.Environment.Version)
