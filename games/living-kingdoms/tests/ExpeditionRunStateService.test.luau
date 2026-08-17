--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRunStateService.luau"), {
	debugName = "ExpeditionRunStateService",
	injectGlobals = true,
})()

local function plan(): any
	return {
		Nodes = {
			{ Index = 1, RoomId = "entry", Role = "Entry" },
			{ Index = 2, RoomId = "combat", Role = "Combat" },
			{ Index = 3, RoomId = "hall", Role = "Traversal" },
			{ Index = 4, RoomId = "boss", Role = "Boss" },
		},
	}
end

service.resetForTests()
check(
	service.create({ RunId = "expedition:run-a", Seed = 11, PartySize = 2, StartedAtUnix = 100, RoomPlan = plan() }).Accepted,
	"run A create"
)
check(
	service.create({ RunId = "expedition:run-b", Seed = 22, PartySize = 1, StartedAtUnix = 200, RoomPlan = plan() }).Accepted,
	"run B create"
)
check(#service.readActiveRunIds() == 2, "simultaneous run records must be isolated")
check(service.bindParticipants("expedition:run-a", { 20, 10 }).Accepted, "run A roster")
check(service.bindParticipants("expedition:run-b", { 30 }).Accepted, "run B roster")
check(service.read("expedition:run-a").ParticipantUserIds[1] == 10, "roster must sort deterministically")

local first = service.sync("expedition:run-a", {
	Snapshot = { RunId = "expedition:run-a", PhaseId = "Dungeon", OutcomeId = "InProgress" },
	CurrentRoomId = "combat",
	CurrentRoomRoleId = "Combat",
	EncounterKey = "Dungeon:combat",
	EncounterActive = true,
	CompletedRoomCount = 0,
	EncounteredRoomCount = 1,
	TotalRoomCount = 2,
	ObservedAtUnix = 110,
})
check(first.Snapshot.LifecycleState == "Encounter", "combat room should expose encounter state")
check(service.read("expedition:run-b").CurrentRoomId == nil, "run A must not mutate run B")
service.sync("expedition:run-a", {
	Snapshot = { RunId = "expedition:run-a", PhaseId = "Dungeon", OutcomeId = "InProgress" },
	EncounterActive = false,
	CompletedRoomCount = 1,
	EncounteredRoomCount = 1,
	TotalRoomCount = 2,
	ObservedAtUnix = 120,
})
service.sync("expedition:run-a", {
	Snapshot = { RunId = "expedition:run-a", PhaseId = "Dungeon", OutcomeId = "InProgress" },
	EncounterActive = false,
	CompletedRoomCount = 1,
	EncounteredRoomCount = 1,
	TotalRoomCount = 2,
	ObservedAtUnix = 121,
})
check(service.read("expedition:run-a").EncountersCompleted == 1, "duplicate completion observations must be idempotent")

check(
	not service.setParticipantConnected("expedition:run-a", 10, false).AllParticipantsDisconnected,
	"one leaver must not end co-op"
)
service.setParticipantConnected("expedition:run-a", 20, false)
check(
	service.setParticipantConnected("expedition:run-a", 10, false).AllParticipantsDisconnected,
	"all leavers must be detectable"
)
service.setParticipantConnected("expedition:run-a", 10, true)
check(
	service.read("expedition:run-a").ConnectedParticipantCount == 1,
	"participant reconnect should restore connectivity"
)

service.recordRewardOutcome("expedition:run-a", "Elite")
service.recordRewardOutcome("expedition:run-a", "Elite")
service.recordRewardOutcome("expedition:run-a", "Boss")
check(#service.read("expedition:run-a").RewardOutcomeIds == 2, "reward outcomes must deduplicate")

service.sync("expedition:run-a", {
	Snapshot = { RunId = "expedition:run-a", PhaseId = "Results", OutcomeId = "Completed" },
	EncounterActive = false,
	CompletedRoomCount = 2,
	EncounteredRoomCount = 2,
	TotalRoomCount = 2,
	ObservedAtUnix = 160,
})
local cleaned = service.completeCleanup("expedition:run-a", 162)
check(cleaned.Accepted and cleaned.Snapshot.Success == true, "completed run should archive success")
check(cleaned.Snapshot.DurationSeconds == 60, "terminal observation should own duration")
check(
	service.read("expedition:run-a") == nil and service.readResult("expedition:run-a") ~= nil,
	"cleanup must release active state and retain result"
)

check(
	service.fail("expedition:run-b", "AllParticipantsLeft", 230, "Abandoned").Accepted,
	"failure should terminalize run"
)
service.completeCleanup("expedition:run-b", 231)
local failed = service.readResult("expedition:run-b")
check(
	failed ~= nil and failed.Success == false and failed.FailureReason == "AllParticipantsLeft",
	"failure result must retain reason"
)
check(#service.readActiveRunIds() == 0, "all active state must be released")

print("ExpeditionRunStateService tests passed")
