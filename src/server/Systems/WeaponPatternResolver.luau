--!strict

--[[
	Pure deterministic secondary-target resolver for already accepted shots.
	The caller supplies only current server-derived sight facts. This module does
	not raycast, discover enemies, spend ammunition, resolve hits, apply damage,
	commit health, or present combat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponPatternConfig = require(ReplicatedStorage.Shared.Config.WeaponPatternConfig)

export type PatternTargetFact = {
	entityId: string,
	worldPosition: { X: number, Y: number, Z: number },
	isAlive: boolean,
	isTargetable: boolean,
	isVisible: boolean,
	hasLineOfSight: boolean,
}

export type PatternImpact = {
	targetEntityId: string,
	damageMultiplier: number,
	requiresPierceValidation: boolean,
}

type RankedCandidate = {
	fact: PatternTargetFact,
	primaryScore: number,
	secondaryScore: number,
}

type WeaponPatternResolver = {
	resolve: (
		weaponId: string,
		operativeWorldPosition: { X: number, Y: number, Z: number },
		primaryTargetEntityId: string,
		targetFacts: { PatternTargetFact }
	) -> { PatternImpact },
}

local WeaponPatternResolver: WeaponPatternResolver = {} :: WeaponPatternResolver
local EMPTY_IMPACTS = table.freeze({})
local modes = WeaponPatternConfig.ModeIds

local function horizontalDelta(
	origin: { X: number, Y: number, Z: number },
	target: { X: number, Y: number, Z: number }
): (number, number)
	return target.X - origin.X, target.Z - origin.Z
end

local function isEligibleSecondary(fact: PatternTargetFact, primaryTargetEntityId: string): boolean
	return fact.entityId ~= primaryTargetEntityId
		and fact.entityId ~= ""
		and fact.isAlive
		and fact.isTargetable
		and fact.isVisible
end

local function findPrimary(targetFacts: { PatternTargetFact }, primaryTargetEntityId: string): PatternTargetFact?
	for _, fact in targetFacts do
		if fact.entityId == primaryTargetEntityId and fact.isAlive and fact.isTargetable and fact.isVisible then
			return fact
		end
	end
	return nil
end

local function rankConeCandidates(
	definition: WeaponPatternConfig.WeaponPatternDefinition,
	operativeWorldPosition: { X: number, Y: number, Z: number },
	primaryTargetEntityId: string,
	primaryDirectionX: number,
	primaryDirectionZ: number,
	targetFacts: { PatternTargetFact }
): { RankedCandidate }
	local ranked = {}
	local maximumRangeSquared = definition.MaximumSecondaryRangeStuds * definition.MaximumSecondaryRangeStuds
	local halfAngle = definition.ConeHalfAngleDegrees
	if halfAngle == nil then
		return ranked
	end
	local minimumDot = math.cos(math.rad(halfAngle))
	for _, fact in targetFacts do
		if not isEligibleSecondary(fact, primaryTargetEntityId) or not fact.hasLineOfSight then
			continue
		end
		local deltaX, deltaZ = horizontalDelta(operativeWorldPosition, fact.worldPosition)
		local distanceSquared = deltaX * deltaX + deltaZ * deltaZ
		if distanceSquared <= 0 or distanceSquared > maximumRangeSquared then
			continue
		end
		local distance = math.sqrt(distanceSquared)
		local forwardDot = (deltaX * primaryDirectionX + deltaZ * primaryDirectionZ) / distance
		if forwardDot < minimumDot then
			continue
		end
		table.insert(ranked, {
			fact = fact,
			primaryScore = distanceSquared,
			secondaryScore = -forwardDot,
		})
	end
	return ranked
end

local function rankPierceCandidates(
	definition: WeaponPatternConfig.WeaponPatternDefinition,
	operativeWorldPosition: { X: number, Y: number, Z: number },
	primaryTargetEntityId: string,
	primaryDistance: number,
	primaryDirectionX: number,
	primaryDirectionZ: number,
	targetFacts: { PatternTargetFact }
): { RankedCandidate }
	local ranked = {}
	local halfWidth = definition.PierceHalfWidthStuds
	local minimumBeyondPrimary = definition.MinimumBeyondPrimaryStuds
	if halfWidth == nil or minimumBeyondPrimary == nil then
		return ranked
	end
	for _, fact in targetFacts do
		if not isEligibleSecondary(fact, primaryTargetEntityId) then
			continue
		end
		local deltaX, deltaZ = horizontalDelta(operativeWorldPosition, fact.worldPosition)
		local forwardProjection = deltaX * primaryDirectionX + deltaZ * primaryDirectionZ
		if
			forwardProjection < primaryDistance + minimumBeyondPrimary
			or forwardProjection > definition.MaximumSecondaryRangeStuds
		then
			continue
		end
		local lateralDistance = math.abs(deltaX * primaryDirectionZ - deltaZ * primaryDirectionX)
		if lateralDistance > halfWidth then
			continue
		end
		table.insert(ranked, {
			fact = fact,
			primaryScore = forwardProjection,
			secondaryScore = lateralDistance,
		})
	end
	return ranked
end

local function sortRanked(ranked: { RankedCandidate })
	table.sort(ranked, function(first, second)
		if first.primaryScore ~= second.primaryScore then
			return first.primaryScore < second.primaryScore
		end
		if first.secondaryScore ~= second.secondaryScore then
			return first.secondaryScore < second.secondaryScore
		end
		return first.fact.entityId < second.fact.entityId
	end)
end

function WeaponPatternResolver.resolve(
	weaponId: string,
	operativeWorldPosition: { X: number, Y: number, Z: number },
	primaryTargetEntityId: string,
	targetFacts: { PatternTargetFact }
): { PatternImpact }
	local definition = WeaponPatternConfig.get(weaponId)
	if
		definition == nil
		or definition.ModeId == modes.SingleTarget
		or definition.MaximumSecondaryTargets <= 0
		or primaryTargetEntityId == ""
	then
		return EMPTY_IMPACTS
	end

	local primary = findPrimary(targetFacts, primaryTargetEntityId)
	if primary == nil or not primary.hasLineOfSight then
		return EMPTY_IMPACTS
	end
	local primaryDeltaX, primaryDeltaZ = horizontalDelta(operativeWorldPosition, primary.worldPosition)
	local primaryDistanceSquared = primaryDeltaX * primaryDeltaX + primaryDeltaZ * primaryDeltaZ
	if primaryDistanceSquared <= 0 then
		return EMPTY_IMPACTS
	end
	local primaryDistance = math.sqrt(primaryDistanceSquared)
	local primaryDirectionX = primaryDeltaX / primaryDistance
	local primaryDirectionZ = primaryDeltaZ / primaryDistance

	local ranked
	if definition.ModeId == modes.ConeCleave then
		ranked = rankConeCandidates(
			definition,
			operativeWorldPosition,
			primaryTargetEntityId,
			primaryDirectionX,
			primaryDirectionZ,
			targetFacts
		)
	elseif definition.ModeId == modes.LinePierce then
		ranked = rankPierceCandidates(
			definition,
			operativeWorldPosition,
			primaryTargetEntityId,
			primaryDistance,
			primaryDirectionX,
			primaryDirectionZ,
			targetFacts
		)
	else
		return EMPTY_IMPACTS
	end

	sortRanked(ranked)
	local impactCount = math.min(definition.MaximumSecondaryTargets, #ranked)
	if impactCount == 0 then
		return EMPTY_IMPACTS
	end
	local impacts = table.create(impactCount)
	for index = 1, impactCount do
		impacts[index] = table.freeze({
			targetEntityId = ranked[index].fact.entityId,
			damageMultiplier = definition.SecondaryDamageMultiplier,
			requiresPierceValidation = definition.ModeId == modes.LinePierce,
		})
	end
	return table.freeze(impacts)
end

return table.freeze(WeaponPatternResolver)
