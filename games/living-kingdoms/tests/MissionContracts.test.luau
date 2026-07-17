--!strict

-- P5-0103 mission vocabulary, safe-snapshot validation, and authored config.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0103 contracts fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local config = loadSimple("games/living-kingdoms/src/shared/Config/MissionConfig.luau", "MissionConfig")
local world = loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

-- Stable identifier vocabulary.
for _, phaseId in { "Insertion", "Infiltration", "Exfiltration", "Holdout", "Resolved" } do
	assert(contracts.MissionPhaseIds[phaseId] == phaseId, "missing phase " .. phaseId)
end
for _, outcomeId in { "Success", "Failure" } do
	assert(contracts.MissionOutcomeIds[outcomeId] == outcomeId)
end
for _, objectiveStateId in { "Inactive", "Active", "Completed" } do
	assert(contracts.ObjectiveStateIds[objectiveStateId] == objectiveStateId)
end
for _, reasonId in
	{
		"ServiceStopped",
		"InvalidPhase",
		"AlreadyCompleted",
		"UnknownOperative",
		"InvalidLifeState",
		"MissingPosition",
		"OutOfRange",
		"InvalidTimestamp",
	}
do
	assert(contracts.RejectionReasonIds[reasonId] == reasonId, "missing rejection reason " .. reasonId)
end
assert(table.isfrozen(contracts))
assert(table.isfrozen(contracts.MissionPhaseIds))
assert(table.isfrozen(contracts.RadioLineIds))
assert(table.isfrozen(config))
assert(table.isfrozen(config.Escalation))

-- Every declared radio line has authored text and vice versa.
for lineId in contracts.RadioLineIds do
	assert(type(config.RadioLines[lineId]) == "string" and config.RadioLines[lineId] ~= "", lineId)
end
for lineId in config.RadioLines do
	assert(contracts.RadioLineIds[lineId] == lineId, "unknown radio line " .. lineId)
end

-- Every phase has authored objective text.
for phaseId in contracts.MissionPhaseIds do
	assert(type(config.ObjectiveTextByPhase[phaseId]) == "string", "missing objective text for " .. phaseId)
end

-- Safe snapshot validation.
local function snapshot(overrides: { [string]: any }): { [string]: any }
	local value = {
		operationId = config.OperationId,
		revision = 3,
		phaseId = "Infiltration",
		objectiveStateId = "Active",
		objectiveText = config.ObjectiveTextByPhase.Infiltration,
		extractionUnlocked = false,
		escalationLevel = 0,
		holdoutDeadlineServerTimestamp = nil,
		outcomeId = nil,
		radio = { lineId = "ProceedToObjective", text = "Proceed.", serverTimestamp = 12.5 },
	}
	for key, override in overrides do
		value[key] = override
	end
	return value
end

assert(contracts.validateSafeMissionSnapshot(snapshot({})))
assert(contracts.validateSafeMissionSnapshot(snapshot({ radio = nil })))
assert(
	contracts.validateSafeMissionSnapshot(
		snapshot({ phaseId = "Resolved", outcomeId = "Success", objectiveStateId = "Completed" })
	)
)
assert(not contracts.validateSafeMissionSnapshot(nil))
assert(not contracts.validateSafeMissionSnapshot("Infiltration"))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ phaseId = "Invented" })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ revision = -1 })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ revision = math.huge })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ objectiveStateId = "Done" })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ objectiveText = "" })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ extractionUnlocked = "yes" })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ holdoutDeadlineServerTimestamp = -4 })))
assert(not contracts.validateSafeMissionSnapshot(snapshot({ outcomeId = "Success" })), "outcome requires Resolved")
assert(not contracts.validateSafeMissionSnapshot(snapshot({ phaseId = "Resolved" })), "Resolved requires outcome")
assert(not contracts.validateSafeMissionSnapshot(snapshot({ phaseId = "Resolved", outcomeId = "Draw" })))
assert(
	not contracts.validateSafeMissionSnapshot(
		snapshot({ radio = { lineId = "Invented", text = "x", serverTimestamp = 1 } })
	)
)
assert(
	not contracts.validateSafeMissionSnapshot(
		snapshot({ radio = { lineId = "HoldPosition", text = "", serverTimestamp = 1 } })
	)
)

-- Authored geometry stays inside the P5-0102 world and on its landmarks.
local function landmarkById(landmarkId: string): any
	for _, landmark in world.Landmarks do
		if landmark.id == landmarkId then
			return landmark
		end
	end
	error("missing landmark " .. landmarkId)
end

local extractionLandmark = landmarkById(config.Extraction.LandmarkId)
assert(config.Extraction.Position.x == extractionLandmark.x and config.Extraction.Position.z == extractionLandmark.z)
assert(config.Extraction.RadiusStuds <= extractionLandmark.radius, "extraction zone must stay on its clearing")
assert(config.Extraction.ArrivalSeconds >= 30 and config.Extraction.ArrivalSeconds <= 300)

local objectiveLandmark = landmarkById(config.Objective.LandmarkId)
local consoleDx = config.Objective.ConsolePosition.x - objectiveLandmark.x
local consoleDz = config.Objective.ConsolePosition.z - objectiveLandmark.z
assert(
	consoleDx * consoleDx + consoleDz * consoleDz <= objectiveLandmark.radius * objectiveLandmark.radius,
	"objective console must sit on its landmark"
)

local seenWaveIds: { [string]: boolean } = {}
for _, wave in config.Escalation.Waves do
	for _, hostile in wave do
		assert(seenWaveIds[hostile.id] == nil, "duplicate hostile id " .. hostile.id)
		seenWaveIds[hostile.id] = true
		assert(math.abs(hostile.x) <= world.PlayableHalfExtentStuds)
		assert(math.abs(hostile.z) <= world.PlayableHalfExtentStuds)
	end
end

-- The insertion regroup and the extraction countdown stay inside the intended
-- 10-15 minute session shape.
assert(config.InsertionHoldSeconds >= 5 and config.InsertionHoldSeconds <= 60)
assert(config.Escalation.SecondWaveDelaySeconds >= 15 and config.Escalation.SecondWaveDelaySeconds <= 180)

print("MissionContracts: P5-0103 vocabulary, snapshot validation, and authored config passed")
