--!strict

--[[
	Resolves one already accepted authoritative shot against current server-owned
	target facts. The caller owns the obstruction test and must provide exactly one
	TargetHit, Blocked, or Miss result; this module performs no raycast or discovery.
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

type AuthoritativeFireResult = CombatContracts.AuthoritativeFireResult
type FirearmHitRejectionReasonId = CombatContracts.FirearmHitRejectionReasonId
type FirearmHitResolution = CombatContracts.FirearmHitResolution
type FirearmTargetContext = CombatContracts.FirearmTargetContext
type ShotResolutionContext = CombatContracts.ShotResolutionContext

type FirearmHitResolver = {
	resolve: (
		acceptedFireResult: AuthoritativeFireResult,
		shotContext: ShotResolutionContext,
		targetContext: FirearmTargetContext
	) -> FirearmHitResolution,
}

local FirearmHitResolver: FirearmHitResolver = {} :: FirearmHitResolver
local reasons = CombatContracts.FirearmHitRejectionReasonIds

local function reject(fireResult: AuthoritativeFireResult, reasonId: FirearmHitRejectionReasonId): FirearmHitResolution
	return {
		shotId = fireResult.shotId,
		sourceEntityId = fireResult.operativeEntityId,
		targetEntityId = fireResult.targetEntityId,
		weaponId = fireResult.weaponId,
		didHit = false,
		rejectionReasonId = reasonId,
	}
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function expectedShotId(fireResult: AuthoritativeFireResult): string?
	if
		not isNonEmptyString(fireResult.operativeEntityId)
		or not isNonEmptyString(fireResult.weaponId)
		or fireResult.firedAtServerTimestamp == nil
	then
		return nil
	end

	return string.format(
		"shot:%s:%s:%.17g",
		fireResult.operativeEntityId,
		fireResult.weaponId,
		fireResult.firedAtServerTimestamp
	)
end

local function horizontalDistanceSquared(first: Vector3, second: Vector3): number
	local deltaX = second.X - first.X
	local deltaZ = second.Z - first.Z
	return deltaX * deltaX + deltaZ * deltaZ
end

function FirearmHitResolver.resolve(
	acceptedFireResult: AuthoritativeFireResult,
	shotContext: ShotResolutionContext,
	targetContext: FirearmTargetContext
): FirearmHitResolution
	if
		acceptedFireResult.statusId ~= CombatContracts.AuthoritativeFireStatusIds.Fired
		or acceptedFireResult.didHit ~= nil
		or acceptedFireResult.hitEntityId ~= nil
	then
		return reject(acceptedFireResult, reasons.FireNotAccepted)
	end

	local shotId = acceptedFireResult.shotId
	local selectedTargetEntityId = acceptedFireResult.targetEntityId
	local expectedId = expectedShotId(acceptedFireResult)
	if
		not isNonEmptyString(shotId)
		or shotId ~= expectedId
		or not isNonEmptyString(selectedTargetEntityId)
		or shotContext.operativeEntityId ~= acceptedFireResult.operativeEntityId
	then
		return reject(acceptedFireResult, reasons.MissingShotIdentity)
	end

	local weapon = resolveWeaponDefinition(acceptedFireResult.weaponId)
	if weapon == nil or shotContext.weaponId ~= acceptedFireResult.weaponId then
		return reject(acceptedFireResult, reasons.WeaponInvalid)
	end

	if
		shotContext.selectedTargetEntityId ~= selectedTargetEntityId
		or targetContext.entityId ~= selectedTargetEntityId
	then
		return reject(acceptedFireResult, reasons.TargetMismatch)
	end

	if not targetContext.isAlive then
		return reject(acceptedFireResult, reasons.TargetDead)
	end

	if not targetContext.isTargetable then
		return reject(acceptedFireResult, reasons.TargetInvalid)
	end

	if targetContext.relationshipId ~= CombatContracts.TeamRelationshipIds.Hostile then
		return reject(acceptedFireResult, reasons.TargetNotHostile)
	end

	if not targetContext.isVisible then
		return reject(acceptedFireResult, reasons.NotVisible)
	end

	local maximumRange = weapon.RangeStuds
	if
		horizontalDistanceSquared(shotContext.operativeWorldPosition, targetContext.worldPosition)
		> maximumRange * maximumRange
	then
		return reject(acceptedFireResult, reasons.OutOfRange)
	end

	if shotContext.obstructionResultId == CombatContracts.ShotObstructionResultIds.Blocked then
		return reject(acceptedFireResult, reasons.LineOfSightBlocked)
	end

	if shotContext.obstructionResultId ~= CombatContracts.ShotObstructionResultIds.TargetHit then
		return reject(acceptedFireResult, reasons.Miss)
	end

	return {
		shotId = shotId,
		sourceEntityId = acceptedFireResult.operativeEntityId,
		targetEntityId = selectedTargetEntityId,
		weaponId = acceptedFireResult.weaponId,
		didHit = true,
		rejectionReasonId = nil,
	}
end

return table.freeze(FirearmHitResolver)
