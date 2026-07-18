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
export type ShotObstructionResultId = "TargetHit" | "Blocked" | "Miss"
export type FirearmHitRejectionReasonId =
	"FireNotAccepted"
	| "MissingShotIdentity"
	| "WeaponInvalid"
	| "TargetMismatch"
	| "TargetInvalid"
	| "TargetDead"
	| "TargetNotHostile"
	| "NotVisible"
	| "OutOfRange"
	| "LineOfSightBlocked"
	| "Miss"
	| "ShotAlreadyResolved"
export type ReloadRejectionReasonId =
	"OperativeStateInvalid"
	| "WeaponInvalid"
	| "WeaponNotReady"
	| "AlreadyReloading"
	| "MagazineFull"
	| "NoReserveAmmunition"
	| "ReloadNotInProgress"
	| "ReloadNotComplete"
	| "ReloadInterrupted"
export type CombatPresentationMessageKindId =
	"TargetSelected"
	| "TargetCleared"
	| "ShotFired"
	| "ReloadStarted"
	| "ReloadCompleted"
	| "ReloadInterrupted"
	| "AmmunitionState"
	| "AmmunitionCollected"

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
	reloadState: ReloadState?,
}

export type ReloadState = {
	weaponId: WeaponId,
	startedAtServerTimestamp: number,
	completionServerTimestamp: number,
}

export type OperativeReloadState = {
	entityId: CombatEntityId,
	combatStateId: OperativeCombatStateId,
	equippedWeaponId: WeaponId,
}

export type ReloadBeginResolution = {
	didBegin: boolean,
	rejectionReasonId: ReloadRejectionReasonId?,
	operativeStateAfter: OperativeReloadState,
	weaponStateAfter: WeaponReadinessState,
}

export type ReloadCompletionResolution = {
	didComplete: boolean,
	wasInterrupted: boolean,
	rejectionReasonId: ReloadRejectionReasonId?,
	operativeStateAfter: OperativeReloadState,
	weaponStateAfter: WeaponReadinessState,
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
	activelyThreateningOperativeEntityId: CombatEntityId?,
}

export type TargetValidationResult = {
	isValid: boolean,
	rejectionReasonId: TargetValidationRejectionReasonId?,
}

export type SelectedTargetState = {
	operativeEntityId: CombatEntityId,
	targetEntityId: CombatEntityId?,
	isValid: boolean,
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
	didHit: boolean?,
	hitEntityId: CombatEntityId?,
	rejectionReasonId: AutomaticFireRejectionReasonId?,
}

export type AutomaticFireResolution = {
	decision: AutomaticFireDecision,
	fireResult: AuthoritativeFireResult,
	weaponStateAfter: WeaponReadinessState,
}

export type ShotResolutionContext = {
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
	selectedTargetEntityId: CombatEntityId,
	operativeWorldPosition: Vector3,
	obstructionResultId: ShotObstructionResultId,
}

export type FirearmTargetContext = {
	entityId: CombatEntityId,
	worldPosition: Vector3,
	isAlive: boolean,
	isTargetable: boolean,
	relationshipId: TeamRelationshipId,
	isVisible: boolean,
}

