--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "P6 cache configuration assertion failed", 2)
	end
end

local scarcity = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/AmmunitionScarcityConfig.luau"), {
	debugName = "ScarcityConfig",
	injectGlobals = true,
})()
local world = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"), {
	debugName = "WorldConfig",
	injectGlobals = true,
})()

local scarcityToken = {}
local worldToken = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/AmmunitionCacheConfig.luau"), {
	debugName = "CacheConfig",
	environment = {
		script = { Parent = { AmmunitionScarcityConfig = scarcityToken, WorldFoundationConfig = worldToken } },
		require = function(token: unknown)
			if token == scarcityToken then
				return scarcity
			end
			if token == worldToken then
				return world
			end
			error("unexpected dependency")
		end,
	},
	injectGlobals = true,
})()

check(config.Version == "P6-0103-v1")
check(#config.Caches == 3)
check(table.isfrozen(config) and table.isfrozen(config.Caches))

local landmarks = {}
for _, landmark in world.Landmarks do
	landmarks[landmark.id] = landmark
end

local seen = {}
for _, definition in config.Caches do
	check(not seen[definition.cacheId])
	seen[definition.cacheId] = true
	check(definition.rounds == scarcity.BasicFirearm.AuthoredCacheRounds)
	check(table.isfrozen(definition) and table.isfrozen(definition.position))
	local landmark = landmarks[definition.landmarkId]
	check(landmark ~= nil)
	local dx = definition.position.x - landmark.x
	local dz = definition.position.z - landmark.z
	check(dx * dx + dz * dz <= landmark.radius * landmark.radius)
	check(math.abs(definition.position.x) <= world.PlayableHalfExtentStuds)
	check(math.abs(definition.position.z) <= world.PlayableHalfExtentStuds)
end
