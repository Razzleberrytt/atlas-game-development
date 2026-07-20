--!strict

--[[
	Resolves pure reload begin and completion transitions from authoritative
	caller state. The caller owns the monotonic server timestamp and commits the
	returned copies. This module accepts no client ammunition, duration, state,
	eligibility, or completion time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end

type AmmunitionState = CombatContracts.AmmunitionState
type OperativeReloadState = CombatContracts.OperativeReloadState
type ReloadBeginResolution = CombatContracts.ReloadBeginResolution
type ReloadCompletionResolution = CombatContracts.ReloadCompletionResolution
type ReloadRejectionReasonId = CombatContracts.ReloadRejectionReasonId
type ReloadState = CombatContracts.ReloadState
type WeaponCadenceState = CombatContracts.WeaponCadenceState
type WeaponReadinessState = CombatContracts.WeaponReadinessState

type ReloadResolver = {
	begin: (
		operativeState: OperativeReloadState,
		weaponState: WeaponReadinessState,
		serverTimestamp: number
	) -> ReloadBeginResolution,
	complete: (
		operativeState: OperativeReloadState,
		weaponState: WeaponReadinessState,
		serverTimestamp: number
	) -> ReloadCompletionResolution,
}

local ReloadResolver: ReloadResolver = {} :: ReloadResolver
local reasons = CombatContracts.ReloadRejectionReasonIds

-- Combat Loader publishes a bounded squad RunReloadDurationMultiplier on
-- ProgressionNetwork. Read it defensively (mirroring the operative-side
-- DamageResolver) and clamp to [0.5, 1] so an upgrade can only shorten, never
-- erase or extend, the authoritative reload commitment. The multiplier is baked
-- into completionServerTimestamp at begin() time so completion stays a pure
-- deadline check. Absent progression state (including fixtures) falls back to 1.
local RELOAD_DURATION_FLOOR = 0.5
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
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return value
end

local function readReloadDurationMultiplier(): number
	local value = readProgressionNumber("RunReloadDurationMultiplier", 1)
	return math.clamp(value, RELOAD_DURATION_FLOOR, 1)
end

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

local function copyOperativeState(operativeState: OperativeReloadState): OperativeReloadState
	return {
		entityId = operativeState.entityId,
		combatStateId = operativeState.combatStateId,
		equippedWeaponId = operativeState.equippedWeaponId,
	}
end

local function configuredWeapon(weaponState: WeaponReadinessState): FirearmConfig.FirearmDefinition?
	local definition = resolveWeaponDefinition(weaponState.weaponId)
	local magazineMultiplier = readProgressionNumber("RunMagazineCapacityMultiplier", 1)
	local expectedMagazineCapacity = if definition ~= nil
			and magazineMultiplier >= 1
			and magazineMultiplier <= 1.75
		then math.max(definition.MagazineCapacity, math.floor(definition.MagazineCapacity * magazineMultiplier + 0.5))
		else nil
	if
		definition == nil
		or expectedMagazineCapacity == nil
		or weaponState.ammunition.weaponId ~= weaponState.weaponId
		or weaponState.cadence.weaponId ~= weaponState.weaponId
		or weaponState.ammunition.magazineCapacity < definition.MagazineCapacity
		or weaponState.ammunition.magazineCapacity > expectedMagazineCapacity
	then
		return nil
	end
	return definition
end

local function rejectBegin(
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	reasonId: ReloadRejectionReasonId
): ReloadBeginResolution
	return {
		didBegin = false,
		rejectionReasonId = reasonId,
		operativeStateAfter = copyOperativeState(operativeState),
		weaponStateAfter = copyWeaponState(weaponState),
	}
end

local function rejectCompletion(
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	reasonId: ReloadRejectionReasonId
): ReloadCompletionResolution
	return {
		didComplete = false,
		wasInterrupted = false,
		rejectionReasonId = reasonId,
		operativeStateAfter = copyOperativeState(operativeState),
		weaponStateAfter = copyWeaponState(weaponState),
	}
end

local function readinessAfterReload(ammunition: AmmunitionState): CombatContracts.WeaponReadinessStateId
	if ammunition.loadedRounds <= 0 then
		return CombatContracts.WeaponReadinessStateIds.Empty
	end

	return CombatContracts.WeaponReadinessStateIds.Ready
end

local function interruptReload(
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState
): ReloadCompletionResolution
	local operativeStateAfter = copyOperativeState(operativeState)
	if operativeStateAfter.combatStateId == CombatContracts.OperativeCombatStateIds.Reloading then
		operativeStateAfter.combatStateId = CombatContracts.OperativeCombatStateIds.Ready
	end

	local weaponStateAfter = copyWeaponState(weaponState)
	weaponStateAfter.reloadState = nil
	if weaponStateAfter.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Disabled then
		weaponStateAfter.readinessStateId = readinessAfterReload(weaponStateAfter.ammunition)
	end

	return {
		didComplete = false,
		wasInterrupted = true,
		rejectionReasonId = reasons.ReloadInterrupted,
		operativeStateAfter = operativeStateAfter,
		weaponStateAfter = weaponStateAfter,
	}
end

function ReloadResolver.begin(
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	serverTimestamp: number
): ReloadBeginResolution
	if operativeState.combatStateId ~= CombatContracts.OperativeCombatStateIds.Ready then
		return rejectBegin(operativeState, weaponState, reasons.OperativeStateInvalid)
	end

	local weapon = configuredWeapon(weaponState)
	if weapon == nil or operativeState.equippedWeaponId ~= weapon.WeaponId then
		return rejectBegin(operativeState, weaponState, reasons.WeaponInvalid)
	end

	if
		weaponState.readinessStateId == CombatContracts.WeaponReadinessStateIds.Reloading
		or weaponState.reloadState ~= nil
	then
		return rejectBegin(operativeState, weaponState, reasons.AlreadyReloading)
	end

	if weaponState.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Ready then
		return rejectBegin(operativeState, weaponState, reasons.WeaponNotReady)
	end

	if weaponState.ammunition.loadedRounds >= weaponState.ammunition.magazineCapacity then
		return rejectBegin(operativeState, weaponState, reasons.MagazineFull)
	end

	if weaponState.ammunition.reserveRounds <= 0 then
		return rejectBegin(operativeState, weaponState, reasons.NoReserveAmmunition)
	end

	local operativeStateAfter = copyOperativeState(operativeState)
	operativeStateAfter.combatStateId = CombatContracts.OperativeCombatStateIds.Reloading
	local weaponStateAfter = copyWeaponState(weaponState)
	weaponStateAfter.readinessStateId = CombatContracts.WeaponReadinessStateIds.Reloading
	weaponStateAfter.reloadState = {
		weaponId = weapon.WeaponId,
		startedAtServerTimestamp = serverTimestamp,
		completionServerTimestamp = serverTimestamp + weapon.ReloadDurationSeconds * readReloadDurationMultiplier(),
	}

	return {
		didBegin = true,
		rejectionReasonId = nil,
		operativeStateAfter = operativeStateAfter,
		weaponStateAfter = weaponStateAfter,
	}
end

function ReloadResolver.complete(
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	serverTimestamp: number
): ReloadCompletionResolution
	local weapon = configuredWeapon(weaponState)
	if weapon == nil then
		return rejectCompletion(operativeState, weaponState, reasons.WeaponInvalid)
	end

	local reloadState = weaponState.reloadState
	if reloadState == nil then
		return rejectCompletion(operativeState, weaponState, reasons.ReloadNotInProgress)
	end

	if reloadState.weaponId ~= weapon.WeaponId then
		return rejectCompletion(operativeState, weaponState, reasons.WeaponInvalid)
	end

	if
		operativeState.combatStateId == CombatContracts.OperativeCombatStateIds.Incapacitated
		or operativeState.combatStateId == CombatContracts.OperativeCombatStateIds.Dead
		or weaponState.readinessStateId == CombatContracts.WeaponReadinessStateIds.Disabled
		or operativeState.equippedWeaponId ~= reloadState.weaponId
		or weaponState.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Reloading
	then
		return interruptReload(operativeState, weaponState)
	end

	if serverTimestamp < reloadState.completionServerTimestamp then
		return rejectCompletion(operativeState, weaponState, reasons.ReloadNotComplete)
	end

	local operativeStateAfter = copyOperativeState(operativeState)
	operativeStateAfter.combatStateId = CombatContracts.OperativeCombatStateIds.Ready
	local weaponStateAfter = copyWeaponState(weaponState)
	local missingRounds =
		math.max(0, weaponStateAfter.ammunition.magazineCapacity - weaponStateAfter.ammunition.loadedRounds)
	local transferredRounds = math.min(missingRounds, weaponStateAfter.ammunition.reserveRounds)
	weaponStateAfter.ammunition.loadedRounds += transferredRounds
	weaponStateAfter.ammunition.reserveRounds -= transferredRounds
	weaponStateAfter.readinessStateId = readinessAfterReload(weaponStateAfter.ammunition)
	weaponStateAfter.reloadState = nil

	return {
		didComplete = true,
		wasInterrupted = false,
		rejectionReasonId = nil,
		operativeStateAfter = operativeStateAfter,
		weaponStateAfter = weaponStateAfter,
	}
end

return table.freeze(ReloadResolver)
