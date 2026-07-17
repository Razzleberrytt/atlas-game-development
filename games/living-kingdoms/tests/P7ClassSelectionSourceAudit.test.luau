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
assertThat(string.find(service, "OperativeLifeService.read(player)", 1, true) ~= nil, "participation must be server-derived")
assertThat(string.find(service, "subscribeRoster", 1, true) ~= nil, "roster lifecycle must follow life owner")
assertThat(string.find(service, "maximumProcessedRequestIdsPerOperative", 1, true) ~= nil, "replay history must be bounded")
assertThat(string.find(service, "minimumRequestIntervalSeconds", 1, true) ~= nil, "selection requests must be rate-limited")
assertThat(string.find(service, "task.delay", 1, true) ~= nil, "one bounded deadline lock must exist")
assertThat(not string.find(service, "Heartbeat", 1, true), "selection must not add a Heartbeat loop")
assertThat(not string.find(service, "RunService", 1, true), "selection must not poll per frame")
assertThat(not string.find(service, "FireAllClients", 1, true), "roster snapshots must be recipient-authored")

for _, forbidden in {
	"ActionIntent",
	"applyAuthoritativeDamage",
	"commitAcceptedTransition",
	"applyCombatRestrictions",
	"AmmunitionCacheService",
	"OperativeCombatRuntimeService",
	"FieldTreatment",
	"FieldResupply",
	"ReviveAssistance",
	"Brace",
} do
	assertThat(not string.find(service, forbidden, 1, true), "selection owner must not implement " .. forbidden)
end

assertThat(string.find(controller, "SelectionIntent", 1, true) ~= nil, "client must use the narrow selection intent")
assertThat(string.find(controller, "ReadState", 1, true) ~= nil, "client must recover an initial safe snapshot")
assertThat(string.find(controller, "requestId =", 1, true) ~= nil, "client request requires replay identity")
assertThat(string.find(controller, "classId = classId", 1, true) ~= nil, "client request contains selected class")
for _, forbidden in {
	"operativeEntityId =",
	"selectionStateId =",
	"revision =",
	"resourceAmount =",
	"cooldownEndServerTimestamp =",
	"health =",
	"ammunition =",
	"ActionIntent",
} do
	assertThat(not string.find(controller, forbidden, 1, true), "client must not submit authority field " .. forbidden)
end

assertThat(string.find(resolver, "game:GetService(\"ReplicatedStorage\")", 1, true) ~= nil, "resolver may read shared declarations")
for _, forbidden in {
	"Instance.new",
	"RemoteEvent",
	"RemoteFunction",
	"Players",
	"Workspace",
	"task.delay",
	"task.spawn",
	"OnServerEvent",
	"FireClient",
} do
	assertThat(not string.find(resolver, forbidden, 1, true), "pure resolver must not contain " .. forbidden)
end

assertThat(string.find(serverBootstrap, "ensureClassNetwork", 1, true) ~= nil, "server must create class network")
assertThat(string.find(serverBootstrap, "SelectionIntent", 1, true) ~= nil, "server must create selection remote")
assertThat(string.find(serverBootstrap, "ReadState", 1, true) ~= nil, "server must create read-only snapshot function")
assertThat(not string.find(serverBootstrap, "ActionIntent", 1, true), "P7-0102 must not create an action remote")
local missionStart = string.find(serverBootstrap, "MissionDirectorService.start()", 1, true)
local classStart = string.find(serverBootstrap, "ClassService.start()", 1, true)
assertThat(missionStart ~= nil and classStart ~= nil and missionStart < classStart, "mission authority must start before class selection")
assertThat(string.find(clientBootstrap, "ClassSelectionController.start()", 1, true) ~= nil, "client selection must be bootstrapped")
