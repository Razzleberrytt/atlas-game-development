--!strict

-- Prototype balance values for the first basic firearm family. P6 now owns
-- finite starting ammunition and carry bounds; the existing pure P2 combat
-- resolvers continue consuming the flattened firearm definition unchanged.
local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)
local AmmunitionScarcityConfig = require(script.Parent.AmmunitionScarcityConfig)

local scarcity = AmmunitionScarcityConfig.BasicFirearm

return table.freeze({
	BasicFirearm = table.freeze({
		WeaponId = CombatContracts.WeaponIds.BasicFirearm,
		DamageTypeId = CombatContracts.DamageTypeIds.Ballistic,
		RangeStuds = 80,
		CadenceSeconds = 0.2,
		MagazineCapacity = 12,
		PrototypeInitialLoadedRounds = scarcity.InitialLoadedRounds,
		PrototypeInitialReserveRounds = scarcity.InitialReserveRounds,
		MaximumReserveRounds = scarcity.MaximumReserveRounds,
		ReloadDurationSeconds = 2,
		DamagePerHit = 20,
	}),
})
