--!strict

-- P10-0107 full non-persistent match loop validation (automated half).
--
-- The per-system fixtures already prove each owner in isolation. This one proves
-- the composed surface: every terminal cause resolves exactly once with the
-- documented precedence under racing facts, the result is assembled and frozen
-- once per run, every declared cleanup owner really exists and is really torn
-- down, and no P10 owner accepts a client request.
--
-- The 1/2/4-operative Studio matrix (success, squad failure, abandonment,
-- disconnect during extraction, replay) remains an explicitly outstanding manual
-- gate and is not claimed here.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local missionContracts =
	loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local lifeContracts =
	loadSimple("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau", "OperativeLifeContracts")

local M_MISSION_TOKEN = {}
local M_LIFE_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Mission/MatchResultContracts.luau"), {
	debugName = "MatchResultContracts",
	environment = {
		script = {
			Parent = {
				MissionContracts = M_MISSION_TOKEN,
				Parent = { Health = { OperativeLifeContracts = M_LIFE_TOKEN } },
			},
		},
		require = function(token: unknown)
			return if token == M_MISSION_TOKEN then missionContracts else lifeContracts
		end,
	},
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MatchResultConfig.luau"), {
	debugName = "MatchResultConfig",
	environment = {
		script = { Parent = { Parent = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } } },
		require = function()
			return contracts
		end,
	},
	injectGlobals = true,
})()

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/TerminalResultResolver.luau"), {
	debugName = "TerminalResultResolver",
	environment = {
		game = {
			GetService = function()
				return { Shared = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } }
			end,
		},
		require = function()
			return contracts
		end,
	},
	injectGlobals = true,
})()

local lifeStateByOperativeEntityId: { [string]: string } = {}
local LIFE_TOKEN = {}
local ledger = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/MatchResultService.luau"), {
	debugName = "MatchResultService",
	environment = {
		game = {
			GetService = function()
				return { Shared = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } }
			end,
		},
		script = { Parent = { OperativeLifeService = LIFE_TOKEN } },
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			return {
				readByOperativeEntityId = function(operativeEntityId: string)
					local lifeStateId = lifeStateByOperativeEntityId[operativeEntityId]
					return if lifeStateId == nil
						then nil
						else { revision = 1, snapshot = { lifeStateId = lifeStateId } }
				end,
			}
		end,
	},
	injectGlobals = true,
})()

-- ===========================================================================
-- 1. Every terminal cause, and every race between them, resolves exactly once.
-- ===========================================================================

local CauseIds = contracts.MissionResultCauseIds
local OutcomeByCauseId = contracts.OutcomeByCauseId

-- The full fact matrix. Precedence is fixed: a committed wipe outranks
-- abandonment, and both outrank a pending extraction, because a dead or departed
-- squad cannot extract.
local expectedCauseByFacts = {
	{ squadWiped = false, isAbandoned = false, extractionArrived = false, expected = nil },
	{ squadWiped = false, isAbandoned = false, extractionArrived = true, expected = CauseIds.Extracted },
	{ squadWiped = false, isAbandoned = true, extractionArrived = false, expected = CauseIds.Abandoned },
	{ squadWiped = false, isAbandoned = true, extractionArrived = true, expected = CauseIds.Abandoned },
	{ squadWiped = true, isAbandoned = false, extractionArrived = false, expected = CauseIds.SquadWipe },
	{ squadWiped = true, isAbandoned = false, extractionArrived = true, expected = CauseIds.SquadWipe },
	{ squadWiped = true, isAbandoned = true, extractionArrived = false, expected = CauseIds.SquadWipe },
	{ squadWiped = true, isAbandoned = true, extractionArrived = true, expected = CauseIds.SquadWipe },
}

local reachableCauses: { [string]: boolean } = {}
for index, case in expectedCauseByFacts do
	local decision = resolver.resolve({
		resolvedCauseId = nil,
		squadWiped = case.squadWiped,
		isAbandoned = case.isAbandoned,
		extractionArrived = case.extractionArrived,
		serverTimestamp = 100 + index,
	})
	if case.expected == nil then
		assertThat(not decision.shouldCommit, "no terminal fact must not resolve the operation, case " .. index)
		assertThat(decision.rejectionReasonId == "NotTerminal", "an unresolved operation reports NotTerminal")
	else
		assertThat(decision.shouldCommit, "a terminal fact must resolve, case " .. index)
		assertThat(decision.causeId == case.expected, "documented precedence failed at case " .. index)
		assertThat(
			decision.outcomeId == OutcomeByCauseId[case.expected],
			"the outcome must follow the fixed cause pairing, case " .. index
		)
		reachableCauses[decision.causeId] = true
	end

	-- The same racing facts after a commit can never produce a second result.
	local afterCommit = resolver.resolve({
		resolvedCauseId = CauseIds.Extracted,
		squadWiped = case.squadWiped,
		isAbandoned = case.isAbandoned,
		extractionArrived = case.extractionArrived,
		serverTimestamp = 200 + index,
	})
	assertThat(not afterCommit.shouldCommit, "a resolved operation must never resolve again, case " .. index)
	assertThat(afterCommit.rejectionReasonId == "AlreadyResolved", "a resolved operation reports AlreadyResolved")
end

local declaredCauseCount = 0
for _ in CauseIds do
	declaredCauseCount += 1
end
local reachableCauseCount = 0
for _ in reachableCauses do
	reachableCauseCount += 1
end
assertThat(reachableCauseCount == declaredCauseCount, "every declared terminal cause must be reachable")

-- ===========================================================================
-- 2. The result is assembled and frozen exactly once per run, for every cause.
-- ===========================================================================

