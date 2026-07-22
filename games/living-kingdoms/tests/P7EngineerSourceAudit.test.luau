--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local classService = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local combatService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local resolver = fs.readFile("games/living-kingdoms/src/server/Systems/FieldResupplyResolver.luau")
local telemetry = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionScarcityTelemetryService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassActionController.luau")

assertThat(string.find(classService, "FieldResupplyResolver.resolveStart", 1, true) ~= nil, "pure start resolver")
assertThat(
	string.find(classService, "FieldResupplyResolver.resolveContinuity", 1, true) ~= nil,
	"continuous validation"
)
assertThat(
	string.find(classService, "configureEngineerResupplyBoundary", 1, true) ~= nil,
	"narrow ammunition-owner boundary"
)
assertThat(
	string.find(classService, "currentAmount = supply.currentAmount -", 1, true) ~= nil,
	"charge spent only after commit"
)
assertThat(string.find(classService, "Heartbeat", 1, true) == nil, "class owner adds no heartbeat")
assertThat(
	string.find(combatService, "AmmunitionSupplyResolver.collect", 1, true) ~= nil,
	"existing supply resolver must enforce capacity/deduplication"
)
assertThat(
	string.find(combatService, "SupplySourceIds.EngineerResupply", 1, true) ~= nil,
	"engineer source must remain distinct"
)
assertThat(
	string.find(combatService, "commitReviveCombatState", 1, true) ~= nil,
	"production ammunition commit boundary required"
)
assertThat(string.find(telemetry, "engineerRoundsGranted", 1, true) ~= nil, "telemetry must conserve engineer grants")
assertThat(string.find(telemetry, "engineerResupplyCount", 1, true) ~= nil, "telemetry must count engineer source")

local payloadStart = string.find(controller, 'requestId = string.format("targeted-action:', 1, true)
assertThat(payloadStart ~= nil, "targeted action payload")
local payloadEnd = string.find(controller, "\n\t\t})", payloadStart :: number, true)
assertThat(payloadEnd ~= nil, "bounded action payload")
local payload = string.sub(controller, payloadStart :: number, payloadEnd :: number)
for _, forbidden in
	{
		"availableRounds =",
		"resourceAmount =",
		"reserveRounds =",
		"maximumReserveRounds =",
		"weaponId =",
		"serverTimestamp =",
	}
do
	assertThat(not string.find(payload, forbidden, 1, true), "client must not submit " .. forbidden)
end

local executableStart = string.find(resolver, "]]", 1, true)
local executable = if executableStart == nil then resolver else string.sub(resolver, executableStart + 2)
for _, forbidden in { "Players", "Workspace", "Instance.new", "RemoteEvent", "OnServerEvent", "task.delay" } do
	assertThat(not string.find(executable, forbidden, 1, true), "pure resolver must not contain " .. forbidden)
end
assertThat(
	not string.find(classService, "ObjectiveRepair", 1, true)
		and not string.find(classService, "repairObjective", 1, true),
	"P8 objective repair runtime must remain absent"
)

print("P7-0105 source audit: finite resupply, ammunition authority, telemetry, and narrow input passed")
