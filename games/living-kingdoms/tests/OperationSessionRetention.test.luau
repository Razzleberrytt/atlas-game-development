--!strict

-- P10-0106 leave, disconnect, rejoin, and shutdown. Everything an operative holds
-- is keyed by their server-owned entity ID and retained only for the running
-- operation, so a reconnect resumes exactly what they left with and duplicates
-- nothing. A never-admitted identity still cannot join mid-operation.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local life = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local squad = fs.readFile("games/living-kingdoms/src/server/Systems/SquadFailureService.luau")
local classes = fs.readFile("games/living-kingdoms/src/server/Systems/ClassService.luau")
local ledger = fs.readFile("games/living-kingdoms/src/server/Systems/MatchResultService.luau")

-- 1. Life state survives a disconnect and resumes on reconnect, so reconnecting
--    cannot undo an incapacitation, death, or retained equipment-adjusted health
--    by handing back a freshly-derived operative snapshot.
assertThat(
	contains(life, "retainedSnapshotByOperativeEntityId[entry.operativeEntityId] = copySnapshot(entry.snapshot)"),
	"a disconnect must retain the authoritative life snapshot"
)
assertThat(
	contains(life, "snapshot = if retained ~= nil") and contains(life, "then copySnapshot(retained)"),
	"a reconnect must resume the retained snapshot rather than derive a fresh one"
)
assertThat(
	contains(life, "else initialSnapshot(operativeEntityId, effectiveMaximumHealth(player))"),
	"only a fresh registration may derive current equipment-adjusted maximum health"
)
assertThat(
	contains(life, "retainedSnapshotByOperativeEntityId[operativeEntityId] = nil"),
	"the retained record must be consumed on restore so it cannot be replayed"
)
assertThat(
	contains(life, "table.clear(retainedSnapshotByOperativeEntityId)"),
	"retention must not survive the operation"
)
assertThat(
	contains(life, "temporaryArmorByPlayer[player] = nil"),
	"a transient combat resource must not survive a disconnect"
)

-- 2. Ammunition is scarce (P6), so a reconnect must not refill it.
assertThat(
	contains(combat, "retainedCombatByOperativeEntityId[removedState.operativeState.entityId] = {"),
	"a disconnect must retain the operative's weapon and ammunition"
)
assertThat(
	contains(combat, "local retained = retainedCombatByOperativeEntityId[operativeEntityId]")
		and contains(combat, "retainedCombatByOperativeEntityId[operativeEntityId] = nil"),
	"a reconnect must consume its retained combat record exactly once"
)
assertThat(
	contains(combat, "loadedRounds = retained.ammunition.loadedRounds")
		and contains(combat, "reserveRounds = retained.ammunition.reserveRounds"),
	"the exact rounds must be resumed, not reissued"
)
assertThat(
	contains(combat, "table.clear(retainedCombatByOperativeEntityId)"),
	"retention must not survive the operation"
)

-- 3. A reconnect resumes admission; a never-admitted identity still cannot join.
assertThat(
	contains(squad, "elseif everAdmittedOperativeIds[operativeEntityId] then"),
	"a reconnect must resume the admission it already held"
)
assertThat(
	contains(squad, "everAdmittedOperativeIds[operativeEntityId] = true"),
	"admission at insertion must be remembered for the operation"
)
assertThat(
	contains(squad, "An identity that was never admitted still cannot join mid-operation."),
	"late joining must remain prohibited"
)
assertThat(
	contains(squad, "table.clear(everAdmittedOperativeIds)"),
	"the admitted-ever set must not survive the operation"
)

-- 4. Abandonment stays authoritative: when every admitted operative has left, the
--    operation resolves through the single terminal boundary.
assertThat(
	contains(squad, "if countIds(admittedOperativeIds) == 0 then")
		and contains(squad, "isAuthoritativelyAbandoned = true"),
	"an empty admitted roster must mark authoritative abandonment"
)
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
assertThat(
	contains(mission, "participation.isAuthoritativelyAbandoned == true"),
	"abandonment must reach the result through the terminal resolver, not a client"
)

-- 5. Nothing an operative holds is keyed by their Player object in a way that
--    would duplicate on reconnect: class state, contribution, and admission are
--    all keyed by the server-owned operative entity ID.
assertThat(
	contains(classes, "local entriesByOperativeId: { [string]: Entry } = {}"),
	"class selection and resources must be keyed by operative entity ID"
)
assertThat(
	not contains(classes, "Players.PlayerRemoving"),
	"a disconnect must not discard class selection or spent resources"
)
assertThat(
	contains(ledger, "recordsByOperativeEntityId[operativeEntityId] = created"),
	"contribution must be keyed by operative entity ID"
)
assertThat(
	not contains(ledger, "PlayerRemoving") and not contains(ledger, "Players"),
	"contribution must not be discarded or duplicated by a disconnect"
)

-- 6. Retention is session-scoped in every owner: a replay issues fresh
--    operatives rather than resuming the previous run.
for _, source in { life, combat } do
	assertThat(
		contains(source, "Retention is operation-scoped")
			or contains(source, "retention must not survive")
			or contains(source, "table.clear(retained"),
		"every retained record must be released with the operation"
	)
end

print("OperationSessionRetention: entity-keyed retention, resumed reconnects, and no duplication passed")
