--!strict

local Contracts = {
	MessageKindIds = table.freeze({
		Consumed = "AmmunitionCacheConsumed",
	}),
}

export type AmmunitionCacheConsumedMessage = {
	kindId: "AmmunitionCacheConsumed",
	cacheId: string,
}

return table.freeze(Contracts)
