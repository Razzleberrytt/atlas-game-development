--!strict

--[[
	Validates one server-derived automatic-target candidate without discovering,
	selecting, caching, or mutating combat state. The caller is responsible for
	supplying authoritative server facts; this module cannot prove their provenance.

	Range uses horizontal XZ distance so prototype elevation does not change the
	legal engagement radius. The inclusive comparison makes exactly maximum range
	valid and any greater distance invalid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type TargetCandidate = CombatContracts.TargetCandidate
type TargetValidationResult = CombatContracts.TargetValidationResult
type WeaponReadinessState = CombatContracts.WeaponReadinessState

export type OperativeTargetingState = {
	worldPosition: Vector3,
	combatStateId: OperativeCombatStateId,
	weaponReadiness: WeaponReadinessState,
}

type TargetCandidateValidator = {
	validate: (operative: OperativeTargetingState, candidate: TargetCandidate) -> TargetValidationResult,
}

local TargetCandidateValidator: TargetCandidateValidator = {} :: TargetCandidateValidator
local rejectionReasons = CombatContracts.TargetValidationRejectionReasonIds

local function reject(reasonId: CombatContracts.TargetValidationRejectionReasonId): TargetValidationResult
	return {
		isValid = false,
		rejectionReasonId = reasonId,
	}
end

local function horizontalDistanceSquared(first: Vector3, second: Vector3): number
	local deltaX = second.X - first.X
	local deltaZ = second.Z - first.Z
	return deltaX * deltaX + deltaZ * deltaZ
end

function TargetCandidateValidator.validate(
	operative: OperativeTargetingState,
	candidate: TargetCandidate
): TargetValidationResult
	if operative.combatStateId ~= CombatContracts.OperativeCombatStateIds.Ready then
		return reject(rejectionReasons.OperativeStateInvalid)
	end

	if candidate.relationshipId ~= CombatContracts.TeamRelationshipIds.Hostile then
		return reject(rejectionReasons.RelationshipNotHostile)
	end

	if not candidate.isAlive then
		return reject(rejectionReasons.HostileDead)
	end

	if not candidate.isTargetable then
		return reject(rejectionReasons.HostileUntargetable)
	end

	if not candidate.isVisible then
		return reject(rejectionReasons.NotVisible)
	end

	if not candidate.hasLineOfSight then
		return reject(rejectionReasons.NoLineOfSight)
	end

	local maximumRange = FirearmConfig.BasicFirearm.RangeStuds
	if horizontalDistanceSquared(operative.worldPosition, candidate.worldPosition) > maximumRange * maximumRange then
		return reject(rejectionReasons.OutOfRange)
	end

	if operative.weaponReadiness.ammunition.loadedRounds <= 0 then
		return reject(rejectionReasons.NoAmmunition)
	end

	if
		operative.weaponReadiness.weaponId ~= FirearmConfig.BasicFirearm.WeaponId
		or operative.weaponReadiness.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Ready
	then
		return reject(rejectionReasons.WeaponNotReady)
	end

	return {
		isValid = true,
		rejectionReasonId = nil,
	}
end

return table.freeze(TargetCandidateValidator)
