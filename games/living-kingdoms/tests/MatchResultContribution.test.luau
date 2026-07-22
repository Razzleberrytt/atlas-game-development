--!strict

-- P10-0104 contribution ledger and result assembly. Authoritative owners record
-- already-committed facts; the ledger counts them, stays bounded, and freezes one
-- validated result snapshot at the single terminal boundary. It represents no XP,
-- rank, or unlock.

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
local matchResultContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Mission/MatchResultContracts.luau"), {
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

-- The life owner is stubbed to a controllable roster: survival state is read from
-- it at resolution, never recorded by a caller.
local lifeStateByOperativeEntityId: { [string]: string } = {}
local CONTRACTS_TOKEN = {}
local LIFE_TOKEN = {}
local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/MatchResultService.luau"), {
	debugName = "MatchResultService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "the ledger may only require replicated modules")
				return { Shared = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } }
			end,
		},
		script = { Parent = { OperativeLifeService = LIFE_TOKEN } },
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return matchResultContracts
			elseif token == LIFE_TOKEN then
				return {
					readByOperativeEntityId = function(operativeEntityId: string)
						local lifeStateId = lifeStateByOperativeEntityId[operativeEntityId]
						if lifeStateId == nil then
							return nil
						end
						return { revision = 1, snapshot = { lifeStateId = lifeStateId } }
					end,
				}
			end
			error("unexpected MatchResultService dependency")
		end,
	},
	injectGlobals = true,
})()

local function facts(overrides: { [string]: any }?)
	local value: { [string]: any } = {
		operationId = "operation.blackwater-relay",
		outcomeId = "Success",
		causeId = "Extracted",
		durationSeconds = 640,
		phaseReachedId = "Holdout",
		objectivesCompleted = 2,
		bossDefeated = true,
		wavesSurvived = 3,
	}
	for key, override in overrides or {} do
		value[key] = override
	end
	return value
end

