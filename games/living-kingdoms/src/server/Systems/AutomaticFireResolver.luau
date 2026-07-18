--!strict

--[[
	Resolves at most one automatic-fire attempt from authoritative caller state.
	The caller owns the monotonic server time source and must commit the returned
	weapon state before resolving another attempt. This module does not discover
	or validate candidates, retain state, resolve hits, apply damage, or present
	combat. Server-owned run modifiers may shorten cadence and deterministically
	conserve a round within strict floors and ceilings; clients never provide them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local MINIMUM_CADENCE_SECONDS = 0.05
local MAXIMUM_AMMO_CONSERVATION_CHANCE = 0.5

type AmmunitionState = CombatContracts.AmmunitionState
type AutomaticFireDecision = CombatContracts.AutomaticFireDecision
type AutomaticFireRejectionReasonId = CombatContracts.AutomaticFireRejectionReasonId
type AutomaticFireResolution = CombatContracts.AutomaticFireResolution
type CombatEntityId = CombatContracts.CombatEntityId
type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type ReloadState = CombatContracts.ReloadState
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
		serverTimestamp: number,
		cadenceSecondsOverride: number?
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

local function copyReloadState(reloadState: ReloadState?): ReloadState?
	if reloadState == nil then
		return nil
	end

	return {
		weaponId = reloadState.weaponId,
		startedAtServerTimestamp = reloadState.startedAtServerTimestamp,
		completionServerTimestamp = reloadState.completionServerTimestamp,
	}
end

local function copyWeaponState(weaponState: WeaponReadinessState): WeaponReadinessState
	return {
		weaponId = weaponState.weaponId,
		readinessStateId = weaponState.readinessStateId,
		ammunition = copyAmmunition(weaponState.ammunition),
		cadence = copyCadence(weaponState.cadence),
		reloadState = copyReloadState(weaponState.reloadState),
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

local function stableUnitInterval(text: string): number
	local hash = 17
	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index) * index) % 2147483647
	end
	return (hash % 10000) / 10000
end

local function readProgressionNumber(attributeName: string, fallback: number): number
	local storageAsAny = ReplicatedStorage :: any
	if type(storageAsAny.FindFirstChild) ~= "function" then
		return fallback
	end
	local network = storageAsAny:FindFirstChild("ProgressionNetwork")
	if network == nil or type(network.GetAttribute) ~= "function" then
		return fallback
	end
	local value = network:GetAttribute(attributeName)
	return if type(value) == "number" and value == value then value else fallback
end

local function resolveCadenceSeconds(override: number?): number?
	local configured = FirearmConfig.BasicFirearm.CadenceSeconds
	local requested = override
	if requested == nil then
		local multiplier = readProgressionNumber("RunCadenceMultiplier", 1)
		requested = configured * multiplier
	end
	if
		type(requested) ~= "number"
		or requested ~= requested
		or requested < MINIMUM_CADENCE_SECONDS
		or requested > configured
	then
		return nil
	end
	return requested
end

local function resolveAmmoConservationChance(): number?
	local chance = readProgressionNumber("RunAmmoConservationChance", 0)
	if chance < 0 or chance > MAXIMUM_AMMO_CONSERVATION_CHANCE then
		return nil
	end
	return chance
end

function AutomaticFireResolver.resolve(
	operativeState: OperativeAutomaticFireState,
	selectedTarget: SelectedTargetState?,
	weaponState: WeaponReadinessState,
	serverTimestamp: number,
	cadenceSecondsOverride: number?
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

	local cadenceSeconds = resolveCadenceSeconds(cadenceSecondsOverride)
	local ammoConservationChance = resolveAmmoConservationChance()
	local configuredWeaponId = FirearmConfig.BasicFirearm.WeaponId
	if
		cadenceSeconds == nil
		or ammoConservationChance == nil
		or weaponState.weaponId ~= configuredWeaponId
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

	local shotId = deterministicShotId(operativeState.entityId, weaponState.weaponId, serverTimestamp)
	local ammunitionAfter = copyAmmunition(weaponState.ammunition)
	if stableUnitInterval(shotId) >= ammoConservationChance then
		ammunitionAfter.loadedRounds -= 1
	end
	local cadenceAfter = copyCadence(weaponState.cadence)
	cadenceAfter.lastFireServerTimestamp = serverTimestamp
	cadenceAfter.nextAllowedFireServerTimestamp = serverTimestamp + cadenceSeconds
	local weaponStateAfter: WeaponReadinessState = {
		weaponId = weaponState.weaponId,
		readinessStateId = weaponState.readinessStateId,
		ammunition = ammunitionAfter,
		cadence = cadenceAfter,
		reloadState = copyReloadState(weaponState.reloadState),
	}

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