export type FirearmHitResolution = {
	shotId: ShotId?,
	sourceEntityId: CombatEntityId?,
	targetEntityId: CombatEntityId?,
	weaponId: WeaponId?,
	didHit: boolean,
	rejectionReasonId: FirearmHitRejectionReasonId?,
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

export type ProcessedShotIds = { [ShotId]: boolean }

export type TargetHealthState = {
	entityId: CombatEntityId,
	currentHealth: number,
	processedShotIds: ProcessedShotIds,
}

export type DamageResolution = {
	damageEvent: AuthoritativeDamageEvent?,
	targetHealthStateAfter: TargetHealthState,
	didApplyDamage: boolean,
	becameDead: boolean,
	rejectionReasonId: FirearmHitRejectionReasonId?,
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

export type SecondaryShotImpactPresentation = {
	targetEntityId: CombatEntityId,
	impactWorldPosition: Vector3,
	damageAmount: number,
}

export type ShotFiredPresentationMessage = {
	kindId: "ShotFired",
	shotId: ShotId,
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
	targetEntityId: CombatEntityId,
	didApplyDamage: boolean,
	impactWorldPosition: Vector3?,
	damageAmount: number?,
	secondaryImpacts: { SecondaryShotImpactPresentation }?,
	serverTimestamp: number,
}

export type ReloadStartedPresentationMessage = {
	kindId: "ReloadStarted",
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
	completionServerTimestamp: number,
}

export type ReloadCompletedPresentationMessage = {
	kindId: "ReloadCompleted",
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
}

export type ReloadInterruptedPresentationMessage = {
	kindId: "ReloadInterrupted",
	operativeEntityId: CombatEntityId,
	weaponId: WeaponId,
}

export type AmmunitionStatePresentationMessage = {
	kindId: "AmmunitionState",
	weaponId: WeaponId,
	loadedRounds: number,
	reserveRounds: number,
	magazineCapacity: number,
	maximumReserveRounds: number,
}

export type AmmunitionCollectedPresentationMessage = {
	kindId: "AmmunitionCollected",
	weaponId: WeaponId,
	grantedRounds: number,
	loadedRounds: number,
	reserveRounds: number,
	magazineCapacity: number,
	maximumReserveRounds: number,
}

export type CombatPresentationMessage =
	TargetSelectedPresentationMessage
	| TargetClearedPresentationMessage
	| ShotFiredPresentationMessage
	| ReloadStartedPresentationMessage
	| ReloadCompletedPresentationMessage
	| ReloadInterruptedPresentationMessage
	| AmmunitionStatePresentationMessage
	| AmmunitionCollectedPresentationMessage

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
	LightMachineGun = "weapon.light-machine-gun",
	BreachShotgun = "weapon.breach-shotgun",
	SniperRifle = "weapon.sniper-rifle",
	ServicePistol = "weapon.service-pistol",
	SubmachineGun = "weapon.submachine-gun",
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

CombatContracts.AuthoritativeFireStatusIds = table.freeze({
	Fired = "Fired",
	Rejected = "Rejected",
})

CombatContracts.ShotObstructionResultIds = table.freeze({
	TargetHit = "TargetHit",
	Blocked = "Blocked",
	Miss = "Miss",
})

CombatContracts.FirearmHitRejectionReasonIds = table.freeze({
	FireNotAccepted = "FireNotAccepted",
	MissingShotIdentity = "MissingShotIdentity",
	WeaponInvalid = "WeaponInvalid",
	TargetMismatch = "TargetMismatch",
	TargetInvalid = "TargetInvalid",
	TargetDead = "TargetDead",
	TargetNotHostile = "TargetNotHostile",
	NotVisible = "NotVisible",
	OutOfRange = "OutOfRange",
	LineOfSightBlocked = "LineOfSightBlocked",
	Miss = "Miss",
	ShotAlreadyResolved = "ShotAlreadyResolved",
})

CombatContracts.ReloadRejectionReasonIds = table.freeze({
	OperativeStateInvalid = "OperativeStateInvalid",
	WeaponInvalid = "WeaponInvalid",
	WeaponNotReady = "WeaponNotReady",
	AlreadyReloading = "AlreadyReloading",
	MagazineFull = "MagazineFull",
	NoReserveAmmunition = "NoReserveAmmunition",
	ReloadNotInProgress = "ReloadNotInProgress",
	ReloadNotComplete = "ReloadNotComplete",
	ReloadInterrupted = "ReloadInterrupted",
})

CombatContracts.DamageTypeIds = table.freeze({
	Ballistic = "Ballistic",
})

CombatContracts.PresentationMessageKindIds = table.freeze({
	TargetSelected = "TargetSelected",
	TargetCleared = "TargetCleared",
	ShotFired = "ShotFired",
	ReloadStarted = "ReloadStarted",
	ReloadCompleted = "ReloadCompleted",
	ReloadInterrupted = "ReloadInterrupted",
	AmmunitionState = "AmmunitionState",
	AmmunitionCollected = "AmmunitionCollected",
})

return table.freeze(CombatContracts)
