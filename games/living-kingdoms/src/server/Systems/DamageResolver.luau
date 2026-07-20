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

export type RunDamageContext = {
	reserveRounds: number,
	maximumReserveRounds: number,
	isSpecialEnemy: boolean,
}

type DamageResolver = {
	resolve: (
		hitResolution: FirearmHitResolution,
		targetHealthState: TargetHealthState,
		serverTimestamp: number,
		damageAmountOverride: number?,
		runContext: RunDamageContext?
	) -> DamageResolution,
	resolvePattern: (
		hitResolution: FirearmHitResolution,
		targetHealthState: TargetHealthState,
		serverTimestamp: number,
		damageMultiplier: number,
		runContext: RunDamageContext?
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

-- Hard safety ceiling for the trusted Pattern Amplifier attribute, matching the
-- shared RPG-0101 ModifierCeilings.maximumPatternDamageMultiplier. Defense in
-- depth alongside the configured*3 total-damage ceiling below.
local RUN_PATTERN_DAMAGE_CEILING = 2

local function resolveDamageAmount(
	weaponId: string,
	override: number?,
	currentHealth: number,
	patternMultiplier: number?,
	runContext: RunDamageContext?
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
		local specialEnemyMultiplier = 1
		local lastMagazineMultiplier = 1
		local cullThreshold = readProgressionNumber("RunCullHealthThreshold", 0)
		if currentHealth <= cullThreshold then
			cullMultiplier = readProgressionNumber("RunCullDamageMultiplier", 1)
		end
		if runContext ~= nil then
			if
				type(runContext.reserveRounds) ~= "number"
				or runContext.reserveRounds ~= runContext.reserveRounds
				or runContext.reserveRounds < 0
				or runContext.reserveRounds % 1 ~= 0
				or type(runContext.maximumReserveRounds) ~= "number"
				or runContext.maximumReserveRounds ~= runContext.maximumReserveRounds
				or runContext.maximumReserveRounds <= 0
				or runContext.maximumReserveRounds % 1 ~= 0
				or runContext.reserveRounds > runContext.maximumReserveRounds
				or type(runContext.isSpecialEnemy) ~= "boolean"
			then
				return nil
			end
			if runContext.isSpecialEnemy then
				specialEnemyMultiplier = readProgressionNumber("RunSpecialEnemyDamageMultiplier", 1)
			end
			local reserveFraction = readProgressionNumber("RunLastMagazineReserveFraction", 0.2)
			if
				reserveFraction <= 0
				or reserveFraction > 0.25
				or reserveFraction ~= reserveFraction
				or specialEnemyMultiplier < 1
				or specialEnemyMultiplier > 2
			then
				return nil
			end
			if runContext.reserveRounds <= math.floor(runContext.maximumReserveRounds * reserveFraction) then
				lastMagazineMultiplier = readProgressionNumber("RunLastMagazineDamageMultiplier", 1)
			end
		end
		-- Each trusted run multiplier must stay within its bounded 1..3 range;
		-- anomalous values fail closed. Legitimate stacked damage and cull
		-- multipliers may combine past the ceiling (e.g. maxed Overpressure 1.8x
		-- and Cull 2.05x), so clamp the product to the hard configured*3 cap
		-- instead of rejecting -- otherwise a maxed build would deal zero damage
		-- to wounded enemies rather than capped damage.
		if
			damageMultiplier < 1
			or damageMultiplier > 3
			or cullMultiplier < 1
			or cullMultiplier > 3
			or lastMagazineMultiplier < 1
			or lastMagazineMultiplier > 1.5
		then
			return nil
		end
		requested = math.min(
			configured * 3,
			math.floor(
				configured * damageMultiplier * cullMultiplier * specialEnemyMultiplier * lastMagazineMultiplier + 0.5
			)
		)
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
		-- Pattern Amplifier (run upgrade) raises secondary cleave/pierce damage
		-- toward full primary damage. Clamp the trusted attribute to the bounded
		-- pattern ceiling and cap the effective multiplier at 1 so secondary
		-- damage can never exceed primary or reach the hard configured*3 cap here.
		local runPatternMultiplier =
			math.clamp(readProgressionNumber("RunPatternDamageMultiplier", 1), 1, RUN_PATTERN_DAMAGE_CEILING)
		local effectiveMultiplier = math.min(1, patternMultiplier * runPatternMultiplier)
		requested = math.max(1, math.floor(requested * effectiveMultiplier + 0.5))
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
	patternMultiplier: number?,
	runContext: RunDamageContext?
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
		resolveDamageAmount(hitResolution.weaponId, damageAmountOverride, healthBefore, patternMultiplier, runContext)
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
	damageAmountOverride: number?,
	runContext: RunDamageContext?
): DamageResolution
	return resolveInternal(hitResolution, targetHealthState, serverTimestamp, damageAmountOverride, nil, runContext)
end

function DamageResolver.resolvePattern(
	hitResolution: FirearmHitResolution,
	targetHealthState: TargetHealthState,
	serverTimestamp: number,
	damageMultiplier: number,
	runContext: RunDamageContext?
): DamageResolution
	return resolveInternal(hitResolution, targetHealthState, serverTimestamp, nil, damageMultiplier, runContext)
end

return table.freeze(DamageResolver)
