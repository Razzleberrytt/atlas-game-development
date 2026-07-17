--!strict

-- P6-0103 authored ammunition-cache identity and placement. These records are
-- inert configuration only: no prompt, instance, collection, replication, or
-- ammunition mutation is created here.
local ScarcityConfig = require(script.Parent.AmmunitionScarcityConfig)
local WorldFoundationConfig = require(script.Parent.WorldFoundationConfig)

local function landmarkById(landmarkId: string)
	for _, landmark in WorldFoundationConfig.Landmarks do
		if landmark.id == landmarkId then
			return landmark
		end
	end
	error("unknown ammunition-cache landmark: " .. landmarkId)
end

local function cache(cacheId: string, landmarkId: string, offsetX: number, offsetZ: number)
	local landmark = landmarkById(landmarkId)
	return table.freeze({
		cacheId = cacheId,
		landmarkId = landmarkId,
		displayName = "Rifle Ammunition",
		weaponId = "weapon.basic_firearm",
		rounds = ScarcityConfig.BasicFirearm.AuthoredCacheRounds,
		position = table.freeze({
			x = landmark.x + offsetX,
			y = 5,
			z = landmark.z + offsetZ,
		}),
	})
end

local Config = {
	Version = "P6-0103-v1",
	Caches = table.freeze({
		cache("ammo-cache.campground-medical-tent", "Campground", 14, -10),
		cache("ammo-cache.military-roadblock-checkpoint", "MilitaryRoadblock", -18, 12),
		cache("ammo-cache.rocky-overlook-vehicle", "RockyOverlook", -12, -18),
	}),
}

local seenIds = {}
for _, definition in Config.Caches do
	assert(not seenIds[definition.cacheId], "ammunition cache IDs must be unique")
	seenIds[definition.cacheId] = true
	assert(definition.rounds > 0, "ammunition caches must grant positive rounds")
	assert(
		math.abs(definition.position.x) <= WorldFoundationConfig.PlayableHalfExtentStuds,
		"ammunition cache X position must remain inside the playable world"
	)
	assert(
		math.abs(definition.position.z) <= WorldFoundationConfig.PlayableHalfExtentStuds,
		"ammunition cache Z position must remain inside the playable world"
	)
	local landmark = landmarkById(definition.landmarkId)
	local dx = definition.position.x - landmark.x
	local dz = definition.position.z - landmark.z
	assert(dx * dx + dz * dz <= landmark.radius * landmark.radius, "cache must remain inside its authored landmark")
end

return table.freeze(Config)
