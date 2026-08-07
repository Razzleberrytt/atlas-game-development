--!strict

--[[
	Blueprint v2.0 queue item 2 — ammunition carry-over across a weapon swap.

	Equipping a weapon previously handed over a full magazine, so every swap
	refilled loaded rounds for free and mid-combat weapon changes bypassed
	ammunition scarcity entirely.

	The rule implemented here: a swap moves the operative's ammunition, it never
	creates any. Total carried rounds are preserved, then fitted to the incoming
	weapon — magazine first, remainder to reserve — and clamped to that weapon's
	caps. Rounds that do not fit are lost, which is a real cost of carrying a
	weapon you cannot supply, not a hidden gain.

	This resolver is pure: no services, no mutation of its inputs.
]]

export type AmmunitionState = {
	loadedRounds: number,
	reserveRounds: number,
}

export type WeaponCapacity = {
	magazineCapacity: number,
	maximumReserveRounds: number,
}

export type SwapResult = {
	Accepted: boolean,
	ReasonId: string,
	LoadedRounds: number,
	ReserveRounds: number,
	-- Rounds the incoming weapon could not hold. Reported so callers can tell
	-- the player why their count dropped rather than leaving it unexplained.
	DiscardedRounds: number,
}

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0
end

local function reject(reasonId: string): SwapResult
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		LoadedRounds = 0,
		ReserveRounds = 0,
		DiscardedRounds = 0,
	})
end

local WeaponSwapAmmunitionResolver = {}

--[[
	`carried` is the operative's ammunition on the outgoing weapon. `incoming`
	describes the weapon being equipped. The result is the ammunition the
	operative holds afterwards.
]]
function WeaponSwapAmmunitionResolver.resolve(carried: AmmunitionState, incoming: WeaponCapacity): SwapResult
	if type(carried) ~= "table" or not isCount(carried.loadedRounds) or not isCount(carried.reserveRounds) then
		return reject("InvalidCarriedAmmunition")
	end
	if type(incoming) ~= "table" or not isCount(incoming.magazineCapacity) then
		return reject("InvalidWeaponCapacity")
	end
	if not isCount(incoming.maximumReserveRounds) or incoming.magazineCapacity <= 0 then
		return reject("InvalidWeaponCapacity")
	end

	local total = carried.loadedRounds + carried.reserveRounds

	-- The magazine is filled first so a swap leaves the operative able to fire
	-- immediately when they had the rounds for it.
	local loaded = math.min(total, incoming.magazineCapacity)
	local reserve = math.min(total - loaded, incoming.maximumReserveRounds)
	local discarded = total - loaded - reserve

	return table.freeze({
		Accepted = true,
		ReasonId = "AmmunitionCarried",
		LoadedRounds = loaded,
		ReserveRounds = reserve,
		DiscardedRounds = discarded,
	})
end

return table.freeze(WeaponSwapAmmunitionResolver)
