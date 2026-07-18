--!strict

--[[
	Always-on procedural army-helmet presentation for every operative character.
	The definition is cosmetic only: it contains bounded geometry, materials,
	colors, and head-relative transforms. It does not alter avatar identity,
	classes, movement, collision, health, combat, or mission state.
]]

export type VectorDefinition = {
	x: number,
	y: number,
	z: number,
}

export type HelmetPartDefinition = {
	name: string,
	size: VectorDefinition,
	offset: VectorDefinition,
	rotationDegrees: VectorDefinition,
	shapeId: "Block" | "Ball",
	materialId: "Metal" | "SmoothPlastic",
	paletteId: "Shell" | "Trim",
}

local function vector(x: number, y: number, z: number): VectorDefinition
	return table.freeze({ x = x, y = y, z = z })
end

local function part(
	name: string,
	size: VectorDefinition,
	offset: VectorDefinition,
	rotationDegrees: VectorDefinition,
	shapeId: "Block" | "Ball",
	materialId: "Metal" | "SmoothPlastic",
	paletteId: "Shell" | "Trim"
): HelmetPartDefinition
	return table.freeze({
		name = name,
		size = size,
		offset = offset,
		rotationDegrees = rotationDegrees,
		shapeId = shapeId,
		materialId = materialId,
		paletteId = paletteId,
	})
end

local Parts: { HelmetPartDefinition } = table.freeze({
	part(
		"HelmetShell",
		vector(2.22, 1.08, 1.96),
		vector(0, 0.34, 0),
		vector(0, 0, 0),
		"Ball",
		"SmoothPlastic",
		"Shell"
	),
	part(
		"HelmetFrontBrim",
		vector(1.92, 0.14, 0.62),
		vector(0, 0.02, -0.72),
		vector(-4, 0, 0),
		"Block",
		"Metal",
		"Trim"
	),
	part(
		"HelmetRearRim",
		vector(2.04, 0.12, 0.38),
		vector(0, 0.03, 0.72),
		vector(3, 0, 0),
		"Block",
		"Metal",
		"Trim"
	),
})

local Config = {
	Version = "VIS-0106-v1-default-army-helmet",
	AssetKey = "visual.operative.default-army-helmet.fallback",
	PresentationModelName = "OperativeDefaultArmyHelmet",
	HeadPartName = "Head",
	MaximumPartsPerHelmet = 3,
	Palette = table.freeze({
		Shell = table.freeze({ r = 72, g = 79, b = 55 }),
		Trim = table.freeze({ r = 42, g = 48, b = 34 }),
	}),
	Parts = Parts,
}

assert(#Parts > 0 and #Parts <= Config.MaximumPartsPerHelmet, "default helmet part budget exceeded")
for _, definition in Parts do
	assert(definition.size.x > 0 and definition.size.y > 0 and definition.size.z > 0, "helmet parts require size")
	assert(Config.Palette[definition.paletteId] ~= nil, "helmet part palette ID is invalid")
end

return table.freeze(Config)
