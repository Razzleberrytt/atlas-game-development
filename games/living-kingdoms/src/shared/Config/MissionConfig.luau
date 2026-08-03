--!strict

--[[
	Authored values for the first horde-horror operation. The route remains
	finite and authored, but regrouping is fast, escalation begins immediately
	after the relay, and extraction ends in a two-minute horde holdout.
]]

local function createRingWave(
	prefix: string,
	displayName: string,
	centerX: number,
	centerZ: number,
	count: number,
	radius: number
)
	local result = {}
	for index = 1, count do
		local angle = (index - 1) * math.pi * 2 / count
		local distance = radius + ((index % 3) - 1) * 10
		table.insert(
			result,
			table.freeze({
				id = string.format("hostile.%s.%02d", prefix, index),
				name = displayName,
				x = centerX + math.cos(angle) * distance,
				y = 4,
				z = centerZ + math.sin(angle) * distance,
			})
		)
	end
	return table.freeze(result)
end

local MissionConfig = {
	Version = "HORDE-VS-001-v2",
	OperationId = "operation.blackwater-relay",
	OperationDisplayName = "Operation Blackwater Relay",
	InsertionHoldSeconds = 8,
	ExtractionPresenceIntervalSeconds = 0.25,
	Objective = table.freeze({
		ObjectiveId = "objective.restore-lookout-relay",
		LandmarkId = "LookoutTower",
		ConsolePosition = table.freeze({ x = -221, y = 17.5, z = 187 }),
		InteractionRadiusStuds = 14,
		PromptActionText = "Restore Relay",
		PromptObjectText = "Emergency Relay Console",
		PromptHoldDurationSeconds = 0.75,
	}),
	Extraction = table.freeze({
		LandmarkId = "ExtractionClearing",
		Position = table.freeze({ x = 218, y = 1, z = 58 }),
		RadiusStuds = 34,
		ArrivalSeconds = 120,
	}),
	Escalation = table.freeze({
		SecondWaveDelaySeconds = 20,
		Waves = table.freeze({
			-- The relay ring is centered far enough from the console that every
			-- authored contact clears the 64-stud fair-spawn radius immediately.
			-- Wave 1 fires when the relay is restored (Lookout).
			createRingWave("relay-collapse", "Relay Pack", -100, 50, 2, 78),
			-- Wave 2 is re-homed to the Military Roadblock and fires when the signal
			-- booster finishes charging (P8-0105), converging on the defended hold so
			-- the position is never indefinitely optimal.
			-- Radius keeps every contact past the 64-stud fair-spawn floor from the
			-- squad holding the roadblock booster (min ring distance 70).
			createRingWave("roadblock-swarm", "Roadblock Pack", 180, -178, 3, 80),
			-- Wave 3 fires when the extraction holdout begins (Clearing).
			createRingWave("extraction-nightmare", "Extraction Pack", 218, 58, 4, 94),
		}),
	}),
	ObjectiveTextByPhase = table.freeze({
		Insertion = "Regroup. Something in the forest has heard you.",
		Infiltration = "Restore the relay before the signal dies",
		Exfiltration = "Run for the extraction clearing",
		Holdout = "Survive the horde until extraction arrives",
		Resolved = "Operation resolved",
	}),
	RadioLines = table.freeze({
		InsertionComplete = "Insertion complete. Regroup now. Movement is converging on your position.",
		ProceedToObjective = "Reach Lookout 7 and restore the emergency relay. Do not stop moving.",
		ObjectiveComplete = "Relay restored. Every hostile in Blackwater just heard it. Extraction inbound.",
		RelayRestored = "Relay's live but the signal's too weak. Reach the roadblock booster and charge it.",
		BoosterCharged = "Booster charged. Command has your extraction. Run for the clearing.",
		FloodlightsRestored = "Floodlights online. The clearing is lit — you'll see them coming.",
		PressureRising = "Command: threat density is spiking. The forest is filling up.",
		HoldPosition = "Something came with the horde. Put it down or you are not leaving this clearing.",
		ExtractionInbound = "Target is down. Bird is inbound — hold the clearing until it lands.",
		MissionSuccess = "Extraction complete. The horde is still following the signal.",
		MissionFailure = "Signal lost. Blackwater has consumed the squad.",
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
assert(#MissionConfig.Escalation.Waves == 3, "the operation requires exactly three authored escalation waves")
for _, wave in MissionConfig.Escalation.Waves do
	assert(#wave >= 2 and #wave <= 4, "authored packs must remain small and dangerous")
end

return table.freeze(MissionConfig)
