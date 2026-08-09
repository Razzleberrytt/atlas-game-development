--!strict

local fs = require("@lune/fs")

local lifecycle = fs.readFile("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau")
local lobby = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local returnController = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionReturnController.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

local retiredServer = "games/living-kingdoms/src/server/expedition-replay-decision.server.luau"
local retiredClient = "games/living-kingdoms/src/client/Controllers/ExpeditionReplayDecisionController.luau"

assert(not fs.isFile(retiredServer), "the direct debrief replay server mount must stay retired")
assert(not fs.isFile(retiredClient), "the redundant replay decision GUI must stay retired")
assert(
	string.find(clientBootstrap, "ExpeditionReplayDecisionController", 1, true) == nil,
	"client bootstrap must not resurrect the redundant replay decision surface"
)

assert(
	string.find(returnController, 'InvokeServer("ReturnToLobby")', 1, true) ~= nil,
	"terminal return must use the canonical lobby bridge"
)
assert(
	string.find(lifecycle, "function OperationLifecycleService.prepareForLaunch()", 1, true) ~= nil,
	"the lifecycle owner must expose server-only fresh-run preparation"
)
assert(string.find(lifecycle, "task.delay(", 1, true) == nil, "terminal resolution must not auto-schedule replay")
assert(
	string.find(lobby, "OperationLifecycleService.prepareForLaunch()", 1, true) ~= nil,
	"lobby must prepare fresh state"
)
assert(
	string.find(lobby, 'return response(false, "ExpeditionActive")', 1, true) ~= nil,
	"active run must reject readiness"
)

local prepareAt = string.find(lobby, "OperationLifecycleService.prepareForLaunch()", 1, true)
local pressureAt = string.find(lobby, "MissionDirectorService.armPressure()", 1, true)
local startAt = string.find(lobby, "ExpeditionLiveRuntimeService.startExpedition", 1, true)
assert(prepareAt ~= nil and pressureAt ~= nil and startAt ~= nil, "deliberate launch handoff tokens must exist")
assert((prepareAt :: number) < (pressureAt :: number), "fresh-run preparation must happen before pressure is armed")
assert((pressureAt :: number) < (startAt :: number), "pressure arming must remain immediately upstream of launch")

assert(
	string.find(lobby, "ExpeditionLiveRuntimeService.readSnapshot() ~= nil", 1, true) ~= nil,
	"the lobby must fail closed while an expedition still exists"
)
assert(
	string.find(lobby, "lobby:consumeLaunch()", 1, true) ~= nil,
	"only a consumed server-owned ready-state launch may reach fresh-run preparation"
)

print("ExpeditionReplayDecisionAuthority: debrief replay retired; lobby owns deliberate next-run launch")
