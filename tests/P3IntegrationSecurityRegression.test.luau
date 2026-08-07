--!strict

-- LK-0308 composition and source-boundary regression audit. Production squad
-- evaluation receives representative death/revive/recovery snapshots while
-- P1/P2 and client-authority surfaces remain isolated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local config = {
	MaximumHealth = 100,
	SoloRecoveryDurationSeconds = 8,
	SoloRecoveriesPerOperation = 1,
	SquadFailureGraceSeconds = 3,
}
local contracts = {
	OperativeLifeStateIds = table.freeze({ Alive = "Alive", Incapacitated = "Incapacitated", Dead = "Dead" }),
	SquadFailureStatusIds = table.freeze({ Viable = "Viable", Pending = "Pending", Failed = "Failed" }),
	SquadFailureRejectionReasonIds = table.freeze({
		InvalidFacts = "InvalidFacts",
		InvalidState = "InvalidState",
		InvalidServerTimestamp = "InvalidServerTimestamp",
		StaleEvaluation = "StaleEvaluation",
	}),
}
local replicatedStorage = {
	Shared = { Config = { OperativeLifeConfig = CONFIG_TOKEN }, Health = { OperativeLifeContracts = CONTRACTS_TOKEN } },
}
local loader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/SquadFailureEvaluator.luau"), {
	debugName = "SquadFailureEvaluator",
	environment = {
		game = {
			GetService = function()
				return replicatedStorage
			end,
		},
		require = function(token)
			return if token == CONFIG_TOKEN then config else contracts
		end,
	},
	injectGlobals = true,
})
local evaluator = loader()

local function snapshot(id: string, state: string, recoveryDeadline: number?, recoveriesUsed: number?)
	return {
		operativeEntityId = id,
		lifeStateId = state,
		healthState = { currentHealth = if state == "Alive" then 30 else 0, maximumHealth = 100 },
		incapacitationState = if state == "Incapacitated"
			then { startedAtServerTimestamp = 10, bleedOutDeadlineServerTimestamp = 40 }
			else nil,
		soloRecoveryState = {
			isEligible = recoveryDeadline ~= nil,
			recoveriesUsed = recoveriesUsed or 0,
			recoveryStartedAtServerTimestamp = if recoveryDeadline == nil then nil else recoveryDeadline - 8,
			recoveryCompletionServerTimestamp = recoveryDeadline,
		},
		processedDamageEventIds = {},
	}
end
local viable = {
	statusId = "Viable",
	pendingStartedAtServerTimestamp = nil,
	pendingDeadlineServerTimestamp = nil,
	failedAtServerTimestamp = nil,
}
local function facts(snapshots, solo: boolean)
	return {
		operativeSnapshots = snapshots,
		operationStartedSolo = solo,
		hasEverHadMultipleParticipants = not solo,
		lateJoiningProhibited = true,
		isAuthoritativelyAbandoned = false,
	}
end

local alive = snapshot("operative.1", "Alive", nil)
local revived = snapshot("operative.2", "Alive", nil)
local down = snapshot("operative.2", "Incapacitated", nil)
local dead = snapshot("operative.1", "Dead", nil)
assert(
	evaluator.resolve(viable, facts({ down, alive }, false), 11).stateAfter.statusId == "Viable",
	"alive teammate did not preserve viability"
)
assert(
	evaluator.resolve(viable, facts({ alive, down }, false), 11).stateAfter.statusId == "Viable",
	"snapshot input order changed viability"
)
local pending = evaluator.resolve(viable, facts({ dead, down }, false), 12).stateAfter
assert(
	pending.statusId == "Pending" and pending.pendingDeadlineServerTimestamp == 15,
	"death did not start exact failure grace"
)
assert(
	evaluator.resolve(pending, facts({ dead, revived }, false), 14).stateAfter.statusId == "Viable",
	"revive did not cancel pending failure"
)
local fresh = evaluator.resolve(viable, facts({ dead, down }, false), 20).stateAfter
assert(fresh.pendingDeadlineServerTimestamp == 23, "fresh viability loss reused old grace")
assert(
	evaluator.resolve(fresh, facts({ dead, down }, false), 22.999).stateAfter.statusId == "Pending",
	"failure committed early"
)
local failed = evaluator.resolve(fresh, facts({ dead, down }, false), 23).stateAfter
assert(failed.statusId == "Failed", "exact failure deadline did not commit")
assert(
	evaluator.resolve(failed, facts({ alive, revived }, false), 24).stateAfter.statusId == "Failed",
	"late Alive state reversed terminal failure"
)

local soloPending = snapshot("operative.solo", "Incapacitated", 18, 0)
assert(
	evaluator.resolve(viable, facts({ soloPending }, true), 12).stateAfter.statusId == "Viable",
	"pending solo recovery was not viable"
)
local recovered = snapshot("operative.solo", "Alive", nil, 1)
assert(
	evaluator.resolve(viable, facts({ recovered }, true), 18).stateAfter.statusId == "Viable",
	"completed recovery was not viable"
)
local secondDown = snapshot("operative.solo", "Incapacitated", nil, 1)
assert(
	evaluator.resolve(viable, facts({ secondDown }, true), 20).stateAfter.statusId == "Pending",
	"consumed second recovery invented viability"
)

local project = fs.readFile("games/living-kingdoms/default.project.json")
local lifeService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local reviveService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")
local lifeClient = fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeLifeController.luau")
local camera = fs.readFile("games/living-kingdoms/src/client/Controllers/CameraController.luau")
local movement = fs.readFile("games/living-kingdoms/src/server/Systems/MovementValidationSystem.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticCombatDevelopmentHarness.luau")
assert(not string.find(project, "RemoteFunction", 1, true), "authority-changing RemoteFunction was added")
assert(not string.find(project, "DamageIntent", 1, true), "client damage surface was added")
assert(string.find(reviveService, "getOrCreateReviveIntentRemote", 1, true), "single revive intent surface missing")
assert(
	not string.find(lifeClient, "healthState", 1, true) and not string.find(lifeClient, "lifeStateId", 1, true),
	"client submits authoritative life state"
)
assert(
	string.find(lifeService, "player.Character == character", 1, true),
	"replacement-character authority gate missing"
)
assert(
	string.find(lifeService, "entry.snapshot.lifeStateId", 1, true),
	"replacement does not reuse authoritative snapshot"
)
assert(
	string.find(reviveService, "session.reviverPlayer.Character == session.reviverCharacter", 1, true),
	"reviver replacement does not cancel"
)
assert(
	string.find(reviveService, "session.targetPlayer.Character == session.targetCharacter", 1, true),
	"target replacement does not cancel"
)
assert(string.find(camera, "localPlayer.Character", 1, true), "camera is not bound to local operative")
assert(not string.find(camera, "GetPlayers", 1, true), "camera gained teammate cycling/spectating")
assert(string.find(movement, "isCharacterMovementAllowed", 1, true), "P1 movement gate regressed")
assert(string.find(combat, "isCombatAllowed", 1, true), "P2 combat gate regressed")
assert(string.find(combat, "processedShotIds", 1, true), "P2 processed ShotIds owner missing")
assert(string.find(combat, "SERVER_REQUEST_COOLDOWN_SECONDS", 1, true), "P2 reload rate limit missing")

print("P3IntegrationSecurityRegression: failure composition, terminality, character/camera, remotes, P1, and P2 passed")