local function factsFor(causeId: string, operationId: string)
	return {
		operationId = operationId,
		outcomeId = OutcomeByCauseId[causeId],
		causeId = causeId,
		durationSeconds = 300,
		phaseReachedId = "Holdout",
		objectivesCompleted = 2,
		bossDefeated = causeId == CauseIds.Extracted,
		wavesSurvived = 3,
	}
end

for _, causeId in CauseIds do
	ledger.start()
	lifeStateByOperativeEntityId["operative:alpha"] = "Alive"
	ledger.recordKills("operative:alpha", 4)
	ledger.recordDamageDealt("operative:alpha", 200)
	assertThat(ledger.commitResult(factsFor(causeId, "operation.test:run-1")), "each cause must assemble a result")
	local snapshot = ledger.readSafeResultSnapshot()
	assertThat(
		contracts.validateSafeMatchResultSnapshot(snapshot),
		"every cause must produce a valid result snapshot: " .. causeId
	)
	assertThat(snapshot.causeId == causeId, "the frozen result carries its cause")
	assertThat(#snapshot.contributions == 1, "the frozen result carries the contribution record")
	-- A racing second commit, from any cause, cannot replace the first.
	for _, otherCauseId in CauseIds do
		assertThat(
			not ledger.commitResult(factsFor(otherCauseId, "operation.test:run-1")),
			"a second result must never commit"
		)
	end
	assertThat(ledger.readSafeResultSnapshot().causeId == causeId, "the first result stands")
	ledger.stop()
	assertThat(ledger.readSafeResultSnapshot() == nil, "teardown releases the result")
end

-- A replayed run assembles its own distinct result.
ledger.start()
lifeStateByOperativeEntityId["operative:alpha"] = "Alive"
ledger.recordKills("operative:alpha", 1)
assertThat(ledger.commitResult(factsFor(CauseIds.Extracted, "operation.test:run-2")), "the replayed run resolves")
assertThat(
	ledger.readSafeResultSnapshot().operationId == "operation.test:run-2",
	"each run carries its own operation identity"
)
ledger.stop()

-- ===========================================================================
-- 3. Every declared cleanup owner exists, is mapped, and is really torn down.
-- ===========================================================================

local lifecycle = fs.readFile("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau")
local moduleByOwnerId = {
	EnemyDirector = "EnemyDirectorService",
	Objectives = "MissionDirectorService",
	AmmunitionCaches = "AmmunitionCacheService",
	Classes = "ClassService",
	ReviveSessions = "OperativeReviveSessionService",
	OperativeLife = "OperativeLifeService",
	SquadFailure = "SquadFailureService",
	ContributionRecord = "MatchResultService",
	MissionDirector = "MissionDirectorService",
}

for _, ownerId in config.CleanupStopOrder do
	local moduleName = moduleByOwnerId[ownerId]
	assertThat(moduleName ~= nil, "every declared cleanup owner needs a real module: " .. ownerId)
	local path = "games/living-kingdoms/src/server/Systems/" .. moduleName .. ".luau"
	local source = fs.readFile(path)
	assertThat(
		contains(source, ".stop()") or contains(source, "resetObjectiveRuntime"),
		"every cleanup owner must expose a real teardown: " .. moduleName
	)
	assertThat(
		contains(lifecycle, "CleanupOwnerIds." .. ownerId .. "]"),
		"the lifecycle owner must map every declared cleanup owner: " .. ownerId
	)
end
assertThat(#config.CleanupStopOrder == #config.ReplayStartOrder, "the stop and start orders must cover the same owners")

-- Teardown really releases state: every owner that retains operation-scoped
-- records clears them, so a replay cannot inherit a previous run.
for _, check in
	{
		{ module = "OperativeLifeService", token = "table.clear(retainedSnapshotByOperativeEntityId)" },
		{ module = "OperativeCombatRuntimeService", token = "table.clear(retainedCombatByOperativeEntityId)" },
		{ module = "SquadFailureService", token = "table.clear(everAdmittedOperativeIds)" },
		{ module = "MatchResultService", token = "table.clear(recordsByOperativeEntityId)" },
	}
do
	local source = fs.readFile("games/living-kingdoms/src/server/Systems/" .. check.module .. ".luau")
	assertThat(contains(source, check.token), check.module .. " must release its operation-scoped records")
end

-- ===========================================================================
-- 4. No P10 owner accepts a client request. The whole terminal loop is
--    server-driven: resolution, result, and replay.
-- ===========================================================================

for _, moduleName in
	{
		"MissionDirectorService",
		"MatchResultService",
		"TerminalResultResolver",
		"OperationLifecycleService",
	}
do
	local source = fs.readFile("games/living-kingdoms/src/server/Systems/" .. moduleName .. ".luau")
	for _, forbidden in { "OnServerEvent", "OnServerInvoke", "FireServer", "InvokeServer", "RemoteFunction" } do
		assertThat(
			not contains(source, forbidden),
			"no P10 owner may accept a client request: " .. moduleName .. " / " .. forbidden
		)
	end
end

local debrief = fs.readFile("games/living-kingdoms/src/client/Controllers/MatchResultController.luau")
for _, forbidden in { "FireServer", "InvokeServer" } do
	assertThat(not contains(debrief, forbidden), "the debrief must send nothing: " .. forbidden)
end

-- ===========================================================================
-- 5. The outstanding manual gate is recorded honestly.
-- ===========================================================================

local roadmap = fs.readFile("docs/roadmap/P6-P12-EXECUTION-ROADMAP.md")
assertThat(
	contains(roadmap, "1/2/4-operative Studio sessions"),
	"the roadmap must keep naming the Studio matrix P10-0107 still owes"
)

print(
	"P10MatchLoopValidation: cause matrix, precedence, single result per run, cleanup coverage, and server-only loop passed"
)
