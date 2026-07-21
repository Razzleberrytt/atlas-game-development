--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local servicePath = "games/living-kingdoms/src/server/Systems/ClassService.luau"
local resolverPath = "games/living-kingdoms/src/server/Systems/ClassSelectionResolver.luau"
local controllerPath = "games/living-kingdoms/src/client/Controllers/ClassSelectionController.luau"
local serverBootstrapPath = "games/living-kingdoms/src/server/init.server.luau"
local clientBootstrapPath = "games/living-kingdoms/src/client/init.client.luau"

local service = fs.readFile(servicePath)
local resolver = fs.readFile(resolverPath)
local controller = fs.readFile(controllerPath)
local serverBootstrap = fs.readFile(serverBootstrapPath)
local clientBootstrap = fs.readFile(clientBootstrapPath)

assertThat(string.find(service, "ClassSelectionResolver.resolve", 1, true) ~= nil, "runtime must use pure resolver")
assertThat(string.find(service, "MissionDirectorService.read", 1, true) ~= nil, "mission phase must be server-derived")
assertThat(
	string.find(service, "OperativeLifeService.read(player)", 1, true) ~= nil,
	"participation must be server-derived"
)
assertThat(string.find(service, "subscribeRoster", 1, true) ~= nil, "roster lifecycle must follow life owner")
assertThat(
	string.find(service, "maximumProcessedRequestIdsPerOperative", 1, true) ~= nil,
	"replay history must be bounded"
)
assertThat(
	string.find(service, "minimumRequestIntervalSeconds", 1, true) ~= nil,
	"selection requests must be rate-limited"
)
assertThat(string.find(service, "task.delay", 1, true) ~= nil, "one bounded deadline lock must exist")
assertThat(not string.find(service, "Heartbeat", 1, true), "selection must not add a Heartbeat loop")
assertThat(not string.find(service, "RunService", 1, true), "selection must not poll per frame")
assertThat(not string.find(service, "FireAllClients", 1, true), "roster snapshots must be recipient-authored")

for _, forbidden in
	{
		"applyAuthoritativeDamage",
		"commitAcceptedTransition",
		"applyCombatRestrictions",
		"AmmunitionCacheService",
		"OperativeCombatRuntimeService",
		"FieldTreatment",
		"FieldResupply",
		"ReviveAssistance",
	}
do
	assertThat(not string.find(service, forbidden, 1, true), "selection owner must not implement " .. forbidden)
end

assertThat(string.find(controller, "SelectionIntent", 1, true) ~= nil, "client must use the narrow selection intent")
assertThat(string.find(controller, "ReadState", 1, true) ~= nil, "client must recover an initial safe snapshot")
assertThat(not string.find(controller, "ActionIntent", 1, true), "P7-0102 client must not expose class actions")

local payloadStart = string.find(controller, "selectionIntentRemote:FireServer({", 1, true)
assertThat(payloadStart ~= nil, "client selection payload must exist")
local payloadEnd = string.find(controller, "\n\t})", payloadStart :: number, true)
assertThat(payloadEnd ~= nil, "client selection payload must have a bounded literal body")
local selectionPayload = string.sub(controller, payloadStart :: number, (payloadEnd :: number) + 3)

assertThat(string.find(selectionPayload, "requestId =", 1, true) ~= nil, "client request requires replay identity")
assertThat(string.find(selectionPayload, "classId = classId", 1, true) ~= nil, "client request contains selected class")
for _, forbidden in
	{
		"operativeEntityId =",
		"selectionStateId =",
		"revision =",
		"resourceAmount =",
		"cooldownEndServerTimestamp =",
		"health =",
		"ammunition =",
	}
do
	assertThat(
		not string.find(selectionPayload, forbidden, 1, true),
		"client selection payload must not submit authority field " .. forbidden
	)
end

local resolverHeaderEnd = string.find(resolver, "]]", 1, true)
local resolverExecutable = if resolverHeaderEnd == nil then resolver else string.sub(resolver, resolverHeaderEnd + 2)
assertThat(
	string.find(resolverExecutable, 'game:GetService("ReplicatedStorage")', 1, true) ~= nil,
	"resolver may read shared declarations"
)
for _, forbidden in
	{
		"Instance.new",
		"RemoteEvent",
		"RemoteFunction",
		"Players",
		"Workspace",
		"task.delay",
		"task.spawn",
		"OnServerEvent",
		"FireClient",
	}
do
	assertThat(
		not string.find(resolverExecutable, forbidden, 1, true),
		"pure resolver executable source must not contain " .. forbidden
	)
end

assertThat(string.find(serverBootstrap, "ensureClassNetwork", 1, true) ~= nil, "server must create class network")
assertThat(string.find(serverBootstrap, "SelectionIntent", 1, true) ~= nil, "server must create selection remote")
assertThat(string.find(serverBootstrap, "ReadState", 1, true) ~= nil, "server must create read-only snapshot function")
assertThat(string.find(serverBootstrap, "ActionIntent", 1, true) ~= nil, "P7-0103 must create the action remote")
local missionStart = string.find(serverBootstrap, "MissionDirectorService.start()", 1, true)
local classStart = string.find(serverBootstrap, "ClassService.start()", 1, true)
assertThat(
	missionStart ~= nil and classStart ~= nil and missionStart < classStart,
	"mission authority must start before class selection"
)
assertThat(
	string.find(clientBootstrap, "ClassSelectionController.start()", 1, true) ~= nil,
	"client selection must be bootstrapped"
)
