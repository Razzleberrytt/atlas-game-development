--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local service = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local resolver = fs.readFile("games/living-kingdoms/src/server/Systems/FieldTreatmentResolver.luau")
local reviveService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")
local reviveResolver = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveResolver.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassActionController.luau")

assertThat(string.find(service, "FieldTreatmentResolver.resolveStart", 1, true) ~= nil, "pure start resolver required")
assertThat(
	string.find(service, "FieldTreatmentResolver.resolveContinuity", 1, true) ~= nil,
	"continuous server revalidation required"
)
assertThat(
	string.find(service, "OperativeLifeService.applyAuthoritativeHealing", 1, true) ~= nil,
	"treatment must use life authority"
)
assertThat(string.find(service, "currentAmount = medical.currentAmount -", 1, true) ~= nil, "charge must be spent")
assertThat(string.find(service, "Heartbeat", 1, true) == nil, "class owner must reuse bounded evaluation")
assertThat(string.find(service, "RunService", 1, true) == nil, "class owner must not add a frame loop")

assertThat(
	string.find(reviveService, "ClassService.readMedicReviveBenefits(player)", 1, true) ~= nil,
	"revive runtime must derive medic benefit from class owner"
)
assertThat(string.find(reviveService, "reviveDurationSeconds =", 1, true) ~= nil, "duration must be server supplied")
assertThat(string.find(reviveService, "restoredHealth =", 1, true) ~= nil, "restored health must be server supplied")
assertThat(
	string.find(reviveResolver, "targetAfter.healthState.currentHealth = restoredHealth(facts)", 1, true) ~= nil,
	"P3 resolver must remain the revive health transition owner"
)

local treatmentPayloadStart = string.find(controller, 'requestId = string.format("targeted-action:', 1, true)
assertThat(treatmentPayloadStart ~= nil, "treatment payload must exist")
local treatmentPayloadEnd = string.find(controller, "\n\t\t})", treatmentPayloadStart :: number, true)
assertThat(treatmentPayloadEnd ~= nil, "treatment payload must remain a bounded literal")
local treatmentPayload = string.sub(controller, treatmentPayloadStart :: number, treatmentPayloadEnd :: number)
assertThat(
	string.find(treatmentPayload, "candidateTargetOperativeEntityId = targetId", 1, true) ~= nil,
	"client may submit only a candidate teammate identity"
)
for _, forbidden in
	{
		"healingAmount =",
		"resourceAmount =",
		"distanceStuds =",
		"hasLineOfSight =",
		"serverTimestamp =",
		"reviveDurationSeconds =",
		"restoredHealth =",
	}
do
	assertThat(not string.find(treatmentPayload, forbidden, 1, true), "client must not submit " .. forbidden)
end

local executableStart = string.find(resolver, "]]", 1, true)
local executable = if executableStart == nil then resolver else string.sub(resolver, executableStart + 2)
for _, forbidden in { "Players", "Workspace", "Instance.new", "RemoteEvent", "OnServerEvent", "task.delay" } do
	assertThat(not string.find(executable, forbidden, 1, true), "pure resolver must not contain " .. forbidden)
end

print("P7-0104 source audit: finite treatment, P3 revive authority, narrow input, and bounded runtime passed")
