--!strict

-- Source-generated starter asset library for Living Kingdoms.
-- These prototypes make the modular content contract usable before authored meshes land.
-- Gameplay authority stays outside this module: no AI, damage, loot, persistence, or interaction logic lives here.

local Catalog = require(script.Parent.Parent.Config.ModularAssetProductionCatalog)

local Factory = {}

local COLORS = {
	Floor = Color3.fromRGB(67, 72, 75),
	Wall = Color3.fromRGB(82, 86, 87),
	Trim = Color3.fromRGB(123, 113, 92),
	Metal = Color3.fromRGB(80, 88, 94),
	DarkMetal = Color3.fromRGB(41, 46, 51),
	Enemy = Color3.fromRGB(91, 100, 91),
	EnemyDark = Color3.fromRGB(44, 49, 48),
	EnemyArmor = Color3.fromRGB(64, 75, 80),
	Corruption = Color3.fromRGB(95, 49, 112),
	Weapon = Color3.fromRGB(57, 63, 68),
	WeaponAccent = Color3.fromRGB(123, 151, 158),
	Wood = Color3.fromRGB(92, 69, 49),
	Stone = Color3.fromRGB(91, 89, 82),
	Plant = Color3.fromRGB(52, 83, 57),
}

local REWARD_COLORS = {
	Common = Color3.fromRGB(151, 151, 145),
	Rare = Color3.fromRGB(77, 130, 167),
	Epic = Color3.fromRGB(132, 83, 163),
	Legendary = Color3.fromRGB(203, 145, 55),
	Boss = Color3.fromRGB(174, 65, 55),
	Secret = Color3.fromRGB(72, 177, 157),
	Event = Color3.fromRGB(218, 187, 92),
}

local function decorate(instance: Instance, assetId: string, packId: string)
	instance:SetAttribute("AssetId", assetId)
	instance:SetAttribute("PackId", packId)
	instance:SetAttribute("CatalogVersion", Catalog.Version)
	instance:SetAttribute("GeneratedPrototype", true)
	instance:SetAttribute("PresentationOnly", true)
