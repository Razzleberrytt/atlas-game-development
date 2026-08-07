--!strict

-- RPG-0103 pure Expanded Feed reconciliation. Capacity growth moves only the
-- newly created slot count from reserve into the magazine, so the upgrade never
-- mints ammunition. A capacity decrease returns excess loaded rounds to the
-- bounded reserve before discarding any impossible overflow.

export type AmmunitionState = {
	weaponId: string,
	loadedRounds: number,
	reserveRounds: number,
	magazineCapacity: number,
}

export type Resolution = {
	didApply: boolean,
	ammunitionAfter: AmmunitionState,
}

local MAXIMUM_CAPACITY_MULTIPLIER = 1.75

local Resolver = {}

local function isWholeNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value % 1 == 0
end

function Resolver.capacityFor(baseCapacity: number, capacityMultiplier: number): number?
	if
		not isWholeNonnegative(baseCapacity)
		or baseCapacity <= 0
		or type(capacityMultiplier) ~= "number"
		or capacityMultiplier ~= capacityMultiplier
		or capacityMultiplier < 1
		or capacityMultiplier > MAXIMUM_CAPACITY_MULTIPLIER
	then
		return nil
	end
	return math.max(baseCapacity, math.floor(baseCapacity * capacityMultiplier + 0.5))
end

function Resolver.resolve(
	ammunition: AmmunitionState,
	baseCapacity: number,
	maximumReserveRounds: number,
	capacityMultiplier: number
): Resolution
	local unchanged = table.clone(ammunition)
	local targetCapacity = Resolver.capacityFor(baseCapacity, capacityMultiplier)
	if
		targetCapacity == nil
		or type(ammunition) ~= "table"
		or type(ammunition.weaponId) ~= "string"
		or ammunition.weaponId == ""
		or not isWholeNonnegative(ammunition.loadedRounds)
		or not isWholeNonnegative(ammunition.reserveRounds)
		or not isWholeNonnegative(ammunition.magazineCapacity)
		or ammunition.magazineCapacity <= 0
		or ammunition.loadedRounds > ammunition.magazineCapacity
		or not isWholeNonnegative(maximumReserveRounds)
		or ammunition.reserveRounds > maximumReserveRounds
	then
		return table.freeze({ didApply = false, ammunitionAfter = table.freeze(unchanged) })
	end

	local after = table.clone(ammunition)
	if targetCapacity > ammunition.magazineCapacity then
		local createdSlots = targetCapacity - ammunition.magazineCapacity
		local transferred = math.min(createdSlots, ammunition.reserveRounds)
		after.loadedRounds += transferred
		after.reserveRounds -= transferred
	elseif targetCapacity < ammunition.magazineCapacity and ammunition.loadedRounds > targetCapacity then
		local excess = ammunition.loadedRounds - targetCapacity
		local returned = math.min(excess, maximumReserveRounds - ammunition.reserveRounds)
		after.loadedRounds -= excess
		after.reserveRounds += returned
	end
	after.magazineCapacity = targetCapacity
	return table.freeze({ didApply = true, ammunitionAfter = table.freeze(after) })
end

return table.freeze(Resolver)
