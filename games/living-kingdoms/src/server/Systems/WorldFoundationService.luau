--!strict

--[[
	Builds the deterministic P5-0101 environment graybox. This service owns
	only static world presentation and collision: no objectives, extraction
	state, enemies, hazards, loot, or mission scripting are created here.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

local WorldFoundationService = {}

local COLORS = table.freeze({
	soil = Color3.fromRGB(55, 58, 46),
	forestFloor = Color3.fromRGB(48, 60, 44),
	road = Color3.fromRGB(79, 71, 59),
	trail = Color3.fromRGB(92, 79, 60),
	rock = Color3.fromRGB(76, 79, 76),
	rockDark = Color3.fromRGB(56, 61, 59),
	trunk = Color3.fromRGB(66, 49, 36),
	pine = Color3.fromRGB(29, 58, 42),
	pineDark = Color3.fromRGB(22, 45, 34),
	hardwood = Color3.fromRGB(48, 70, 42),
	wood = Color3.fromRGB(89, 68, 48),
	structure = Color3.fromRGB(73, 81, 76),
	military = Color3.fromRGB(67, 72, 58),
	water = Color3.fromRGB(47, 77, 83),
	emergency = Color3.fromRGB(184, 41, 29),
	tape = Color3.fromRGB(225, 187, 51),
})

local started = false
local root: Folder? = nil
local insertionSpawn: SpawnLocation? = nil
local playerAddedConnection: RBXScriptConnection? = nil

local function assignInsertion(player: Player)
	local spawn = insertionSpawn
	if spawn ~= nil and spawn.Parent ~= nil then
		player.RespawnLocation = spawn
	end
end

local function makeFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = if canCollide == nil then true else canCollide
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeSegment(
	parent: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?
): Part
	local midpoint = (from + to) / 2
	local length = (to - from).Magnitude
	return makePart(
		parent,
		name,
		Vector3.new(width, height, length),
		CFrame.lookAt(midpoint, to),
		color,
		material,
		canCollide
	)
end

local function markLandmark(model: Model, id: string, displayName: string)
	model:SetAttribute("LandmarkId", id)
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("Graybox", true)
end

local function addPointLight(part: BasePart, color: Color3, range: number, brightness: number, flickers: boolean)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	if flickers then
		part:SetAttribute("BaseLightBrightness", brightness)
		CollectionService:AddTag(part, "LK_EnvironmentFlicker")
	end
end

local function addLabel(parent: Instance, text: string, cframe: CFrame, size: Vector3)
	local sign =
		makePart(parent, "GrayboxLabel", size, cframe, Color3.fromRGB(212, 204, 174), Enum.Material.Wood, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(32, 36, 32)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function buildTerrain(parent: Folder)
	local terrain = makeFolder("TerrainGraybox", parent)
	makePart(
		terrain,
		"ForestFloor",
		Vector3.new(Config.PlayableHalfExtentStuds * 2, 8, Config.PlayableHalfExtentStuds * 2),
		CFrame.new(0, -4, 0),
		COLORS.forestFloor,
		Enum.Material.Ground
	)

	-- Layered shelves establish ridges, ravines, a plateau, and natural walls.
	makePart(
		terrain,
		"NorthwestRidge",
		Vector3.new(225, 16, 92),
		CFrame.new(-175, 6, 215) * CFrame.Angles(0, math.rad(-8), math.rad(2)),
		COLORS.soil,
		Enum.Material.Ground
	)
	makePart(
		terrain,
		"OverlookPlateau",
		Vector3.new(175, 24, 105),
		CFrame.new(178, 10, 205) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.rockDark,
		Enum.Material.Slate
	)
	makePart(
		terrain,
		"WestShelf",
		Vector3.new(82, 12, 220),
		CFrame.new(-276, 4, 35) * CFrame.Angles(0, math.rad(-5), math.rad(-2)),
		COLORS.soil,
		Enum.Material.Ground
	)
	makePart(
		terrain,
		"EastRidge",
		Vector3.new(58, 18, 260),
		CFrame.new(292, 7, 20) * CFrame.Angles(0, math.rad(5), 0),
		COLORS.rockDark,
		Enum.Material.Slate
	)
	makePart(
		terrain,
		"RavineWestBank",
		Vector3.new(72, 8, 250),
		CFrame.new(-18, 1, 10) * CFrame.Angles(0, math.rad(-4), math.rad(-3)),
		COLORS.soil,
		Enum.Material.Ground
	)
	makePart(
		terrain,
		"RavineEastBank",
		Vector3.new(72, 9, 250),
		CFrame.new(71, 2, 8) * CFrame.Angles(0, math.rad(4), math.rad(3)),
		COLORS.soil,
		Enum.Material.Ground
	)

	for index = 1, 9 do
		local z = -250 + index * 55
		makePart(
			terrain,
			"BoundaryRockWest" .. index,
			Vector3.new(34, 26 + (index % 3) * 8, 64),
			CFrame.new(-320, 8, z) * CFrame.Angles(math.rad(index * 3), math.rad(index * 13), math.rad(4)),
			COLORS.rockDark,
			Enum.Material.Slate
		)
		makePart(
			terrain,
			"BoundaryRockEast" .. index,
			Vector3.new(34, 24 + ((index + 1) % 3) * 9, 64),
			CFrame.new(320, 8, z) * CFrame.Angles(math.rad(index * 2), math.rad(-index * 11), math.rad(-4)),
			COLORS.rockDark,
			Enum.Material.Slate
		)
	end

	-- A winding, shallow creek visually divides the center without becoming an arena wall.
	local creekPoints = {
		Vector3.new(2, 0.25, -315),
		Vector3.new(13, 0.25, -210),
		Vector3.new(4, 0.25, -105),
		Vector3.new(28, 0.25, 10),
		Vector3.new(17, 0.25, 112),
		Vector3.new(40, 0.25, 225),
		Vector3.new(31, 0.25, 315),
	}
	for index = 1, #creekPoints - 1 do
		local water = makeSegment(
			terrain,
			"Creek" .. index,
			creekPoints[index],
			creekPoints[index + 1],
			15,
			0.5,
			COLORS.water,
			Enum.Material.Glass,
			false
		)
		water.Transparency = 0.18
		water.Reflectance = 0.08
	end

	-- Switchback trail and logging road give strong navigation lines.
	local roadPoints = {
		Vector3.new(-315, 0.55, -238),
		Vector3.new(-215, 0.55, -190),
		Vector3.new(-92, 0.55, -150),
		Vector3.new(30, 0.55, -112),
		Vector3.new(178, 0.55, -178),
		Vector3.new(315, 0.55, -195),
	}
	for index = 1, #roadPoints - 1 do
		makeSegment(
			terrain,
			"LoggingRoad" .. index,
			roadPoints[index],
			roadPoints[index + 1],
			26,
			1,
			COLORS.road,
			Enum.Material.Ground,
			true
		)
	end
	local trailPoints = {
		Vector3.new(-205, 14.55, 170),
		Vector3.new(-142, 7.5, 124),
		Vector3.new(-175, 2.55, 82),
		Vector3.new(-92, 0.55, 45),
		Vector3.new(25, 0.55, 12),
		Vector3.new(104, 4.5, 94),
		Vector3.new(158, 22.55, 176),
	}
	for index = 1, #trailPoints - 1 do
		makeSegment(
			terrain,
			"SwitchbackTrail" .. index,
			trailPoints[index],
			trailPoints[index + 1],
			9,
			0.7,
			COLORS.trail,
			Enum.Material.Ground,
			true
		)
	end
end

local function buildRangerStation(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "RangerStation"
	model.Parent = parent
	markLandmark(model, "RangerStation", "Ranger Station")
	makePart(
		model,
		"Foundation",
		Vector3.new(42, 2, 28),
		CFrame.new(-220, 1, -190),
		COLORS.rockDark,
		Enum.Material.Concrete
	)
	makePart(
		model,
		"Cabin",
		Vector3.new(36, 15, 23),
		CFrame.new(-220, 9.5, -190),
		COLORS.structure,
		Enum.Material.WoodPlanks
	)
	makePart(
		model,
		"Roof",
		Vector3.new(42, 2, 29),
		CFrame.new(-220, 18, -190) * CFrame.Angles(0, 0, math.rad(6)),
		COLORS.rockDark,
		Enum.Material.Metal
	)
	makePart(
		model,
		"Door",
		Vector3.new(7, 11, 0.8),
		CFrame.new(-220, 7, -201.9),
		Color3.fromRGB(50, 45, 37),
		Enum.Material.Wood
	)
	makePart(model, "Porch", Vector3.new(24, 1, 9), CFrame.new(-220, 1.8, -205), COLORS.wood, Enum.Material.WoodPlanks)
	addLabel(model, "BLACKWATER RANGER DISTRICT", CFrame.new(-220, 14, -202.5), Vector3.new(24, 3, 0.5))
	local emergencyLamp = makePart(
		model,
		"EmergencyLamp",
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(-211, 15, -202.2),
		COLORS.emergency,
		Enum.Material.Neon,
		false
	)
	addPointLight(emergencyLamp, Color3.fromRGB(255, 65, 42), 24, 1.4, true)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SquadInsertion"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(Config.InsertionPosition.x, Config.InsertionPosition.y, Config.InsertionPosition.z)
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = model

	-- A hurried departure: open utility truck, cases, and a broken fence.
	local truck = Instance.new("Model")
	truck.Name = "AbandonedUtilityTruck"
	truck.Parent = model
	makePart(
		truck,
		"Body",
		Vector3.new(9, 4, 18),
		CFrame.new(-254, 3, -177) * CFrame.Angles(0, math.rad(-18), 0),
		Color3.fromRGB(104, 111, 92),
		Enum.Material.Metal
	)
	makePart(
		truck,
		"Cab",
		Vector3.new(9, 6, 7),
		CFrame.new(-252.3, 5, -184) * CFrame.Angles(0, math.rad(-18), 0),
		Color3.fromRGB(104, 111, 92),
		Enum.Material.Metal
	)
	for side = -1, 1, 2 do
		for offset = -5, 5, 10 do
			local wheel = makePart(
				truck,
				"Wheel",
				Vector3.new(2.2, 4.2, 4.2),
				CFrame.new(-254 + side * 4.7, 2, -177 + offset) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(24, 24, 23),
				Enum.Material.SmoothPlastic
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	for index = 1, 4 do
		makePart(
			model,
			"SupplyCase",
			Vector3.new(4, 2, 3),
			CFrame.new(-242 + index * 3, 1.3, -211 + (index % 2) * 4) * CFrame.Angles(0, math.rad(index * 19), 0),
			COLORS.military,
			Enum.Material.Metal
		)
	end
end

local function buildLookout(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "LookoutTower"
	model.Parent = parent
	markLandmark(model, "LookoutTower", "Forest Service Lookout")
	local center = Vector3.new(-205, 15, 170)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			makeSegment(
				model,
				"TowerLeg",
				center + Vector3.new(x * 9, 0, z * 9),
				center + Vector3.new(x * 5, 31, z * 5),
				1.3,
				1.3,
				COLORS.wood,
				Enum.Material.Wood,
				true
			)
		end
	end
	makePart(
		model,
		"Platform",
		Vector3.new(24, 2, 24),
		CFrame.new(-205, 46, 170),
		COLORS.wood,
		Enum.Material.WoodPlanks
	)
	makePart(
		model,
		"Cab",
		Vector3.new(18, 10, 18),
		CFrame.new(-205, 52, 170),
		COLORS.structure,
		Enum.Material.WoodPlanks
	)
	makePart(model, "Roof", Vector3.new(24, 1.5, 24), CFrame.new(-205, 58, 170), COLORS.rockDark, Enum.Material.Metal)
	makeSegment(
		model,
		"Stairs",
		Vector3.new(-217, 15.5, 183),
		Vector3.new(-217, 46, 174),
		4,
		0.8,
		COLORS.wood,
		Enum.Material.WoodPlanks,
		true
	)
	addLabel(model, "LOOKOUT 7", CFrame.new(-205, 53, 160.6), Vector3.new(10, 2.5, 0.4))
end

local function buildCampground(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "Campground"
	model.Parent = parent
	markLandmark(model, "Campground", "Campground")
	for index, position in
		{
			Vector3.new(-113, 2, 32),
			Vector3.new(-78, 2, 28),
			Vector3.new(-106, 2, 68),
		}
	do
		local tent = makePart(
			model,
			"AbandonedTent" .. index,
			Vector3.new(12, 5, 9),
			CFrame.new(position) * CFrame.Angles(0, math.rad(index * 37), math.rad(12)),
			Color3.fromRGB(91, 99, 72),
			Enum.Material.Fabric
		)
		tent.Shape = Enum.PartType.Wedge
	end
	for index = 1, 10 do
		local angle = (index / 10) * math.pi * 2
		makePart(
			model,
			"FireRingStone",
			Vector3.new(2.2, 1.5, 2.2),
			CFrame.new(-91 + math.cos(angle) * 5, 0.9, 48 + math.sin(angle) * 5),
			COLORS.rock,
			Enum.Material.Slate
		)
	end
	makePart(
		model,
		"DeadFire",
		Vector3.new(5, 0.4, 2),
		CFrame.new(-91, 1, 48) * CFrame.Angles(0, math.rad(25), 0),
		Color3.fromRGB(31, 27, 23),
		Enum.Material.Wood,
		false
	)
	for index = 1, 5 do
		makePart(
			model,
			"ScatteredSupply",
			Vector3.new(2 + index % 2, 1, 2),
			CFrame.new(-65 + index * 2, 0.8, 54 + (index % 3) * 3) * CFrame.Angles(0, math.rad(index * 31), 0),
			Color3.fromRGB(120, 111, 83),
			Enum.Material.Fabric
		)
	end
	addLabel(
		model,
		"CAMPSITES 1–6",
		CFrame.new(-124, 5, 54) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(13, 3, 0.4)
	)
end

local function buildCreekCrossing(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "CreekCrossing"
	model.Parent = parent
	markLandmark(model, "CreekCrossing", "Creek Crossing")
	for index = -3, 3 do
		makePart(
			model,
			"BridgePlank",
			Vector3.new(5, 0.8, 13),
			CFrame.new(25 + index * 5, 2.1, 12) * CFrame.Angles(0, math.rad(90), 0),
			COLORS.wood,
			Enum.Material.WoodPlanks
		)
	end
	for side = -1, 1, 2 do
		makeSegment(
			model,
			"BridgeRail",
			Vector3.new(8, 5, 12 + side * 7),
			Vector3.new(42, 5, 12 + side * 7),
			0.8,
			0.8,
			COLORS.wood,
			Enum.Material.Wood,
			true
		)
	end
	makePart(
		model,
		"WashedOutWarning",
		Vector3.new(12, 3, 0.5),
		CFrame.new(42, 4, -1) * CFrame.Angles(0, math.rad(-20), math.rad(8)),
		COLORS.tape,
		Enum.Material.SmoothPlastic,
		false
	)
end

local function buildOverlook(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "RockyOverlook"
	model.Parent = parent
	markLandmark(model, "RockyOverlook", "Rocky Overlook")
	for index = 1, 14 do
		local angle = index * 0.74
		local radius = 12 + (index % 4) * 7
		local rock = makePart(
			model,
			"OverlookRock",
			Vector3.new(10 + index % 5, 7 + index % 6, 12 + (index * 2) % 7),
			CFrame.new(158 + math.cos(angle) * radius, 25 + index % 4, 176 + math.sin(angle) * radius)
				* CFrame.Angles(math.rad(index * 7), math.rad(index * 19), math.rad(index * 3)),
			if index % 2 == 0 then COLORS.rock else COLORS.rockDark,
			Enum.Material.Slate
		)
		rock.Shape = if index % 3 == 0 then Enum.PartType.Ball else Enum.PartType.Block
	end
	makeSegment(
		model,
		"BrokenGuardRail",
		Vector3.new(135, 31, 203),
		Vector3.new(161, 31, 213),
		1,
		1,
		Color3.fromRGB(119, 112, 96),
		Enum.Material.Metal,
		true
	)
	addLabel(
		model,
		"BLACKWATER OVERLOOK",
		CFrame.new(139, 30, 188) * CFrame.Angles(0, math.rad(35), 0),
		Vector3.new(16, 3, 0.4)
	)
end

local function buildRoadblock(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "MilitaryRoadblock"
	model.Parent = parent
	markLandmark(model, "MilitaryRoadblock", "Military Roadblock")
	for index = -2, 2 do
		makePart(
			model,
			"Barrier",
			Vector3.new(10, 3.5, 2.5),
			CFrame.new(180 + index * 10, 2.3, -178 + index % 2 * 5) * CFrame.Angles(0, math.rad(-12), 0),
			if index % 2 == 0 then Color3.fromRGB(198, 195, 174) else COLORS.military,
			Enum.Material.Concrete
		)
	end
	for index = 1, 12 do
		makePart(
			model,
			"Sandbag",
			Vector3.new(4.5, 1.4, 2.2),
			CFrame.new(151 + index * 4.2, 1, -161 + math.sin(index) * 3) * CFrame.Angles(0, math.rad(index * 11), 0),
			Color3.fromRGB(103, 94, 71),
			Enum.Material.Fabric
		)
	end
	local checkpoint = makePart(
		model,
		"CheckpointCabin",
		Vector3.new(16, 9, 12),
		CFrame.new(200, 5, -153),
		COLORS.military,
		Enum.Material.Metal
	)
	local lamp = makePart(
		model,
		"RoadblockEmergencyLight",
		Vector3.new(1.5, 1.5, 1.5),
		checkpoint.CFrame * CFrame.new(0, 5.3, -4),
		COLORS.emergency,
		Enum.Material.Neon,
		false
	)
	addPointLight(lamp, Color3.fromRGB(255, 54, 35), 34, 2.1, true)
	addLabel(model, "QUARANTINE — NO ENTRY", CFrame.new(180, 8, -181), Vector3.new(26, 4, 0.5))
	for index = 1, 5 do
		makeSegment(
			model,
			"PoliceTape",
			Vector3.new(145 + index * 12, 5, -188),
			Vector3.new(154 + index * 12, 5, -185),
			0.3,
			0.3,
			COLORS.tape,
			Enum.Material.Neon,
			false
		)
	end
end

local function buildExtraction(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "ExtractionClearing"
	model.Parent = parent
	markLandmark(model, "ExtractionClearing", "Forest Extraction Clearing")
	local pad = makePart(
		model,
		"ExtractionPad",
		Vector3.new(72, 1, 72),
		CFrame.new(218, 1, 58),
		Color3.fromRGB(61, 67, 58),
		Enum.Material.Ground
	)
	pad:SetAttribute("FutureExtractionZone", true)
	for _, offset in
		{
			Vector3.new(-31, 1.5, -31),
			Vector3.new(31, 1.5, -31),
			Vector3.new(-31, 1.5, 31),
			Vector3.new(31, 1.5, 31),
		}
	do
		local beacon = makePart(
			model,
			"PerimeterBeacon",
			Vector3.new(1.4, 2.4, 1.4),
			CFrame.new(Vector3.new(218, 0, 58) + offset),
			Color3.fromRGB(242, 138, 45),
			Enum.Material.Neon,
			false
		)
		addPointLight(beacon, Color3.fromRGB(255, 142, 51), 25, 1.25, true)
	end
	makePart(
		model,
		"LandingMarkNorth",
		Vector3.new(8, 0.25, 36),
		CFrame.new(218, 1.6, 58),
		Color3.fromRGB(153, 158, 139),
		Enum.Material.Concrete,
		false
	)
	makePart(
		model,
		"LandingMarkCross",
		Vector3.new(36, 0.25, 8),
		CFrame.new(218, 1.6, 58),
		Color3.fromRGB(153, 158, 139),
		Enum.Material.Concrete,
		false
	)
	for index = 1, 7 do
		makePart(
			model,
			"CutStump",
			Vector3.new(4 + index % 3, 2, 4 + index % 3),
			CFrame.new(175 + index * 11, 1.2, 104 + math.sin(index) * 9),
			COLORS.trunk,
			Enum.Material.Wood
		)
	end
	local generator = makePart(
		model,
		"SilentGenerator",
		Vector3.new(7, 5, 5),
		CFrame.new(254, 3, 25),
		Color3.fromRGB(81, 86, 65),
		Enum.Material.Metal
	)
	local generatorLamp = makePart(
		model,
		"GeneratorWorkLight",
		Vector3.new(2, 1, 2),
		generator.CFrame * CFrame.new(0, 4, 0),
		Color3.fromRGB(238, 202, 132),
		Enum.Material.Neon,
		false
	)
	addPointLight(generatorLamp, Color3.fromRGB(255, 220, 160), 38, 2.2, true)
end

local function buildLoggingDetails(parent: Folder)
	local model = Instance.new("Model")
	model.Name = "LoggingRoad"
	model.Parent = parent
	markLandmark(model, "LoggingRoad", "Logging Road")
	for stack = 1, 3 do
		for logIndex = 1, 5 do
			local log = makePart(
				model,
				"CutLog",
				Vector3.new(18, 3, 3),
				CFrame.new(-25 + stack * 22, 2 + (logIndex - 1) * 2.4, -91 + stack * 5)
					* CFrame.Angles(0, 0, math.rad(90)),
				COLORS.trunk,
				Enum.Material.Wood
			)
			log.Shape = Enum.PartType.Cylinder
		end
	end
	makePart(
		model,
		"BrokenUtilityPole",
		Vector3.new(34, 1.5, 1.5),
		CFrame.new(72, 2, -129) * CFrame.Angles(0, math.rad(22), math.rad(5)),
		Color3.fromRGB(75, 57, 41),
		Enum.Material.Wood
	)
end

local function isInsideClearance(x: number, z: number): boolean
	for _, landmark in Config.Landmarks do
		local dx = x - landmark.x
		local dz = z - landmark.z
		local clearance = landmark.radius + Config.Vegetation.MinimumLandmarkClearanceStuds
		if dx * dx + dz * dz < clearance * clearance then
			return true
		end
	end
	-- Preserve the road, creek, and an insertion-to-camp navigation corridor.
	if math.abs(z - (-205 + (x + 220) * 0.42)) < 14 and x < -70 then
		return true
	end
	if math.abs(x - 18) < 18 then
		return true
	end
	return false
end

local function randomOpenPosition(random: Random): Vector3
	for _ = 1, 30 do
		local x = random:NextNumber(-300, 300)
		local z = random:NextNumber(-300, 300)
		if not isInsideClearance(x, z) then
			return Vector3.new(x, 0, z)
		end
	end
	return Vector3.new(random:NextNumber(-300, 300), 0, random:NextNumber(-300, 300))
end

local function buildVegetation(parent: Folder)
	local vegetation = makeFolder("Vegetation", parent)
	local random = Random.new(Config.Seed)
	for index = 1, Config.Vegetation.PineCount do
		local position = randomOpenPosition(random)
		local height = random:NextNumber(27, 49)
		local trunk = makePart(
			vegetation,
			"PineTrunk",
			Vector3.new(2.2, height, 2.2),
			CFrame.new(position + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(0, random:NextNumber(0, math.pi), random:NextNumber(-0.025, 0.025)),
			COLORS.trunk,
			Enum.Material.Wood
		)
		trunk:SetAttribute("VegetationIndex", index)
		for layer = 1, 3 do
			local canopy = makePart(
				vegetation,
				"PineCanopy",
				Vector3.new(12 + layer * 3, 10, 12 + layer * 3),
				CFrame.new(position + Vector3.new(0, height - 5 - layer * 6, 0)),
				if layer == 3 then COLORS.pineDark else COLORS.pine,
				Enum.Material.Grass,
				false
			)
			canopy.Shape = Enum.PartType.Ball
			if index % 5 == 0 and layer == 1 then
				canopy:SetAttribute("WindPhase", random:NextNumber(0, math.pi * 2))
				canopy:SetAttribute("WindStrength", random:NextNumber(0.6, 1.2))
				CollectionService:AddTag(canopy, "LK_WindAnimated")
			end
		end
	end
	for index = 1, Config.Vegetation.HardwoodCount do
		local position = randomOpenPosition(random)
		local height = random:NextNumber(20, 35)
		makePart(
			vegetation,
			"HardwoodTrunk",
			Vector3.new(2.8, height, 2.8),
			CFrame.new(position + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(0, random:NextNumber(0, math.pi), random:NextNumber(-0.04, 0.04)),
			COLORS.trunk,
			Enum.Material.Wood
		)
		for lobe = 1, 3 do
			local offset =
				Vector3.new(random:NextNumber(-4, 4), height + random:NextNumber(-2, 4), random:NextNumber(-4, 4))
			local canopy = makePart(
				vegetation,
				"HardwoodCanopy",
				Vector3.new(15, 11, 15),
				CFrame.new(position + offset),
				if index % 4 == 0 then Color3.fromRGB(73, 77, 43) else COLORS.hardwood,
				Enum.Material.Grass,
				false
			)
			canopy.Shape = Enum.PartType.Ball
			if index % 6 == 0 and lobe == 1 then
				canopy:SetAttribute("WindPhase", random:NextNumber(0, math.pi * 2))
				canopy:SetAttribute("WindStrength", random:NextNumber(0.5, 1))
				CollectionService:AddTag(canopy, "LK_WindAnimated")
			end
		end
	end
	for _ = 1, Config.Vegetation.FallenLogCount do
		local position = randomOpenPosition(random)
		local log = makePart(
			vegetation,
			"FallenLog",
			Vector3.new(random:NextNumber(13, 28), random:NextNumber(2, 4), random:NextNumber(2, 4)),
			CFrame.new(position + Vector3.new(0, 1.7, 0))
				* CFrame.Angles(random:NextNumber(-0.08, 0.08), random:NextNumber(0, math.pi), math.rad(90)),
			COLORS.trunk,
			Enum.Material.Wood
		)
		log.Shape = Enum.PartType.Cylinder
	end
	for index = 1, Config.Vegetation.BoulderCount do
		local position = randomOpenPosition(random)
		local size = random:NextNumber(4, 12)
		local rock = makePart(
			vegetation,
			"Boulder",
			Vector3.new(size, size * random:NextNumber(0.65, 1.15), size * random:NextNumber(0.8, 1.3)),
			CFrame.new(position + Vector3.new(0, size * 0.35, 0))
				* CFrame.Angles(random:NextNumber(0, 1), random:NextNumber(0, math.pi), random:NextNumber(0, 1)),
			if index % 3 == 0 then COLORS.rockDark else COLORS.rock,
			Enum.Material.Slate
		)
		rock.Shape = if index % 4 == 0 then Enum.PartType.Ball else Enum.PartType.Block
	end
end

local function configureLighting()
	Lighting.ClockTime = Config.Lighting.ClockTime
	Lighting.Brightness = Config.Lighting.Brightness
	Lighting.ExposureCompensation = Config.Lighting.ExposureCompensation
	Lighting.Ambient = Color3.fromRGB(61, 70, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 81, 94)
	Lighting.EnvironmentDiffuseScale = 0.48
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.65
	Lighting.FogColor = Color3.fromRGB(83, 95, 103)
	Lighting.FogStart = Config.Lighting.FogStart
	Lighting.FogEnd = Config.Lighting.FogEnd

	for _, childName in { "LivingKingdomsAtmosphere", "LivingKingdomsColorGrade" } do
		local existing = Lighting:FindFirstChild(childName)
		if existing ~= nil then
			existing:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "LivingKingdomsAtmosphere"
	atmosphere.Color = Color3.fromRGB(126, 142, 151)
	atmosphere.Decay = Color3.fromRGB(47, 57, 65)
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.08
	atmosphere.Glare = 0.03
	atmosphere.Haze = 2.1
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LivingKingdomsColorGrade"
	grade.Brightness = 0.02
	grade.Contrast = 0.11
	grade.Saturation = -0.24
	grade.TintColor = Color3.fromRGB(205, 216, 221)
	grade.Parent = Lighting
	local existingClouds = Workspace.Terrain:FindFirstChild("LivingKingdomsClouds")
	if existingClouds ~= nil then
		existingClouds:Destroy()
	end
	local clouds = Instance.new("Clouds")
	clouds.Name = "LivingKingdomsClouds"
	clouds.Cover = 0.74
	clouds.Density = 0.68
	clouds.Color = Color3.fromRGB(88, 97, 104)
	clouds.Parent = Workspace.Terrain
end

function WorldFoundationService.start()
	if started then
		return
	end
	started = true
	local existing = Workspace:FindFirstChild(Config.WorldRootName)
	if existing ~= nil then
		existing:Destroy()
	end
	local worldRoot = makeFolder(Config.WorldRootName, Workspace)
	worldRoot:SetAttribute("WorldFoundationVersion", Config.Version)
	worldRoot:SetAttribute("EnvironmentOnly", true)
	root = worldRoot
	configureLighting()
	buildTerrain(worldRoot)
	local landmarks = makeFolder("Landmarks", worldRoot)
	buildRangerStation(landmarks)
	buildLoggingDetails(landmarks)
	buildLookout(landmarks)
	buildCampground(landmarks)
	buildCreekCrossing(landmarks)
	buildOverlook(landmarks)
	buildRoadblock(landmarks)
	buildExtraction(landmarks)
	buildVegetation(worldRoot)
	local generatedSpawn = worldRoot:FindFirstChild("SquadInsertion", true)
	assert(generatedSpawn ~= nil and generatedSpawn:IsA("SpawnLocation"), "world insertion spawn was not generated")
	insertionSpawn = generatedSpawn
	for _, player in Players:GetPlayers() do
		assignInsertion(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(assignInsertion)
	print("[Living Kingdoms] World foundation ready: " .. Config.Version)
end

function WorldFoundationService.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	local spawn = insertionSpawn
	if spawn ~= nil then
		for _, player in Players:GetPlayers() do
			if player.RespawnLocation == spawn then
				player.RespawnLocation = nil
			end
		end
		insertionSpawn = nil
	end
	if root ~= nil then
		root:Destroy()
		root = nil
	end
end

return WorldFoundationService
