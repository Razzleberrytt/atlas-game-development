--!strict

--[[
	Presentation-only modular asset catalog. The catalog deliberately contains no
	combat values: it describes interchangeable silhouette pieces and chooses a
	stable combination from an enemy seed. Server and client presentation code can
	consume the same weapon IDs without giving visual assets gameplay authority.
]]

local Config = {}

export type EnemyVariant = {
	BodyId: string,
	WarPlateId: string,
	HornId: string,
	WeaponId: string,
	BackSpikeId: string,
}

export type BodyProfile = {
	TorsoScale: { number },
	RibScale: { number },
	HeadScale: { number },
}

export type WeaponProfile = {
	DisplayName: string,
	Silhouette: string,
	HandleLength: number,
	HeadLength: number,
	HeadWidth: number,
}

Config.Version = "VIS-modular-assets-v1"

local BODY_IDS = table.freeze({ "OgreBase", "OgreBrute", "OgreRavaged" })
local WAR_PLATE_IDS = table.freeze({ "ScrapHarness", "RiotPlates", "WardenPlate", "Bare" })
local HORN_IDS = table.freeze({ "None", "Twin", "Swept", "Broken" })
local WEAPON_IDS = table.freeze({ "Sword", "Axe", "Spear", "Staff" })
local BACK_SPIKE_IDS = table.freeze({ "None", "Sparse", "Heavy" })

Config.EnemySlots = table.freeze({ "Body", "WarPlate", "Horns", "Weapon", "BackSpikes" })
Config.BodyIds = BODY_IDS
Config.WarPlateIds = WAR_PLATE_IDS
Config.HornIds = HORN_IDS
Config.WeaponIds = WEAPON_IDS
Config.BackSpikeIds = BACK_SPIKE_IDS

local BODY_PROFILES: { [string]: BodyProfile } = {
	OgreBase = table.freeze({
		TorsoScale = table.freeze({ 1.0, 1.0, 1.0 }),
		RibScale = table.freeze({ 1.0, 1.0, 1.0 }),
		HeadScale = table.freeze({ 1.0, 1.0, 1.0 }),
	}),
	OgreBrute = table.freeze({
		TorsoScale = table.freeze({ 1.17, 1.08, 1.12 }),
		RibScale = table.freeze({ 1.2, 1.05, 1.16 }),
		HeadScale = table.freeze({ 1.08, 1.04, 1.08 }),
	}),
	OgreRavaged = table.freeze({
		TorsoScale = table.freeze({ 0.91, 1.08, 0.92 }),
		RibScale = table.freeze({ 0.92, 1.13, 0.9 }),
		HeadScale = table.freeze({ 0.92, 1.08, 0.95 }),
	}),
}
Config.BodyProfiles = table.freeze(BODY_PROFILES)

local WEAPON_PROFILES: { [string]: WeaponProfile } = {
	Sword = table.freeze({
		DisplayName = "Scrap Sword",
		Silhouette = "Blade",
		HandleLength = 1.25,
		HeadLength = 2.8,
		HeadWidth = 0.56,
	}),
	Axe = table.freeze({
		DisplayName = "Field Axe",
		Silhouette = "Axe",
		HandleLength = 3.25,
		HeadLength = 1.3,
		HeadWidth = 1.75,
	}),
	Spear = table.freeze({
		DisplayName = "Breach Spear",
		Silhouette = "Spear",
		HandleLength = 4.8,
		HeadLength = 1.15,
		HeadWidth = 0.72,
	}),
	Staff = table.freeze({
		DisplayName = "Corruption Staff",
		Silhouette = "Staff",
		HandleLength = 4.5,
		HeadLength = 0.9,
		HeadWidth = 1.05,
	}),
}
Config.WeaponProfiles = table.freeze(WEAPON_PROFILES)

local function stableHash(seed: string): number
	local hash = 17
	for index = 1, #seed do
		hash = (hash * 131 + string.byte(seed, index)) % 2147483647
	end
	return hash
end

local function choose(list: { string }, hash: number, salt: number): string
	return list[((hash + salt) % #list) + 1]
end

function Config.resolveEnemyVariant(seed: string): EnemyVariant
	assert(type(seed) == "string" and seed ~= "", "modular enemy variant requires a non-empty seed")
	local hash = stableHash(seed)
	return table.freeze({
		BodyId = choose(BODY_IDS, hash, 3),
		WarPlateId = choose(WAR_PLATE_IDS, hash, 11),
		HornId = choose(HORN_IDS, hash, 23),
		WeaponId = choose(WEAPON_IDS, hash, 37),
		BackSpikeId = choose(BACK_SPIKE_IDS, hash, 53),
	})
end

function Config.getBodyProfile(bodyId: unknown): BodyProfile?
	if type(bodyId) ~= "string" then
		return nil
	end
	return BODY_PROFILES[bodyId]
end

function Config.getWeaponProfile(weaponId: unknown): WeaponProfile?
	if type(weaponId) ~= "string" then
		return nil
	end
	return WEAPON_PROFILES[weaponId]
end

return table.freeze(Config)
