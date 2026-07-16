--!strict

--[[
	Resolves at most one automatic-fire attempt from authoritative caller state.
	The caller owns the monotonic server time source and must commit the returned
	weapon state before resolving another attempt. This module does not discover
	or validate candidates, retain state, resolve hits, apply damage, or present
	combat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

type AmmunitionState = CombatContracts.AmmunitionState
type AutomaticFireDecision = CombatContracts.AutomaticFireDecision
type AutomaticFireRejectionReasonId = CombatContracts.AutomaticFireRejectionReasonId
type AutomaticFireResolution = CombatContracts.AutomaticFireResolution
type CombatEntityId = CombatContracts.CombatEntityId
type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type SelectedTargetState = CombatContracts.SelectedTargetState
type WeaponCadenceState = CombatContracts.WeaponCadenceState
type WeaponReadinessState = CombatContracts.WeaponReadinessState

export type OperativeAutomaticFireState = {
	entityId: CombatEntityId,
	combatStateId: OperativeCombatStateId,
}

type AutomaticFireResolver = {
	resolve: (
		operativeState: OperativeAutomaticFireState,
		selectedTarget: SelectedTargetState?,
		weaponState: WeaponReadinessState,
		serverTimestamp: number
	) -> AutomaticFireResolution,
}

local AutomaticFireResolver: AutomaticFireResolver = {} :: AutomaticFireResolver
local rejectionReasons = CombatContracts.AutomaticFireRejectionReasonIds

local function copyAmmunition(ammunition: AmmunitionState): AmmunitionState
	return {
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
	}
end

local function copyCadence(cadence: WeaponCadenceState): WeaponCadenceState
	return {
		weaponId = cadence.weaponId,
		lastFireServerTimestamp = cadence.lastFireServerTimestamp,
		nextAllowedFireServerTimestamp = cadence.nextAllowedFireServerTimestamp,
	}
end

local function copyWeaponState(weaponState: WeaponReadinessState): WeaponReadinessState
	return {
		weaponId = weaponState.weaponId,
		readinessStateId = weaponState.readinessStateId,
		ammunition = copyAmmunition(weaponState.ammunition),
		cadence = copyCadence(weaponState.cadence),
	}
end

local function createDecision(
	operativeState: OperativeAutomaticFireState,
	weaponState: WeaponReadinessState,
	targetEntityId: CombatEntityId?,
	serverTimestamp: number,
	shouldFire: boolean,
	rejectionReasonId: AutomaticFireRejectionReasonId?
): AutomaticFireDecision
	return {
		shouldFire = shouldFire,
		operativeEntityId = operativeState.entityId,
		weaponId = weaponState.weaponId,
		targetEntityId = targetEntityId,
		evaluatedAtServerTimestamp = serverTimestamp,
		rejectionReasonId = rejectionReasonId,
	}
end

local function reject(
	operativeState: OperativeAutomaticFireState,
	weaponState: WeaponReadinessState,
	targetEntityId: CombatEntityId?,
	serverTimestamp: number,
	reasonId: AutomaticFireRejectionReasonId
): AutomaticFireResolution
	local weaponStateAfter = copyWeaponState(weaponState)
	return {
		decision = createDecision(operativeState, weaponState, targetEntityId, serverTimestamp, false, reasonId),
		fireResult = {
			statusId = CombatContracts.AuthoritativeFireStatusIds.Rejected,
			shotId = nil,
			operativeEntityId = operativeState.entityId,
			weaponId = weaponState.weaponId,
			targetEntityId = targetEntityId,
			firedAtServerTimestamp = nil,
			ammunitionAfter = copyAmmunition(weaponStateAfter.ammunition),
			didHit = nil,
			hitEntityId = nil,
			rejectionReasonId = reasonId,
		},
		weaponStateAfter = weaponStateAfter,
	}
end

local function deterministicShotId(
	operativeEntityId: CombatEntityId,
	weaponId: CombatContracts.WeaponId,
	serverTimestamp: number
): CombatContracts.ShotId
	return string.format("shot:%s:%s:%.17g", operativeEntityId, weaponId, serverTimestamp)
end

function AutomaticFireResolver.resolve(
	operativeState: OperativeAutomaticFireState,
	selectedTarget: SelectedTargetState?,
	weaponState: WeaponReadinessState,
	serverTimestamp: number
): AutomaticFireResolution
	local targetEntityId = if selectedTarget == nil then nil else selectedTarget.targetEntityId

	if operativeState.combatStateId ~= CombatContracts.OperativeCombatStateIds.Ready then
		return reject(
			operativeState,
			weaponState,
			targetEntityId,
			serverTimestamp,
			rejectionReasons.OperativeStateInvalid
		)
	end

	if selectedTarget == nil then
		return reject(operativeState, weaponState, nil, serverTimestamp, rejectionReasons.NoSelectedTarget)
	end

	if
		not selectedTarget.isValid
		or selectedTarget.operativeEntityId ~= operativeState.entityId
		or targetEntityId == nil
	then
		return reject(
			operativeState,
			weaponState,
			targetEntityId,
			serverTimestamp,
			rejectionReasons.SelectedTargetInvalid
		)
	end

	local configuredWeaponId = FirearmConfig.BasicFirearm.WeaponId
	if
		weaponState.weaponId ~= configuredWeaponId
		or weaponState.ammunition.weaponId ~= configuredWeaponId
		or weaponState.cadence.weaponId ~= configuredWeaponId
		or weaponState.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Ready
	then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.WeaponNotReady)
	end

	if weaponState.ammunition.loadedRounds <= 0 then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.NoAmmunition)
	end

	if serverTimestamp < weaponState.cadence.nextAllowedFireServerTimestamp then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.CadenceBlocked)
	end

	local ammunitionAfter = copyAmmunition(weaponState.ammunition)
	ammunitionAfter.loadedRounds -= 1
	local cadenceAfter = copyCadence(weaponState.cadence)
	cadenceAfter.lastFireServerTimestamp = serverTimestamp
	cadenceAfter.nextAllowedFireServerTimestamp = serverTimestamp + FirearmConfig.BasicFirearm.CadenceSeconds
	local weaponStateAfter: WeaponReadinessState = {
		weaponId = weaponState.weaponId,
		readinessStateId = weaponState.readinessStateId,
		ammunition = ammunitionAfter,
		cadence = cadenceAfter,
	}
	local shotId = deterministicShotId(operativeState.entityId, weaponState.weaponId, serverTimestamp)

	return {
		decision = createDecision(operativeState, weaponState, targetEntityId, serverTimestamp, true, nil),
		fireResult = {
			statusId = CombatContracts.AuthoritativeFireStatusIds.Fired,
			shotId = shotId,
			operativeEntityId = operativeState.entityId,
			weaponId = weaponState.weaponId,
			targetEntityId = targetEntityId,
			firedAtServerTimestamp = serverTimestamp,
			ammunitionAfter = copyAmmunition(ammunitionAfter),
			didHit = nil,
			hitEntityId = nil,
			rejectionReasonId = nil,
		},
		weaponStateAfter = weaponStateAfter,
	}
end

return table.freeze(AutomaticFireResolver)
