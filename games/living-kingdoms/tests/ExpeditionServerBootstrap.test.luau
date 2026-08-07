--!strict

-- VS-0110 composition-root fixture: the bootstrap drives the authoritative
-- runtime, deterministic room plan, and encounter coordinator through one full
-- expedition without exposing a client path.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "VS-0110 expedition bootstrap assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string, environment: { [string]: any }?): any
	return luau.load(fs.readFile("games/living-kingdoms/src/" .. path), {
		debugName = debugName,
		environment = environment,
		injectGlobals = true,
	})()
end

-- Shared declarations first; each layer is injected into the next by token so a
-- module can only ever see the dependencies the Rojo tree actually gives it.
local expeditionContracts = loadModule("shared/Expeditions/ExpeditionContracts.luau", "ExpeditionContracts")
local roomAssemblyContracts = loadModule("shared/Expeditions/RoomAssemblyContracts.luau", "RoomAssemblyContracts")

local EXPEDITION_CONTRACTS_TOKEN = {}
local expeditionConfig = loadModule("shared/Config/ExpeditionConfig.luau", "ExpeditionConfig", {
	script = { Parent = { Parent = { Expeditions = { ExpeditionContracts = EXPEDITION_CONTRACTS_TOKEN } } } },
	require = function(token: unknown)
		assert(token == EXPEDITION_CONTRACTS_TOKEN, "unexpected ExpeditionConfig dependency")
		return expeditionContracts
	end,
})

local ROOM_CONTRACTS_TOKEN = {}
local roomAssemblyConfig = loadModule("shared/Config/RoomAssemblyConfig.luau", "RoomAssemblyConfig", {
	script = { Parent = { Parent = { Expeditions = { RoomAssemblyContracts = ROOM_CONTRACTS_TOKEN } } } },
	require = function(token: unknown)
		assert(token == ROOM_CONTRACTS_TOKEN, "unexpected RoomAssemblyConfig dependency")
		return roomAssemblyContracts
	end,
})

local ASSEMBLER_CONTRACTS_TOKEN = {}
local ASSEMBLER_CONFIG_TOKEN = {}
local roomSequenceAssembler = loadModule("shared/Expeditions/RoomSequenceAssembler.luau", "RoomSequenceAssembler", {
	script = {
		Parent = {
			RoomAssemblyContracts = ASSEMBLER_CONTRACTS_TOKEN,
			Parent = { Config = { RoomAssemblyConfig = ASSEMBLER_CONFIG_TOKEN } },
		},
	},
	require = function(token: unknown)
		if token == ASSEMBLER_CONTRACTS_TOKEN then
			return roomAssemblyContracts
		end
		if token == ASSEMBLER_CONFIG_TOKEN then
			return roomAssemblyConfig
		end
		error("unexpected RoomSequenceAssembler dependency")
	end,
})

local RUNTIME_CONTRACTS_TOKEN = {}
local RUNTIME_CONFIG_TOKEN = {}
local expeditionRuntime = loadModule("server/Systems/ExpeditionRuntime.luau", "ExpeditionRuntime", {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected service request")
			return {
				Shared = {
					Expeditions = { ExpeditionContracts = RUNTIME_CONTRACTS_TOKEN },
					Config = { ExpeditionConfig = RUNTIME_CONFIG_TOKEN },
				},
			}
		end,
	},
	require = function(token: unknown)
		if token == RUNTIME_CONTRACTS_TOKEN then
			return expeditionContracts
		end
		if token == RUNTIME_CONFIG_TOKEN then
			return expeditionConfig
		end
		error("unexpected ExpeditionRuntime dependency")
	end,
})

local encounterCoordinator =
	loadModule("server/Systems/ExpeditionEncounterCoordinator.luau", "ExpeditionEncounterCoordinator")
local directorAdapter = loadModule("server/Systems/EnemyDirectorEncounterAdapter.luau", "EnemyDirectorEncounterAdapter")

local BOOTSTRAP_CONFIG_TOKEN = {}
local BOOTSTRAP_CONTRACTS_TOKEN = {}
local BOOTSTRAP_ASSEMBLER_TOKEN = {}
local BOOTSTRAP_RUNTIME_TOKEN = {}
local BOOTSTRAP_COORDINATOR_TOKEN = {}
local BOOTSTRAP_ADAPTER_TOKEN = {}

local Bootstrap = loadModule("server/Systems/ExpeditionServerBootstrap.luau", "ExpeditionServerBootstrap", {
	script = {
		Parent = {
			ExpeditionRuntime = BOOTSTRAP_RUNTIME_TOKEN,
			ExpeditionEncounterCoordinator = BOOTSTRAP_COORDINATOR_TOKEN,
			EnemyDirectorEncounterAdapter = BOOTSTRAP_ADAPTER_TOKEN,
		},
	},
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected service request")
			return {
				Shared = {
					Config = { ExpeditionConfig = BOOTSTRAP_CONFIG_TOKEN },
					Expeditions = {
						ExpeditionContracts = BOOTSTRAP_CONTRACTS_TOKEN,
						RoomSequenceAssembler = BOOTSTRAP_ASSEMBLER_TOKEN,
					},
				},
			}
		end,
	},
	require = function(token: unknown)
		if token == BOOTSTRAP_CONFIG_TOKEN then
			return expeditionConfig
		end
		if token == BOOTSTRAP_CONTRACTS_TOKEN then
			return expeditionContracts
		end
		if token == BOOTSTRAP_ASSEMBLER_TOKEN then
			return roomSequenceAssembler
		end
		if token == BOOTSTRAP_RUNTIME_TOKEN then
			return expeditionRuntime
		end
		if token == BOOTSTRAP_COORDINATOR_TOKEN then
			return encounterCoordinator
		end
		if token == BOOTSTRAP_ADAPTER_TOKEN then
			return directorAdapter
		end
		error("unexpected ExpeditionServerBootstrap dependency")
	end,
})

