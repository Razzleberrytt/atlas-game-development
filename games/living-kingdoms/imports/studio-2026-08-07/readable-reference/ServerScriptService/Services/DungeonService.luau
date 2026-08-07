-- DungeonService: Procedural dungeon generation with room layout, corridors, encounters, and RNG modifiers
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DungeonDefs = require(ReplicatedStorage.Shared.Config.DungeonDefinitions)
local EnemyDefs = require(ReplicatedStorage.Shared.Config.EnemyDefinitions)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)

local DungeonService = {}

-- Dependencies
local enemyService
local lootService
local combatService
local playerDataService
local inventoryService

function DungeonService.setDependencies(enemy, loot, combat, pds, inv)
	enemyService = enemy
	lootService = loot
	combatService = combat
	playerDataService = pds
	inventoryService = inv
end

-- Generates a dungeon layout from a seed
function DungeonService.generateDungeon(dungeonId, seed, origin)
	local def = DungeonDefs.Dungeons[dungeonId or "prototype_dungeon"]
	if not def then return nil end

	seed = seed or RandomUtility.generateSeed()
	local rng = RandomUtility.fromSeed(seed)

	-- Roll dungeon modifiers using RNG engine
	local modifiers = RNGEngine.rollDungeonModifiers(rng)
	local modifierEffects = RNGEngine.aggregateDungeonEffects(modifiers)

	-- Apply room count multiplier from modifiers
	local numRooms = RandomUtility.int(def.minRooms, def.maxRooms, rng)
	if modifierEffects.roomCountMult then
		numRooms = math.floor(numRooms * modifierEffects.roomCountMult)
	end

	local rooms = {}
	local corridors = {}

	-- Generate rooms in a roughly linear path with some branches
	local currentPos = origin or Vector3.new(0, 0, 0)
	local direction = CFrame.new()

	for i = 1, numRooms do
		-- Determine room type
		local roomType = "normal"
		if i == numRooms then
			roomType = "boss"
		else
			local typeEntries = {}
			for rtype, config in def.roomTypes do
				table.insert(typeEntries, {item = rtype, weight = config.weight})
			end
			roomType = RandomUtility.weighted(typeEntries, rng)
		end

		-- Room size
		local roomSize = def.roomSize
		if roomType == "boss" then
			roomSize = DungeonDefs.RoomTypes.boss.size or Vector3.new(60, 16, 60)
		end

		-- Room position (spread along z-axis with slight x variation)
		local roomPos = currentPos
		local room = {
			index = i,
			roomType = roomType,
			position = roomPos,
			size = roomSize,
			doorways = {},
			spawnPoints = {},
			chestPosition = nil,
			enemiesSpawned = false,
			cleared = false,
			isSecret = roomType == "secret",
		}

		-- Add secret room (off the main path)
		if def.hasSecret and i == math.floor(numRooms / 2) then
			local secretPos = roomPos + Vector3.new(50, 0, 0)
			local secretRoom = {
				index = i + 0.5,
				roomType = "secret",
				position = secretPos,
				size = def.roomSize,
				doorways = {},
				spawnPoints = {},
				chestPosition = secretPos + Vector3.new(0, 2, 0),
				enemiesSpawned = false,
				cleared = false,
				isSecret = true,
				connectedTo = i,
			}
			table.insert(rooms, secretRoom)
		end

		table.insert(rooms, room)

		-- Create corridor to next room
		if i < numRooms then
			local corridorLength = def.corridorLength
			local nextRoomPos = roomPos + Vector3.new(0, 0, -(roomSize.Z / 2 + corridorLength + roomSize.Z / 2))
			local corridor = {
				from = i,
				to = i + 1,
				position = roomPos + Vector3.new(0, 0, -(roomSize.Z / 2 + corridorLength / 2)),
				size = Vector3.new(def.corridorWidth, def.corridorHeight, corridorLength),
			}
			table.insert(corridors, corridor)
			currentPos = nextRoomPos
		end
	end

	-- Sort rooms by index
	table.sort(rooms, function(a, b) return a.index < b.index end)

	return {
		seed = seed,
		defId = def.id,
		name = def.name,
		rooms = rooms,
		corridors = corridors,
		currentRoomIndex = 1,
		isComplete = false,
		parts = {}, -- physical parts for cleanup
		modifiers = modifiers,
		modifierEffects = modifierEffects,
	}
