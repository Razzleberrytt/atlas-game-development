--!strict

-- Generates a deterministic top-down SVG from the exact composition kernel used
-- by Roblox. Output is intentionally written to /tmp so visualization evidence is
-- reproducible without making generated files repository authority.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local worldPath = "games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"
local placementPath = "games/living-kingdoms/src/shared/Config/EnvironmentModelPlacementConfig.luau"
local mathPath = "games/living-kingdoms/src/shared/Environment/EnvironmentCompositionMath.luau"
local outputPath = "/tmp/LivingKingdomsEnvironmentComposition.svg"

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
local placements = compositionMath.Plan(world, placementConfig)

local canvasSize = 1040
local plotPadding = 80
local plotSize = canvasSize - plotPadding * 2
local halfExtent = placementConfig.HalfExtentStuds
local fieldGridSize = 32

local fieldColors = {
	frontier = "#59765a",
	corruption = "#76528b",
	industry = "#8b684d",
	camp = "#9a8150",
}
local tierColors = {
	Anchor = "#f4e4b2",
	Mass = "#d4d7c8",
	Detail = "#f2b887",
}

local function worldToCanvasX(x: number): number
	return plotPadding + ((x + halfExtent) / (halfExtent * 2)) * plotSize
end

local function worldToCanvasY(z: number): number
	return plotPadding + ((halfExtent - z) / (halfExtent * 2)) * plotSize
end

local function dominantField(evaluation): (string, number)
	local fieldName = "frontier"
	local bestScore = evaluation.frontier
	for _, candidate in { "corruption", "industry", "camp" } do
		local score = evaluation[candidate]
		if score > bestScore then
			fieldName = candidate
			bestScore = score
		end
	end
	return fieldName, bestScore
end

local function polylinePoints(points): string
	local output = {}
	for _, point in points do
		table.insert(output, string.format("%.2f,%.2f", worldToCanvasX(point.x), worldToCanvasY(point.z)))
	end
	return table.concat(output, " ")
end

local svg = {
	string.format(
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
		canvasSize,
		canvasSize,
		canvasSize,
		canvasSize
	),
	'<rect width="100%" height="100%" fill="#171b19"/>',
	'<text x="80" y="42" fill="#f0ead8" font-family="sans-serif" font-size="22" font-weight="700">Living Kingdoms — Environment Composition Blueprint</text>',
	string.format(
		'<text x="80" y="66" fill="#aaa99f" font-family="monospace" font-size="12">seed=%d | %s | %d placements</text>',
		placementConfig.Seed,
		placementConfig.AlgorithmVersion,
		#placements
	),
}

local cellWorldSize = (halfExtent * 2) / fieldGridSize
local cellCanvasSize = plotSize / fieldGridSize
for gridZ = 0, fieldGridSize - 1 do
	for gridX = 0, fieldGridSize - 1 do
		local x = -halfExtent + (gridX + 0.5) * cellWorldSize
		local z = -halfExtent + (gridZ + 0.5) * cellWorldSize
		local evaluation = compositionMath.EvaluatePoint(world, x, z)
		local fieldName, score = dominantField(evaluation)
		local opacity = math.clamp(0.08 + math.max(score, 0) * 0.18, 0.08, 0.34)
		local canvasX = plotPadding + gridX * cellCanvasSize
		local canvasY = plotPadding + (fieldGridSize - gridZ - 1) * cellCanvasSize
		table.insert(
			svg,
			string.format(
				'<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" fill-opacity="%.3f"/>',
				canvasX,
				canvasY,
				cellCanvasSize + 0.5,
				cellCanvasSize + 0.5,
				fieldColors[fieldName],
				opacity
			)
		)
	end
end

local route = {}
for _, point in world.Dressing.TrailReflectorPositions do
	table.insert(route, { x = point.x, z = point.z })
end
local creek = {}
for _, point in world.EnvironmentPresentation.Water.CreekPoints do
	table.insert(creek, { x = point.x, z = point.z })
end

table.insert(
	svg,
	string.format(
		'<polyline points="%s" fill="none" stroke="#d7c98c" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>',
		polylinePoints(route)
	)
)
table.insert(
	svg,
	string.format(
		'<polyline points="%s" fill="none" stroke="#77a9b4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
		polylinePoints(creek)
	)
)

for _, landmark in world.Landmarks do
	local radiusPixels = (landmark.radius / (halfExtent * 2)) * plotSize
	local x = worldToCanvasX(landmark.x)
	local y = worldToCanvasY(landmark.z)
	table.insert(
		svg,
		string.format(
			'<circle cx="%.2f" cy="%.2f" r="%.2f" fill="none" stroke="#e5dfc9" stroke-opacity="0.55" stroke-width="1.5"/>',
			x,
			y,
			radiusPixels
		)
	)
	table.insert(
		svg,
		string.format(
			'<text x="%.2f" y="%.2f" text-anchor="middle" fill="#ece7d8" font-family="sans-serif" font-size="10">%s</text>',
			x,
			y - radiusPixels - 5,
			landmark.displayName
		)
	)
end

for _, placement in placements do
	local x = worldToCanvasX(placement.x)
	local y = worldToCanvasY(placement.z)
	local radius = 3 + placement.packingRadiusStuds * 0.28
	local color = tierColors[placement.tier]
	if placement.tier == "Anchor" then
		local points = string.format(
			"%.2f,%.2f %.2f,%.2f %.2f,%.2f",
			x,
			y - radius,
			x - radius,
			y + radius,
			x + radius,
			y + radius
		)
		table.insert(
			svg,
			string.format(
				'<polygon points="%s" fill="%s" stroke="#101210" stroke-width="1" data-id="%s"/>',
				points,
				color,
				placement.id
			)
		)
	elseif placement.tier == "Mass" then
		table.insert(
			svg,
			string.format(
				'<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s" stroke="#101210" stroke-width="1" data-id="%s"/>',
				x,
				y,
				radius,
				color,
				placement.id
			)
		)
	else
		table.insert(
			svg,
			string.format(
				'<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" stroke="#101210" stroke-width="1" data-id="%s"/>',
				x - radius,
				y - radius,
				radius * 2,
				radius * 2,
				color,
				placement.id
			)
		)
	end
end

local legendY = canvasSize - 30
table.insert(
	svg,
	string.format(
		'<text x="80" y="%d" fill="#aaa99f" font-family="sans-serif" font-size="11">△ Anchor   ○ Mass   □ Detail   |   field heatmap: frontier / corruption / industry / camp</text>',
		legendY
	)
)
table.insert(svg, "</svg>")

fs.writeFile(outputPath, table.concat(svg, "\n"))
print(string.format("Environment composition SVG: %s (%d deterministic placements)", outputPath, #placements))
