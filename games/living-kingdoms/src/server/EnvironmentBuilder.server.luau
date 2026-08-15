--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.EnvironmentVisualConfig)
local WorldFoundationService = require(script.Parent.Systems.WorldFoundationService)

local Terrain = Workspace.Terrain
local activeRoot: Instance? = nil
local applying = false

local function clearOwnedTerrain()
	Terrain:FillBlock(Config.Terrain.UnderlayCFrame, Config.Terrain.UnderlaySize, Enum.Material.Air)
	for _, ridge in Config.Terrain.BoundaryRidges do
		Terrain:FillBall(ridge.position, ridge.radius + 4, Enum.Material.Air)
	end
	for index = 1, #Config.Terrain.CreekPoints - 1 do
		local from = Config.Terrain.CreekPoints[index]
		local to = Config.Terrain.CreekPoints[index + 1]
		local midpoint = (from + to) / 2
		local length = (to - from).Magnitude
		Terrain:FillBlock(
			CFrame.lookAt(midpoint, to),
			Vector3.new(Config.Terrain.CreekWidth + 4, Config.Terrain.CreekDepth + 4, length + 6),
			Enum.Material.Air
		)
	end
end

local function configureTerrainMaterials()
	Terrain:SetMaterialColor(Enum.Material.Grass, Config.Terrain.MaterialColors.Grass)
	Terrain:SetMaterialColor(Enum.Material.Ground, Config.Terrain.MaterialColors.Ground)
	Terrain:SetMaterialColor(Enum.Material.Mud, Config.Terrain.MaterialColors.Mud)
	Terrain:SetMaterialColor(Enum.Material.Rock, Config.Terrain.MaterialColors.Rock)
	Terrain:SetMaterialColor(Enum.Material.Slate, Config.Terrain.MaterialColors.Slate)

	Terrain.WaterColor = Config.Water.Color
	Terrain.WaterTransparency = Config.Water.Transparency
	Terrain.WaterReflectance = Config.Water.Reflectance
	Terrain.WaterWaveSize = Config.Water.WaveSize
	Terrain.WaterWaveSpeed = Config.Water.WaveSpeed
end

local function buildTerrainAndWater()
	clearOwnedTerrain()
	configureTerrainMaterials()

	-- A voxel underlay catches gaps in the authored graybox and the outer ridge
	-- stamps replace the empty horizon with a readable Appalachian silhouette.
	Terrain:FillBlock(Config.Terrain.UnderlayCFrame, Config.Terrain.UnderlaySize, Enum.Material.Ground)
	for _, ridge in Config.Terrain.BoundaryRidges do
		Terrain:FillBall(ridge.position, ridge.radius, ridge.material)
	end

	-- Real Terrain water sits immediately beneath the existing creek dressing.
	-- The glass route surface remains a traversal/readability guide only.
	for index = 1, #Config.Terrain.CreekPoints - 1 do
		local from = Config.Terrain.CreekPoints[index]
		local to = Config.Terrain.CreekPoints[index + 1]
		local midpoint = (from + to) / 2
		local length = (to - from).Magnitude
		Terrain:FillBlock(
			CFrame.lookAt(midpoint, to),
			Vector3.new(Config.Terrain.CreekWidth, Config.Terrain.CreekDepth, length),
			Enum.Material.Water
		)
	end
end

local function makeInvisibleAnchor(parent: Instance, name: string, cframe: CFrame): Part
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = cframe
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Parent = parent
	return anchor
end

local function addMistEmitter(parent: Instance, index: number, position: Vector3)
	local anchor = makeInvisibleAnchor(parent, "MistAnchor" .. index, CFrame.new(position))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LowGroundMist"
	emitter.Texture = Config.Mist.Texture
	emitter.Color = ColorSequence.new(Config.Mist.Color)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.14, 0.72),
		NumberSequenceKeypoint.new(0.72, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5.5),
		NumberSequenceKeypoint.new(0.55, 10.5),
		NumberSequenceKeypoint.new(1, 15),
	})
	emitter.Lifetime = Config.Mist.Lifetime
	emitter.Rate = Config.Mist.Rate
	emitter.Speed = Config.Mist.Speed
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

