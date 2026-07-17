--!strict

--[[
	VIS-0104 pure procedural fallback definitions for operative and starting-class
	silhouettes. The data contains geometry and palette IDs only. It does not
	assign classes, mutate characters, own movement, or activate class actions.
]]

local ClassContracts = require(script.Parent.Parent.Classes.ClassContracts)

export type VectorDefinition = {
	x: number,
	y: number,
	z: number,
}

export type SilhouettePartDefinition = {
	name: string,
	size: VectorDefinition,
	offset: VectorDefinition,
	rotationDegrees: VectorDefinition,
	shapeId: "Block" | "Cylinder" | "Ball",
	materialId: "Metal" | "SmoothPlastic",
	paletteId: "BaseArmor" | "BaseTrim" | "Specialist" | "Medic" | "Engineer" | "Signal",
}

export type ClassSilhouetteDefinition = {
	classId: string,
	modelName: string,
	readabilityCue: string,
	parts: { SilhouettePartDefinition },
}

local function vector(x: number, y: number, z: number): VectorDefinition
	return table.freeze({ x = x, y = y, z = z })
end

local function part(
	name: string,
	size: VectorDefinition,
	offset: VectorDefinition,
	rotationDegrees: VectorDefinition,
	shapeId: "Block" | "Cylinder" | "Ball",
	materialId: "Metal" | "SmoothPlastic",
	paletteId: "BaseArmor" | "BaseTrim" | "Specialist" | "Medic" | "Engineer" | "Signal"
): SilhouettePartDefinition
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

local SharedParts: { SilhouettePartDefinition } = table.freeze({
	part("OperativeChestPlate", vector(1.72, 1.38, 0.18), vector(0, 0.05, -0.58), vector(0, 0, 0), "Block", "Metal", "BaseArmor"),
	part("OperativeBackPlate", vector(1.58, 1.44, 0.2), vector(0, 0.03, 0.58), vector(0, 0, 0), "Block", "Metal", "BaseArmor"),
	part("OperativeShoulderLeft", vector(0.48, 0.52, 0.66), vector(-1.03, 0.44, 0), vector(0, 0, -8), "Block", "Metal", "BaseTrim"),
	part("OperativeShoulderRight", vector(0.48, 0.52, 0.66), vector(1.03, 0.44, 0), vector(0, 0, 8), "Block", "Metal", "BaseTrim"),
})

