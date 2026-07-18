--!strict

--[[
	Applies at most one configured damage event for a resolved ShotId. The caller
	owns and commits targetHealthStateAfter, including its processed-ShotId set.
	No hidden deduplication state, Humanoid mutation, death behavior, or
	presentation is created here. Server-owned run modifiers may raise damage
	within a strict multiple of the configured firearm value.
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

type DamageResolution = CombatContracts.DamageResolution
type FirearmHitRejectionReasonId = CombatContracts.FirearmHitRejectionReasonId
type FirearmHitResolution = CombatContracts.FirearmHitResolution
type ProcessedShotIds = CombatContracts.ProcessedShotIds
type TargetHealthState = CombatContracts.TargetHealthState

type DamageResolver = {
	resolve: (
		hitResolution: FirearmHitResolution,
		targetHealthState: TargetHealthState,
		serverTimestamp: number,
		damageAmountOverride: number?
	) -> DamageResolution,
	resolvePattern: (
		hitResolution: FirearmHitResolution,
		targetHealthState: TargetHealthState,
		serverTimestamp: number,
		damageMultiplier: number
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

local function resolveDamageAmount(
	weaponId: string,
	override: number?,
	currentHealth: number,
	patternMultiplier: number?
): number?
	local weapon = resolveWeaponDefinition(weaponId)
	if weapon == nil then
		return nil
	end
	local configured = weapon.DamagePerHit
	local requested = override
	if requested == nil then
		local damageMultiplier = readProgressionNumber("RunDamageMultiplier", 1)
		local cullMultiplier = 1
		local cullThreshold = readProgressionNumber("RunCullHealthThreshold", 0)
		if currentHealth <= cullThreshold then
			cullMultiplier = readProgressionNumber("RunCullDamageMultiplier", 1)
		end
		requested = math.floor(configured * damageMultiplier * cullMultiplier + 0.5)
	end
	if patternMultiplier ~= nil then
		if
			type(patternMultiplier) ~= "number"
			or patternMultiplier ~= patternMultiplier
			or patternMultiplier <= 0
			or patternMultiplier > 1
		then
			return nil
		end
		requested = math.max(1, math.floor(requested * patternMultiplier + 0.5))
	end
	local minimumDamage = if patternMultiplier == nil then configured else 1
	if
		type(requested) ~= "number"
		or requested ~= requested
		or requested <= 0
		or requested % 1 ~= 0
		or requested < minimumDamage
		or requested > configured * 3
	then
		return nil
	end
	return requested
end

local function resolveInternal(
	hitResolution: FirearmHitResolution,
	targetHealthState: TargetHealthState,
	serverTimestamp: number,
	damageAmountOverride: number?,
	patternMultiplier: number?
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

	local healthBefore = math.max(0, targetHealthState.currentHealth)
	local weapon = resolveWeaponDefinition(hitResolution.weaponId)
	local damageAmount =
		resolveDamageAmount(hitResolution.weaponId, damageAmountOverride, healthBefore, patternMultiplier)
	if damageAmount == nil or weapon == nil or hitResolution.sourceEntityId == nil then
		return withoutDamage(healthStateAfter, reasons.WeaponInvalid)
	end

	healthStateAfter.currentHealth = math.max(0, healthBefore - damageAmount)
	local becameDead = healthBefore > 0 and healthStateAfter.currentHealth == 0
	local damageEvent = table.freeze({
		damageEventId = "damage:" .. shotId,
		shotId = shotId,
		sourceEntityId = hitResolution.sourceEntityId,
		targetEntityId = targetHealthState.entityId,
		weaponId = weapon.WeaponId,
		damageTypeId = weapon.DamageTypeId,
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

function DamageResolver.resolve(
	hitResolution: FirearmHitResolution,
	targetHealthState: TargetHealthState,
	serverTimestamp: number,
	damageAmountOverride: number?
): DamageResolution
	return resolveInternal(hitResolution, targetHealthState, serverTimestamp, damageAmountOverride, nil)
end

function DamageResolver.resolvePattern(
	hitResolution: FirearmHitResolution,
	targetHealthState: TargetHealthState,
	serverTimestamp: number,
	damageMultiplier: number
): DamageResolution
	return resolveInternal(hitResolution, targetHealthState, serverTimestamp, nil, damageMultiplier)
end

return table.freeze(DamageResolver)
