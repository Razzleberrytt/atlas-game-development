--!strict

-- Pure bounded geometry only. Qualification means a point is inside the
-- authoritative cone; it does not establish LOS, observation, disclosure, or
-- target eligibility and performs no raycast or world scan.
local PersonalFlashlightCoverage = {}

export type VectorFacts = { x: number, y: number, z: number }
export type CoverageFacts = {
	origin: VectorFacts,
	direction: VectorFacts,
	rangeStuds: number,
	coneAngleDegrees: number,
	visibilityProfileId: string,
}

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function vector(value: unknown): VectorFacts?
	if type(value) ~= "table" then
		return nil
	end
	local candidate = value :: any
	if not finite(candidate.x) or not finite(candidate.y) or not finite(candidate.z) then
		return nil
	end
	return { x = candidate.x, y = candidate.y, z = candidate.z }
end

local function magnitudeSquared(value: VectorFacts): number
	return value.x * value.x + value.y * value.y + value.z * value.z
end

function PersonalFlashlightCoverage.buildFacts(
	originValue: unknown,
	directionValue: unknown,
	rangeStuds: number,
	coneAngleDegrees: number,
	visibilityProfileId: string
): CoverageFacts?
	local origin = vector(originValue)
	local direction = vector(directionValue)
	if
		origin == nil
		or direction == nil
		or not finite(rangeStuds)
		or rangeStuds <= 0
		or not finite(coneAngleDegrees)
		or coneAngleDegrees <= 0
		or coneAngleDegrees > 180
		or type(visibilityProfileId) ~= "string"
		or visibilityProfileId == ""
	then
		return nil
	end
	local directionMagnitudeSquared = magnitudeSquared(direction)
	if directionMagnitudeSquared <= 0 then
		return nil
	end
	local inverseMagnitude = 1 / math.sqrt(directionMagnitudeSquared)
	return table.freeze({
		origin = table.freeze(origin),
		direction = table.freeze({
			x = direction.x * inverseMagnitude,
			y = direction.y * inverseMagnitude,
			z = direction.z * inverseMagnitude,
		}),
		rangeStuds = rangeStuds,
		coneAngleDegrees = coneAngleDegrees,
		visibilityProfileId = visibilityProfileId,
	})
end

function PersonalFlashlightCoverage.qualifiesPoint(factsValue: unknown, pointValue: unknown): boolean
	if type(factsValue) ~= "table" then
		return false
	end
	local facts = factsValue :: any
	local origin = vector(facts.origin)
	local direction = vector(facts.direction)
	local point = vector(pointValue)
	if
		origin == nil
		or direction == nil
		or point == nil
		or not finite(facts.rangeStuds)
		or not finite(facts.coneAngleDegrees)
	then
		return false
	end
	local offset = {
		x = point.x - origin.x,
		y = point.y - origin.y,
		z = point.z - origin.z,
	}
	local distanceSquared = magnitudeSquared(offset)
	if distanceSquared > facts.rangeStuds * facts.rangeStuds then
		return false
	end
	if distanceSquared == 0 then
		return true
	end
	local directionMagnitudeSquared = magnitudeSquared(direction)
	if directionMagnitudeSquared <= 0 then
		return false
	end
	local dot = offset.x * direction.x + offset.y * direction.y + offset.z * direction.z
	local cosine = dot / math.sqrt(distanceSquared * directionMagnitudeSquared)
	local minimumCosine = math.cos(math.rad(facts.coneAngleDegrees * 0.5))
	return cosine >= minimumCosine
end

return table.freeze(PersonalFlashlightCoverage)
