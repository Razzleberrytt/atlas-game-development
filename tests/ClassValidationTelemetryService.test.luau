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
local CONTRACTS_TOKEN = {}
local service =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ClassValidationTelemetryService.luau"), {
		debugName = "ClassValidationTelemetryService",
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					assertThat(serviceName == "ReplicatedStorage", "telemetry must use only shared declarations")
					return { Shared = { Classes = { ClassContracts = CONTRACTS_TOKEN } } }
				end,
			},
			require = function(token: unknown)
				if token == CONTRACTS_TOKEN then
					return contracts
				end
				error("unexpected class telemetry dependency", 2)
			end,
		},
		injectGlobals = true,
	})()

local medicId = "operative.player:1"
local engineerId = "operative.player:2"
service.reset()
service.assign(medicId, contracts.ClassIds.Medic, 3)
service.assign(engineerId, contracts.ClassIds.Engineer, 2)
service.recordActionStarted(medicId, contracts.ClassActionIds.FieldTreatment, 10)
service.recordActionEnded(medicId, contracts.ClassActionIds.FieldTreatment, 13, true, true)
service.recordResourceCommit(medicId, 1, 25, 0)
service.recordActionAvailable(medicId, contracts.ClassActionIds.FieldTreatment)
service.recordActionStarted(engineerId, contracts.ClassActionIds.FieldResupply, 20)
service.recordActionEnded(engineerId, contracts.ClassActionIds.FieldResupply, 21, false, true)
service.recordActionStarted(engineerId, contracts.ClassActionIds.FieldResupply, 30)
service.recordActionEnded(engineerId, contracts.ClassActionIds.FieldResupply, 32.5, true, true)
service.recordResourceCommit(engineerId, 1, 0, 8)
service.setConnected(engineerId, false)

local snapshot = service.read()
assertThat(snapshot.trackedOperativeCount == 2, "disconnect history must remain bounded and readable")
assertThat(snapshot.connectedOperativeCount == 1, "disconnect state must be explicit")
assertThat(snapshot.actionStartCount == 3, "starts must aggregate")
assertThat(snapshot.actionCompletionCount == 2, "completions must aggregate")
assertThat(snapshot.actionInterruptionCount == 1, "interruptions must aggregate")
assertThat(snapshot.activeSeconds == 6.5, "channel commitment time must aggregate")
assertThat(snapshot.resourceIssued == 5, "issued resources must aggregate")
assertThat(snapshot.resourceSpent == 2 and snapshot.resourceRemaining == 3, "resource conservation must hold")
assertThat(snapshot.healthRestored == 25 and snapshot.ammunitionGranted == 8, "effects must be exact commits")
assertThat(snapshot.operatives[1].operativeEntityId == medicId, "operative output must be stable-sorted")
assertThat(snapshot.operatives[2].isConnected == false, "removed operative metrics must remain inactive")

local medicActions = snapshot.operatives[1].actions
assertThat(#medicActions == 2, "medic treatment and revive assistance must be independently observable")
local treatment = if medicActions[1].actionId == contracts.ClassActionIds.FieldTreatment
	then medicActions[1]
	else medicActions[2]
assertThat(treatment.availableCount == 2, "cooldown return must create a new availability")
assertThat(treatment.startCount == 1 and treatment.completionCount == 1, "treatment lifecycle must be recorded")

local mutationSucceeded = pcall(function()
	snapshot.operatives[1].resourceRemaining = 99
end)
assertThat(not mutationSucceeded, "validation reads must be immutable")
service.reset()
assertThat(service.read().trackedOperativeCount == 0, "operation reset must clear the bounded ledger")
for index = 1, 8 do
	service.assign("operative.scale:" .. tostring(index), contracts.ClassIds.CombatSpecialist, 0)
end
assertThat(service.read().trackedOperativeCount == 8, "validation ledger must support the future eight-player ceiling")
local ninthSucceeded = pcall(function()
	service.assign("operative.scale:9", contracts.ClassIds.CombatSpecialist, 0)
end)
assertThat(not ninthSucceeded, "validation ledger must fail closed above its explicit bound")
service.reset()

local source = fs.readFile("games/living-kingdoms/src/server/Systems/ClassValidationTelemetryService.luau")
for _, forbidden in { "Instance.new", "RemoteEvent", "RemoteFunction", "Heartbeat", "task.spawn", "task.delay" } do
	assertThat(not string.find(source, forbidden, 1, true), "read-only telemetry must not contain " .. forbidden)
end

print("ClassValidationTelemetryService: lifecycle, effects, conservation, disconnect, bounds, and reset passed")