local function tagAccentLight(light: Light, accent: any)
	light:SetAttribute("BaseBrightness", accent.baseBrightness)
	light:SetAttribute("NightMultiplier", accent.nightMultiplier)
	light:SetAttribute("DayColor", accent.dayColor)
	light:SetAttribute("NightColor", accent.nightColor)
	CollectionService:AddTag(light, Config.AccentLightTag)
end

local function addAccent(parent: Instance, accent: any)
	local target = accent.target
	local cframe = if typeof(target) == "Vector3"
		then CFrame.lookAt(accent.position, target)
		else CFrame.new(accent.position)
	local anchor = makeInvisibleAnchor(parent, accent.name, cframe)

	if accent.kind == "PointLight" then
		local light = Instance.new("PointLight")
		light.Name = "EnvironmentAccent"
		light.Brightness = accent.baseBrightness
		light.Range = accent.range
		light.Color = accent.dayColor
		light.Shadows = false
		light.Parent = anchor
		tagAccentLight(light, accent)
		return
	end

	if accent.kind == "SpotLight" then
		local light = Instance.new("SpotLight")
		light.Name = "EnvironmentAccent"
		light.Face = Enum.NormalId.Front
		light.Brightness = accent.baseBrightness
		light.Range = accent.range
		light.Angle = accent.angle
		light.Color = accent.dayColor
		light.Shadows = false
		light.Parent = anchor
		tagAccentLight(light, accent)
		return
	end

	warn("[Living Kingdoms] Unsupported environment accent kind: " .. tostring(accent.kind))
	anchor:Destroy()
end

local function retuneCreekDressing(worldRoot: Instance)
	for _, descendant in worldRoot:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^Creek%d+$") ~= nil then
			descendant.Color = Config.Water.Color
			descendant.Material = Enum.Material.Glass
			descendant.Transparency = 0.52
			descendant.Reflectance = 0.06
		end
	end
end

local function buildPresentation(worldRoot: Instance)
	local oldPresentation = worldRoot:FindFirstChild(Config.PresentationFolderName)
	if oldPresentation ~= nil then
		oldPresentation:Destroy()
	end

	local presentation = Instance.new("Folder")
	presentation.Name = Config.PresentationFolderName
	presentation.Parent = worldRoot

	for index, position in Config.Mist.Locations do
		addMistEmitter(presentation, index, position)
	end
	for _, accent in Config.Accents do
		addAccent(presentation, accent)
	end

	retuneCreekDressing(worldRoot)
	worldRoot:SetAttribute("EnvironmentVisualVersion", Config.Version)
end

local function applyToWorld(worldRoot: Instance)
	if applying or worldRoot.Parent ~= Workspace or worldRoot.Name ~= Config.WorldRootName then
		return
	end
	applying = true
	local landmarks = worldRoot:WaitForChild("Landmarks", 8)
	if landmarks == nil then
		warn("[Living Kingdoms] EnvironmentBuilder skipped: landmark foundation was not ready")
		applying = false
		return
	end

	buildTerrainAndWater()
	buildPresentation(worldRoot)
	activeRoot = worldRoot
	applying = false
	print("[Living Kingdoms] Environment visuals ready: " .. Config.Version)
end

-- Preserve the established deterministic landmark builder as the geometry
-- source of truth. start() is idempotent, so this remains safe alongside the
-- legacy server bootstrap while making EnvironmentBuilder a real orchestrator.
WorldFoundationService.start()

task.wait()
local initialRoot = Workspace:FindFirstChild(Config.WorldRootName)
if initialRoot ~= nil then
	applyToWorld(initialRoot)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name ~= Config.WorldRootName then
		return
	end
	task.defer(function()
		task.wait()
		applyToWorld(child)
	end)
end)

Workspace.ChildRemoved:Connect(function(child)
	if child ~= activeRoot then
		return
	end
	activeRoot = nil
	clearOwnedTerrain()
end)
