--!strict

local MeleeContracts = require(script.Parent.Parent.Combat.MeleeContracts)

local Config = {
	Version = "MVP-0.1-melee-v1",
	OpeningWeapon = table.freeze({
		WeaponId = MeleeContracts.WeaponIds.FieldHatchet,
		DisplayName = "Field Hatchet",
		ShortName = "FIELD HATCHET",
		RoleDescription = "Humble close-range survival tool used before firearms are recovered.",
		DamagePerHit = 34,
		RangeStuds = 8,
		CadenceSeconds = 0.62,
		AimHalfAngleDegrees = 52,
	}),
	MaximumRequestIdLength = 96,
	MaximumProcessedRequestIdsPerOperative = 64,
}

assert(
	Config.OpeningWeapon.DamagePerHit > 0 and Config.OpeningWeapon.DamagePerHit <= 100,
	"melee damage must be bounded"
)
assert(Config.OpeningWeapon.RangeStuds >= 4 and Config.OpeningWeapon.RangeStuds <= 12, "melee range must remain close")
assert(
	Config.OpeningWeapon.CadenceSeconds >= 0.3 and Config.OpeningWeapon.CadenceSeconds <= 1.5,
	"melee cadence must be bounded"
)
assert(
	Config.OpeningWeapon.AimHalfAngleDegrees >= 20 and Config.OpeningWeapon.AimHalfAngleDegrees <= 75,
	"melee aim cone must remain intentional"
)
assert(
	Config.MaximumProcessedRequestIdsPerOperative > 0 and Config.MaximumProcessedRequestIdsPerOperative <= 256,
	"melee request history must be bounded"
)

return table.freeze(Config)
