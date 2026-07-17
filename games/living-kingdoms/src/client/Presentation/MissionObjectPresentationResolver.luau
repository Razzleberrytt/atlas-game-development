--!strict

--[[
	Pure VIS-0105 resolver for mission-object readability. Inputs are copied from
	the validated server-authored safe mission snapshot. The result owns no
	Instances, connections, timers, interaction, phase transitions, or outcomes.
]]

export type MissionObjectFacts = {
	phaseId: unknown,
	objectiveStateId: unknown,
	extractionUnlocked: unknown,
	outcomeId: unknown,
}

export type RelayStateId = "Hidden" | "Standby" | "Active" | "Completed"
export type ExtractionStateId = "Hidden" | "Open" | "Holdout" | "Success" | "Failure"

export type RelayPresentation = {
	stateId: RelayStateId,
	labelText: string,
}

export type ExtractionPresentation = {
	stateId: ExtractionStateId,
	labelText: string,
}

export type MissionObjectPresentation = {
	relay: RelayPresentation,
	extraction: ExtractionPresentation,
}

local Resolver = {}

local RELAY_HIDDEN: RelayPresentation = table.freeze({
	stateId = "Hidden",
	labelText = "",
})

local EXTRACTION_HIDDEN: ExtractionPresentation = table.freeze({
	stateId = "Hidden",
	labelText = "",
})

local function relay(stateId: RelayStateId, labelText: string): RelayPresentation
	return table.freeze({
		stateId = stateId,
		labelText = labelText,
	})
end

local function extraction(stateId: ExtractionStateId, labelText: string): ExtractionPresentation
	return table.freeze({
		stateId = stateId,
		labelText = labelText,
	})
end

local function resolveRelay(facts: MissionObjectFacts): RelayPresentation
	if facts.objectiveStateId == "Inactive" and facts.phaseId == "Insertion" then
		return relay("Standby", "RELAY STANDBY")
	end
	if facts.objectiveStateId == "Active" and facts.phaseId == "Infiltration" then
		return relay("Active", "RESTORE RELAY")
	end
	if
		facts.objectiveStateId == "Completed"
		and (facts.phaseId == "Exfiltration" or facts.phaseId == "Holdout" or facts.phaseId == "Resolved")
	then
		return relay("Completed", "RELAY ONLINE")
	end
	return RELAY_HIDDEN
end

local function resolveExtraction(facts: MissionObjectFacts): ExtractionPresentation
	if facts.extractionUnlocked ~= true then
		return EXTRACTION_HIDDEN
	end
	if facts.phaseId == "Exfiltration" and facts.outcomeId == nil then
		return extraction("Open", "EXTRACTION OPEN")
	end
	if facts.phaseId == "Holdout" and facts.outcomeId == nil then
		return extraction("Holdout", "HOLD POSITION")
	end
	if facts.phaseId == "Resolved" and facts.outcomeId == "Success" then
		return extraction("Success", "EXTRACTED")
	end
	if facts.phaseId == "Resolved" and facts.outcomeId == "Failure" then
		return extraction("Failure", "EXTRACTION LOST")
	end
	return EXTRACTION_HIDDEN
end

function Resolver.resolve(facts: MissionObjectFacts): MissionObjectPresentation
	return table.freeze({
		relay = resolveRelay(facts),
		extraction = resolveExtraction(facts),
	})
end

return table.freeze(Resolver)
