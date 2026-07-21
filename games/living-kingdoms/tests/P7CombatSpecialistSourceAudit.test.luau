--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local service = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local resolver = fs.readFile("games/living-kingdoms/src/server/Systems/BraceResolver.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local fireResolver = fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassActionController.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assertThat(string.find(serverBootstrap, '"ActionIntent"', 1, true) ~= nil, "server must create action intent remote")
assertThat(
	string.find(service, "BraceResolver.resolveStart", 1, true) ~= nil,
	"server owner must use pure start resolver"
)
assertThat(
	string.find(service, "BraceResolver.resolveContinuity", 1, true) ~= nil,
	"server owner must use pure continuity resolver"
)
assertThat(string.find(service, "processedActionRequestIds", 1, true) ~= nil, "action replay must be owned")
assertThat(
	string.find(service, "maximumProcessedRequestIdsPerOperative", 1, true) ~= nil,
	"action replay history must remain bounded"
)
assertThat(string.find(service, "operativePosition", 1, true) ~= nil, "Brace movement must be server-derived")
assertThat(string.find(service, "Heartbeat", 1, true) == nil, "class owner must not add a heartbeat")
assertThat(string.find(service, "RunService", 1, true) == nil, "class owner must not add a frame loop")

assertThat(
	string.find(combat, "ClassService.evaluateActionsAt(serverTimestamp)", 1, true) ~= nil,
	"existing combat evaluation must advance Brace"
)
assertThat(
	string.find(combat, "ClassService.interruptBraceForReload", 1, true) ~= nil,
	"accepted reload must interrupt Brace"
)
assertThat(
	string.find(combat, "ClassService.readBraceCadenceMultiplier", 1, true) ~= nil,
	"combat owner must read server-owned Brace modifier"
)
assertThat(
	string.find(fireResolver, "classCadenceMultiplier", 1, true) ~= nil,
	"automatic fire must compose bounded class cadence"
)

local payloadStart = string.find(controller, 'requestId = string.format("class-action:', 1, true)
assertThat(payloadStart ~= nil, "client action payload must exist")
local payloadEnd = string.find(controller, "\n\t\t})", payloadStart :: number, true)
assertThat(payloadEnd ~= nil, "client action payload must have a bounded literal")
local payload = string.sub(controller, payloadStart :: number, payloadEnd :: number)
for _, required in { "requestId =", "actionId = actionId", "phaseId = phaseId" } do
	assertThat(string.find(payload, required, 1, true) ~= nil, "action payload missing " .. required)
end
for _, forbidden in
	{
		"operativeEntityId =",
		"serverTimestamp =",
		"cadenceIntervalMultiplier =",
		"movementDistanceStuds =",
		"cooldownEndServerTimestamp =",
		"ammunition =",
		"health =",
	}
do
	assertThat(not string.find(payload, forbidden, 1, true), "client must not submit " .. forbidden)
end
assertThat(string.find(controller, "RenderStepped", 1, true) == nil, "feedback must not add a render loop")
assertThat(string.find(controller, "Heartbeat", 1, true) == nil, "feedback must not add a heartbeat")
assertThat(
	string.find(clientBootstrap, "ClassActionController.start()", 1, true) ~= nil,
	"Brace feedback/input must be bootstrapped"
)

local executableStart = string.find(resolver, "]]", 1, true)
local resolverExecutable = if executableStart == nil then resolver else string.sub(resolver, executableStart + 2)
for _, forbidden in { "Players", "Workspace", "Instance.new", "RemoteEvent", "OnServerEvent", "task.delay" } do
	assertThat(not string.find(resolverExecutable, forbidden, 1, true), "pure resolver must not contain " .. forbidden)
end

print(
	"P7-0103 source audit: narrow input, server authority, combat composition, bounded lifecycle, and feedback passed"
)
