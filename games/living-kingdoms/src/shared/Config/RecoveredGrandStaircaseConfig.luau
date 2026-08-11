--!strict

-- Patch 0.5 held reconstruction contract for the Studio-authored
-- Workspace/HubTown/GrandStaircase group from the 2026-08-10 RBXL revision.
-- Presentation evidence only; this module never creates runtime geometry.

local STEP_Y = table.freeze({
	57.295631408691406,
	59.295631408691406,
	61.295631408691406,
	63.295631408691406,
	65.2956314086914,
	67.2956314086914,
	69.2956314086914,
	71.29562377929688,
	73.29562377929688,
	75.29562377929688,
})

local parts = {}
local lights = {}

for index, y in STEP_Y do
	table.insert(
		parts,
		table.freeze({
			name = `Step{index}`,
			sourceId = 229 + index,
			parent = "GrandStaircase",
			position = table.freeze({ x = 0.0, y = y, z = -27.75 + 8 * (index - 1) }),
			rotationId = 2,
			size = table.freeze({ x = 80.0, y = 2.0, z = 8.0 }),
			colorBytes = table.freeze({ r = 160, g = 155, b = 145 }),
			materialEnumValue = 784,
			shapeEnumValue = 1,
			canCollide = true,
			transparency = 0.0,
			reflectance = 0.0,
		})
	)
end

local railDefinitions = table.freeze({
	table.freeze({ name = "Rail-1", sourceId = 240, x = -42.0, y = 66.2956314086914, sizeX = 5.0, sizeY = 25.0 }),
	table.freeze({ name = "RailGlow-1", sourceId = 241, x = -42.0, y = 78.29562377929688, sizeX = 2.0, sizeY = 3.0 }),
	table.freeze({ name = "Rail1", sourceId = 242, x = 42.0, y = 66.2956314086914, sizeX = 5.0, sizeY = 25.0 }),
	table.freeze({ name = "RailGlow1", sourceId = 243, x = 42.0, y = 78.29562377929688, sizeX = 2.0, sizeY = 3.0 }),
})

for _, rail in railDefinitions do
	table.insert(
		parts,
		table.freeze({
			name = rail.name,
			sourceId = rail.sourceId,
			parent = "GrandStaircase",
			position = table.freeze({ x = rail.x, y = rail.y, z = 4.25 }),
			rotationId = 2,
			size = table.freeze({ x = rail.sizeX, y = rail.sizeY, z = 85.0 }),
			colorBytes = table.freeze({ r = 160, g = 155, b = 145 }),
			materialEnumValue = 784,
			shapeEnumValue = 1,
			canCollide = true,
			transparency = 0.0,
			reflectance = 0.0,
		})
	)
end

local lanternStepIndexes = table.freeze({ 2, 4, 6, 8, 10 })
for pairIndex, stepIndex in lanternStepIndexes do
	local y = STEP_Y[stepIndex] + 1.0
	local z = -27.75 + 8 * (stepIndex - 1)
	local leftSourceId = 244 + (pairIndex - 1) * 4
	local rightSourceId = leftSourceId + 2

	for _, lantern in
		table.freeze({
			table.freeze({ side = "L", x = -3.0, sourceId = leftSourceId }),
			table.freeze({ side = "R", x = 3.0, sourceId = rightSourceId }),
		})
	do
		local name = `Lantern_{lantern.side}_{stepIndex}`
		table.insert(
			parts,
			table.freeze({
				name = name,
				sourceId = lantern.sourceId,
				parent = "GrandStaircase",
				position = table.freeze({ x = lantern.x, y = y, z = z }),
				rotationId = 2,
				size = table.freeze({ x = 0.5, y = 1.5, z = 0.5 }),
				colorBytes = table.freeze({ r = 255, g = 200, b = 100 }),
				materialEnumValue = 288,
				shapeEnumValue = 1,
				canCollide = true,
				transparency = 0.0,
				reflectance = 0.0,
			})
		)
		table.insert(
			lights,
			table.freeze({
				name = "PointLight",
				sourceId = lantern.sourceId + 1,
				parent = name,
				brightness = 2.0,
				color = table.freeze({ r = 1.0, g = 0.7843137383460999, b = 0.3921568691730499 }),
				enabled = true,
				range = 12.0,
				shadows = false,
			})
		)
	end
end

local Config = {
	Version = "P0.5-GRAND-STAIRCASE-v1",
	SourcePath = "Workspace/HubTown/GrandStaircase",
	CoordinateSpaceId = "authored-overworld",
	SemanticContentId = "main_world.hub_core.grand_staircase",
	StreamingGroupId = "main_world.hub_core",
	SourceHold = true,
	RuntimeEnabled = false,
	Evidence = table.freeze({
		SourceRbxlSha256 = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b",
		SourceRbxlBytes = 1808699,
		IdentityRows = 35,
		PropertyBackedRows = 34,
		GeneratedContainerRows = 1,
		PendingNodeRows = 0,
		EvidenceArtifactName = "hub-civic-geometry-summary.json",
	}),
	Parts = table.freeze(parts),
	PointLights = table.freeze(lights),
}

return table.freeze(Config)
