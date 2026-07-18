--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONFIG_TOKEN = {}

local ModeIds = table.freeze({
	SingleTarget = "SingleTarget",
	ConeCleave = "ConeCleave",
	LinePierce = "LinePierce",
})

local definitions = {
	["weapon.lmg"] = table.freeze({
		WeaponId = "weapon.lmg",
		ModeId = ModeIds.SingleTarget,
		MaximumSecondaryTargets = 0,
		SecondaryDamageMultiplier = 1,
		MaximumSecondaryRangeStuds = 0,
	}),
	["weapon.shotgun"] = table.freeze({
		WeaponId = "weapon.shotgun",
		ModeId = ModeIds.ConeCleave,
		MaximumSecondaryTargets = 3,
		SecondaryDamageMultiplier = 0.7,
		MaximumSecondaryRangeStuds = 30,
		ConeHalfAngleDegrees = 26,
	}),
	["weapon.sniper"] = table.freeze({
		WeaponId = "weapon.sniper",
		ModeId = ModeIds.LinePierce,
		MaximumSecondaryTargets = 1,
		SecondaryDamageMultiplier = 0.72,
		MaximumSecondaryRangeStuds = 165,
		PierceHalfWidthStuds = 3.25,
		MinimumBeyondPrimaryStuds = 2,
	}),
}

local config = {
	ModeIds = ModeIds,
	get = function(weaponId: unknown)
		return if type(weaponId) == "string" then definitions[weaponId] else nil
	end,
}

local replicatedStorage = {
	Shared = {
		Config = {
			WeaponPatternConfig = CONFIG_TOKEN,
		},
	},
}

local source = fs.readFile("games/living-kingdoms/src/server/Systems/WeaponPatternResolver.luau")
local loadResolver = luau.load(source, {
	debugName = "WeaponPatternResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			assert(token == CONFIG_TOKEN, "unexpected module")
			return config
		end,
	},
	injectGlobals = true,
})
local resolver = loadResolver()

local function position(x: number, z: number)
	return { X = x, Y = 0, Z = z }
end

local function fact(entityId: string, x: number, z: number)
	return {
		entityId = entityId,
		worldPosition = position(x, z),
		isAlive = true,
		isTargetable = true,
		isVisible = true,
		hasLineOfSight = true,
	}
end

local origin = position(0, 0)
local primary = fact("enemy.primary", 10, 0)

assert(#resolver.resolve("weapon.lmg", origin, primary.entityId, { primary }) == 0, "single target must not cleave")
assert(
	#resolver.resolve("weapon.unknown", origin, primary.entityId, { primary }) == 0,
	"unknown weapon must fail closed"
)
assert(
	#resolver.resolve("weapon.shotgun", origin, "enemy.missing", { primary }) == 0,
	"missing primary must fail closed"
)

local closeCenter = fact("enemy.close-center", 7, 0.5)
local closeLeft = fact("enemy.close-left", 9, -2)
local midRight = fact("enemy.mid-right", 15, 4)
local fourthValid = fact("enemy.fourth-valid", 20, -4)
local outsideAngle = fact("enemy.outside-angle", 10, 10)
local outsideRange = fact("enemy.outside-range", 31, 0)
local blocked = fact("enemy.blocked", 8, 0)
blocked.hasLineOfSight = false
local dead = fact("enemy.dead", 8, 0)
dead.isAlive = false

local shotgunImpacts = resolver.resolve("weapon.shotgun", origin, primary.entityId, {
	outsideAngle,
	fourthValid,
	primary,
	blocked,
	closeLeft,
	outsideRange,
	midRight,
	dead,
	closeCenter,
})
assert(#shotgunImpacts == 3, "shotgun must remain capped at three secondary targets")
assert(shotgunImpacts[1].targetEntityId == "enemy.close-center", "shotgun should prefer nearest valid target")
assert(shotgunImpacts[2].targetEntityId == "enemy.close-left", "shotgun should deterministically rank second nearest")
assert(shotgunImpacts[3].targetEntityId == "enemy.mid-right", "shotgun should take the third bounded cone target")
for _, impact in shotgunImpacts do
	assert(impact.damageMultiplier == 0.7, "shotgun multiplier must come from server config")
	assert(impact.targetEntityId ~= primary.entityId, "primary cannot be duplicated as a secondary")
end

local reversedImpacts = resolver.resolve("weapon.shotgun", origin, primary.entityId, {
	closeCenter,
	dead,
	midRight,
	outsideRange,
	closeLeft,
	blocked,
	primary,
	fourthValid,
	outsideAngle,
})
for index, impact in shotgunImpacts do
	assert(reversedImpacts[index].targetEntityId == impact.targetEntityId, "shotgun result must ignore input order")
end

local sniperPrimary = fact("enemy.sniper-primary", 20, 0)
local nearestBehind = fact("enemy.nearest-behind", 24, 1)
local fartherBehind = fact("enemy.farther-behind", 45, 0)
local tooWide = fact("enemy.too-wide", 30, 4)
local beforePrimary = fact("enemy.before-primary", 15, 0)
local hiddenBehind = fact("enemy.hidden-behind", 23, 0)
hiddenBehind.isVisible = false

local sniperImpacts = resolver.resolve("weapon.sniper", origin, sniperPrimary.entityId, {
	fartherBehind,
	tooWide,
	beforePrimary,
	sniperPrimary,
	hiddenBehind,
	nearestBehind,
})
assert(#sniperImpacts == 1, "sniper must pierce at most one secondary target")
assert(
	sniperImpacts[1].targetEntityId == nearestBehind.entityId,
	"sniper must choose nearest aligned target behind primary"
)
assert(sniperImpacts[1].damageMultiplier == 0.72, "sniper multiplier must come from server config")

local immutable = pcall(function()
	(sniperImpacts :: any)[1] = nil
end)
assert(not immutable, "pattern impact list must be immutable")

print("WeaponPatternResolver: bounded cone cleave, line pierce, filtering, order independence, and immutability passed")
