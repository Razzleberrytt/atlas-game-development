--!strict

-- P10-0103 the final extraction sequence. Boss defeat opens a bounded arrival
-- window; an admitted, Alive operative inside the clearing at the deadline
-- extracts. Every terminal cause converges on the one pure P10-0102 resolver, and
-- a missed extraction is deliberately not a failure.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local total = 0
	local index = 1
	while true do
		local found = string.find(source, token, index, true)
		if found == nil then
			break
		end
		total += 1
		index = found + 1
	end
	return total
end

local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local resolver = fs.readFile("games/living-kingdoms/src/server/Systems/TerminalResultResolver.luau")
local missionConfig = fs.readFile("games/living-kingdoms/src/shared/Config/MissionConfig.luau")
local missionContracts = fs.readFile("games/living-kingdoms/src/shared/Mission/MissionContracts.luau")

-- One terminal boundary. The mission owner commits a result in exactly one place,
-- and only from the pure resolver's decision.
assertThat(
	count(mission, "local function resolveMission(") == 1,
	"the mission owner must keep exactly one terminal commit"
)
assertThat(
	count(mission, "resolveMission(") == 2,
	"resolveMission must be defined once and called once, from the terminal evaluation"
)
assertThat(
	contains(mission, "local decision = TerminalResultResolver.resolve({"),
	"the terminal commit must come from the pure P10-0102 resolver"
)
assertThat(
	contains(mission, "if not decision.shouldCommit or decision.causeId == nil or decision.outcomeId == nil then"),
	"a non-committing decision must never resolve the operation"
)
assertThat(
	contains(mission, "resolvedCauseId = resultCauseId"),
	"the already-committed cause must be fed back so first-commit-wins holds"
)

-- Squad failure is a fact, not a direct outcome: a wipe and an abandonment must
-- reach the result with their own cause.
assertThat(
	contains(mission, 'if started and state.statusId == "Failed" then\n\t\t\tevaluateTerminalAt(now())'),
	"squad failure must route through the terminal evaluation, not commit an outcome itself"
)
assertThat(
	contains(mission, "squadWiped = hasFailed and not isAbandoned") and contains(mission, "isAbandoned = isAbandoned"),
	"abandonment must be reported separately from a wipe so each carries its own cause"
)
assertThat(
	contains(mission, "participation.isAuthoritativelyAbandoned == true"),
	"abandonment must come from the authoritative squad-failure participation facts"
)

-- Boss defeat is the win condition, read from the existing authoritative
-- disclosure — never declared by a client.
assertThat(
	contains(mission, "return EnemyDirectorService.readBossState()")
		and contains(mission, "bossState.isDefeated == true"),
	"the extraction window must open on the boss's authoritative defeat"
)
assertThat(
	contains(
		mission,
		"holdoutDeadlineServerTimestamp = serverTimestamp + MatchResultConfig.ExtractionArrivalWindowSeconds"
	),
	"the arrival window must come from the shared configured value"
)
assertThat(
	not contains(mission, "MissionConfig.Extraction.ArrivalSeconds"),
	"the bare holdout timer must no longer decide the operation"
)

-- Presence at the deadline is the arrival rule, and it reuses the existing
-- admitted-and-Alive check.
assertThat(
	contains(
		mission,
		"if countAdmittedAliveInsideExtraction() < 1 then\n\t\treturn false\n\tend\n\textractionReadinessStateId = ReadinessIds.Arrived"
	),
	"arrival must require an admitted, Alive operative inside the clearing"
)
assertThat(
	contains(mission, "if deadline == nil or serverTimestamp < deadline then"),
	"extraction cannot arrive before its deadline"
)
assertThat(
	contains(mission, "extractionArrived = extractionReadinessStateId"),
	"only an Arrived extraction may feed the resolver's extraction fact"
)

-- A missed extraction is not a terminal failure: the vocabulary has no cause for
-- it, so the operation stays unresolved until someone is present.
assertThat(count(resolver, "commit(CauseIds.") == 3, "the resolver must commit exactly the three declared causes")
assertThat(
	not contains(mission, "OutcomeIds.Failure, serverTimestamp")
		and not contains(mission, "resolveMission(OutcomeIds.Failure"),
	"no path may invent a terminal failure outside the resolver's causes"
)

-- Readability: the boss fight discloses no countdown, and the inbound window has
-- its own radio line.
assertThat(
	contains(
		mission,
		"holdoutDeadlineServerTimestamp = nil\n\textractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateIds.Locked"
	),
	"the holdout must begin with no countdown and a locked extraction"
)
assertThat(
	contains(mission, "setRadio(RadioLineIds.ExtractionInbound, serverTimestamp)"),
	"the inbound window must be announced"
)
assertThat(
	contains(missionContracts, 'ExtractionInbound = "ExtractionInbound",'),
	"the inbound radio line must join the frozen vocabulary"
)
assertThat(contains(missionConfig, "ExtractionInbound = "), "the inbound radio line requires authored text")
assertThat(
	not contains(missionConfig, "Extraction is two minutes out."),
	"the hold line must no longer promise a timed extraction"
)

-- The readiness state and the result cause are server-owned facts the later P10
-- tasks read, and they reset with the operation.
assertThat(
	contains(mission, "causeId = resultCauseId,")
		and contains(mission, "extractionReadinessStateId = extractionReadinessStateId,"),
	"the authoritative read must expose the cause and the extraction readiness"
)
assertThat(
	count(mission, "extractionReadinessStateId = MatchResultContracts.ExtractionReadinessStateIds.Locked") == 3,
	"readiness must lock on holdout and reset on both start and stop"
)
assertThat(count(mission, "resultCauseId = nil") == 2, "the committed cause must clear on both start and stop")

print("ExtractionSequenceIntegration: boss-gated extraction, one terminal boundary, and no invented failure passed")
