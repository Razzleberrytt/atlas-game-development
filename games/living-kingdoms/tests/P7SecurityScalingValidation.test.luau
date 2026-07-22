--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassContracts.luau"), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()

local actionBase = {
	requestId = "security-action",
	actionId = contracts.ClassActionIds.FieldTreatment,
	phaseId = contracts.ClassActionPhaseIds.Begin,
	candidateTargetOperativeEntityId = "operative.player:2",
}
for _, forgedField in
	{
		"operativeEntityId",
		"classId",
		"resourceAmount",
		"distanceStuds",
		"hasLineOfSight",
		"serverTimestamp",
		"cooldownEndServerTimestamp",
		"revision",
		"healAmount",
		"roundsPerCharge",
		"weaponId",
		"didComplete",
	}
do
	local forged = table.clone(actionBase)
	forged[forgedField] = if forgedField == "hasLineOfSight" or forgedField == "didComplete" then true else 1
	assertThat(not contracts.validateClassActionIntent(forged), "action shape must reject forged " .. forgedField)
end
assertThat(contracts.validateClassActionIntent(actionBase), "minimal candidate target hint must remain legal")

local selectionBase = { requestId = "security-selection", classId = contracts.ClassIds.Engineer }
for _, forgedField in { "operativeEntityId", "targetOperativeEntityId", "isUnlocked", "serverTimestamp", "revision" } do
	local forged = table.clone(selectionBase)
	forged[forgedField] = true
	assertThat(not contracts.validateClassSelectionIntent(forged), "selection shape must reject forged " .. forgedField)
end

local members = {}
for index = 1, 8 do
	table.insert(members, {
		operativeEntityId = "operative.scale:" .. tostring(index),
		classId = if index % 3 == 1
			then contracts.ClassIds.CombatSpecialist
			else if index % 3 == 2 then contracts.ClassIds.Medic else contracts.ClassIds.Engineer,
		actionStateId = contracts.ClassActionStateIds.Idle,
		actionId = nil,
	})
end
assertThat(
	contracts.validateSafeClassSelectionSnapshot({
		operationId = contracts.ClassSelectionNetworkOperationIds.Snapshot,
		rosterRevision = 8,
		selectionStateId = contracts.ClassSelectionStateIds.Locked,
		ownerAssignment = nil,
		ownerActionState = nil,
		ownerResources = {},
		squadMembers = members,
	}),
	"safe snapshot must scale without fixed four-player slots"
)
members[8].operativeEntityId = members[1].operativeEntityId
assertThat(not contracts.validateSafeClassSelectionSnapshot({
	operationId = contracts.ClassSelectionNetworkOperationIds.Snapshot,
	rosterRevision = 9,
	selectionStateId = contracts.ClassSelectionStateIds.Locked,
	ownerAssignment = nil,
	ownerActionState = nil,
	ownerResources = {},
	squadMembers = members,
}), "duplicate operative disclosure must fail closed")

local service = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local presentation = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassSquadPresentationController.luau")
local telemetry = fs.readFile("games/living-kingdoms/src/server/Systems/ClassValidationTelemetryService.luau")

for _, required in
	{
		"entryByPlayer[player]",
		"OperativeLifeService.isCombatAllowed(player)",
		"distanceAndLineOfSight(player, targetPlayer)",
		"processedActionRequestIds",
		"minimumRequestIntervalSeconds",
		"ClassValidationTelemetryService.recordResourceCommit",
		"table.clear(entriesByOperativeId)",
		"table.clear(entryByPlayer)",
	}
do
	assertThat(string.find(service, required, 1, true) ~= nil, "authoritative class boundary missing " .. required)
end
assertThat(
	string.find(bootstrap, '"SelectionIntent", "ActionIntent", "State"', 1, true) ~= nil,
	"network must stay narrow"
)
-- P8-0106 permits the mission to read class for opportunities (the engineer's
-- objective-equipment repair), but no mandatory objective may be class-gated.
-- Encode that as a config invariant rather than forbidding any class reference:
-- required objectives grant class no advantage (assistedRateMultiplier == 1) and
-- every objective is completable without a class (baseRatePerSecond > 0).
local objectiveChain = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Config/ObjectiveChainConfig.luau"),
	{ debugName = "ObjectiveChainConfig", injectGlobals = true }
)()
for _, definition in objectiveChain.Objectives do
	assertThat(
		definition.baseRatePerSecond > 0,
		"every objective must be completable without a class: " .. definition.objectiveId
	)
	if not definition.isOptional then
		assertThat(
			definition.assistedRateMultiplier == 1,
			"a mandatory objective must not be class-gated: " .. definition.objectiveId
		)
	end
end
for _, hiddenVocabulary in { "EnemyDirector", "MissionObject", "SupplyCache", "objectiveState", "hostileId" } do
	assertThat(
		not string.find(presentation, hiddenVocabulary, 1, true),
		"class presentation must not reveal " .. hiddenVocabulary
	)
end
for _, forbidden in { "Instance.new", "RemoteEvent", "RemoteFunction", "Heartbeat", "task.delay", "task.spawn" } do
	assertThat(not string.find(telemetry, forbidden, 1, true), "telemetry must not own " .. forbidden)
end
assertThat(string.find(service, "for index = 1, 4", 1, true) == nil, "class owner must not hard-code four slots")
assertThat(string.find(service, "[4]", 1, true) == nil, "class owner must not use a fixed four-entry roster")

print("P7-0107 security/scaling: forged facts, duplicate disclosure, authority, no gates, bounds, and cleanup passed")
