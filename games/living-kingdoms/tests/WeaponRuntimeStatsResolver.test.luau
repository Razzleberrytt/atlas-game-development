--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/WeaponRuntimeStatsResolver.luau"), {
	debugName = "WeaponRuntimeStatsResolver",
	injectGlobals = true,
})()

local base = {
	WeaponId = "weapon.fixture",
	DamagePerHit = 40,
	CadenceSeconds = 0.2,
	MagazineCapacity = 20,
	ReloadDurationSeconds = 2,
	RangeStuds = 100,
	FiringModeId = "Automatic",
	PelletCount = 1,
	SpreadDegrees = 2,
	HeadshotMultiplier = 1.5,
	BurstCount = 1,
	BurstIntervalSeconds = 0.2,
}

local neutral = resolver.resolve(base, nil)
assert(neutral ~= nil, "neutral resolution failed")
assert(neutral.DamagePerHit == 40, "neutral damage changed")
assert(neutral.MagazineCapacity == 20, "neutral magazine changed")
assert(neutral.FiringModeId == "Automatic", "behavior identity changed")
assert(table.isfrozen(neutral), "resolved runtime stats must be immutable")

local modified = resolver.resolve(base, {
	DamageMultiplier = 1.25,
	CadenceMultiplier = 0.8,
	MagazineCapacityMultiplier = 1.5,
	ReloadDurationMultiplier = 0.75,
	SpreadMultiplier = 0.5,
	HeadshotMultiplierBonus = 0.25,
})
assert(modified ~= nil, "valid item modifiers were rejected")
assert(modified.DamagePerHit == 50, "damage modifier did not compose")
assert(math.abs(modified.CadenceSeconds - 0.16) < 1e-12, "cadence modifier did not compose")
assert(modified.MagazineCapacity == 30, "magazine modifier did not compose")
assert(math.abs(modified.ReloadDurationSeconds - 1.5) < 1e-12, "reload modifier did not compose")
assert(modified.SpreadDegrees == 1, "spread modifier did not compose")
assert(modified.HeadshotMultiplier == 1.75, "headshot bonus did not compose")
assert(resolver.resolveImpactDamage(modified, false) == 50, "normal impact damage changed")
assert(resolver.resolveImpactDamage(modified, true) == 88, "critical impact calculation is wrong")

assert(resolver.resolve(base, { DamageMultiplier = 99 }) == nil, "unbounded damage modifier must fail closed")
assert(resolver.resolve(base, { CadenceMultiplier = 0 }) == nil, "impossible cadence modifier must fail closed")
assert(resolver.resolve(base, { SpreadMultiplier = 10 }) == nil, "unbounded spread modifier must fail closed")
assert(resolver.resolve({}, nil) == nil, "invalid base definition must fail closed")

print("WeaponRuntimeStatsResolver: base + trusted modifiers and critical calculations passed")