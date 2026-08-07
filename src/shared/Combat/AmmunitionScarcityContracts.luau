--!strict

local Contracts = {
	SupplySourceIds = table.freeze({
		AuthoredCache = "AuthoredCache",
		EngineerResupply = "EngineerResupply",
		EnemyLoot = "EnemyLoot",
		-- Compatibility alias for the isolated recovery-loot service. Both names
		-- resolve to the same server-owned enemy-loot authority boundary.
		EnemyDrop = "EnemyLoot",
	}),
	CollectionRejectionReasonIds = table.freeze({
		InvalidState = "InvalidState",
		InvalidSupply = "InvalidSupply",
		DuplicateCollection = "DuplicateCollection",
		NoCapacity = "NoCapacity",
	}),
}

export type ScarcityAmmunitionState = {
	weaponId: string,
	loadedRounds: number,
	reserveRounds: number,
	magazineCapacity: number,
	maximumReserveRounds: number,
	processedSupplyIds: { [string]: boolean },
}

export type AmmunitionSupply = {
	supplyId: string,
	sourceId: string,
	weaponId: string,
	availableRounds: number,
}

export type CollectionResult = {
	didCollect: boolean,
	grantedRounds: number,
	rejectionReasonId: string?,
	stateAfter: ScarcityAmmunitionState,
}

return table.freeze(Contracts)
