--!strict

--[[
	Patch 0.6 effective encounter-intensity read model.

	This view overlays an already-composed run modifier onto the canonical room
	plan without mutating either input. It intentionally does not decide how an
	intensity value changes enemy counts, archetypes, rewards, or pacing; those
	consequences remain owned by the encounter director/content integration layer.
]]

export type EncounterIntensityRecord = {
	NodeIndex: number,
	RoomId: string,
	EncounterSlotId: string,
	BaseIntensity: number,
	EffectiveIntensity: number,
	ModifierApplied: boolean,
}

export type EncounterView = {
	Seed: number,
	RoomPlanIdentity: string,
	VariationIdentity: string,
	Records: { EncounterIntensityRecord },
}

local RunVariationEncounterView = {}

local function modifierOverrideByNode(variationPlan: any): { [number]: any }
	local byNode = {}
	local modifier = variationPlan.RunModifier
	if modifier == nil then
		return byNode
	end
	assert(type(modifier.IntensityOverrides) == "table", "run modifier intensity overrides are required")
	for _, override in modifier.IntensityOverrides do
		assert(type(override.NodeIndex) == "number" and override.NodeIndex % 1 == 0, "invalid override node index")
		assert(byNode[override.NodeIndex] == nil, "duplicate run modifier node override")
		byNode[override.NodeIndex] = override
	end
	return byNode
end

function RunVariationEncounterView.build(roomPlan: any, variationPlan: any): EncounterView
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(variationPlan) == "table", "variation plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.PlanIdentity) == "string" and roomPlan.PlanIdentity ~= "", "room plan identity is required")
	assert(type(roomPlan.Nodes) == "table", "room plan nodes are required")
	assert(variationPlan.Seed == roomPlan.Seed, "variation seed must match room plan seed")
	assert(variationPlan.RoomPlanIdentity == roomPlan.PlanIdentity, "variation room identity must match room plan")
	assert(
		type(variationPlan.VariationIdentity) == "string" and variationPlan.VariationIdentity ~= "",
		"variation identity is required"
	)

	local overridesByNode = modifierOverrideByNode(variationPlan)
	local records = {}
	for _, node in roomPlan.Nodes do
		if type(node.EncounterSlotId) == "string" and type(node.EncounterIntensity) == "number" then
			local override = overridesByNode[node.Index]
			local effectiveIntensity = node.EncounterIntensity
			local modifierApplied = false
			if override ~= nil then
				assert(override.RoomId == node.RoomId, "run modifier override room mismatch")
				assert(
					override.EncounterSlotId == node.EncounterSlotId,
					"run modifier override encounter slot mismatch"
				)
				assert(
					override.BaseIntensity == node.EncounterIntensity,
					"run modifier override base intensity mismatch"
				)
				assert(type(override.ModifiedIntensity) == "number", "run modifier modified intensity is required")
				effectiveIntensity = override.ModifiedIntensity
				modifierApplied = true
			end
			table.insert(
				records,
				table.freeze({
					NodeIndex = node.Index,
					RoomId = node.RoomId,
					EncounterSlotId = node.EncounterSlotId,
					BaseIntensity = node.EncounterIntensity,
					EffectiveIntensity = effectiveIntensity,
					ModifierApplied = modifierApplied,
				})
			)
		end
	end

	return table.freeze({
		Seed = roomPlan.Seed,
		RoomPlanIdentity = roomPlan.PlanIdentity,
		VariationIdentity = variationPlan.VariationIdentity,
		Records = table.freeze(records),
	})
end

return table.freeze(RunVariationEncounterView)
