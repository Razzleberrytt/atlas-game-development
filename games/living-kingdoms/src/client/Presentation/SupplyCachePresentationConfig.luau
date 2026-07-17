--!strict

--[[
	Pure VIS-0105 procedural presentation definitions for the authored supply
	cache. The data contains geometry and palette IDs only. It owns no cache
	identity, placement, prompt, stock, collection history, grant, or networking.
]]

export type VectorDefinition = {
	x: number,
	y: number,
	z: number,
}

export type PartDefinition = {
	name: string,
	size: VectorDefinition,
	offset: VectorDefinition,
	rotationDegrees: VectorDefinition,
	materialId: "Metal" | "SmoothPlastic",
	paletteId: "Body" | "Panel" | "Rail" | "Latch" | "Signal" | "Interior",
}

local function vector(x: number, y: number, z: number): VectorDefinition
	return table.freeze({ x = x, y = y, z = z })
end

local function part(
	name: string,
	size: VectorDefinition,
	offset: VectorDefinition,
	rotationDegrees: VectorDefinition,
	materialId: "Metal" | "SmoothPlastic",
	paletteId: "Body" | "Panel" | "Rail" | "Latch" | "Signal" | "Interior"
): PartDefinition
	return table.freeze({
		name = name,
		size = size,
		offset = offset,
		rotationDegrees = rotationDegrees,
		materialId = materialId,
		paletteId = paletteId,
	})
end

local Config = {
	Version = "VIS-0105-supply-cache-v1",
	PresentationModelName = "SupplyCachePresentation",
	MaximumPartsPerCache = 13,
	StateIds = table.freeze({
		Available = "Available",
		Consumed = "Consumed",
	}),
	Lid = table.freeze({
		Name = "SupplyCacheLid",
		Size = vector(3.72, 0.22, 2.72),
		ClosedOffset = vector(0, 0.91, 0),
		ClosedRotationDegrees = vector(0, 0, 0),
		ConsumedOffset = vector(0, 1.30, 0.76),
		ConsumedRotationDegrees = vector(55, 0, 0),
	}),
	Parts = table.freeze({
		part("SupplyCacheBody", vector(3.54, 1.54, 2.54), vector(0, -0.10, 0), vector(0, 0, 0), "Metal", "Body"),
		part(
			"SupplyCacheFrontPanel",
			vector(3.10, 0.92, 0.12),
			vector(0, -0.06, -1.33),
			vector(0, 0, 0),
			"Metal",
			"Panel"
		),
		part(
			"SupplyCacheRearPanel",
			vector(3.10, 0.92, 0.12),
			vector(0, -0.06, 1.33),
			vector(0, 0, 0),
			"Metal",
			"Panel"
		),
		part(
			"SupplyCacheLeftRail",
			vector(0.18, 1.72, 2.66),
			vector(-1.77, -0.02, 0),
			vector(0, 0, 0),
			"Metal",
			"Rail"
		),
		part(
			"SupplyCacheRightRail",
			vector(0.18, 1.72, 2.66),
			vector(1.77, -0.02, 0),
			vector(0, 0, 0),
			"Metal",
			"Rail"
		),
		part(
			"SupplyCacheLatchLeft",
			vector(0.34, 0.42, 0.18),
			vector(-0.90, 0.42, -1.43),
			vector(0, 0, 0),
			"Metal",
			"Latch"
		),
		part(
			"SupplyCacheLatchRight",
			vector(0.34, 0.42, 0.18),
			vector(0.90, 0.42, -1.43),
			vector(0, 0, 0),
			"Metal",
			"Latch"
		),
		part(
			"SupplyCacheSignalBand",
			vector(2.36, 0.18, 0.14),
			vector(0, 0.12, -1.43),
			vector(0, 0, 0),
			"SmoothPlastic",
			"Signal"
		),
		part(
			"SupplyCacheHandleBaseLeft",
			vector(0.18, 0.48, 0.18),
			vector(-0.56, 1.06, 0),
			vector(0, 0, 0),
			"Metal",
			"Rail"
		),
		part(
			"SupplyCacheHandleBaseRight",
			vector(0.18, 0.48, 0.18),
			vector(0.56, 1.06, 0),
			vector(0, 0, 0),
			"Metal",
			"Rail"
		),
		part(
			"SupplyCacheHandleBar",
			vector(1.30, 0.18, 0.24),
			vector(0, 1.28, 0),
			vector(0, 0, 0),
			"SmoothPlastic",
			"Rail"
		),
		part(
			"SupplyCacheEmptyTray",
			vector(3.12, 0.12, 2.10),
			vector(0, 0.55, 0),
			vector(0, 0, 0),
			"Metal",
			"Interior"
		),
	}),
}

assert(#Config.Parts + 1 == Config.MaximumPartsPerCache, "supply cache presentation part budget drifted")

return table.freeze(Config)
