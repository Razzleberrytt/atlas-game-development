--!strict

--[[
	Second-stage environment builder for physical ambience that should not live in
	WorldFoundationService's deterministic gameplay geometry.

	This layer is deliberately narrow and cheap:
	- real Terrain water beneath the existing glass creek guide
	- tuned Terrain water material properties
	- four low-rate mist emitters on non-colliding, non-queryable anchors
	- no dynamic lights and no recurring update loop

	The builder is replay-safe: presentation objects live under the generated world
	root, while repeated Terrain water stamps are deterministic and idempotent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

local Terrain = Workspace.Terrain
local Presentation = Config.EnvironmentPresentation
local PRESENTATION_FOLDER_NAME = "EnvironmentPresentation"

local applying = false
local activeRoot: Folder? = nil

type PointSpec = { x: number, y: number, z: number }
type RgbSpec = { r: number, g: number, b: number }

local function toVector3(spec: PointSpec): Vector3
	return Vector3.new(spec.x, spec.y, spec.z)
end

local function toColor3(spec: RgbSpec): Color3
	return Color3.fromRGB(spec.r, spec.g, spec.b)
end

local function configureWaterMaterial()
	local water = Presentation.Water
	Terrain.WaterColor = toColor3(water.Color)
	Terrain.WaterTransparency = water.Transparency
	Terrain.WaterReflectance = water.Reflectance
	Terrain.WaterWaveSize = water.WaveSize
	Terrain.WaterWaveSpeed = water.WaveSpeed
end

local function stampCreekWater()
	local water = Presentation.Water
	local points = water.CreekPoints
	for index = 1, #points - 1 do
		local from = toVector3(points[index])
		local to = toVector3(points[index + 1])
		local midpoint = (from + to) / 2
		local length = (to - from).Magnitude
		Terrain:FillBlock(
			CFrame.lookAt(midpoint, to),
			Vector3.new(water.CreekWidth, water.CreekDepth, length + 1.5),
			Enum.Material.Water
		)
	end
end

local function makeMistAnchor(parent: Instance, index: number, position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = string.format("MistAnchor%02d", index)
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(position)
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor:SetAttribute("EnvironmentPresentationOnly", true)
	anchor.Parent = parent

	local mist = Presentation.Mist
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LowGroundMist"
	emitter.Texture = mist.Texture
	emitter.Color = ColorSequence.new(toColor3(mist.Color))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.14, 0.76),
		NumberSequenceKeypoint.new(0.72, 0.86),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5),
		NumberSequenceKeypoint.new(0.55, 10),
		NumberSequenceKeypoint.new(1, 14),
	})
	emitter.Lifetime = NumberRange.new(mist.LifetimeMin, mist.LifetimeMax)
	emitter.Rate = mist.Rate
	emitter.Speed = NumberRange.new(mist.SpeedMin, mist.SpeedMax)
	emitter.SpreadAngle = Vector2.new(180, 18)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-7, 7)
	emitter.Acceleration = Vector3.new(0, 0.08, 0)
	emitter.Drag = 1.4
	emitter.LightEmission = 0.02
	emitter.LightInfluence = 0.82
	emitter.LockedToPart = false
	emitter.Parent = anchor
end

local function retuneCreekGuide(worldRoot: Folder)
	local waterColor = toColor3(Presentation.Water.Color)
	for _, descendant in worldRoot:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^Creek%d+$") ~= nil then
			descendant.Color = waterColor
			descendant.Material = Enum.Material.Glass
			descendant.Transparency = 0.52
			descendant.Reflectance = 0.06
		end
	end
end

local function buildPresentation(worldRoot: Folder)
	local existing = worldRoot:FindFirstChild(PRESENTATION_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = PRESENTATION_FOLDER_NAME
	folder:SetAttribute("EnvironmentPresentationOnly", true)
	folder:SetAttribute("EnvironmentPresentationVersion", Presentation.Version)
	folder.Parent = worldRoot

	for index, positionSpec in Presentation.Mist.Locations do
		makeMistAnchor(folder, index, toVector3(positionSpec))
	end

	retuneCreekGuide(worldRoot)
	worldRoot:SetAttribute("EnvironmentPresentationVersion", Presentation.Version)
end

local function applyToWorld(candidate: Instance)
	if applying or candidate.Parent ~= Workspace or candidate.Name ~= Config.WorldRootName or not candidate:IsA("Folder") then
		return
	end
	applying = true

	local landmarks = candidate:WaitForChild("Landmarks", 8)
	if landmarks == nil then
		warn("[Living Kingdoms] EnvironmentBuilder skipped: landmark foundation was not ready")
		applying = false
		return
	end

	configureWaterMaterial()
	stampCreekWater()
	buildPresentation(candidate)
	activeRoot = candidate
	applying = false
	print("[Living Kingdoms] Environment physical ambience ready: " .. Presentation.Version)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == Config.WorldRootName then
		task.defer(applyToWorld, child)
	end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == activeRoot then
		activeRoot = nil
	end
end)

local initialRoot = Workspace:FindFirstChild(Config.WorldRootName)
if initialRoot ~= nil then
	task.defer(applyToWorld, initialRoot)
end
