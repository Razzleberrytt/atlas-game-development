--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local worldPath = "games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"
local placementPath = "games/living-kingdoms/src/shared/Config/EnvironmentModelPlacementConfig.luau"
local mathPath = "games/living-kingdoms/src/shared/Environment/EnvironmentCompositionMath.luau"

local function loadPureModule(path)
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})()
end

local world = loadPureModule(worldPath)
local placementConfig = loadPureModule(placementPath)
local compositionMath = loadPureModule(mathPath)

local firstPlan = compositionMath.Plan(world, placementConfig)
local secondPlan = compositionMath.Plan(world, placementConfig)

assert(#firstPlan == 59, "shared environment composition must produce the 59-model budget")
assert(#secondPlan == #firstPlan, "repeated environment composition changed model count")

local specByAssetId = {}
for _, spec in placementConfig.AssetSpecs do
	specByAssetId[spec.assetId] = spec
end

local tierCounts = {
	Anchor = 0,
	Mass = 0,
	Detail = 0,
}
local idSet = {}

for index, placement in firstPlan do
	local repeated = secondPlan[index]
	assert(repeated ~= nil, "deterministic environment composition lost a placement")
	assert(placement.id == repeated.id, "deterministic environment composition changed placement identity")
	assert(placement.assetId == repeated.assetId, "deterministic environment composition changed asset identity")
	assert(placement.x == repeated.x, "deterministic environment composition changed x")
	assert(placement.z == repeated.z, "deterministic environment composition changed z")
	assert(placement.yawDegrees == repeated.yawDegrees, "deterministic environment composition changed yaw")
	assert(placement.fieldScore == repeated.fieldScore, "deterministic environment composition changed field score")
	assert(not idSet[placement.id], "environment composition placement ids must be unique")
	idSet[placement.id] = true

	local spec = specByAssetId[placement.assetId]
	assert(spec ~= nil, "environment composition returned an unconfigured semantic asset")
	assert(placement.tier == spec.tier, "environment composition changed hierarchy tier")
	tierCounts[placement.tier] += 1

	local evaluation = compositionMath.EvaluatePoint(world, placement.x, placement.z)
	assert(
		evaluation.landmarkClearance >= placementConfig.LandmarkPaddingStuds,
		"environment composition violated landmark clearance"
	)
	assert(evaluation.routeDistance >= spec.minRouteDistanceStuds, "environment composition violated route clearance")
	assert(evaluation.creekDistance >= spec.minCreekDistanceStuds, "environment composition violated creek clearance")
	assert(evaluation[placement.field] > 0, "environment composition accepted a non-positive story field")
end

assert(tierCounts.Anchor == 20, "shared composition changed Anchor model budget")
assert(tierCounts.Mass == 18, "shared composition changed Mass model budget")
assert(tierCounts.Detail == 21, "shared composition changed Detail model budget")

for leftIndex = 1, #firstPlan do
	local left = firstPlan[leftIndex]
	local leftSpec = specByAssetId[left.assetId]
	for rightIndex = leftIndex + 1, #firstPlan do
		local right = firstPlan[rightIndex]
		local dx = left.x - right.x
		local dz = left.z - right.z
		local distance = math.sqrt(dx * dx + dz * dz)
		if left.assetId == right.assetId then
			assert(distance >= leftSpec.minSpacingStuds, "same-family Poisson spacing was violated")
		else
			local requiredDistance = (left.packingRadiusStuds + right.packingRadiusStuds)
				* placementConfig.CrossFamilySpacingScale
			assert(distance >= requiredDistance, "cross-family footprint packing was violated")
		end
	end
end

local extraction = compositionMath.EvaluatePoint(world, 218, 58)
local campground = compositionMath.EvaluatePoint(world, -92, 45)
assert(extraction.corruption > extraction.camp, "Extraction Clearing must read more corrupted than camp-like")
assert(campground.camp > campground.industry, "Campground must read more camp-like than industrial")

print("EnvironmentCompositionMath: deterministic 59-model plan and spatial constraints passed")
