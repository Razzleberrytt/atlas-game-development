--!strict

local Contracts = {
	SupplySourceIds = table.freeze({
		AuthoredCache = "AuthoredCache",
		EngineerResupply = "EngineerResupply",
		EnemyDrop = "EnemyDrop",
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
	processedSupplyIds: { [string]: boolean,
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
