--!strict

--[[
	Pure VIS-0104 resolver and immutable procedural pose definitions for operative
	firearm carry readability. Inputs are copied server-disclosed Player
	attributes. The result owns no Instances, connections, animation playback,
	movement, combat, health, revive completion, or weapon state.
]]

export type CarryPoseFacts = {
	operativeEntityId: unknown,
	lifeStateId: unknown,
	reviveStatus: unknown,
	reviveReviverOperativeEntityId: unknown,
}

export type RigId = "R6" | "R15"
export type PoseId = "Hidden" | "Ready" | "Reviving" | "Incapacitated" | "Dead"

export type VectorDefinition = {
	x: number,
	y: number,
	z: number,
}

export type PoseDefinition = {
	rightShoulderRotationDegrees: VectorDefinition,
	leftShoulderRotationDegrees: VectorDefinition,
	gripOffset: VectorDefinition,
	gripRotationDegrees: VectorDefinition,
}

local Resolver = {}

local function vector(x: number, y: number, z: number): VectorDefinition
	return table.freeze({ x = x, y = y, z = z })
end

local function pose(
	rightShoulderRotationDegrees: VectorDefinition,
	leftShoulderRotationDegrees: VectorDefinition,
	gripOffset: VectorDefinition,
	gripRotationDegrees: VectorDefinition
): PoseDefinition
	return table.freeze({
		rightShoulderRotationDegrees = rightShoulderRotationDegrees,
		leftShoulderRotationDegrees = leftShoulderRotationDegrees,
		gripOffset = gripOffset,
		gripRotationDegrees = gripRotationDegrees,
	})
end

local DefinitionsByRigId: { [RigId]: { [PoseId]: PoseDefinition } } = table.freeze({
	R6 = table.freeze({
		Ready = pose(vector(-22, 0, 16), vector(-36, 0, -22), vector(0, -0.04, -0.04), vector(-3, 0, 0)),
		Reviving = pose(vector(15, 0, 35), vector(12, 0, -35), vector(0, -0.08, 0.12), vector(0, -10, 55)),
		Incapacitated = pose(vector(36, 0, 60), vector(32, 0, -60), vector(0, 0.10, 0.15), vector(20, 0, 65)),
		Dead = pose(vector(55, 0, 80), vector(50, 0, -80), vector(0, 0.18, 0.24), vector(25, 0, 85)),
	}),
	R15 = table.freeze({
		Ready = pose(vector(-28, 4, 12), vector(-42, -10, -18), vector(0, -0.05, -0.05), vector(-3, 0, 0)),
		Reviving = pose(vector(18, 6, 28), vector(12, -6, -28), vector(0, -0.08, 0.12), vector(0, -10, 55)),
		Incapacitated = pose(vector(42, 10, 54), vector(38, -10, -54), vector(0, 0.10, 0.15), vector(20, 0, 65)),
		Dead = pose(vector(64, 12, 72), vector(60, -12, -72), vector(0, 0.18, 0.24), vector(25, 0, 85)),
	}),
})

Resolver.PoseIds = table.freeze({
	Hidden = "Hidden",
	Ready = "Ready",
	Reviving = "Reviving",
	Incapacitated = "Incapacitated",
	Dead = "Dead",
})
Resolver.DefinitionsByRigId = DefinitionsByRigId

function Resolver.resolve(facts: CarryPoseFacts): PoseId
	if facts.lifeStateId == "Dead" then
		return "Dead"
	end
	if facts.lifeStateId == "Incapacitated" then
		return "Incapacitated"
	end
	if facts.lifeStateId ~= "Alive" then
		return "Hidden"
	end
	local isAuthoritativeReviver = facts.reviveStatus == "Active"
		and type(facts.operativeEntityId) == "string"
		and facts.operativeEntityId ~= ""
		and facts.reviveReviverOperativeEntityId == facts.operativeEntityId
	if isAuthoritativeReviver then
		return "Reviving"
	end
	return "Ready"
end

function Resolver.definitionFor(rigId: RigId, poseId: PoseId): PoseDefinition?
	local definitions = DefinitionsByRigId[rigId]
	return definitions[poseId]
end

return table.freeze(Resolver)
