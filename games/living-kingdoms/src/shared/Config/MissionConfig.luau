--!strict

--[[
	P5-0103 authored values for the first playable operation, extended by
	P5-0105 with bounded pressure pacing. Positions reference the P5-0102
	authored landmarks; the server remains authoritative over every derived fact.
]]

local MissionConfig = {
	Version = "P5-0105-v1",
	OperationId = "operation.blackwater-relay",
	OperationDisplayName = "Operation Blackwater Relay",
	InsertionHoldSeconds = 20,
	ExtractionPresenceIntervalSeconds = 0.5,
	Objective = table.freeze({
		ObjectiveId = "objective.restore-lookout-relay",
		LandmarkId = "LookoutTower",
		ConsolePosition = table.freeze({ x = -221, y = 17.5, z = 187 }),
		InteractionRadiusStuds = 14,
		PromptActionText = "Restore Relay",
		PromptObjectText = "Emergency Relay Console",
		PromptHoldDurationSeconds = 1,
	}),
	Extraction = table.freeze({
		LandmarkId = "ExtractionClearing",
		Position = table.freeze({ x = 218, y = 1, z = 58 }),
		RadiusStuds = 34,
		ArrivalSeconds = 90,
	}),
	Escalation = table.freeze({
		SecondWaveDelaySeconds = 45,
		MaximumConcurrentEnemies = 5,
		MinimumSecondsBetweenWaves = 12,
		RecoverySecondsAfterWave = 10,
		Waves = table.freeze({
			-- Level 1: contacts on the descent between the lookout and the campground.
			table.freeze({
				table.freeze({ id = "hostile.p50103.descent-a", name = "Exclusion Hostile", x = -168, y = 5, z = 92 }),
				table.freeze({ id = "hostile.p50103.descent-b", name = "Exclusion Hostile", x = -114, y = 3, z = 58 }),
			}),
			-- Level 2: pressure along the creek crossing and the eastern approach.
			table.freeze({
				table.freeze({ id = "hostile.p50103.creek-a", name = "Exclusion Hostile", x = 52, y = 3, z = 18 }),
				table.freeze({ id = "hostile.p50103.creek-b", name = "Exclusion Hostile", x = 118, y = 6, z = 52 }),
			}),
			-- Level 3: the clearing perimeter during holdout.
			table.freeze({
				table.freeze({ id = "hostile.p50103.clearing-a", name = "Exclusion Hostile", x = 218, y = 4, z = 8 }),
				table.freeze({ id = "hostile.p50103.clearing-b", name = "Exclusion Hostile", x = 256, y = 4, z = 84 }),
				table.freeze({ id = "hostile.p50103.clearing-c", name = "Exclusion Hostile", x = 176, y = 4, z = 92 }),
			}),
		}),
	}),
	ObjectiveTextByPhase = table.freeze({
		Insertion = "Regroup at the ranger station",
		Infiltration = "Restore the communications relay at Lookout 7",
		Exfiltration = "Reach the forest extraction clearing",
		Holdout = "Hold the clearing until extraction arrives",
		Resolved = "Operation resolved",
	}),
	RadioLines = table.freeze({
		InsertionComplete = "Insertion complete. Regroup at the ranger station.",
		ProceedToObjective = "Proceed to Lookout 7 and restore the emergency relay.",
		ObjectiveComplete = "Relay restored. Extraction inbound at the forest clearing.",
		PressureRising = "Command: hostile activity is rising. Keep moving.",
		HoldPosition = "Extraction on approach. Hold your position.",
		MissionSuccess = "Extraction complete. Good work, squad.",
		MissionFailure = "Signal lost. Operation failed.",
	}),
}

assert(
	MissionConfig.InsertionHoldSeconds > 0 and MissionConfig.InsertionHoldSeconds < math.huge,
	"insertion regroup must be a bounded positive duration"
)
assert(
	MissionConfig.ExtractionPresenceIntervalSeconds > 0 and MissionConfig.ExtractionPresenceIntervalSeconds <= 1,
	"presence checks must stay bounded and responsive"
)
assert(MissionConfig.Objective.InteractionRadiusStuds > 0, "objective interaction requires a positive radius")
assert(MissionConfig.Extraction.RadiusStuds > 0, "the extraction zone requires a positive radius")
assert(
	MissionConfig.Extraction.ArrivalSeconds > 0 and MissionConfig.Extraction.ArrivalSeconds < math.huge,
	"the holdout countdown must be a bounded positive duration"
)
assert(MissionConfig.Escalation.SecondWaveDelaySeconds > 0, "the second escalation wave requires a positive delay")
assert(
	MissionConfig.Escalation.MaximumConcurrentEnemies > 0,
	"pressure pacing requires a positive concurrent-enemy budget"
)
assert(
	MissionConfig.Escalation.MinimumSecondsBetweenWaves >= 0,
	"the inter-wave interval must be bounded and non-negative"
)
assert(
	MissionConfig.Escalation.RecoverySecondsAfterWave >= 0,
	"the post-wave recovery window must be bounded and non-negative"
)
assert(#MissionConfig.Escalation.Waves == 3, "the prototype authored exactly three escalation waves")
for _, wave in MissionConfig.Escalation.Waves do
	assert(#wave > 0, "every escalation wave must author at least one hostile")
	assert(
		#wave <= MissionConfig.Escalation.MaximumConcurrentEnemies,
		"an authored wave must fit inside the pressure budget"
	)
end

return table.freeze(MissionConfig)
