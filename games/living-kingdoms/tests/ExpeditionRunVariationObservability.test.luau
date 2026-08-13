--!strict

local fs = require("@lune/fs")

local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau")
local mountSource = fs.readFile("games/living-kingdoms/src/server/expedition-live.server.luau")

local function has(source: string, text: string): boolean
	return string.find(source, text, 1, true) ~= nil
end

for _, field in {
	"CurrentEncounterPhaseId",
	"CurrentRoomId",
	"ActiveWaveIndex",
	"AuthoredWaveCount",
	"RemainingAuthoredWaves",
	"EncounteredRoomCount",
	"CompletedRoomCount",
	"TotalRoomCount",
} do
	assert(has(serviceSource, field), "missing live diagnostic field: " .. field)
end

for _, reasonId in {
	"ServiceStopped",
	"NoActiveExpedition",
	"ExpectedRunIdRequired",
	"StaleRun",
	"DiagnosticRateLimited",
} do
	assert(has(serviceSource, reasonId), "missing diagnostic reason: " .. reasonId)
end

assert(has(serviceSource, "MAX_DIAGNOSTIC_READS_PER_SECOND = 20"), "diagnostic rate bound drift")
assert(has(serviceSource, "SequenceStageIndex"), "wave progress source drift")
assert(has(serviceSource, "NextDungeonNodeIndex"), "room progress source drift")
assert(has(mountSource, "payload.ExpectedRunId"), "expected-run binding drift")
assert(has(mountSource, 'Instance.new("BindableFunction")'), "diagnostics must remain server-only")

print("Expedition run variation observability contract audit passed")
