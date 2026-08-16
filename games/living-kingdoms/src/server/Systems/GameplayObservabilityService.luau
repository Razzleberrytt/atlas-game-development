--!strict

--[[
	Canonical read-only gameplay observability surface. This service composes
	authoritative snapshots that already exist; it owns no gameplay state,
	scheduler, remote, sampling cadence, or mutation path.
]]

local Workspace = game:GetService("Workspace")

local AmmunitionScarcityTelemetryService = require(script.Parent.AmmunitionScarcityTelemetryService)
local ClassService = require(script.Parent.ClassService)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local ExpeditionRunStateService = require(script.Parent.ExpeditionRunStateService)

local SCHEMA_VERSION = 1

local Service = {}

local function ratio(numerator: number, denominator: number): number
	if denominator <= 0 then
		return 0
	end
	return numerator / denominator
end

local function readRunMetrics(): any
	local activeRunIds = ExpeditionRunStateService.readActiveRunIds()
	local activeRuns = {}
	local lifecycleCounts: { [string]: number } = {}
	local connectedParticipantCount = 0
	local roomsCompleted = 0
	local roomsEncountered = 0
	local totalRooms = 0
	local encountersCompleted = 0

	for _, runId in activeRunIds do
		local snapshot = ExpeditionRunStateService.read(runId)
		assert(snapshot ~= nil, "active expedition run id must resolve to an active run snapshot")
		table.insert(activeRuns, snapshot)
		lifecycleCounts[snapshot.LifecycleState] = (lifecycleCounts[snapshot.LifecycleState] or 0) + 1
		connectedParticipantCount += snapshot.ConnectedParticipantCount
		roomsCompleted += snapshot.RoomsCompleted
		roomsEncountered += snapshot.RoomsEncountered
		totalRooms += snapshot.TotalRooms
		encountersCompleted += snapshot.EncountersCompleted
	end

	return table.freeze({
		activeRunCount = #activeRuns,
		activeRunIds = activeRunIds,
		activeRuns = table.freeze(activeRuns),
		lifecycleCounts = table.freeze(lifecycleCounts),
		connectedParticipantCount = connectedParticipantCount,
		roomsCompleted = roomsCompleted,
		roomsEncountered = roomsEncountered,
		totalRooms = totalRooms,
		encountersCompleted = encountersCompleted,
		roomCompletionRatio = ratio(roomsCompleted, totalRooms),
		roomEncounterRatio = ratio(roomsEncountered, totalRooms),
		lastResult = ExpeditionRunStateService.readLastResult(),
	})
end

function Service.readSnapshot(): any
	local ammunition = AmmunitionScarcityTelemetryService.read()
	local classTelemetry = ClassService.readValidationTelemetry()
	local enemyPressure = EnemyDirectorService.readPressureState()
	local enemyFacts = EnemyDirectorService.readEnemyCombatFacts()
	local targetedEnemyCount = 0
	for _, fact in enemyFacts do
		if fact.targetOperativeEntityId ~= nil then
			targetedEnemyCount += 1
		end
	end

	return table.freeze({
		schemaVersion = SCHEMA_VERSION,
		serverTimestamp = Workspace:GetServerTimeNow(),
		run = readRunMetrics(),
		ammunition = table.freeze({
			telemetry = ammunition,
			dryOperativeRatio = ratio(ammunition.dryOperativeCount, ammunition.activeOperativeCount),
			cacheOpportunityConsumptionRatio = ratio(
				ammunition.consumedCacheOpportunityCount,
				ammunition.totalCacheOpportunityCount
			),
		}),
		classes = table.freeze({
			roster = ClassService.readRoster(),
			telemetry = classTelemetry,
			actionCompletionRatio = ratio(classTelemetry.actionCompletionCount, classTelemetry.actionStartCount),
			actionInterruptionRatio = ratio(classTelemetry.actionInterruptionCount, classTelemetry.actionStartCount),
			resourceUtilizationRatio = ratio(classTelemetry.resourceSpent, classTelemetry.resourceIssued),
		}),
		enemies = table.freeze({
			pressure = enemyPressure,
			activeCombatFactCount = #enemyFacts,
			targetedEnemyCount = targetedEnemyCount,
			targetedEnemyRatio = ratio(targetedEnemyCount, #enemyFacts),
			pressureCountMatchesCombatFacts = enemyPressure.activeEnemyCount == #enemyFacts,
		}),
	})
end

return table.freeze(Service)
