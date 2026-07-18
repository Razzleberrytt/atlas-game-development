--!strict
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
type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type TargetCandidate = CombatContracts.TargetCandidate
type TargetValidationResult = CombatContracts.TargetValidationResult
type WeaponReadinessState = CombatContracts.WeaponReadinessState
export type OperativeTargetingState = {
	worldPosition: Vector3,
	combatStateId: OperativeCombatStateId,
	weaponReadiness: WeaponReadinessState,
}
local Validator = {}
local reasons = CombatContracts.TargetValidationRejectionReasonIds
local function reject(reasonId)
	return { isValid = false, rejectionReasonId = reasonId }
end
local function distanceSquared(a: Vector3, b: Vector3): number
	local x = b.X - a.X
	local z = b.Z - a.Z
	return x * x + z * z
end
function Validator.validate(operative: OperativeTargetingState, candidate: TargetCandidate): TargetValidationResult
	if operative.combatStateId ~= CombatContracts.OperativeCombatStateIds.Ready then
		return reject(reasons.OperativeStateInvalid)
	end
	if candidate.relationshipId ~= CombatContracts.TeamRelationshipIds.Hostile then
		return reject(reasons.RelationshipNotHostile)
	end
	if not candidate.isAlive then
		return reject(reasons.HostileDead)
	end
	if not candidate.isTargetable then
		return reject(reasons.HostileUntargetable)
	end
	if not candidate.isVisible then
		return reject(reasons.NotVisible)
	end
	if not candidate.hasLineOfSight then
		return reject(reasons.NoLineOfSight)
	end
	local weapon = resolveWeaponDefinition(operative.weaponReadiness.weaponId)
	if
		weapon == nil
		or operative.weaponReadiness.ammunition.weaponId ~= weapon.WeaponId
		or operative.weaponReadiness.cadence.weaponId ~= weapon.WeaponId
		or operative.weaponReadiness.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Ready
	then
		return reject(reasons.WeaponNotReady)
	end
	if distanceSquared(operative.worldPosition, candidate.worldPosition) > weapon.RangeStuds * weapon.RangeStuds then
		return reject(reasons.OutOfRange)
	end
	if operative.weaponReadiness.ammunition.loadedRounds <= 0 then
		return reject(reasons.NoAmmunition)
	end
	return { isValid = true, rejectionReasonId = nil }
end
return table.freeze(Validator)