local alive: { [string]: boolean } = {}
local bossState = { exists = false, isAlive = false, isDefeated = false }

local director = {
	spawnAuthoredWave = function(_waveIndex: number, definitions: { any }): number
		for _, definition in definitions do
			alive[definition.id] = true
		end
		return #definitions
	end,
	spawnBoss = function(_position: any, _floodlightsRestored: boolean): boolean
		bossState = { exists = true, isAlive = true, isDefeated = false }
		return true
	end,
	readEnemyCombatFacts = function(): { any }
		local facts = {}
		for entityId, isAlive in alive do
			if isAlive then
				table.insert(facts, { entityId = entityId, isAlive = true })
			end
		end
		return facts
	end,
	readBossState = function(): any
		return bossState
	end,
	endOperationPressure = function() end,
}

local service = Bootstrap.new(director, {
	RunId = "run-bootstrap-001",
	Seed = 321,
	PartySize = 1,
	StartedAtUnix = 100,
})

local plan = service:getRoomPlan()
assert(plan ~= nil and plan.Seed == 321 and #plan.Nodes >= 6, "bootstrap must expose the deterministic room plan")
assert(service:getSnapshot().PhaseId == "Preparation", "a new expedition starts in Preparation")

-- Preparation has no encounter and advances immediately.
local preparation = service:step(100)
assert(preparation.Accepted == true, "preparation should advance without an encounter")
assert(service:getSnapshot().PhaseId == "Approach", "preparation advances into Approach")

-- Approach starts, remains active, then completes after its exact authored IDs die.
-- A combat encounter must be observed alive at least once before it can be
-- reported complete, so reaching the next phase always takes three steps:
-- start, an in-progress poll, then the completing poll.
local clock = 110
local function step(): (boolean, string)
	local outcome = service:step(clock)
	clock += 10
	return outcome.Accepted, outcome.ReasonId
end

local function killTrackedEnemies()
	for entityId in alive do
		alive[entityId] = false
	end
end

local startedApproach, startedApproachReason = step()
assert(startedApproach == true and startedApproachReason == "EncounterStarted", "approach encounter should start")
local _, pendingApproachReason = step()
assert(pendingApproachReason == "EncounterInProgress", "a live encounter blocks phase advance")
killTrackedEnemies()
local approachDone, approachReason = step()
assert(approachDone == true, "approach completes once its authored enemies are dead")
assert(approachReason == "EncounterCompletedAndPhaseAdvanced", "approach completion advances the phase")
assert(service:getSnapshot().PhaseId == "Dungeon", "approach advances into Dungeon")

-- Walk every deterministic dungeon node. Traversal rooms resolve on the next
-- poll; combat rooms resolve only after their exact authored IDs are dead.
local guard = 0
while service:getSnapshot().PhaseId == "Dungeon" do
	guard += 1
	assert(guard < 60, "dungeon traversal must terminate")
	local _, reasonId = step()
	if reasonId == "EncounterInProgress" then
		killTrackedEnemies()
	end
end
assert(service:getSnapshot().PhaseId == "Elite", "the dungeon advances into Elite")

local eliteStarted, eliteStartedReason = step()
assert(eliteStarted == true and eliteStartedReason == "EncounterStarted", "elite encounter should start")
local _, elitePendingReason = step()
assert(elitePendingReason == "EncounterInProgress", "the elite blocks advance while alive")
killTrackedEnemies()
local eliteDone = step()
assert(eliteDone == true, "elite completes once its authored enemy is dead")
assert(service:getSnapshot().PhaseId == "Boss", "elite advances into Boss")

local bossStarted, bossStartedReason = step()
assert(bossStarted == true and bossStartedReason == "EncounterStarted", "boss encounter should start")
local _, bossPendingReason = step()
assert(bossPendingReason == "EncounterInProgress", "the boss blocks advance while alive")
bossState = { exists = true, isAlive = false, isDefeated = true }
local bossDone = step()
assert(bossDone == true, "boss completes once defeated")
assert(service:getSnapshot().PhaseId == "Rewards", "boss advances into Rewards")

-- Rewards carries no encounter, so it advances straight into the terminal
-- Results phase, which then finalizes the run exactly once.
local rewardsAdvanced, rewardsReason = step()
assert(rewardsAdvanced == true and rewardsReason == "PhaseAdvanced", "rewards advances without an encounter")
assert(service:getSnapshot().PhaseId == "Results", "rewards advances into Results")

local finalized, finalizedReason = step()
assert(finalized == true and finalizedReason == "RunFinished", "the results phase finalizes the run")
assert(service:getSnapshot().OutcomeId == "Completed", "a full expedition completes")

-- Finalization is one-shot; further steps cannot produce a second result.
local replayed, replayedReason = step()
assert(replayed == false and replayedReason == "RunTerminal", "a finished run rejects further steps")
assert(service:getSnapshot().OutcomeId == "Completed", "the terminal outcome is stable")

service:destroy()
assert(service:getSnapshot() == nil, "a destroyed bootstrap discloses no snapshot")
assert(service:step(600).ReasonId == "BootstrapDestroyed", "a destroyed bootstrap rejects further steps")

print("ExpeditionServerBootstrap fixture passed")
