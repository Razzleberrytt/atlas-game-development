--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local AMMUNITION_TOKEN = {}
local CLASS_TOKEN = {}
local ENEMY_TOKEN = {}
local RUN_TOKEN = {}

local ammunitionReadCount = 0
local classRosterReadCount = 0
local classTelemetryReadCount = 0
local pressureReadCount = 0
local enemyFactsReadCount = 0
local activeRunIdsReadCount = 0
local runReadCount = 0
local lastResultReadCount = 0

local ammunitionSnapshot = table.freeze({
	dryOperativeCount = 1,
	activeOperativeCount = 2,
	consumedCacheOpportunityCount = 2,
	totalCacheOpportunityCount = 6,
})
local classTelemetry = table.freeze({
	actionCompletionCount = 3,
	actionStartCount = 4,
	actionInterruptionCount = 1,
	resourceSpent = 2,
	resourceIssued = 4,
})
local roster = table.freeze({
	table.freeze({ operativeEntityId = "operative:1", classId = "Medic" }),
	table.freeze({ operativeEntityId = "operative:2", classId = "Engineer" }),
})
local pressure = table.freeze({ activeEnemyCount = 3, escalationLevel = 2 })
local enemyFacts = table.freeze({
	table.freeze({ entityId = "enemy:1", targetOperativeEntityId = "operative:1" }),
	table.freeze({ entityId = "enemy:2", targetOperativeEntityId = nil }),
	table.freeze({ entityId = "enemy:3", targetOperativeEntityId = "operative:2" }),
})
local activeRunIds = table.freeze({ "run-a", "run-b" })
local runById = {
	["run-a"] = table.freeze({
		RunId = "run-a",
		LifecycleState = "Active",
		ConnectedParticipantCount = 2,
		RoomsCompleted = 2,
		RoomsEncountered = 3,
		TotalRooms = 4,
		EncountersCompleted = 1,
	}),
	["run-b"] = table.freeze({
		RunId = "run-b",
		LifecycleState = "Boss",
		ConnectedParticipantCount = 1,
		RoomsCompleted = 1,
		RoomsEncountered = 2,
		TotalRooms = 4,
		EncountersCompleted = 2,
	}),
}
local lastResult = table.freeze({ RunId = "run-old", OutcomeId = "Completed" })

local service =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/GameplayObservabilityService.luau"), {
		debugName = "GameplayObservabilityService",
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					if serviceName == "Workspace" then
						return {
							GetServerTimeNow = function()
								return 123.5
							end,
						}
					end
					error("unexpected service " .. serviceName)
				end,
			},
			script = {
				Parent = {
					AmmunitionScarcityTelemetryService = AMMUNITION_TOKEN,
					ClassService = CLASS_TOKEN,
					EnemyDirectorService = ENEMY_TOKEN,
					ExpeditionRunStateService = RUN_TOKEN,
				},
			},
			require = function(token: unknown)
				if token == AMMUNITION_TOKEN then
					return {
						read = function()
							ammunitionReadCount += 1
							return ammunitionSnapshot
						end,
					}
				end
				if token == CLASS_TOKEN then
					return {
						readRoster = function()
							classRosterReadCount += 1
							return roster
						end,
						readValidationTelemetry = function()
							classTelemetryReadCount += 1
							return classTelemetry
						end,
					}
				end
				if token == ENEMY_TOKEN then
					return {
						readPressureState = function()
							pressureReadCount += 1
							return pressure
						end,
						readEnemyCombatFacts = function()
							enemyFactsReadCount += 1
							return enemyFacts
						end,
					}
				end
				if token == RUN_TOKEN then
					return {
						readActiveRunIds = function()
							activeRunIdsReadCount += 1
							return activeRunIds
						end,
						read = function(runId: string)
							runReadCount += 1
							return runById[runId]
						end,
						readLastResult = function()
							lastResultReadCount += 1
							return lastResult
						end,
					}
				end
				error("unexpected module request")
			end,
		},
		injectGlobals = true,
	})()

local snapshot = service.readSnapshot()
check(snapshot.schemaVersion == 1, "schema version")
check(snapshot.serverTimestamp == 123.5, "server timestamp")

check(snapshot.run.activeRunCount == 2, "active run count")
check(snapshot.run.activeRunIds == activeRunIds, "canonical active run ids must be reused")
check(#snapshot.run.activeRuns == 2, "active run snapshots")
check(snapshot.run.lifecycleCounts.Active == 1 and snapshot.run.lifecycleCounts.Boss == 1, "lifecycle counts")
check(snapshot.run.connectedParticipantCount == 3, "connected participant total")
check(snapshot.run.roomsCompleted == 3, "rooms completed total")
check(snapshot.run.roomsEncountered == 5, "rooms encountered total")
check(snapshot.run.totalRooms == 8, "total room count")
check(snapshot.run.encountersCompleted == 3, "encounters completed total")
check(snapshot.run.roomCompletionRatio == 3 / 8, "room completion ratio")
check(snapshot.run.roomEncounterRatio == 5 / 8, "room encounter ratio")
check(snapshot.run.lastResult == lastResult, "last result")

check(snapshot.ammunition.telemetry == ammunitionSnapshot, "ammunition telemetry must be reused")
check(snapshot.ammunition.dryOperativeRatio == 0.5, "dry operative ratio")
check(snapshot.ammunition.cacheOpportunityConsumptionRatio == 1 / 3, "cache opportunity ratio")

check(snapshot.classes.roster == roster, "class roster must be reused")
check(snapshot.classes.telemetry == classTelemetry, "class telemetry must be reused")
check(snapshot.classes.actionCompletionRatio == 0.75, "class action completion ratio")
check(snapshot.classes.actionInterruptionRatio == 0.25, "class action interruption ratio")
check(snapshot.classes.resourceUtilizationRatio == 0.5, "class resource utilization ratio")

check(snapshot.enemies.pressure == pressure, "enemy pressure must be reused")
check(snapshot.enemies.activeCombatFactCount == 3, "active enemy facts")
check(snapshot.enemies.targetedEnemyCount == 2, "targeted enemy count")
check(snapshot.enemies.targetedEnemyRatio == 2 / 3, "targeted enemy ratio")
check(snapshot.enemies.pressureCountMatchesCombatFacts == true, "enemy pressure/fact coherence")

check(ammunitionReadCount == 1, "ammunition must be read once")
check(classRosterReadCount == 1 and classTelemetryReadCount == 1, "class truth must be read once")
check(pressureReadCount == 1 and enemyFactsReadCount == 1, "enemy truth must be read once")
check(activeRunIdsReadCount == 1 and runReadCount == 2 and lastResultReadCount == 1, "run truth read counts")

local mutationSucceeded = pcall(function()
	snapshot.schemaVersion = 99
end)
check(not mutationSucceeded, "canonical gameplay snapshot must be frozen")

print("GameplayObservabilityService: canonical cross-system read-only metrics passed")
