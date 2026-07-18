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
	Version = "HORDE-VS-001-v1",
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
			createRingWave("relay-collapse", "Relay Horde", -150, 95, 10, 78),
			createRingWave("creek-swarm", "Creek Swarm", 65, 28, 14, 82),
			createRingWave("extraction-nightmare", "Extraction Nightmare", 218, 58, 22, 94),
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
		PressureRising = "Command: threat density is spiking. The forest is filling up.",
		HoldPosition = "Extraction is two minutes out. Hold the clearing or die there.",
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
	assert(#wave >= 10, "every horde wave must author substantial pressure")
end

return table.freeze(MissionConfig)
