-- DungeonDefinitions: Definitions for dungeon layouts and room types
local DungeonDefinitions = {}

DungeonDefinitions.RoomTypes = {
	normal = {weight = 50, size = Vector3.new(30, 12, 30)},
	combat = {weight = 30, size = Vector3.new(35, 14, 35)},
	loot = {weight = 15, size = Vector3.new(25, 12, 25)},
	boss = {weight = 0, size = Vector3.new(60, 16, 60)},
	secret = {weight = 0, size = Vector3.new(20, 12, 20)},
}

DungeonDefinitions.Dungeons = {
	prototype_dungeon = {
		id = "prototype_dungeon",
		name = "Prototype Dungeon",
		minRooms = 5,
		maxRooms = 8,
		roomSize = Vector3.new(30, 12, 30),
		corridorLength = 12,
		corridorWidth = 6,
		corridorHeight = 8,
		floorColor = Color3.fromRGB(60, 55, 50),
		ceilingColor = Color3.fromRGB(40, 38, 35),
		wallColor = Color3.fromRGB(70, 65, 60),
		hasSecret = true,
		enemiesPerRoom = {min = 2, max = 4},
		roomTypes = {
			normal = {weight = 50},
			combat = {weight = 30},
			loot = {weight = 15},
		},
	},
}

return DungeonDefinitions