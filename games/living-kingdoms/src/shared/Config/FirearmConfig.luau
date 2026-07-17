--!strict

-- Prototype balance values for the first basic firearm family. P6 now owns
-- finite starting ammunition and carry bounds; the existing pure P2 combat
-- resolvers continue consuming the flattened firearm definition unchanged.
local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)

local scarcityModule = script.Parent.AmmunitionScarcityConfig
local scarcity
if scarcityModule ~= nil then
	scarcity = require(scarcityModule).BasicFirearm
else
	-- Legacy Lune pure-module loaders model `script.Parent` as a plain table and
	-- predate the P6 dependency. Roblox Instance loading always resolves the real
	-- sibling module above; this compatibility snapshot is fixture-only.
	scarcity = {
		InitialLoadedRounds = 12,
		InitialReserveRounds = 24,
		MaximumReserveRounds = 48,
	}
end

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
