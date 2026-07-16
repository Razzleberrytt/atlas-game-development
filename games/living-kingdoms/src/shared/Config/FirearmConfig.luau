--!strict

-- Prototype balance values for the first basic firearm family. Pure combat
-- resolvers consume this configuration without runtime bootstrap integration.
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