end

-- Builds the physical geometry of a dungeon in the workspace
function DungeonService.buildDungeon(dungeon, parentFolder)
	local def = DungeonDefs.Dungeons[dungeon.defId]
	if not def then return end

	local dungeonFolder = Instance.new("Folder")
	 dungeonFolder.Name = "DungeonRuntime"
	if parentFolder then
		dungeonFolder.Parent = parentFolder
	else
		dungeonFolder.Parent = workspace
	end

	-- Build rooms
	for _, room in dungeon.rooms do
		local roomFolder = Instance.new("Folder")
		roomFolder.Name = "Room_" .. tostring(room.index) .. "_" .. room.roomType
		roomFolder.Parent = dungeonFolder

		-- Floor
		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Size = Vector3.new(room.size.X, 1, room.size.Z)
		floor.Position = room.position + Vector3.new(0, 0, 0)
		floor.Anchored = true
		floor.CanCollide = true
		floor.Color = def.floorColor
		floor.Material = Enum.Material.Plastic
		floor.Parent = roomFolder

		-- Ceiling
		local ceiling = Instance.new("Part")
		ceiling.Name = "Ceiling"
		ceiling.Size = Vector3.new(room.size.X, 1, room.size.Z)
		ceiling.Position = room.position + Vector3.new(0, room.size.Y, 0)
		ceiling.Anchored = true
		ceiling.CanCollide = true
		ceiling.Color = def.ceilingColor
		ceiling.Material = Enum.Material.Plastic
		ceiling.Parent = roomFolder

		-- Walls (north, south, east, west)
		local wallThickness = 2
		local wallHeight = room.size.Y

		-- Determine if this room has corridors connecting to north/south
		local hasNorthDoor = false
		local hasSouthDoor = false
		local hasEastDoor = false
		local hasWestDoor = room.isSecret or false
		for _, corridor in dungeon.corridors do
			if corridor.from == room.index or corridor.to == room.index then
				-- Corridor goes in -Z direction (north)
				if corridor.to == room.index then
					hasSouthDoor = true
				end
				if corridor.from == room.index then
					hasNorthDoor = true
				end
			end
		end
		-- Check if this room has a secret room connected to it (east door)
		if not room.isSecret then
			for _, otherRoom in dungeon.rooms do
				if otherRoom.isSecret and otherRoom.connectedTo == room.index then
					hasEastDoor = true
					break
				end
			end
		end

		local doorWidth = def.corridorWidth + 2

		-- North wall (split into two sections if doorway)
		if hasNorthDoor and not room.isSecret then
			local leftWidth = (room.size.X - doorWidth) / 2
			local northWallL = Instance.new("Part")
			northWallL.Name = "WallNorthL"
			northWallL.Size = Vector3.new(leftWidth, wallHeight, wallThickness)
			northWallL.Position = room.position + Vector3.new(-(room.size.X/2 - leftWidth/2), wallHeight / 2, -room.size.Z / 2)
			northWallL.Anchored = true
			northWallL.CanCollide = true
			northWallL.Color = def.wallColor
			northWallL.Material = Enum.Material.Plastic
			northWallL.Parent = roomFolder
			local northWallR = Instance.new("Part")
			northWallR.Name = "WallNorthR"
			northWallR.Size = Vector3.new(leftWidth, wallHeight, wallThickness)
			northWallR.Position = room.position + Vector3.new((room.size.X/2 - leftWidth/2), wallHeight / 2, -room.size.Z / 2)
			northWallR.Anchored = true
			northWallR.CanCollide = true
			northWallR.Color = def.wallColor
			northWallR.Material = Enum.Material.Plastic
			northWallR.Parent = roomFolder
		else
			local northWall = Instance.new("Part")
			northWall.Name = "WallNorth"
			northWall.Size = Vector3.new(room.size.X, wallHeight, wallThickness)
			northWall.Position = room.position + Vector3.new(0, wallHeight / 2, -room.size.Z / 2)
			northWall.Anchored = true
			northWall.CanCollide = true
			northWall.Color = def.wallColor
			northWall.Material = Enum.Material.Plastic
			northWall.Parent = roomFolder
		end

		-- South wall (split into two sections if doorway)
		if hasSouthDoor and not room.isSecret then
			local leftWidth = (room.size.X - doorWidth) / 2
			local southWallL = Instance.new("Part")
			southWallL.Name = "WallSouthL"
			southWallL.Size = Vector3.new(leftWidth, wallHeight, wallThickness)
			southWallL.Position = room.position + Vector3.new(-(room.size.X/2 - leftWidth/2), wallHeight / 2, room.size.Z / 2)
			southWallL.Anchored = true
			southWallL.CanCollide = true
			southWallL.Color = def.wallColor
			southWallL.Material = Enum.Material.Plastic
			southWallL.Parent = roomFolder
			local southWallR = Instance.new("Part")
			southWallR.Name = "WallSouthR"
			southWallR.Size = Vector3.new(leftWidth, wallHeight, wallThickness)
			southWallR.Position = room.position + Vector3.new((room.size.X/2 - leftWidth/2), wallHeight / 2, room.size.Z / 2)
			southWallR.Anchored = true
			southWallR.CanCollide = true
			southWallR.Color = def.wallColor
			southWallR.Material = Enum.Material.Plastic
			southWallR.Parent = roomFolder
		else
			local southWall = Instance.new("Part")
			southWall.Name = "WallSouth"
			southWall.Size = Vector3.new(room.size.X, wallHeight, wallThickness)
			southWall.Position = room.position + Vector3.new(0, wallHeight / 2, room.size.Z / 2)
			southWall.Anchored = true
			southWall.CanCollide = true
			southWall.Color = def.wallColor
			southWall.Material = Enum.Material.Plastic
			southWall.Parent = roomFolder
		end

		-- East wall (with doorway if secret room)
		if hasEastDoor then
			local leftWidth = (room.size.Z - doorWidth) / 2
			local eastWallL = Instance.new("Part")
			eastWallL.Name = "WallEastL"
			eastWallL.Size = Vector3.new(wallThickness, wallHeight, leftWidth)
			eastWallL.Position = room.position + Vector3.new(room.size.X / 2, wallHeight / 2, -(room.size.Z/2 - leftWidth/2))
			eastWallL.Anchored = true
			eastWallL.CanCollide = true
			eastWallL.Color = def.wallColor
			eastWallL.Material = Enum.Material.Plastic
			eastWallL.Parent = roomFolder
			local eastWallR = Instance.new("Part")
			eastWallR.Name = "WallEastR"
			eastWallR.Size = Vector3.new(wallThickness, wallHeight, leftWidth)
			eastWallR.Position = room.position + Vector3.new(room.size.X / 2, wallHeight / 2, (room.size.Z/2 - leftWidth/2))
			eastWallR.Anchored = true
			eastWallR.CanCollide = true
			eastWallR.Color = def.wallColor
			eastWallR.Material = Enum.Material.Plastic
			eastWallR.Parent = roomFolder
		else
			local eastWall = Instance.new("Part")
			eastWall.Name = "WallEast"
			eastWall.Size = Vector3.new(wallThickness, wallHeight, room.size.Z)
			eastWall.Position = room.position + Vector3.new(room.size.X / 2, wallHeight / 2, 0)
			eastWall.Anchored = true
			eastWall.CanCollide = true
			eastWall.Color = def.wallColor
			eastWall.Material = Enum.Material.Plastic
			eastWall.Parent = roomFolder
		end

		-- West wall (split into two sections if doorway for secret room)
		if hasWestDoor then
			local leftWidth = (room.size.Z - doorWidth) / 2
			local westWallL = Instance.new("Part")
			westWallL.Name = "WallWestL"
			westWallL.Size = Vector3.new(wallThickness, wallHeight, leftWidth)
			westWallL.Position = room.position + Vector3.new(-room.size.X / 2, wallHeight / 2, -(room.size.Z/2 - leftWidth/2))
			westWallL.Anchored = true
			westWallL.CanCollide = true
			westWallL.Color = def.wallColor
			westWallL.Material = Enum.Material.Plastic
			westWallL.Parent = roomFolder
			local westWallR = Instance.new("Part")
			westWallR.Name = "WallWestR"
			westWallR.Size = Vector3.new(wallThickness, wallHeight, leftWidth)
			westWallR.Position = room.position + Vector3.new(-room.size.X / 2, wallHeight / 2, (room.size.Z/2 - leftWidth/2))
			westWallR.Anchored = true
			westWallR.CanCollide = true
			westWallR.Color = def.wallColor
			westWallR.Material = Enum.Material.Plastic
			westWallR.Parent = roomFolder
		else
			local westWall = Instance.new("Part")
			westWall.Name = "WallWest"
			westWall.Size = Vector3.new(wallThickness, wallHeight, room.size.Z)
			westWall.Position = room.position + Vector3.new(-room.size.X / 2, wallHeight / 2, 0)
			westWall.Anchored = true
			westWall.CanCollide = true
			westWall.Color = def.wallColor
			westWall.Material = Enum.Material.Plastic
			westWall.Parent = roomFolder
		end

		-- Spawn point markers (invisible parts)
		local def2 = def
		if room.roomType == "combat" or room.roomType == "boss" then
			local enemyCount = def2.enemiesPerRoom
			if room.roomType == "boss" then
				room.spawnPoints = {room.position + Vector3.new(0, 3, -room.size.Z / 4)}
			else
				for j = 1, enemyCount.max do
					local angle = (j / enemyCount.max) * math.pi * 2
					local radius = room.size.X * 0.3
					local spawnPos = room.position + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
					table.insert(room.spawnPoints, spawnPos)
				end
			end
		end

		-- Chest position for loot/secret/boss rooms
		if room.roomType == "loot" or room.roomType == "secret" or room.roomType == "boss" then
			room.chestPosition = room.position + Vector3.new(0, 2, room.size.Z / 4)
		end
	

		-- Build secret room connecting corridor (east door to secret room)
		if room.isSecret and room.connectedTo then
			local mainRoom = nil
			for _, r in dungeon.rooms do
				if r.index == room.connectedTo then
					mainRoom = r
					break
				end
			end
			if mainRoom then
				local corridorPos = (mainRoom.position + room.position) / 2
			local corridorLength = (room.position - mainRoom.position).Magnitude
			local cFloor = Instance.new("Part")
			cFloor.Name = "SecretCorridorFloor"
			cFloor.Size = Vector3.new(corridorLength, 1, def.corridorWidth)
			cFloor.Position = corridorPos + Vector3.new(0, 0, 0)
			cFloor.Anchored = true
			cFloor.CanCollide = true
			cFloor.Color = def.floorColor
			cFloor.Material = Enum.Material.Plastic
			cFloor.Parent = dungeonFolder

			local cCeil = Instance.new("Part")
			cCeil.Name = "SecretCorridorCeiling"
			cCeil.Size = Vector3.new(corridorLength, 1, def.corridorWidth)
			cCeil.Position = corridorPos + Vector3.new(0, def.corridorHeight, 0)
			cCeil.Anchored = true
			cCeil.CanCollide = true
			cCeil.Color = def.ceilingColor
			cCeil.Material = Enum.Material.Plastic
			cCeil.Parent = dungeonFolder

			-- Corridor walls (top and bottom in Z)
			for _, side in {1, -1} do
				local wall = Instance.new("Part")
				wall.Name = "SecretCorridorWall_" .. (side > 0 and "R" or "L")
				wall.Size = Vector3.new(corridorLength, def.corridorHeight, 2)
				wall.Position = corridorPos + Vector3.new(0, def.corridorHeight / 2, side * def.corridorWidth / 2)
				wall.Anchored = true
				wall.CanCollide = true
				wall.Color = def.wallColor
				wall.Material = Enum.Material.Plastic
				wall.Parent = dungeonFolder
			end
		end
	end
	end

	-- Build corridors
	for _, corridor in dungeon.corridors do
		local floor = Instance.new("Part")
		floor.Name = "CorridorFloor"
		floor.Size = Vector3.new(corridor.size.X, 1, corridor.size.Z)
		floor.Position = corridor.position + Vector3.new(0, 0, 0)
		floor.Anchored = true
		floor.CanCollide = true
		floor.Color = def.floorColor
		floor.Material = Enum.Material.Plastic
		floor.Parent = dungeonFolder

		-- Corridor walls
		for _, side in {1, -1} do
			local wall = Instance.new("Part")
			wall.Name = "CorridorWall_" .. (side > 0 and "R" or "L")
			wall.Size = Vector3.new(2, corridor.size.Y, corridor.size.Z)
			wall.Position = corridor.position + Vector3.new(side * corridor.size.X / 2, corridor.size.Y / 2, 0)
			wall.Anchored = true
			wall.CanCollide = true
			wall.Color = def.wallColor
			wall.Material = Enum.Material.Plastic
			wall.Parent = dungeonFolder
		end

		-- Corridor ceiling
		local ceil = Instance.new("Part")
		ceil.Name = "CorridorCeiling"
		ceil.Size = Vector3.new(corridor.size.X, 1, corridor.size.Z)
		ceil.Position = corridor.position + Vector3.new(0, corridor.size.Y, 0)
		ceil.Anchored = true
		ceil.CanCollide = true
		ceil.Color = def.ceilingColor
		ceil.Material = Enum.Material.Plastic
		ceil.Parent = dungeonFolder
	end

	dungeon.folder = dungeonFolder
	dungeon.isBuilt = true

	return dungeonFolder
