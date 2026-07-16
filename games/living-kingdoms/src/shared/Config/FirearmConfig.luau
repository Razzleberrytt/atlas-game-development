--!strict

-- Prototype balance values for the first basic firearm family. No runtime
-- combat system consumes this configuration in LK-0201.
local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)

return table.freeze({
	BasicFirearm = table.freeze({
		WeaponId = CombatContracts.WeaponIds.BasicFirearm,
		DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
		RangeStuds = 80,
		CadenceSeconds = 0.2,
		MagazineCapacity = 12,
		PrototypeInitialLoadedRounds = 12,
		PrototypeInitialReserveRounds = 24,
		ReloadDurationSeconds = 2,
		DamagePerHit = 20,
	}),
})
