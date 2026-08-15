--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local lifecycle = fs.readFile("games/living-kingdoms/src/server/expedition-run-lifecycle.server.luau")
local harness = fs.readFile("games/living-kingdoms/src/server/expedition-run-development.server.luau")

check(string.find(lifecycle, "ExpeditionRunStateService", 1, true) ~= nil, "lifecycle must use run state authority")
check(string.find(lifecycle, "ExpeditionRunRosterService", 1, true) ~= nil, "lifecycle must consume launch-time roster")
check(string.find(lifecycle, "AllParticipantsLeft", 1, true) ~= nil, "lifecycle must handle all-participant departure")
check(
	string.find(lifecycle, "EnemyDirectorService.stop()", 1, true) ~= nil,
	"teardown must clear enemies through public lifecycle"
)
check(
	string.find(lifecycle, "EquipmentRewardContracts", 1, true) ~= nil,
	"run summary must use stable reward source contracts"
)
check(string.find(lifecycle, "RemoteEvent", 1, true) == nil, "run lifecycle must not expose client mutation remotes")
check(string.find(harness, "RunService:IsStudio()", 1, true) ~= nil, "development harness must stay Studio-only")
check(
	string.find(harness, "ServerStorage", 1, true) ~= nil and string.find(harness, "RemoteEvent", 1, true) == nil,
	"development harness must stay server-only"
)
check(string.find(harness, "StartSeed", 1, true) ~= nil, "development harness should start a known seed")
check(string.find(harness, "ReplayLastSeed", 1, true) ~= nil, "development harness should replay the last seed")
check(string.find(harness, "ForceCleanup", 1, true) ~= nil, "development harness should force cleanup")

print("ExpeditionRunLifecycle source audit passed")