-- A stopped ledger records nothing and holds no result.
service.recordKills("operative:alpha", 3)
assertThat(#service.readContributions() == 0, "a stopped ledger must record nothing")
assertThat(not service.commitResult(facts()), "a stopped ledger must not commit a result")

service.start()
lifeStateByOperativeEntityId["operative:alpha"] = "Alive"
lifeStateByOperativeEntityId["operative:bravo"] = "Incapacitated"

-- Every recorded fact accumulates against the operative who earned it.
service.recordKills("operative:alpha", 3)
service.recordKills("operative:alpha", 2)
service.recordDamageDealt("operative:alpha", 120)
service.recordBossExposureHit("operative:alpha")
service.recordBossExposureHit("operative:alpha")
service.recordRevivePerformed("operative:alpha")
service.recordObjectiveContribution("operative:alpha")
service.recordClassActionCommitted("operative:alpha")
service.recordDamageDealt("operative:bravo", 40)

local live = service.readContributions()
assertThat(#live == 2, "each contributing operative appears exactly once")
assertThat(live[1].operativeEntityId == "operative:alpha", "records keep first-contribution order")
assertThat(live[1].kills == 5 and live[1].damageDealt == 120, "counts accumulate")
assertThat(live[1].bossExposureHits == 2 and live[1].revivesPerformed == 1, "one-shot facts count once each")
assertThat(live[1].objectivesContributed == 1 and live[1].classActionsCommitted == 1, "objective and class credit")
assertThat(live[2].kills == 0, "an operative who only dealt damage has no kills")

-- Malformed or non-positive amounts are dropped rather than corrupting a record.
for _, invalid in { 0, -5, 1.5, 0 / 0, math.huge } do
	service.recordKills("operative:alpha", invalid)
end
service.recordKills("", 1)
service.recordKills(nil :: any, 1)
assertThat(service.readContributions()[1].kills == 5, "invalid amounts and identities must not record")
assertThat(#service.readContributions() == 2, "an invalid identity must not create a record")

-- The tracked population is bounded, and it is not a fixed-four assumption.
for index = 1, 12 do
	service.recordKills("operative:filler" .. tostring(index), 1)
end
local bounded = service.readContributions()
assertThat(#bounded == 8, "the tracked population must stay bounded")
assertThat(bounded[1].operativeEntityId == "operative:alpha", "existing records survive the ceiling")
assertThat(#bounded > 4, "the ceiling must not bake in a four-operative squad")

-- Survival state is read from the life owner at resolution; an operative who has
-- left the roster did not walk out.
assertThat(service.commitResult(facts()), "a valid result must commit")
local snapshot = service.readSafeResultSnapshot()
assertThat(snapshot ~= nil, "the result snapshot must be readable after commit")
assertThat(
	matchResultContracts.validateSafeMatchResultSnapshot(snapshot),
	"the frozen result must satisfy the P10-0101 validator"
)
assertThat(snapshot.causeId == "Extracted" and snapshot.outcomeId == "Success", "the committed cause is carried")
assertThat(snapshot.contributions[1].survivalStateId == "Alive", "survival state comes from the life owner")
assertThat(snapshot.contributions[2].survivalStateId == "Incapacitated", "each operative keeps its own state")
assertThat(snapshot.contributions[3].survivalStateId == "Dead", "an operative off the roster is not a survivor")

-- First commit wins, and a resolved operation records nothing further.
assertThat(not service.commitResult(facts({ causeId = "SquadWipe", outcomeId = "Failure" })), "a second commit fails")
assertThat(service.readSafeResultSnapshot().causeId == "Extracted", "the first result stands")
service.recordKills("operative:alpha", 10)
assertThat(service.readSafeResultSnapshot().contributions[1].kills == 5, "a frozen result cannot change")

-- An invalid result is refused rather than published.
service.stop()
service.start()
service.recordKills("operative:alpha", 1)
assertThat(
	not service.commitResult(facts({ causeId = "Extracted", outcomeId = "Failure" })),
	"a snapshot whose outcome contradicts its cause must be refused"
)
assertThat(service.readSafeResultSnapshot() == nil, "a refused result must not be published")

-- Teardown releases every record.
service.stop()
assertThat(#service.readContributions() == 0, "teardown must release the ledger")
assertThat(service.readSafeResultSnapshot() == nil, "teardown must release the result")

-- Source audits: the ledger is inert authority, and every fact is recorded by the
-- owner that already observes the committed event.
local ledger = fs.readFile("games/living-kingdoms/src/server/Systems/MatchResultService.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local revive = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")
local classes = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assertThat(
	not contains(ledger, "RemoteEvent") and not contains(ledger, "FireClient") and not contains(ledger, "FireServer"),
	"the ledger must add no network surface"
)
assertThat(
	not contains(ledger, "Connect(") and not contains(ledger, "task.delay") and not contains(ledger, "Heartbeat"),
	"the ledger must own no connection or timer"
)
assertThat(
	not contains(ledger, "applyAuthoritativeDamage") and not contains(ledger, "applyAuthoritativeHealing"),
	"the ledger must hold no gameplay authority"
)
-- The snapshot carries exactly the P10-0101 fields and nothing else, so no XP,
-- rank, unlock, or reward can ride along. P11 owns those and reads these facts.
service.start()
service.recordKills("operative:alpha", 1)
service.commitResult(facts())
local frozen = service.readSafeResultSnapshot()
local expectedResultFields = {
	operationId = true,
	outcomeId = true,
	causeId = true,
	durationSeconds = true,
	phaseReachedId = true,
	objectivesCompleted = true,
	bossDefeated = true,
	wavesSurvived = true,
	contributions = true,
}
local expectedContributionFields = {
	operativeEntityId = true,
	kills = true,
	damageDealt = true,
	revivesPerformed = true,
	objectivesContributed = true,
	classActionsCommitted = true,
	bossExposureHits = true,
	survivalStateId = true,
}
for key in frozen :: { [string]: unknown } do
	assertThat(expectedResultFields[key] == true, "the result snapshot carries an undeclared field: " .. key)
end
for key in frozen.contributions[1] :: { [string]: unknown } do
	assertThat(expectedContributionFields[key] == true, "the contribution carries an undeclared field: " .. key)
end
service.stop()
assertThat(
	contains(combat, "MatchResultService.recordDamageDealt(operativeEntityId, damageAmount)")
		and contains(combat, "MatchResultService.recordKills(playerState.operativeState.entityId, killCount)"),
	"the combat owner records committed damage and kills"
)
assertThat(
	contains(combat, "EnemyDirectorService.isBossEntity(targetEntityId)")
		and contains(combat, "MatchResultService.recordBossExposureHit(operativeEntityId)"),
	"boss exposure credit follows a committed hit on the live boss"
)
assertThat(
	contains(revive, "MatchResultService.recordRevivePerformed(session.sessionState.reviverOperativeEntityId)"),
	"the revive owner credits the operative who performed the revive"
)
assertThat(
	contains(classes, "MatchResultService.recordClassActionCommitted(entry.operativeEntityId)"),
	"the class owner records a committed action"
)
assertThat(
	contains(mission, "MatchResultService.recordObjectiveContribution(worker.operativeEntityId)"),
	"the mission owner credits the operatives it sampled working the objective"
)
assertThat(
	contains(mission, "MatchResultService.commitResult({"),
	"the result must be frozen at the single terminal boundary"
)
assertThat(
	contains(mission, "local phaseReachedId = phaseId"),
	"the reported phase must be the one the squad reached, not Resolved"
)
assertThat(contains(bootstrap, "MatchResultService.start()"), "the ledger must be bootstrapped")

print("MatchResultContribution: bounded inert contribution ledger, owner-recorded facts, and one frozen result passed")