local DefinitionsByClassId: { [string]: ClassSilhouetteDefinition } = table.freeze({
	[ClassContracts.ClassIds.CombatSpecialist] = table.freeze({
		classId = ClassContracts.ClassIds.CombatSpecialist,
		modelName = "CombatSpecialistSilhouette",
		readabilityCue = "broad reinforced shoulders, paired ammunition cases, and a diagonal chest band",
		parts = table.freeze({
			part("SpecialistGuardLeft", vector(0.7, 0.82, 0.88), vector(-1.18, 0.4, 0.02), vector(0, 0, -10), "Block", "Metal", "Specialist"),
			part("SpecialistGuardRight", vector(0.7, 0.82, 0.88), vector(1.18, 0.4, 0.02), vector(0, 0, 10), "Block", "Metal", "Specialist"),
			part("SpecialistAmmoCaseLeft", vector(0.48, 0.72, 0.42), vector(-0.84, -0.76, 0.43), vector(0, 0, -4), "Block", "Metal", "Specialist"),
			part("SpecialistAmmoCaseRight", vector(0.48, 0.72, 0.42), vector(0.84, -0.76, 0.43), vector(0, 0, 4), "Block", "Metal", "Specialist"),
			part("SpecialistBackRoll", vector(1.36, 0.4, 0.4), vector(0, 0.72, 0.76), vector(0, 0, 0), "Cylinder", "SmoothPlastic", "BaseTrim"),
			part("SpecialistChestBand", vector(1.72, 0.24, 0.13), vector(0, 0.04, -0.72), vector(0, 0, -19), "Block", "Metal", "Signal"),
		}),
	}),
	[ClassContracts.ClassIds.Medic] = table.freeze({
		classId = ClassContracts.ClassIds.Medic,
		modelName = "MedicSilhouette",
		readabilityCue = "tall twin canisters, compact medical pack, side satchels, and a round beacon",
		parts = table.freeze({
			part("MedicPackBody", vector(1.16, 1.52, 0.4), vector(0, -0.02, 0.78), vector(0, 0, 0), "Block", "SmoothPlastic", "Medic"),
			part("MedicCanisterLeft", vector(1.18, 0.32, 0.32), vector(-0.43, 0.04, 1.02), vector(0, 0, 90), "Cylinder", "Metal", "BaseTrim"),
			part("MedicCanisterRight", vector(1.18, 0.32, 0.32), vector(0.43, 0.04, 1.02), vector(0, 0, 90), "Cylinder", "Metal", "BaseTrim"),
			part("MedicSatchelLeft", vector(0.42, 0.62, 0.34), vector(-0.94, -0.66, 0.28), vector(0, 0, -3), "Block", "SmoothPlastic", "Medic"),
			part("MedicSatchelRight", vector(0.42, 0.62, 0.34), vector(0.94, -0.66, 0.28), vector(0, 0, 3), "Block", "SmoothPlastic", "Medic"),
			part("MedicRoundBeacon", vector(0.34, 0.34, 0.34), vector(0, 0.91, 0.96), vector(0, 0, 0), "Ball", "SmoothPlastic", "Signal"),
		}),
	}),
	[ClassContracts.ClassIds.Engineer] = table.freeze({
		classId = ClassContracts.ClassIds.Engineer,
		modelName = "EngineerSilhouette",
		readabilityCue = "wide utility frame, asymmetric antenna, squared tool cases, and a lower power block",
		parts = table.freeze({
			part("EngineerPackBody", vector(1.46, 1.3, 0.48), vector(0, -0.02, 0.82), vector(0, 0, 0), "Block", "Metal", "Engineer"),
			part("EngineerToolCaseLeft", vector(0.46, 0.78, 0.4), vector(-0.99, -0.62, 0.23), vector(0, 0, -2), "Block", "Metal", "Engineer"),
			part("EngineerToolCaseRight", vector(0.46, 0.78, 0.4), vector(0.99, -0.62, 0.23), vector(0, 0, 2), "Block", "Metal", "Engineer"),
			part("EngineerFrameBar", vector(1.76, 0.16, 0.16), vector(0, 0.56, 1.08), vector(0, 0, 0), "Block", "Metal", "BaseTrim"),
			part("EngineerAntennaStem", vector(0.12, 1.18, 0.12), vector(0.61, 0.98, 1.02), vector(0, 0, 0), "Block", "Metal", "Signal"),
			part("EngineerAntennaHead", vector(0.3, 0.3, 0.3), vector(0.61, 1.6, 1.02), vector(0, 0, 0), "Ball", "SmoothPlastic", "Signal"),
		}),
	}),
})

local Config = {
	Version = "VIS-0104-v1",
	AssetKey = "visual.operative.class-silhouette.fallback",
	PresentationModelName = "OperativeClassSilhouette",
	OperativeIdAttributeName = "LK_P3_OperativeEntityId",
	MaximumPartsPerOperative = 10,
	SharedParts = SharedParts,
	DefinitionsByClassId = DefinitionsByClassId,
}

for _, classId in ClassContracts.ClassIds do
	local definition = DefinitionsByClassId[classId]
	assert(definition ~= nil, "every starting class requires a silhouette definition")
	assert(definition.classId == classId, "silhouette definition class ID drifted")
	assert(#SharedParts + #definition.parts <= Config.MaximumPartsPerOperative, "operative silhouette part budget exceeded")
end

return table.freeze(Config)
