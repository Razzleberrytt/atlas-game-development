--!strict

--[[
	P9-0103 pure boss phase logic for The Progenitor. Deterministic, side-effect
	free, loop free (no yielding), Roblox-service free, and randomness free: the
	caller supplies server-owned facts and a monotonic server timestamp, and
	receives one phase decision without input mutation, raycasts, or randomness.

	`resolveBossPhase` derives the monotonic phase from health thresholds, drives
	the Slam attack lifecycle (windup → commit AoE against Alive operatives in
	radius), reports the post-Slam exposure window that alone makes the boss
	vulnerable, signals the one-shot Brood surge, and reports the spore-shroud /
	Collapse-darkness visibility reduction (the P8 floodlight repair pays off in
	Collapse). The runtime owner (P9-0104) commits health, damage, summons, and
	visibility; it never regresses a phase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossConfig = require(ReplicatedStorage.Shared.Config.BossConfig)
local BossContracts = require(ReplicatedStorage.Shared.Combat.BossContracts)

type EnemyWorldPosition = BossContracts.EnemyWorldPosition
type EnemyOperativeFact = BossContracts.EnemyOperativeFact
type AuthoritativeEnemyAttack = BossContracts.AuthoritativeEnemyAttack
type BossPhaseFacts = BossContracts.BossPhaseFacts
type BossPhaseDecision = BossContracts.BossPhaseDecision

local PhaseIds = BossContracts.BossPhaseIds
local PhaseOrder = BossContracts.BossPhaseOrder
local ActionIds = BossContracts.BossActionIds
local OutcomeIds = BossContracts.BossOutcomeIds
local RejectionReasonIds = BossContracts.BossDecisionRejectionReasonIds

local BossPhaseResolver = {}

local EMPTY_IMPACTS: { AuthoritativeEnemyAttack } = table.freeze({})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteTimestamp(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0
end

local function isNonemptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isKnownValue(values: { [string]: string }, value: unknown): boolean
	for _, knownValue in values do
		if knownValue == value then
			return true
		end
	end
	return false
end

local function isWorldPosition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local position = value :: { [string]: unknown }
	return isFiniteNumber(position.x) and isFiniteNumber(position.y) and isFiniteNumber(position.z)
end

local function horizontalDistanceSquared(a: { x: number, z: number }, b: { x: number, z: number }): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return dx * dx + dz * dz
end

local function copyPosition(position: EnemyWorldPosition): EnemyWorldPosition
	return table.freeze({ x = position.x, y = position.y, z = position.z }) :: EnemyWorldPosition
end

local function decision(
	phaseIdAfter: string,
	isVulnerable: boolean,
	slamActionId: string,
	slamTargetPosition: EnemyWorldPosition?,
	slamImpacts: { AuthoritativeEnemyAttack },
	shouldSummonBrood: boolean,
	broodSurgeCount: number,
	shroudActive: boolean,
	visibilityOverrideRadiusStuds: number?,
	outcomeId: string,
	rejectionReasonId: string?
): BossPhaseDecision
	return table.freeze({
		phaseIdAfter = phaseIdAfter,
		isVulnerable = isVulnerable,
		slamActionId = slamActionId,
		slamTargetPosition = slamTargetPosition,
		slamImpacts = slamImpacts,
		shouldSummonBrood = shouldSummonBrood,
		broodSurgeCount = broodSurgeCount,
		shroudActive = shroudActive,
		visibilityOverrideRadiusStuds = visibilityOverrideRadiusStuds,
		outcomeId = outcomeId,
		rejectionReasonId = rejectionReasonId,
	}) :: BossPhaseDecision
end

local function invalidFactsDecision(phaseId: string): BossPhaseDecision
	return decision(
		phaseId,
		false,
		ActionIds.None,
		nil,
		EMPTY_IMPACTS,
		false,
		0,
		false,
		nil,
		OutcomeIds.Pending,
		RejectionReasonIds.InvalidFacts
	)
end

-- The monotonic phase from health, never regressing below the incoming phase.
local function resolvePhase(currentPhaseId: string, currentHealth: number, maximumHealth: number): string
	local healthPhaseId: string
	if currentHealth <= 0 then
		healthPhaseId = PhaseIds.Defeated
	else
		local fraction = currentHealth / maximumHealth
		if fraction <= BossConfig.Progenitor.CollapseHealthFraction then
			healthPhaseId = PhaseIds.Collapse
		elseif fraction <= BossConfig.Progenitor.BroodHealthFraction then
			healthPhaseId = PhaseIds.Brood
		else
			healthPhaseId = PhaseIds.Carapace
		end
	end
	if PhaseOrder[healthPhaseId] >= PhaseOrder[currentPhaseId] then
		return healthPhaseId
	end
	return currentPhaseId
end

function BossPhaseResolver.resolveBossPhase(
	boss: BossPhaseFacts,
	operatives: { EnemyOperativeFact },
	serverTimestamp: number
): BossPhaseDecision
	if
		type(boss) ~= "table"
		or not isNonemptyString(boss.entityId)
		or not isKnownValue(PhaseIds :: any, boss.phaseId)
		or not isWorldPosition(boss.position)
		or not isFiniteNumber(boss.currentHealth)
		or not isFiniteNumber(boss.maximumHealth)
		or boss.maximumHealth <= 0
		or type(boss.broodSummonedForPhase) ~= "boolean"
		or type(boss.floodlightsRestored) ~= "boolean"
		or type(operatives) ~= "table"
	then
		return invalidFactsDecision(PhaseIds.Carapace)
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return decision(
			boss.phaseId,
			false,
			ActionIds.None,
			nil,
			EMPTY_IMPACTS,
			false,
			0,
			false,
			nil,
			OutcomeIds.Pending,
			RejectionReasonIds.InvalidTimestamp
		)
	end

	local lastSlamCommit = boss.lastSlamCommitServerTimestamp
	if
		lastSlamCommit ~= nil
		and (not isFiniteTimestamp(lastSlamCommit) or (lastSlamCommit :: number) > serverTimestamp)
	then
		return invalidFactsDecision(boss.phaseId)
	end

	local slamTarget = boss.slamTargetPosition
	local slamWindupStartedAt = boss.slamWindupStartedServerTimestamp
	local hasSlamTarget = slamTarget ~= nil
	local hasSlamTimestamp = slamWindupStartedAt ~= nil
	local hasWindup = hasSlamTarget and hasSlamTimestamp
	if
		hasSlamTarget ~= hasSlamTimestamp
		or (hasSlamTarget and not isWorldPosition(slamTarget))
		or (
			hasSlamTimestamp
			and (not isFiniteTimestamp(slamWindupStartedAt) or (slamWindupStartedAt :: number) > serverTimestamp)
		)
	then
		return invalidFactsDecision(boss.phaseId)
	end

	local phaseIdAfter = resolvePhase(boss.phaseId, boss.currentHealth, boss.maximumHealth)

	if phaseIdAfter == PhaseIds.Defeated then
		return decision(
			PhaseIds.Defeated,
			false,
			if hasWindup then ActionIds.Cancel else ActionIds.None,
			nil,
			EMPTY_IMPACTS,
			false,
			0,
			false,
			nil,
			OutcomeIds.Defeated,
			nil
		)
	end

	local phaseTuning = BossConfig.Phases[phaseIdAfter]
	local isVulnerable = lastSlamCommit ~= nil
		and serverTimestamp < (lastSlamCommit :: number) + phaseTuning.ExposureWindowSeconds

	local shroudActive = phaseIdAfter == PhaseIds.Brood
	local visibilityOverride: number? = nil
	if phaseIdAfter == PhaseIds.Brood then
		visibilityOverride = BossConfig.Visibility.ShroudRadiusStuds
	elseif phaseIdAfter == PhaseIds.Collapse and not boss.floodlightsRestored then
		visibilityOverride = BossConfig.Visibility.CollapseDarkRadiusStuds
	end

	local shouldSummonBrood = phaseIdAfter == PhaseIds.Brood and not boss.broodSummonedForPhase
	local broodSurgeCount = if shouldSummonBrood then BossConfig.Brood.SurgeCount else 0

	local function phaseDecision(
		slamActionId: string,
		slamTargetPosition: EnemyWorldPosition?,
		slamImpacts: { AuthoritativeEnemyAttack }
	): BossPhaseDecision
		return decision(
			phaseIdAfter,
			isVulnerable,
			slamActionId,
			slamTargetPosition,
			slamImpacts,
			shouldSummonBrood,
			broodSurgeCount,
			shroudActive,
			visibilityOverride,
			OutcomeIds.Pending,
			nil
		)
	end

	if hasWindup then
		local startedAt = slamWindupStartedAt :: number
		local center = slamTarget :: EnemyWorldPosition
		local commitAt = startedAt + phaseTuning.SlamWindupSeconds
		if serverTimestamp < commitAt then
			return phaseDecision(ActionIds.Continue, copyPosition(center), EMPTY_IMPACTS)
		end
		local radiusSquared = BossConfig.Slam.RadiusStuds * BossConfig.Slam.RadiusStuds
		local impacts: { AuthoritativeEnemyAttack } = {}
		for _, operative in operatives do
			if
				type(operative) == "table"
				and isNonemptyString(operative.operativeEntityId)
				and operative.isAlive == true
				and isWorldPosition(operative.position)
				and horizontalDistanceSquared(center, operative.position) <= radiusSquared
			then
				table.insert(
					impacts,
					table.freeze({
						damageEventId = "bossslam:"
							.. boss.entityId
							.. ":"
							.. operative.operativeEntityId
							.. ":"
							.. tostring(startedAt),
						sourceEntityId = boss.entityId,
						targetEntityId = operative.operativeEntityId,
						damageAmount = BossConfig.Slam.Damage,
						serverTimestamp = serverTimestamp,
					}) :: AuthoritativeEnemyAttack
				)
			end
		end
		return phaseDecision(ActionIds.Commit, copyPosition(center), table.freeze(impacts))
	end

	local slamCooldownElapsed = lastSlamCommit == nil
		or serverTimestamp >= (lastSlamCommit :: number) + phaseTuning.SlamCooldownSeconds
	if slamCooldownElapsed then
		return phaseDecision(ActionIds.Begin, copyPosition(boss.position), EMPTY_IMPACTS)
	end
	return phaseDecision(ActionIds.None, nil, EMPTY_IMPACTS)
end

return table.freeze(BossPhaseResolver)
