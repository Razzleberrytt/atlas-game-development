--!strict

--[[
	Applies at most one configured damage event for a resolved ShotId. The caller
	owns and commits targetHealthStateAfter, including its processed-ShotId set.
	No hidden deduplication state, Humanoid mutation, death behavior, or presentation
	is created here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

type DamageResolution = CombatContracts.DamageResolution
type FirearmHitRejectionReasonId = CombatContracts.FirearmHitRejectionReasonId
type FirearmHitResolution = CombatContracts.FirearmHitResolution
type ProcessedShotIds = CombatContracts.ProcessedShotIds
type TargetHealthState = CombatContracts.TargetHealthState

type DamageResolver = {
	resolve: (
		hitResolution: FirearmHitResolution,
		targetHealthState: TargetHealthState,
		serverTimestamp: number
	) -> DamageResolution,
}

local DamageResolver: DamageResolver = {} :: DamageResolver
local reasons = CombatContracts.FirearmHitRejectionReasonIds

local function copyProcessedShotIds(processedShotIds: ProcessedShotIds): ProcessedShotIds
	return table.clone(processedShotIds)
end

local function copyHealthState(targetHealthState: TargetHealthState): TargetHealthState
	return {
		entityId = targetHealthState.entityId,
		currentHealth = targetHealthState.currentHealth,
		processedShotIds = copyProcessedShotIds(targetHealthState.processedShotIds),
	}
end

local function withoutDamage(
	healthStateAfter: TargetHealthState,
	reasonId: FirearmHitRejectionReasonId?
): DamageResolution
	return {
		damageEvent = nil,
		targetHealthStateAfter = healthStateAfter,
		didApplyDamage = false,
		becameDead = false,
		rejectionReasonId = reasonId,
	}
end

function DamageResolver.resolve(
	hitResolution: FirearmHitResolution,
	targetHealthState: TargetHealthState,
	serverTimestamp: number
): DamageResolution
	local healthStateAfter = copyHealthState(targetHealthState)
	local shotId = hitResolution.shotId
	if shotId == nil or shotId == "" then
		return withoutDamage(healthStateAfter, reasons.MissingShotIdentity)
	end

	if targetHealthState.processedShotIds[shotId] == true then
		return withoutDamage(healthStateAfter, reasons.ShotAlreadyResolved)
	end

	-- Every accepted ShotId is terminal after one pass, including misses and
	-- invalidated targets, so a later retry cannot convert it into damage.
	healthStateAfter.processedShotIds[shotId] = true

	if not hitResolution.didHit then
		return withoutDamage(healthStateAfter, hitResolution.rejectionReasonId)
	end

	if hitResolution.targetEntityId ~= targetHealthState.entityId then
		return withoutDamage(healthStateAfter, reasons.TargetMismatch)
	end

	if hitResolution.weaponId ~= FirearmConfig.BasicFirearm.WeaponId or hitResolution.sourceEntityId == nil then
		return withoutDamage(healthStateAfter, reasons.WeaponInvalid)
	end

	local damageAmount = FirearmConfig.BasicFirearm.DamagePerHit
	local healthBefore = math.max(0, targetHealthState.currentHealth)
	healthStateAfter.currentHealth = math.max(0, healthBefore - damageAmount)
	local becameDead = healthBefore > 0 and healthStateAfter.currentHealth == 0
	local damageEvent = table.freeze({
		damageEventId = "damage:" .. shotId,
		shotId = shotId,
		sourceEntityId = hitResolution.sourceEntityId,
		targetEntityId = targetHealthState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		damageTypeId = FirearmConfig.BasicFirearm.DamageTypeId,
		damageAmount = damageAmount,
		serverTimestamp = serverTimestamp,
	})

	return {
		damageEvent = damageEvent,
		targetHealthStateAfter = healthStateAfter,
		didApplyDamage = true,
		becameDead = becameDead,
		rejectionReasonId = nil,
	}
end

return table.freeze(DamageResolver)
