--!strict

--[[
	P8-0101 authored objective chain for Operation Blackwater Relay.

	The specification lives in docs/specifications/authored-objective-chain.md.
	Two required objectives (restore the relay at the Forest Service Lookout,
	charge the signal booster at the Military Roadblock) plus one optional
	engineer floodlight repair at the Extraction Clearing. The whole chain runs
	inside the existing Infiltration/Exfiltration phases and the single terminal
	boundary — no new phase, no parallel state machine.

	Every constant here is first-pass authoring intent, tunable from evidence in
	P12. Positions sit on the existing WorldFoundationConfig landmarks; wave
	triggers reference MissionConfig.Escalation.Waves by index so this module
	stays self-contained.
]]

local ObjectiveChainConfig = {
	Version = "OBJECTIVE-CHAIN-001-v1",
	-- Bound each objective-presence sample so a long frame hitch or a fixture's
	-- large time step can never commit more than one authored step of progress.
	MaxSampleDeltaSeconds = 1.0,
	-- The mission phases in which the objective chain progresses at all. A sample
	-- outside these phases is rejected by the runtime before any progress.
	ActiveChainPhaseIds = table.freeze({
		Infiltration = true,
		Exfiltration = true,
	}),
	Objectives = table.freeze({
		-- Objective 1 (required): a readable opening hold at the home station.
		table.freeze({
			objectiveId = "objective.restore-lookout-relay",
			landmarkId = "RangerStation",
			displayText = "Secure the ranger station perimeter",
			destinationDisplayName = "Home Ranger Station",
			interactionKindId = "HeldChannel",
			activePhaseIds = table.freeze({ Infiltration = true }),
			center = table.freeze({ x = -220, y = 3, z = -208 }),
			interactionRadiusStuds = 24,
			completionUnits = 4, -- short tutorial hold with HUD percentage confirmation
			baseRatePerSecond = 1,
			decayRatePerSecond = 0, -- a paused channel never regresses
			assistedRateMultiplier = 1,
			isOptional = false,
			isRequiredForExtraction = false,
			prerequisiteObjectiveId = nil,
			waveIndexOnComplete = 1,
			radioLineIdOnComplete = "RelayRestored",
		}),
		-- Objective 2 (required): a decaying accumulated-presence hold at the
		-- Military Roadblock. Abandoning the point drains the charge; the cover is
		-- useful only while charging, then escalation pushes the squad off it.
		table.freeze({
			objectiveId = "objective.charge-roadblock-booster",
			landmarkId = "MilitaryRoadblock",
			displayText = "Charge the signal booster",
			destinationDisplayName = "Military Roadblock",
			interactionKindId = "DecayingCharge",
			activePhaseIds = table.freeze({ Infiltration = true }),
			center = table.freeze({ x = 180, y = 3.5, z = -178 }),
			interactionRadiusStuds = 16,
			completionUnits = 24, -- net seconds of held charge
			baseRatePerSecond = 1,
			decayRatePerSecond = 0.5, -- drains at half the fill rate when abandoned
			assistedRateMultiplier = 1,
			isOptional = false,
			isRequiredForExtraction = true,
			prerequisiteObjectiveId = "objective.restore-lookout-relay",
			waveIndexOnComplete = 2,
			radioLineIdOnComplete = "BoosterCharged",
		}),
		-- Objective 3 (optional): restore the extraction floodlights. An engineer
		-- repairs fast; any operative can complete the slower manual bypass. A
		-- class opportunity, never a class gate. Completing it lights the holdout.
		table.freeze({
			objectiveId = "objective.restore-extraction-floodlights",
			landmarkId = "ExtractionClearing",
			displayText = "Restore the extraction floodlights",
			destinationDisplayName = "Extraction Clearing",
			-- On the Extraction Clearing landmark but outside the 34-stud holdout
			-- zone, so restoring the floodlights is a distinct approach step and not
			-- the same act as standing in the extraction zone.
			interactionKindId = "EquipmentRepair",
			activePhaseIds = table.freeze({ Exfiltration = true }),
			center = table.freeze({ x = 182, y = 1, z = 42 }),
			interactionRadiusStuds = 14,
			completionUnits = 6, -- engineer-seconds of repair
			baseRatePerSecond = 0.4, -- manual bypass rate (~15s) without an engineer
			decayRatePerSecond = 0, -- repair progress holds
			assistedRateMultiplier = 2.5, -- engineer restores full 1.0/s (~6s)
			isOptional = true,
			isRequiredForExtraction = false,
			prerequisiteObjectiveId = "objective.charge-roadblock-booster",
			waveIndexOnComplete = nil,
			radioLineIdOnComplete = "FloodlightsRestored",
		}),
	}),
	-- The class whose presence supplies the assisted repair rate (P8-0106).
	AssistingClassId = "class.engineer",
}

assert(#ObjectiveChainConfig.Objectives == 3, "the authored chain has exactly three objectives")
assert(
	ObjectiveChainConfig.MaxSampleDeltaSeconds > 0 and ObjectiveChainConfig.MaxSampleDeltaSeconds < math.huge,
	"the objective sample step must be bounded and positive"
)

local seenIds: { [string]: boolean } = {}
local requiredForExtractionCount = 0
for index, definition in ObjectiveChainConfig.Objectives do
	assert(not seenIds[definition.objectiveId], "objective ids must be unique: " .. definition.objectiveId)
	seenIds[definition.objectiveId] = true
	if definition.isRequiredForExtraction then
		requiredForExtractionCount += 1
	end
	-- Every prerequisite must reference an objective declared earlier in the
	-- chain, so completion order is deterministic and acyclic.
	local prerequisiteId = definition.prerequisiteObjectiveId
	if prerequisiteId ~= nil then
		local prerequisiteFound = false
		for earlierIndex = 1, index - 1 do
			if ObjectiveChainConfig.Objectives[earlierIndex].objectiveId == prerequisiteId then
				prerequisiteFound = true
				break
			end
		end
		assert(prerequisiteFound, "prerequisite must precede its dependant: " .. definition.objectiveId)
	end
end
assert(requiredForExtractionCount == 1, "exactly one objective unlocks extraction")

return table.freeze(ObjectiveChainConfig)
