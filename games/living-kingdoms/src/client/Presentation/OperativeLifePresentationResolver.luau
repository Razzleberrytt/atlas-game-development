--!strict

--[[
	Pure VIS-0104 resolver for client-local operative life-state cues. Inputs are
	copied server-disclosed Player attributes. The result owns no Instances,
	connections, timers, movement, health, revive progress, or gameplay state.
]]

export type LifePresentationFacts = {
	operativeEntityId: unknown,
	lifeStateId: unknown,
	soloRecoveryPending: unknown,
	reviveStatus: unknown,
	reviveProgress: unknown,
	reviveTargetOperativeEntityId: unknown,
}

export type CueId = "Hidden" | "Downed" | "Reviving" | "SoloRecovery" | "Dead"
export type MarkerKindId = "None" | "RescueCross" | "RecoveryChevron" | "DeathX"

export type LifePresentation = {
	cueId: CueId,
	markerKindId: MarkerKindId,
	labelText: string,
	normalizedProgress: number?,
}

local Resolver = {}

local HIDDEN: LifePresentation = table.freeze({
	cueId = "Hidden",
	markerKindId = "None",
	labelText = "",
	normalizedProgress = nil,
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function presentation(
	cueId: CueId,
	markerKindId: MarkerKindId,
	labelText: string,
	normalizedProgress: number?
): LifePresentation
	return table.freeze({
		cueId = cueId,
		markerKindId = markerKindId,
		labelText = labelText,
		normalizedProgress = normalizedProgress,
	})
end

function Resolver.resolve(facts: LifePresentationFacts): LifePresentation
	if facts.lifeStateId == "Dead" then
		return presentation("Dead", "DeathX", "KIA", nil)
	end
	if facts.lifeStateId ~= "Incapacitated" then
		return HIDDEN
	end
	if facts.soloRecoveryPending == true then
		return presentation("SoloRecovery", "RecoveryChevron", "SELF RECOVERY", nil)
	end
	local isTargetedRevive = facts.reviveStatus == "Active"
		and type(facts.operativeEntityId) == "string"
		and facts.operativeEntityId ~= ""
		and facts.reviveTargetOperativeEntityId == facts.operativeEntityId
	if isTargetedRevive and isFiniteNumber(facts.reviveProgress) then
		local progress = math.clamp(facts.reviveProgress :: number, 0, 1)
		return presentation(
			"Reviving",
			"RescueCross",
			string.format("REVIVING %.0f%%", progress * 100),
			progress
		)
	end
	return presentation("Downed", "RescueCross", "DOWNED", nil)
end

return table.freeze(Resolver)
