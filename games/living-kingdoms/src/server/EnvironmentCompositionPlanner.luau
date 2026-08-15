--!strict

--[[
	Deterministic hierarchical environmental composition planner.

	The authored world defines landmarks, a primary route, and a creek. This module
	turns those semantic constraints into presentation-model placements by combining:
	- Gaussian attraction/repulsion fields for environmental storytelling,
	- minimum route/creek/landmark clearances for gameplay readability,
	- seeded candidate generation for reproducibility,
	- tiered anchor -> mass -> detail placement,
	- greedy Poisson-like same-family spacing,
	- global footprint-aware packing across every generated family.

	The planner is runtime placement logic only. Generated models remain
	presentation-only and own no collision, navigation, combat, or progression truth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local PlacementConfig = require(ReplicatedStorage.Shared.Config.EnvironmentModelPlacementConfig)

local EnvironmentCompositionPlanner = {}

local MODULUS = 2147483647
local MULTIPLIER = 48271

type Point2 = {
	x: number,
	z: number,
}

type Landmark2 = Point2 & {
	radius: number,
}

type Candidate = {
	priority: number,
	fieldScore: number,
	x: number,
	z: number,
	yawDegrees: number,
}

type Placement = {
	id: string,
	assetId: string,
	field: string,
	tier: string,
	packingRadiusStuds: number,
	x: number,
	z: number,
	yawDegrees: number,
	fieldScore: number,
}

type AssetSpec = {
	idPrefix: string,
	assetId: string,
	field: string,
	tier: string,
	count: number,
	packingRadiusStuds: number,
	minSpacingStuds: number,
	minRouteDistanceStuds: number,
	minCreekDistanceStuds: number,
}

type PackedPlacement = {
	x: number,
	z: number,
	packingRadiusStuds: number,
}

type RandomState = {
	state: number,
}

local function nextRandom(randomState: RandomState): number
	randomState.state = (randomState.state * MULTIPLIER) % MODULUS
	return randomState.state / MODULUS
end

local function initializeRandom(seed: number): RandomState
	local normalizedSeed = seed % MODULUS
	if normalizedSeed <= 0 then
		normalizedSeed += MODULUS - 1
	end
	return { state = normalizedSeed }
end

local function gaussian(distance: number, sigma: number): number
	return math.exp(-(distance * distance) / (2 * sigma * sigma))
end

local function pointSegmentDistance(point: Point2, segmentA: Point2, segmentB: Point2): number
	local dx = segmentB.x - segmentA.x
	local dz = segmentB.z - segmentA.z
	local denominator = dx * dx + dz * dz
	if denominator == 0 then
		local offsetX = point.x - segmentA.x
		local offsetZ = point.z - segmentA.z
		return math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
	end

	local t = ((point.x - segmentA.x) * dx + (point.z - segmentA.z) * dz) / denominator
	t = math.clamp(t, 0, 1)

	local closestX = segmentA.x + t * dx
	local closestZ = segmentA.z + t * dz
	local offsetX = point.x - closestX
	local offsetZ = point.z - closestZ
	return math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
end

local function polylineDistance(point: Point2, points: { Point2 }): number
	assert(#points >= 2, "Environment composition polyline requires at least two points")
	local bestDistance = math.huge
	for index = 1, #points - 1 do
		bestDistance = math.min(bestDistance, pointSegmentDistance(point, points[index], points[index + 1]))
	end
	return bestDistance
end

local function pointDistance(a: Point2, b: Point2): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local function buildLandmarkMap(): { [string]: Landmark2 }
	local landmarks: { [string]: Landmark2 } = {}
	for _, landmark in WorldFoundationConfig.Landmarks do
		landmarks[landmark.id] = {
			x = landmark.x,
			z = landmark.z,
			radius = landmark.radius,
		}
	end
	return landmarks
end

local function buildRoutePoints(): { Point2 }
	local points: { Point2 } = {}
	for _, routePoint in WorldFoundationConfig.Dressing.TrailReflectorPositions do
		table.insert(points, { x = routePoint.x, z = routePoint.z })
	end
	return points
end

local function buildCreekPoints(): { Point2 }
	local points: { Point2 } = {}
	for _, creekPoint in WorldFoundationConfig.EnvironmentPresentation.Water.CreekPoints do
		table.insert(points, { x = creekPoint.x, z = creekPoint.z })
	end
	return points
end

local function requireLandmark(landmarks: { [string]: Landmark2 }, id: string): Landmark2
	local landmark = landmarks[id]
	assert(landmark ~= nil, string.format("Missing environment-composition landmark: %s", id))
	return landmark
end

local function landmarkDistance(point: Point2, landmarks: { [string]: Landmark2 }, id: string): number
	return pointDistance(point, requireLandmark(landmarks, id))
end

local function minimumLandmarkClearance(point: Point2, landmarks: { [string]: Landmark2 }): number
	local minimumClearance = math.huge
	for _, landmark in landmarks do
		minimumClearance = math.min(minimumClearance, pointDistance(point, landmark) - landmark.radius)
	end
	return minimumClearance
end

local function fieldScore(
	fieldName: string,
	point: Point2,
	landmarks: { [string]: Landmark2 },
	routeDistance: number,
	creekDistance: number
): number
	if fieldName == "frontier" then
		return 0.55
			+ 0.50 * gaussian(landmarkDistance(point, landmarks, "RockyOverlook"), 105)
			+ 0.35 * gaussian(landmarkDistance(point, landmarks, "Campground"), 95)
			+ 0.18 * gaussian(creekDistance, 70)
			- 0.80 * gaussian(routeDistance, 22)
	elseif fieldName == "corruption" then
		return 1.10 * gaussian(landmarkDistance(point, landmarks, "ExtractionClearing"), 120)
			+ 0.42 * gaussian(landmarkDistance(point, landmarks, "RockyOverlook"), 115)
			- 0.75 * gaussian(landmarkDistance(point, landmarks, "RangerStation"), 100)
			- 0.60 * gaussian(routeDistance, 20)
	elseif fieldName == "industry" then
		return 1.05 * gaussian(landmarkDistance(point, landmarks, "MilitaryRoadblock"), 95)
			+ 0.70 * gaussian(landmarkDistance(point, landmarks, "LoggingRoad"), 80)
			- 0.65 * gaussian(routeDistance, 18)
			- 0.30 * gaussian(creekDistance, 28)
	elseif fieldName == "camp" then
		return 1.15 * gaussian(landmarkDistance(point, landmarks, "Campground"), 72)
			+ 0.30 * gaussian(landmarkDistance(point, landmarks, "RangerStation"), 100)
			- 0.70 * gaussian(routeDistance, 18)
	end

	error(string.format("Unknown environment composition field: %s", fieldName))
end

local function candidateDistance(candidate: Candidate, x: number, z: number): number
	local dx = candidate.x - x
	local dz = candidate.z - z
	return math.sqrt(dx * dx + dz * dz)
end

local function isFarEnough(candidate: Candidate, chosen: { Candidate }, minimumSpacing: number): boolean
	for _, accepted in chosen do
		if candidateDistance(candidate, accepted.x, accepted.z) < minimumSpacing then
			return false
		end
	end
	return true
end

local function isGloballyFarEnough(
	candidate: Candidate,
	spec: AssetSpec,
	globalAccepted: { PackedPlacement }
): boolean
	for _, accepted in globalAccepted do
		local requiredDistance =
			(spec.packingRadiusStuds + accepted.packingRadiusStuds) * PlacementConfig.CrossFamilySpacingScale
		if candidateDistance(candidate, accepted.x, accepted.z) < requiredDistance then
			return false
		end
	end
	return true
end

local function generateForSpec(
	spec: AssetSpec,
	randomState: RandomState,
	landmarks: { [string]: Landmark2 },
	routePoints: { Point2 },
	creekPoints: { Point2 },
	globalAccepted: { PackedPlacement }
): { Placement }
	local candidates: { Candidate } = {}
	local halfExtent = PlacementConfig.HalfExtentStuds

	for _ = 1, PlacementConfig.CandidateCountPerAsset do
		local x = -halfExtent + (2 * halfExtent) * nextRandom(randomState)
		local z = -halfExtent + (2 * halfExtent) * nextRandom(randomState)
		local point = { x = x, z = z }
		local routeDistance = polylineDistance(point, routePoints)
		local creekDistance = polylineDistance(point, creekPoints)
		local landmarkClearance = minimumLandmarkClearance(point, landmarks)
		local jitter = 0.75 + 0.50 * nextRandom(randomState)
		local yawDegrees = -180 + 360 * nextRandom(randomState)

		if
			landmarkClearance >= PlacementConfig.LandmarkPaddingStuds
			and routeDistance >= spec.minRouteDistanceStuds
			and creekDistance >= spec.minCreekDistanceStuds
		then
			local score = math.max(0, fieldScore(spec.field, point, landmarks, routeDistance, creekDistance))
			if score > 0 then
				table.insert(candidates, {
					priority = score * jitter,
					fieldScore = score,
					x = x,
					z = z,
					yawDegrees = yawDegrees,
				})
			end
		end
	end

	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)

	local chosen: { Candidate } = {}
	for _, candidate in candidates do
		if
			isFarEnough(candidate, chosen, spec.minSpacingStuds)
			and isGloballyFarEnough(candidate, spec, globalAccepted)
		then
			table.insert(chosen, candidate)
			if #chosen >= spec.count then
				break
			end
		end
	end

	assert(
		#chosen == spec.count,
		string.format("Environment composition could only place %d/%d assets for %s", #chosen, spec.count, spec.assetId)
	)

	local placements: { Placement } = {}
	for index, candidate in chosen do
		local placement = {
			id = string.format("%s.%02d", spec.idPrefix, index),
			assetId = spec.assetId,
			field = spec.field,
			tier = spec.tier,
			packingRadiusStuds = spec.packingRadiusStuds,
			x = candidate.x,
			z = candidate.z,
			yawDegrees = candidate.yawDegrees,
			fieldScore = candidate.fieldScore,
		}
		table.insert(placements, placement)
		table.insert(globalAccepted, {
			x = candidate.x,
			z = candidate.z,
			packingRadiusStuds = spec.packingRadiusStuds,
		})
	end
	return placements
end

function EnvironmentCompositionPlanner.Plan(): { Placement }
	local landmarks = buildLandmarkMap()
	local routePoints = buildRoutePoints()
	local creekPoints = buildCreekPoints()
	local randomState = initializeRandom(PlacementConfig.Seed)
	local placements: { Placement } = {}
	local globalAccepted: { PackedPlacement } = {}

	for _, tierName in PlacementConfig.TierOrder do
		for _, rawSpec in PlacementConfig.AssetSpecs do
			local spec = rawSpec :: AssetSpec
			if spec.tier == tierName then
				local generated = generateForSpec(spec, randomState, landmarks, routePoints, creekPoints, globalAccepted)
				for _, placement in generated do
					table.insert(placements, placement)
				end
			end
		end
	end

	return placements
end

return table.freeze(EnvironmentCompositionPlanner)
