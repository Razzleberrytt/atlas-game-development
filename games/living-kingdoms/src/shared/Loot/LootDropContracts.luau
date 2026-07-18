--!strict

--[[
	HROI-0106 stable vocabulary and safe data shapes for immediate run-only loot.
	This shared module declares no spawning, collection, reward, health, ammo, XP,
	persistence, or client authority.
]]

local LootDropContracts = {}

export type LootKindId = "loot.ammunition_bundle" | "loot.field_dressing" | "loot.field_intel"

export type DeathDropFact = {
	enemyEntityId: string,
	worldPosition: {
		x: number,
		y: number,
		z: number,
	},
	activeDropCount: number,
	serverTimestamp: number,
}

export type DropResolution = {
	didDrop: boolean,
	rejectionReasonId: string?,
	dropId: string?,
	kindId: LootKindId?,
	worldPosition: {
		x: number,
		y: number,
		z: number,
	}?,
	expiresAtServerTimestamp: number?,
}

LootDropContracts.LootKindIds = table.freeze({
	AmmunitionBundle = "loot.ammunition_bundle",
	FieldDressing = "loot.field_dressing",
	FieldIntel = "loot.field_intel",
})

LootDropContracts.AttributeNames = table.freeze({
	DropId = "LootDropId",
	KindId = "LootKindId",
	Available = "LootAvailable",
	SpawnedAtServerTimestamp = "LootSpawnedAtServerTimestamp",
	ExpiresAtServerTimestamp = "LootExpiresAtServerTimestamp",
})

return table.freeze(LootDropContracts)
