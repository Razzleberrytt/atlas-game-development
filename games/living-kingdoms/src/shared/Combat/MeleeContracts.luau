--!strict

--[[
	MVP 0.1 melee declarations. These IDs and result shapes are intentionally
	separate from firearm ammunition/readiness contracts: a melee weapon never
	owns a magazine, reserve ammunition, reload state, or firearm shot identity.
]]

local MeleeContracts = {}

export type MeleeWeaponId = "weapon.field-hatchet"
export type MeleeStrikeId = string
export type MeleeStrikeRejectionReasonId =
	"ServiceStopped"
	| "InvalidIntent"
	| "DuplicateRequest"
	| "CombatNotAllowed"
	| "CadenceBlocked"
	| "NoTarget"
	| "TargetOccluded"
	| "TargetStale"
	| "CommitRejected"

export type MeleeTargetCandidate = {
	entityId: string,
	worldPosition: Vector3,
	isAlive: boolean,
}

export type MeleeTargetSelection = {
	targetEntityId: string?,
	distanceStuds: number?,
	aimDot: number?,
	rejectionReasonId: MeleeStrikeRejectionReasonId?,
}

export type MeleeStrikeResult = {
	accepted: boolean,
	swingAccepted: boolean,
	strikeId: MeleeStrikeId?,
	weaponId: MeleeWeaponId,
	targetEntityId: string?,
	damageAmount: number,
	becameDead: boolean,
	serverTimestamp: number,
	rejectionReasonId: MeleeStrikeRejectionReasonId?,
}

MeleeContracts.WeaponIds = table.freeze({
	FieldHatchet = "weapon.field-hatchet",
})

MeleeContracts.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidIntent = "InvalidIntent",
	DuplicateRequest = "DuplicateRequest",
	CombatNotAllowed = "CombatNotAllowed",
	CadenceBlocked = "CadenceBlocked",
	NoTarget = "NoTarget",
	TargetOccluded = "TargetOccluded",
	TargetStale = "TargetStale",
	CommitRejected = "CommitRejected",
})

return table.freeze(MeleeContracts)