end

-- Spawns enemies in a room (with dungeon modifier integration)
function DungeonService.spawnRoomEnemies(dungeon, room, playerLevel)
	if room.enemiesSpawned then return end
	room.enemiesSpawned = true

	local effects = dungeon.modifierEffects or {}

	if room.roomType == "boss" then
		if room.spawnPoints and room.spawnPoints[1] then
			local bossModifiers = RNGEngine.rollBossModifiers()
			room.bossModifiers = bossModifiers
			enemyService.spawnEnemy("ancient_guardian", room.spawnPoints[1], true, {dungeonModifiers = effects, bossModifiers = bossModifiers})
		end
	elseif room.roomType == "combat" or room.roomType == "secret" then
		local def = DungeonDefs.Dungeons[dungeon.defId]
		local count = RandomUtility.int(def.enemiesPerRoom.min, def.enemiesPerRoom.max)
		if effects.enemyCountMult then count = math.floor(count * effects.enemyCountMult) end
		local enemyIds = {"goblin_scout", "skeleton_archer", "wolf"}
		for i = 1, count do
			if room.spawnPoints[i] then
				local enemyId = RandomUtility.choice(enemyIds)
				enemyService.spawnEnemy(enemyId, room.spawnPoints[i], true, {dungeonModifiers = effects, roomDepth = room.index})
			end
		end
		if room.roomType == "secret" then enemyService.spawnEnemy("elite_brute", room.position + Vector3.new(0, 3, 0), true, {dungeonModifiers = effects}) end
		if effects.eliteInEveryRoom and room.roomType == "combat" then enemyService.spawnEnemy("elite_brute", room.position + Vector3.new(5, 3, 0), true, {dungeonModifiers = effects}) end
	end
end

function DungeonService.spawnChest(dungeon, room, playerLevel)
	if not room.chestPosition then return nil end
	local chest = Instance.new("Part")
	chest.Name = "DungeonChest"
	chest.Size = Vector3.new(3, 2, 3)
	chest.Position = room.chestPosition
	chest.Anchored = true
	chest.CanCollide = true
	chest.Color = Color3.fromRGB(130, 100, 50)
	chest.Material = Enum.Material.WoodPlanks
	chest:SetAttribute("IsChest", true)
	chest:SetAttribute("LootTable", room.roomType == "boss" and "boss" or (room.roomType == "secret" and "secret_area" or "dungeon_chest"))
	chest:SetAttribute("IsOpened", false)
	chest.Parent = dungeon.folder
	return chest
end

function DungeonService.cleanupDungeon(dungeon)
	enemyService.clearDungeonEnemies()
	if dungeon.folder and dungeon.folder.Parent then dungeon.folder.Parent = nil end
	dungeon.isBuilt = false
end

return DungeonService
