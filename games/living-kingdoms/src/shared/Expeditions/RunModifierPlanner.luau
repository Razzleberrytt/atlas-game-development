--!strict

--[[
	Patch 0.6 deterministic run-modifier planner.

	The planner derives at most one curated encounter-pressure modifier from the
	server-owned run seed and returns bounded per-node intensity overrides. It does
	not mutate the room plan or execute encounter/spawn consequences.
]]

local Config = require(script.Parent.Parent.Config.RunModifierConfig)

export type IntensityOverride = {
	NodeIndex: number,
	RoomId: string,
	EncounterSlotId: string,
	BaseIntensity: number,
	ModifiedIntensity: number,
}

export type RunModifierPlan = {
	Seed: number,
	ConfigVersion: string,
	PlanIdentity: string,
	ModifierId: string,
	ModifierVersion: string,
	DisplayName: string,
	EncounterIntensityDelta: number,
	IntensityOverrides: { IntensityOverride },
}

local RunModifierPlanner = {}

local function nextValue(value: number): number
	return (value * 48_271) % 2_147_483_647
end

local function clampIntensity(value: number): number
	return math.clamp(value, Config.MinimumEncounterIntensity, Config.MaximumEncounterIntensity)
end

function RunModifierPlanner.plan(roomPlan: any): RunModifierPlan?
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.Nodes) == "table", "room plan nodes are required")

	-- Secret and optional-objective planning consume earlier deterministic stream
	-- positions. This offset keeps modifier selection stable without sharing the
	-- same immediate roll with either planner.
	local rollState = roomPlan.Seed
	for _ = 1, 6 do
		rollState = nextValue(rollState)
	end

	local appearanceRoll = (rollState % 100) + 1
	if appearanceRoll > Config.AppearanceChancePercent then
		return nil
	end

	rollState = nextValue(rollState)
	local modifier = Config.Modifiers[(rollState % #Config.Modifiers) + 1]
	local overrides = {}
	for _, node in roomPlan.Nodes do
		if
			type(node.EncounterSlotId) == "string"
			and modifier.EligibleEncounterSlots[node.EncounterSlotId] == true
			and type(node.EncounterIntensity) == "number"
			and node.EncounterIntensity >= Config.MinimumEncounterIntensity
		then
			local modifiedIntensity = clampIntensity(node.EncounterIntensity + modifier.EncounterIntensityDelta)
			if modifiedIntensity ~= node.EncounterIntensity then
				table.insert(
					overrides,
					table.freeze({
						NodeIndex = node.Index,
						RoomId = node.RoomId,
						EncounterSlotId = node.EncounterSlotId,
						BaseIntensity = node.EncounterIntensity,
						ModifiedIntensity = modifiedIntensity,
					})
				)
			end
		end
	end

	local overrideIdentityParts = {}
	for _, override in overrides do
		table.insert(
			overrideIdentityParts,
			`{override.NodeIndex}:{override.RoomId}:{override.BaseIntensity}>{override.ModifiedIntensity}`
		)
	end
	local identity =
		`{Config.Version}|seed={roomPlan.Seed}|modifier={modifier.Id}@{modifier.Version}|overrides={table.concat(
			overrideIdentityParts,
			","
		)}`

	return table.freeze({
		Seed = roomPlan.Seed,
		ConfigVersion = Config.Version,
		PlanIdentity = identity,
		ModifierId = modifier.Id,
		ModifierVersion = modifier.Version,
		DisplayName = modifier.DisplayName,
		EncounterIntensityDelta = modifier.EncounterIntensityDelta,
		IntensityOverrides = table.freeze(overrides),
	})
end

return table.freeze(RunModifierPlanner)
