--!strict

--[[
	Canonical shared data shapes and stable IDs for the automatic-combat pipeline.
	These declarations do not implement discovery, validation, selection, firing,
	damage, networking, or presentation behavior.
]]

local CombatContracts = {}

export type CombatEntityId = string
export type CombatEntityKindId = "Operative" | "Hostile"
export type CombatTeamId = string
export type TeamRelationshipId = "Friendly" | "Hostile" | "Neutral"
export type WeaponId = string
export type ShotId = string
export type DamageEventId = string

export type OperativeCombatStateId = "Ready" | "Reloading" | "Incapacitated" | "Dead" | "Disabled"
export type WeaponReadinessStateId = "Ready" | "CadenceBlocked" | "Reloading" | "Empty" | "Disabled"
export type DamageTypeId = "Ballistic"

export type TargetValidationRejectionReasonId =
	"OperativeStateInvalid"
	| "RelationshipNotHostile"
	| "HostileDead"
	| "HostileUntargetable"
	| "NotVisible"
	| "NoLineOfSight"
	| "OutOfRange"
	| "NoAmmunition"
	| "WeaponNotReady"

export type TargetSelectionReasonId = "ThreateningClosest" | "ValidClosest"
export type AutomaticFireRejectionReasonId =
	"NoSelectedTarget"
	| "SelectedTargetInvalid"
	| "OperativeStateInvalid"
	| "NoAmmunition"
	| "WeaponNotReady"
	| "CadenceBlocked"

export type AuthoritativeFireStatusId = "Fired" | "Rejected"
export type CombatPresentationMessageKindId = "TargetSelected" | "TargetCleared" | "ShotFired"

export type AmmunitionState = {
	weaponId: WeaponId,
	loadedRounds: number,
	reserveRounds: number,
	magazineCapacity: number,
}

export type WeaponCadenceState = {
	weaponId: WeaponId,
	lastFireServerTimestamp: number?,
	nextAllowedFireServerTimestamp: number,
}

export type WeaponReadinessState = {
	weaponId: WeaponId,
	readinessStateId: WeaponReadinessStateId,
	ammunition: AmmunitionState,
	cadence: WeaponCadenceState,
}

export type TargetCandidate = {
	entityId: CombatEntityId,
	entityKindId: CombatEntityKindId,
	teamId: CombatTeamId,
	relationshipId: TeamRelationshipId,
	worldPosition: Vector3,
	distanceStuds: number,
	isAlive: boolean,
	isTargetable: boolean,
	isVisible: boolean,
	hasLineOfSight: boolean,
	isActivelyThreatening: boolean,
}

export type TargetValidationResult = {
	isValid: boolean,
	rejectionReasonId: TargetValidationRejectionReasonId?,
}

export type SelectedTargetState = {
	operativeEntityId: CombatEntityId,
	targetEntityId: CombatEntityId?,
	selectionReasonId: TargetSelectionReasonId?,
	selectedAtServerTimestamp: number?,
}

export type AutomaticFireDecision = {
	shouldFire: boolean,
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
	targetEntityId: CombatEntityId?,
	evaluatedAtServerTimestamp: number,
	rejectionReasonId: AutomaticFireRejectionReasonId?,
}

export type AuthoritativeFireResult = {
	statusId: AuthoritativeFireStatusId,
	shotId: ShotId?,
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
	targetEntityId: CombatEntityId?,
	firedAtServerTimestamp: number?,
	ammunitionAfter: AmmunitionState,
	didHit: boolean,
	hitEntityId: CombatEntityId?,
	rejectionReasonId: AutomaticFireRejectionReasonId?,
}

export type AuthoritativeDamageEvent = {
	damageEventId: DamageEventId,
	shotId: ShotId,
	sourceEntityId: CombatEntityId,
	targetEntityId: CombatEntityId,
	weaponId: WeaponId,
	damageTypeId: DamageTypeId,
	damageAmount: number,
	serverTimestamp: number,
}

export type ReloadIntent = {
	weaponId: WeaponId,
}

export type TargetSelectedPresentationMessage = {
	kindId: "TargetSelected",
	operativeEntityId: CombatEntityId,
	targetEntityId: CombatEntityId,
	serverTimestamp: number,
}

export type TargetClearedPresentationMessage = {
	kindId: "TargetCleared",
	operativeEntityId: CombatEntityId,
	serverTimestamp: number,
}

export type ShotFiredPresentationMessage = {
	kindId: "ShotFired",
	shotId: ShotId,
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
	targetEntityId: CombatEntityId,
	serverTimestamp: number,
}

export type CombatPresentationMessage =
	TargetSelectedPresentationMessage
	| TargetClearedPresentationMessage
	| ShotFiredPresentationMessage

CombatContracts.CombatEntityKindIds = table.freeze({
	Operative = "Operative",
	Hostile = "Hostile",
})

CombatContracts.TeamRelationshipIds = table.freeze({
	Friendly = "Friendly",
	Hostile = "Hostile",
	Neutral = "Neutral",
})

CombatContracts.WeaponIds = table.freeze({
	BasicFirearm = "weapon.basic_firearm",
})

CombatContracts.OperativeCombatStateIds = table.freeze({
	Ready = "Ready",
	Reloading = "Reloading",
	Incapacitated = "Incapacitated",
	Dead = "Dead",
	Disabled = "Disabled",
})

CombatContracts.WeaponReadinessStateIds = table.freeze({
	Ready = "Ready",
	CadenceBlocked = "CadenceBlocked",
	Reloading = "Reloading",
	Empty = "Empty",
	Disabled = "Disabled",
})

CombatContracts.TargetValidationRejectionReasonIds = table.freeze({
	OperativeStateInvalid = "OperativeStateInvalid",
	RelationshipNotHostile = "RelationshipNotHostile",
	HostileDead = "HostileDead",
	HostileUntargetable = "HostileUntargetable",
	NotVisible = "NotVisible",
	NoLineOfSight = "NoLineOfSight",
	OutOfRange = "OutOfRange",
	NoAmmunition = "NoAmmunition",
	WeaponNotReady = "WeaponNotReady",
})

CombatContracts.TargetSelectionReasonIds = table.freeze({
	ThreateningClosest = "ThreateningClosest",
	ValidClosest = "ValidClosest",
})

CombatContracts.AutomaticFireRejectionReasonIds = table.freeze({
	NoSelectedTarget = "NoSelectedTarget",
	SelectedTargetInvalid = "SelectedTargetInvalid",
	OperativeStateInvalid = "OperativeStateInvalid",
	NoAmmunition = "NoAmmunition",
	WeaponNotReady = "WeaponNotReady",
	CadenceBlocked = "CadenceBlocked",
})

CombatContracts.DamageTypeIds = table.freeze({
	Ballistic = "Ballistic",
})

CombatContracts.PresentationMessageKindIds = table.freeze({
	TargetSelected = "TargetSelected",
	TargetCleared = "TargetCleared",
	ShotFired = "ShotFired",
})

return table.freeze(CombatContracts)