end

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = part.Transparency < 1
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createCylinder(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = createPart(parent, name, size, position, color, material, nil)
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	return part
end

local function createBall(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = createPart(parent, name, size, position, color, material, nil)
	part.Shape = Enum.PartType.Ball
	return part
end

local function createSocket(parent: BasePart, name: string, position: Vector3, kind: string): Attachment
	local socket = Instance.new("Attachment")
	socket.Name = name
	socket.Position = position
	socket:SetAttribute("SocketKind", kind)
	socket.Parent = parent
	return socket
end

local function createModel(parent: Instance, name: string, assetId: string, packId: string): Model
	local model = Instance.new("Model")
	model.Name = name
	decorate(model, assetId, packId)
	model.Parent = parent
	return model
end

local function createPackFolder(parent: Instance, name: string, packId: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	decorate(folder, packId, packId)
	folder.Parent = parent
	return folder
end

local function readableName(assetId: string): string
	local result = assetId:gsub("[._]", " ")
	return result:gsub("(%a)([%w']*)", function(first, rest)
		return string.upper(first) .. rest
	end)
end

local function addDungeonSockets(root: BasePart, halfX: number, halfZ: number)
	createSocket(root, "Snap_North", Vector3.new(0, 0, -halfZ), Catalog.Dungeon.SnapSocketKind)
	createSocket(root, "Snap_South", Vector3.new(0, 0, halfZ), Catalog.Dungeon.SnapSocketKind)
	createSocket(root, "Snap_West", Vector3.new(-halfX, 0, 0), Catalog.Dungeon.SnapSocketKind)
	createSocket(root, "Snap_East", Vector3.new(halfX, 0, 0), Catalog.Dungeon.SnapSocketKind)
end

local function buildDungeonModule(parent: Instance, definition): Model
	local assetId = definition.id
	local model = createModel(parent, readableName(assetId), assetId, "pack.modular_dungeon")
	model:SetAttribute("ModuleFamily", definition.family)
	model:SetAttribute("ModuleVariant", definition.variant)
	model:SetAttribute("GridStuds", Catalog.Dungeon.GridStuds)

	local floorSize = Vector3.new(32, 1, 32)
	if definition.family == "Corridor" or definition.family == "Door" or definition.family == "Transition" then
		floorSize = Vector3.new(16, 1, 32)
	elseif definition.family == "Arena" then
		floorSize = Vector3.new(64, 1, 64)
	elseif definition.family == "Platform" or definition.family == "DeadEnd" then
		floorSize = Vector3.new(24, 1, 24)
	end

	local floor = createPart(model, "Root", floorSize, Vector3.new(0, 0, 0), COLORS.Floor, Enum.Material.Slate, nil)
	floor.CanCollide = true
	model.PrimaryPart = floor
	addDungeonSockets(floor, floorSize.X / 2, floorSize.Z / 2)

	local wallHeight = Catalog.Dungeon.WallHeightStuds
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local function wall(name: string, size: Vector3, position: Vector3)
		local part = createPart(model, name, size, position, COLORS.Wall, Enum.Material.Concrete, nil)
		part.CanCollide = true
	end

	if definition.family == "Corridor" then
		wall("Wall_Left", Vector3.new(1, wallHeight, floorSize.Z), Vector3.new(-halfX, wallHeight / 2, 0))
		wall("Wall_Right", Vector3.new(1, wallHeight, floorSize.Z), Vector3.new(halfX, wallHeight / 2, 0))
		if definition.variant == "Broken" then
			local breach = model:FindFirstChild("Wall_Right")
			if breach and breach:IsA("BasePart") then
				breach.Size = Vector3.new(1, wallHeight * 0.55, floorSize.Z * 0.42)
				breach.Position += Vector3.new(0, -wallHeight * 0.2, -floorSize.Z * 0.2)
			end
		elseif definition.variant == "Curved" then
			local turn = createPart(model, "TurnGuide", Vector3.new(floorSize.X, 1, floorSize.X), Vector3.new(halfX / 2, 0.05, halfZ - halfX / 2), COLORS.Trim, Enum.Material.Slate, nil)
			turn.CanCollide = true
		end
	elseif definition.family == "Door" then
		wall("Frame_Left", Vector3.new(3, wallHeight, 2), Vector3.new(-5.5, wallHeight / 2, 0))
		wall("Frame_Right", Vector3.new(3, wallHeight, 2), Vector3.new(5.5, wallHeight / 2, 0))
		wall("Frame_Top", Vector3.new(8, 4, 2), Vector3.new(0, wallHeight - 2, 0))
		local door = createPart(model, "DoorPanel", Vector3.new(8, 14, 1), Vector3.new(0, 7, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
		door.CanCollide = true
		door:SetAttribute("DoorVariant", definition.variant)
		createSocket(door, "Interaction", Vector3.new(3, 0, -0.6), "Interaction")
	elseif definition.family == "Transition" and definition.variant == "Stairs" then
		for index = 1, 8 do
			local step = createPart(model, "Step_" .. tostring(index), Vector3.new(14, 1, 4), Vector3.new(0, index - 0.5, -14 + index * 3.5), COLORS.Stone, Enum.Material.Concrete, nil)
			step.CanCollide = true
		end
	elseif definition.family == "Transition" and definition.variant == "Bridge" then
		for index = 1, 7 do
			local plank = createPart(model, "BridgeDeck_" .. tostring(index), Vector3.new(14, 1, 3.5), Vector3.new(0, 3, -12 + index * 4), COLORS.Trim, Enum.Material.WoodPlanks, nil)
			plank.CanCollide = true
		end
	elseif definition.family == "Platform" then
		floor.Position = Vector3.new(0, 8, 0)
		for _, x in ipairs({ -halfX + 2, halfX - 2 }) do
			for _, z in ipairs({ -halfZ + 2, halfZ - 2 }) do
				local support = createPart(model, "Support", Vector3.new(2, 8, 2), Vector3.new(x, 4, z), COLORS.DarkMetal, Enum.Material.Metal, nil)
				support.CanCollide = true
			end
		end
	elseif definition.family == "Arena" then
		for _, offset in ipairs({ Vector3.new(-halfX, wallHeight / 2, 0), Vector3.new(halfX, wallHeight / 2, 0), Vector3.new(0, wallHeight / 2, -halfZ), Vector3.new(0, wallHeight / 2, halfZ) }) do
			local horizontal = math.abs(offset.X) > 0
			wall("ArenaWall", horizontal and Vector3.new(1, wallHeight, floorSize.Z) or Vector3.new(floorSize.X, wallHeight, 1), offset)
		end
		createSocket(floor, "BossAnchor", Vector3.new(0, 1, 0), "EncounterAnchor")
	else
		wall("Wall_West", Vector3.new(1, wallHeight, floorSize.Z), Vector3.new(-halfX, wallHeight / 2, 0))
		wall("Wall_East", Vector3.new(1, wallHeight, floorSize.Z), Vector3.new(halfX, wallHeight / 2, 0))
		if definition.variant == "Secret" then
			model:SetAttribute("HiddenByDefault", true)
		elseif definition.variant == "Treasure" or definition.variant == "Loot" then
			createSocket(floor, "RewardAnchor", Vector3.new(0, 1, 0), "RewardAnchor")
		elseif definition.variant == "Combat" then
			createSocket(floor, "EncounterAnchor", Vector3.new(0, 1, 0), "EncounterAnchor")
		elseif definition.variant == "Puzzle" then
			createSocket(floor, "PuzzleAnchor", Vector3.new(0, 1, 0), "PuzzleAnchor")
		end
	end

	return model
end

local function choice(values, seed: number, salt: number): string
	local index = ((math.abs(seed) + salt * 17) % #values) + 1
	return values[index]
end

local function enemyScale(archetype: string): number
	if archetype == "Heavy" then
		return 1.28
	elseif archetype == "Sniper" then
		return 1.08
	elseif archetype == "Support" then
		return 1.04
	elseif archetype == "Elite" then
		return 1.18
	elseif archetype == "Corrupted" then
		return 1.12
	end
	return 1
end

local function buildEnemyWeapon(parent: Instance, weaponId: string, scale: number)
	local melee = weaponId:find("blade", 1, true) ~= nil
	local bodySize = melee and Vector3.new(0.55, 0.55, 5.5) or Vector3.new(1, 1, 4.5)
	local weapon = createPart(parent, "Weapon", bodySize * scale, Vector3.new(2.25 * scale, 4.1 * scale, -0.5 * scale), COLORS.Weapon, Enum.Material.Metal, nil)
	weapon:SetAttribute("VisualPartId", weaponId)
	if melee then
		weapon.Orientation = Vector3.new(0, 0, -18)
	else
		createSocket(weapon, "Muzzle", Vector3.new(0, 0, -bodySize.Z / 2), "Muzzle")
	end
end

function Factory.BuildEnemyVariant(parent: Instance, archetype: string, seed: number?): Model
	local actualSeed = seed or 1
	local scale = enemyScale(archetype)
	local bodyId = choice(Catalog.Enemies.Bodies, actualSeed, 1)
	local headId = choice(Catalog.Enemies.Heads, actualSeed, 2)
	local armorId = choice(Catalog.Enemies.Armor, actualSeed, 3)
	local weaponId = choice(Catalog.Enemies.Weapons, actualSeed, 4)
	local accessoryId = choice(Catalog.Enemies.Accessories, actualSeed, 5)
	local assetId = "enemy.archetype." .. string.lower(archetype)
	local model = createModel(parent, archetype, assetId, "pack.modular_enemy")
	model:SetAttribute("Archetype", archetype)
	model:SetAttribute("VariantSeed", actualSeed)
	model:SetAttribute("BodyPartId", bodyId)
	model:SetAttribute("HeadPartId", headId)
	model:SetAttribute("ArmorPartId", armorId)
	model:SetAttribute("WeaponPartId", weaponId)
	model:SetAttribute("AccessoryPartId", accessoryId)

	local enemyColor = archetype == "Corrupted" and COLORS.Corruption or COLORS.Enemy
	local root = createPart(model, "Root", Vector3.new(2.5, 4, 1.6) * scale, Vector3.new(0, 4 * scale, 0), enemyColor, Enum.Material.SmoothPlastic, 1)
	root.CanQuery = false
	model.PrimaryPart = root
	createSocket(root, "TargetCenter", Vector3.new(0, 0.6 * scale, 0), "Target")

	local torso = createPart(model, "Body", Vector3.new(3.1, 3.5, 1.8) * scale, Vector3.new(0, 4.2 * scale, 0), enemyColor, Enum.Material.SmoothPlastic, nil)
	torso:SetAttribute("VisualPartId", bodyId)
	local head = createPart(model, "Head", Vector3.new(2.1, 2.1, 2) * scale, Vector3.new(0, 7.05 * scale, 0), COLORS.EnemyDark, Enum.Material.SmoothPlastic, nil)
	head:SetAttribute("VisualPartId", headId)
	local armor = createPart(model, "Armor", Vector3.new(3.35, 2.25, 2.05) * scale, Vector3.new(0, 4.65 * scale, -0.05 * scale), archetype == "Corrupted" and COLORS.Corruption or COLORS.EnemyArmor, Enum.Material.Metal, nil)
	armor:SetAttribute("VisualPartId", armorId)

	for _, x in ipairs({ -1.05, 1.05 }) do
		createPart(model, "Leg", Vector3.new(0.9, 3.2, 1) * scale, Vector3.new(x * scale, 1.6 * scale, 0), enemyColor, Enum.Material.SmoothPlastic, nil)
		createPart(model, "Arm", Vector3.new(0.85, 3.1, 0.9) * scale, Vector3.new(x * 1.85 * scale, 4.35 * scale, 0), enemyColor, Enum.Material.SmoothPlastic, nil)
	end

	if accessoryId ~= "accessory.none" then
		local accessory = createPart(model, "Accessory", Vector3.new(1.7, 2.5, 0.8) * scale, Vector3.new(0, 4.65 * scale, 1.25 * scale), COLORS.DarkMetal, Enum.Material.Metal, nil)
		accessory:SetAttribute("VisualPartId", accessoryId)
	end
	buildEnemyWeapon(model, weaponId, scale)

	if archetype == "Elite" then
		model:SetAttribute("EliteVisual", true)
		createBall(model, "EliteCore", Vector3.new(0.65, 0.65, 0.65) * scale, Vector3.new(0, 5.2 * scale, -1.2 * scale), Color3.fromRGB(216, 155, 65), Enum.Material.Neon)
	elseif archetype == "Corrupted" then
		for index = 1, 3 do
			createBall(model, "CorruptionNode_" .. tostring(index), Vector3.new(0.6, 0.6, 0.6) * scale, Vector3.new((index - 2) * 0.8 * scale, (5 + index * 0.35) * scale, -1.15 * scale), COLORS.Corruption, Enum.Material.Neon)
		end
	end

	return model
end

local function weaponDimensions(category: string): (number, number, number)
	if category == "SMG" then
		return 4.8, 1.25, 0.95
	elseif category == "Shotgun" then
		return 7.6, 1.25, 1.05
	elseif category == "HandCannon" then
		return 3.6, 1.5, 1.1
	elseif category == "SniperRifle" then
		return 9.4, 1.15, 0.9
	elseif category == "LMG" then
		return 7.8, 1.8, 1.35
	elseif category == "Launcher" then
		return 7, 2.1, 1.7
	elseif category == "Exotic" then
		return 7.2, 1.55, 1.2
	end
	return 6.6, 1.35, 1
end

local function buildWeapon(parent: Instance, definition): Model
	local model = createModel(parent, definition.category, definition.id, "pack.player_weapons")
	model:SetAttribute("WeaponCategory", definition.category)
	local length, width, height = weaponDimensions(definition.category)
	local receiver = createPart(model, "Root", Vector3.new(width, height, length * 0.52), Vector3.new(0, 1.8, 0), COLORS.Weapon, Enum.Material.Metal, nil)
	model.PrimaryPart = receiver
	local barrel = createPart(model, "Barrel", Vector3.new(width * 0.48, height * 0.48, length * 0.48), Vector3.new(0, 1.85, -(length * 0.47)), COLORS.DarkMetal, Enum.Material.Metal, nil)
	local grip = createPart(model, "GripVisual", Vector3.new(width * 0.55, 1.65, 0.75), Vector3.new(0, 0.75, 0.55), COLORS.DarkMetal, Enum.Material.Metal, nil)
	grip.Orientation = Vector3.new(-12, 0, 0)
	createSocket(receiver, "Grip", Vector3.new(0, -height / 2, 0.35), "Grip")
	createSocket(barrel, "Muzzle", Vector3.new(0, 0, -barrel.Size.Z / 2), "Muzzle")
	createSocket(receiver, "Secondary", Vector3.new(0, height / 2, 0), "WeaponSecondary")

	if definition.category == "SniperRifle" then
		createCylinder(model, "Scope", Vector3.new(0.65, 2.8, 0.65), Vector3.new(0, 2.7, -0.2), COLORS.DarkMetal, Enum.Material.Metal)
	elseif definition.category == "LMG" then
		createPart(model, "Magazine", Vector3.new(1.5, 1.7, 1.4), Vector3.new(0, 0.95, -0.3), COLORS.DarkMetal, Enum.Material.Metal, nil)
	elseif definition.category == "Launcher" then
		createCylinder(model, "LaunchTube", Vector3.new(1.7, length * 0.72, 1.7), Vector3.new(0, 2.05, -0.8), COLORS.DarkMetal, Enum.Material.Metal)
	elseif definition.category == "Exotic" then
		createBall(model, "EnergyCore", Vector3.new(0.85, 0.85, 0.85), Vector3.new(0, 2.05, -0.8), Color3.fromRGB(88, 201, 204), Enum.Material.Neon)
	elseif definition.category == "Shotgun" then
		createPart(model, "Pump", Vector3.new(width * 0.85, height * 0.9, 1.8), Vector3.new(0, 1.75, -2.1), COLORS.Wood, Enum.Material.Wood, nil)
	elseif definition.category == "HandCannon" then
		createCylinder(model, "Cylinder", Vector3.new(1.2, 1.35, 1.2), Vector3.new(0, 1.9, -0.15), COLORS.WeaponAccent, Enum.Material.Metal)
	end
	return model
end

local function buildProp(parent: Instance, definition): Model
	local model = createModel(parent, definition.category, definition.id, "pack.environment_props")
	model:SetAttribute("PropCategory", definition.category)
	local root: Part

	if definition.category == "Crate" then
		root = createPart(model, "Root", Vector3.new(5, 4, 5), Vector3.new(0, 2, 0), COLORS.Wood, Enum.Material.WoodPlanks, nil)
	elseif definition.category == "Barrel" then
		root = createCylinder(model, "Root", Vector3.new(3, 4.5, 3), Vector3.new(0, 2.25, 0), COLORS.Metal, Enum.Material.Metal)
	elseif definition.category == "Pipe" then
		root = createCylinder(model, "Root", Vector3.new(1.5, 8, 1.5), Vector3.new(0, 1.5, 0), COLORS.DarkMetal, Enum.Material.Metal)
	elseif definition.category == "Terminal" then
		root = createPart(model, "Root", Vector3.new(3.5, 5, 2), Vector3.new(0, 2.5, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
		createPart(model, "Screen", Vector3.new(2.7, 1.7, 0.12), Vector3.new(0, 3.2, -1.06), Color3.fromRGB(67, 165, 169), Enum.Material.Neon, nil)
		createSocket(root, "Interaction", Vector3.new(0, 0.5, -1.1), "Interaction")
	elseif definition.category == "Desk" then
		root = createPart(model, "Root", Vector3.new(7, 0.5, 3), Vector3.new(0, 3.2, 0), COLORS.Wood, Enum.Material.WoodPlanks, nil)
		for _, x in ipairs({ -2.7, 2.7 }) do
			createPart(model, "Leg", Vector3.new(0.5, 3, 0.5), Vector3.new(x, 1.5, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
		end
	elseif definition.category == "Shelf" then
		root = createPart(model, "Root", Vector3.new(6, 0.45, 2), Vector3.new(0, 0.4, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
		for level = 1, 4 do
			createPart(model, "Shelf_" .. tostring(level), Vector3.new(6, 0.35, 2), Vector3.new(0, level * 2, 0), COLORS.Metal, Enum.Material.Metal, nil)
		end
	elseif definition.category == "BrokenMachinery" then
		root = createPart(model, "Root", Vector3.new(6, 3.5, 4), Vector3.new(0, 1.75, 0), COLORS.DarkMetal, Enum.Material.CorrodedMetal, nil)
		createCylinder(model, "BrokenAxle", Vector3.new(1, 5, 1), Vector3.new(1.5, 3.7, -0.4), COLORS.Metal, Enum.Material.CorrodedMetal).Orientation = Vector3.new(15, 0, 70)
	elseif definition.category == "Sign" then
		root = createPart(model, "Root", Vector3.new(0.6, 7, 0.6), Vector3.new(0, 3.5, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
		createPart(model, "SignFace", Vector3.new(6, 2.6, 0.35), Vector3.new(0, 6, 0), COLORS.Trim, Enum.Material.Metal, nil)
	elseif definition.category == "Lamp" then
		root = createPart(model, "Root", Vector3.new(0.5, 7, 0.5), Vector3.new(0, 3.5, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
		createBall(model, "Lamp", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 7.3, 0), Color3.fromRGB(227, 187, 104), Enum.Material.Neon)
	elseif definition.category == "Debris" then
		root = createPart(model, "Root", Vector3.new(4.5, 0.7, 2), Vector3.new(0, 0.4, 0), COLORS.Stone, Enum.Material.Concrete, nil)
		for index = 1, 3 do
			local chunk = createPart(model, "Chunk_" .. tostring(index), Vector3.new(1.2 + index * 0.4, 0.8, 1.5), Vector3.new(index * 1.1 - 2, 0.7, index % 2), COLORS.Stone, Enum.Material.Concrete, nil)
			chunk.Orientation = Vector3.new(index * 9, index * 21, index * 5)
		end
	elseif definition.category == "Rock" then
		root = createBall(model, "Root", Vector3.new(5.5, 3.8, 4.7), Vector3.new(0, 1.8, 0), COLORS.Stone, Enum.Material.Rock)
		root.Orientation = Vector3.new(9, 23, 6)
	else
		root = createPart(model, "Root", Vector3.new(0.8, 4.5, 0.8), Vector3.new(0, 2.25, 0), COLORS.Plant, Enum.Material.Grass, nil)
		for index = 1, 5 do
			local leaf = createPart(model, "Leaf_" .. tostring(index), Vector3.new(0.4, 3, 1), Vector3.new((index - 3) * 0.45, 3.6, 0), COLORS.Plant, Enum.Material.Grass, nil)
			leaf.Orientation = Vector3.new(index * 7 - 21, index * 31, index * 5 - 15)
		end
	end

	root.CanCollide = true
	model.PrimaryPart = root
	return model
end

local function buildRewardContainer(parent: Instance, definition): Model
	local model = createModel(parent, definition.tier .. " Chest", definition.id, "pack.reward_containers")
	model:SetAttribute("RewardTier", definition.tier)
	local accent = REWARD_COLORS[definition.tier] or REWARD_COLORS.Common
	local base = createPart(model, "Root", Vector3.new(6, 2.4, 4), Vector3.new(0, 1.2, 0), COLORS.DarkMetal, Enum.Material.Metal, nil)
	base.CanCollide = true
	model.PrimaryPart = base
	createPart(model, "Lid", Vector3.new(6.2, 1.5, 4.2), Vector3.new(0, 3.1, 0), accent, Enum.Material.Metal, nil)
	createPart(model, "Latch", Vector3.new(1.1, 1.3, 0.45), Vector3.new(0, 2.2, -2.2), accent, Enum.Material.Neon, nil)
	createSocket(base, "RewardOrigin", Vector3.new(0, 2.4, 0), "RewardOrigin")
	createSocket(base, "Interaction", Vector3.new(0, 0.7, -2.1), "Interaction")
	if definition.tier == "Boss" or definition.tier == "Legendary" or definition.tier == "Event" then
		for _, x in ipairs({ -2.5, 2.5 }) do
			createPart(model, "TierFin", Vector3.new(0.45, 2.8, 4.5), Vector3.new(x, 2.5, 0), accent, Enum.Material.Metal, nil)
		end
	end
	return model
end

local function buildEnemyPartLibrary(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Parts"
	folder.Parent = parent
	local groups = {
		Bodies = Catalog.Enemies.Bodies,
		Heads = Catalog.Enemies.Heads,
		Armor = Catalog.Enemies.Armor,
		Weapons = Catalog.Enemies.Weapons,
		Accessories = Catalog.Enemies.Accessories,
	}
	for groupName, values in pairs(groups) do
		local group = Instance.new("Folder")
		group.Name = groupName
		group.Parent = folder
		for _, assetId in ipairs(values) do
			local marker = Instance.new("Folder")
			marker.Name = readableName(assetId)
			decorate(marker, assetId, "pack.modular_enemy")
			marker:SetAttribute("PartGroup", groupName)
			marker.Parent = group
		end
	end
end

function Factory.BuildStarterLibrary(parent: Instance): Folder
	local library = Instance.new("Folder")
	library.Name = "StarterLibrary"
	decorate(library, "library.modular_assets.starter", "pack.modular_assets")
	library.Parent = parent

	local dungeon = createPackFolder(library, "Dungeon", "pack.modular_dungeon")
	for _, definition in ipairs(Catalog.Dungeon.Modules) do
		buildDungeonModule(dungeon, definition)
	end

	local enemies = createPackFolder(library, "Enemies", "pack.modular_enemy")
	buildEnemyPartLibrary(enemies)
	local archetypes = Instance.new("Folder")
	archetypes.Name = "Archetypes"
	archetypes.Parent = enemies
	for index, archetype in ipairs(Catalog.Enemies.Archetypes) do
		Factory.BuildEnemyVariant(archetypes, archetype, 100 + index * 29)
	end

	local weapons = createPackFolder(library, "Weapons", "pack.player_weapons")
	for _, definition in ipairs(Catalog.Weapons.Categories) do
		buildWeapon(weapons, definition)
	end

	local props = createPackFolder(library, "Props", "pack.environment_props")
	for _, definition in ipairs(Catalog.Props.Categories) do
		buildProp(props, definition)
	end

	local rewards = createPackFolder(library, "RewardContainers", "pack.reward_containers")
	for _, definition in ipairs(Catalog.RewardContainers.Tiers) do
		buildRewardContainer(rewards, definition)
	end

	library:SetAttribute("DungeonPrototypeCount", #Catalog.Dungeon.Modules)
	library:SetAttribute("EnemyArchetypeCount", #Catalog.Enemies.Archetypes)
	library:SetAttribute("EnemyBaseCombinationCount", #Catalog.Enemies.Bodies * #Catalog.Enemies.Heads * #Catalog.Enemies.Armor * #Catalog.Enemies.Weapons)
	library:SetAttribute("WeaponPrototypeCount", #Catalog.Weapons.Categories)
	library:SetAttribute("PropPrototypeCount", #Catalog.Props.Categories)
	library:SetAttribute("RewardContainerPrototypeCount", #Catalog.RewardContainers.Tiers)
	return library
end

return table.freeze(Factory)
