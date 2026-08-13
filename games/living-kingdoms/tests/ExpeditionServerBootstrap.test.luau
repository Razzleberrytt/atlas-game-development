--!strict

-- VS-0110 composition-root fixture: the bootstrap drives the authoritative
-- runtime, authored outdoor Approach combat, deterministic room plan, room-local
-- encounter placement, and coordinator through one full expedition without
-- exposing a client completion path.
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

local expeditionContracts = loadModule("shared/Expeditions/ExpeditionContracts.luau", "ExpeditionContracts")
local roomAssemblyContracts = loadModule("shared/Expeditions/RoomAssemblyContracts.luau", "RoomAssemblyContracts")
local roomPlacementPlanner = loadModule("shared/Expeditions/RoomPlacementPlanner.luau", "RoomPlacementPlanner")

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

local hordeConfig = {
	Roles = {
		Basic = { Id = "horde.role.infected", DisplayName = "Exclusion Stalker" },
		Runner = { Id = "horde.role.runner", DisplayName = "Rushing Stalker" },
		Crawler = { Id = "horde.role.crawler", DisplayName = "Low Stalker" },
		Screamer = { Id = "horde.role.screamer", DisplayName = "Choir Screamer" },
		Brute = { Id = "horde.role.brute", DisplayName = "Grief Brute" },
	},
}
local enemyContracts = {
	EnemyArchetypeIds = {
		ExclusionWalker = "enemy.exclusion_walker",
		BlightSpitter = "enemy.blight_spitter",
		Progenitor = "boss.progenitor",
	},
}
local specialConfig = { BlightSpitter = { DisplayName = "Blight Spitter" } }
local firstOutdoorEncounterBeatConfig = {
	RuntimeConsumptionActive = true,
	RuntimeConsumptionScopeId = "ApproachCombatSequenceOnly",
	Beats = {
		{
			Id = "logging-road-contact",
			PostClearRecoverySeconds = 8,
			Waves = {
				{
					DelayAfterPreviousSeconds = 0,
					Units = {
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 2,
							HordeRoleId = hordeConfig.Roles.Basic.Id,
						},
					},
				},
			},
		},
		{
			Id = "campground-crossfire",
			PostClearRecoverySeconds = 10,
			Waves = {
				{
					DelayAfterPreviousSeconds = 0,
					Units = {
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Basic.Id,
						},
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Runner.Id,
						},
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Crawler.Id,
						},
					},
				},
			},
		},
		{
			Id = "military-roadblock-gate",
			PostClearRecoverySeconds = 15,
			Waves = {
				{
					DelayAfterPreviousSeconds = 0,
					Units = {
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Basic.Id,
						},
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Runner.Id,
						},
					},
				},
				{
					DelayAfterPreviousSeconds = 5,
					Units = {
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Basic.Id,
						},
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.BlightSpitter,
							Count = 1,
							HordeRoleId = nil,
						},
					},
				},
			},
		},
	},
}
local encounterByRoomId = {}
for _, room in roomAssemblyConfig.Rooms do
	if room.Role ~= roomAssemblyContracts.RoleIds.Entry and room.Role ~= roomAssemblyContracts.RoleIds.Boss then
		encounterByRoomId[room.Id] = {
			Waves = {
				{
					Units = {
						{
							ArchetypeId = enemyContracts.EnemyArchetypeIds.ExclusionWalker,
							Count = 1,
							HordeRoleId = hordeConfig.Roles.Basic.Id,
						},
					},
				},
			},
		}
	end
end
local firstDungeonContentConfig = { Encounters = encounterByRoomId }

local BOOTSTRAP_CONFIG_TOKEN = {}
local BOOTSTRAP_FIRST_CONTENT_TOKEN = {}
local BOOTSTRAP_FIRST_OUTDOOR_BEATS_TOKEN = {}
local BOOTSTRAP_HORDE_TOKEN = {}
local BOOTSTRAP_SPECIAL_TOKEN = {}
local BOOTSTRAP_ENEMY_CONTRACTS_TOKEN = {}
local BOOTSTRAP_CONTRACTS_TOKEN = {}
local BOOTSTRAP_PLANNER_TOKEN = {}
local BOOTSTRAP_ASSEMBLER_TOKEN = {}
local BOOTSTRAP_VARIATION_PLANNER_TOKEN = {}
local BOOTSTRAP_ENCOUNTER_VIEW_TOKEN = {}
local BOOTSTRAP_ENCOUNTER_COMPOSER_TOKEN = {}
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
					Config = {
						ExpeditionConfig = BOOTSTRAP_CONFIG_TOKEN,
						FirstDungeonContentConfig = BOOTSTRAP_FIRST_CONTENT_TOKEN,
						FirstOutdoorEncounterBeatConfig = BOOTSTRAP_FIRST_OUTDOOR_BEATS_TOKEN,
						HordeExperienceConfig = BOOTSTRAP_HORDE_TOKEN,
						SpecialEnemyConfig = BOOTSTRAP_SPECIAL_TOKEN,
					},
					Combat = { EnemyContracts = BOOTSTRAP_ENEMY_CONTRACTS_TOKEN },
					Expeditions = {
						ExpeditionContracts = BOOTSTRAP_CONTRACTS_TOKEN,
						RoomPlacementPlanner = BOOTSTRAP_PLANNER_TOKEN,
						RoomSequenceAssembler = BOOTSTRAP_ASSEMBLER_TOKEN,
						RunVariationPlanner = BOOTSTRAP_VARIATION_PLANNER_TOKEN,
						RunVariationEncounterView = BOOTSTRAP_ENCOUNTER_VIEW_TOKEN,
						RunVariationAuthoredEncounterComposer = BOOTSTRAP_ENCOUNTER_COMPOSER_TOKEN,
					},
				},
			}
		end,
	},
	require = function(token: unknown)
		if token == BOOTSTRAP_CONFIG_TOKEN then
			return expeditionConfig
		end
		if token == BOOTSTRAP_FIRST_CONTENT_TOKEN then
			return firstDungeonContentConfig
		end
		if token == BOOTSTRAP_FIRST_OUTDOOR_BEATS_TOKEN then
			return firstOutdoorEncounterBeatConfig
		end
		if token == BOOTSTRAP_HORDE_TOKEN then
			return hordeConfig
		end
		if token == BOOTSTRAP_SPECIAL_TOKEN then
			return specialConfig
		end
		if token == BOOTSTRAP_ENEMY_CONTRACTS_TOKEN then
			return enemyContracts
		end
		if token == BOOTSTRAP_CONTRACTS_TOKEN then
			return expeditionContracts
		end
		if token == BOOTSTRAP_PLANNER_TOKEN then
			return roomPlacementPlanner
		end
		if token == BOOTSTRAP_ASSEMBLER_TOKEN then
			return roomSequenceAssembler
		end
		if token == BOOTSTRAP_VARIATION_PLANNER_TOKEN then
			return {
				plan = function(_roomPlan: any)
					return {}
				end,
			}
		end
		if token == BOOTSTRAP_ENCOUNTER_VIEW_TOKEN then
			return {
				build = function(roomPlan: any, _variationPlan: any)
					local records = {}
					for _, node in roomPlan.Nodes do
						if firstDungeonContentConfig.Encounters[node.RoomId] ~= nil then
							table.insert(records, { RoomId = node.RoomId })
						end
					end
					return { Records = records }
				end,
			}
		end
		if token == BOOTSTRAP_ENCOUNTER_COMPOSER_TOKEN then
			return {
				compose = function(_seed: number, _record: any, authoredEncounter: any)
					return authoredEncounter
				end,
			}
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
local spawnedWaves = {}
local activeSpawnedWave: any = nil
local bossPosition: any = nil

local director = {
	spawnAuthoredWave = function(waveIndex: number, definitions: { any }): number
		assert(#definitions == 0, "typed bridge must not mint legacy generic walkers")
		activeSpawnedWave = { WaveIndex = waveIndex, Definitions = {} }
		table.insert(spawnedWaves, activeSpawnedWave)
		return 0
	end,
	spawnEnemy = function(request: any): any
		assert(activeSpawnedWave ~= nil, "typed spawn must follow authored pressure setup")
		local definition = {
			id = request.entityId,
			x = request.position.x,
			y = request.position.y,
			z = request.position.z,
			archetypeId = request.archetypeId,
			hordeRoleId = request.hordeRoleId,
		}
		table.insert(activeSpawnedWave.Definitions, definition)
		alive[request.entityId] = true
		return { didSpawn = true, wasDeferred = false, rejectionReasonId = nil }
	end,
	spawnBoss = function(position: any, _floodlightsRestored: boolean): boolean
		bossPosition = position
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
local layout = roomPlacementPlanner.plan(plan)
assert(#layout.Placements == #plan.Nodes, "fixture layout must match the assembled room plan")
assert(service:getSnapshot().PhaseId == "Preparation", "a new expedition starts in Preparation")

local preparation = service:step(100)
assert(preparation.Accepted == true, "preparation should advance without an encounter")
assert(service:getSnapshot().PhaseId == "Approach", "preparation advances into Approach")

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

local function assertApproachPlacement(wave: any)
	for _, definition in wave.Definitions do
		assert(math.abs(definition.x) <= 18, "approach enemy X offsets must stay bounded")
		assert(definition.z >= 0 and definition.z <= 48, "approach enemies must stay in the existing arrival band")
	end
end

local startedApproach, startedApproachReason = step()
assert(startedApproach == true and startedApproachReason == "EncounterStarted", "approach encounter should start")
assert(#spawnedWaves == 1, "approach must start with the logging-road contact")
assert(#spawnedWaves[1].Definitions == 2, "logging-road contact must spawn two basic walkers")
for _, definition in spawnedWaves[1].Definitions do
	assert(definition.archetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker)
	assert(definition.hordeRoleId == hordeConfig.Roles.Basic.Id)
end
assertApproachPlacement(spawnedWaves[1])

local _, loggingPendingReason = step()
assert(loggingPendingReason == "EncounterInProgress", "logging-road enemies must be observed alive before completion")
killTrackedEnemies()
local _, loggingRecoveryReason = step()
assert(loggingRecoveryReason == "EncounterInProgress", "logging-road clear must preserve its recovery window")
local _, campgroundStartReason = step()
assert(
	campgroundStartReason == "EncounterInProgress",
	"campground stage remains under the same Approach encounter token"
)
assert(#spawnedWaves == 2, "campground wave should start after the authored eight-second breather")
assert(#spawnedWaves[2].Definitions == 3, "campground must spawn the authored three-enemy mixed wave")
local campgroundRoles = {}
for _, definition in spawnedWaves[2].Definitions do
	assert(definition.archetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker)
	campgroundRoles[definition.hordeRoleId] = true
end
assert(campgroundRoles[hordeConfig.Roles.Basic.Id] == true)
assert(campgroundRoles[hordeConfig.Roles.Runner.Id] == true)
assert(campgroundRoles[hordeConfig.Roles.Crawler.Id] == true)
assertApproachPlacement(spawnedWaves[2])

local _, campgroundPendingReason = step()
assert(campgroundPendingReason == "EncounterInProgress")
killTrackedEnemies()
local _, campgroundRecoveryReason = step()
assert(campgroundRecoveryReason == "EncounterInProgress", "campground clear must preserve its recovery window")
local _, roadblockStartReason = step()
assert(roadblockStartReason == "EncounterInProgress")
assert(#spawnedWaves == 3, "roadblock opening stage should start after the authored ten-second breather")
assert(#spawnedWaves[3].Definitions == 2, "roadblock opening must remain a two-walker pressure stage")
local roadblockOpeningRoles = {}
for _, definition in spawnedWaves[3].Definitions do
	assert(definition.archetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker)
	roadblockOpeningRoles[definition.hordeRoleId] = true
end
assert(roadblockOpeningRoles[hordeConfig.Roles.Basic.Id] == true)
assert(roadblockOpeningRoles[hordeConfig.Roles.Runner.Id] == true)
assertApproachPlacement(spawnedWaves[3])

local _, roadblockPendingReason = step()
assert(roadblockPendingReason == "EncounterInProgress")
killTrackedEnemies()
local _, roadblockFollowupRecoveryReason = step()
assert(roadblockFollowupRecoveryReason == "EncounterInProgress", "roadblock follow-up must wait its authored delay")
local _, roadblockFollowupStartReason = step()
assert(roadblockFollowupStartReason == "EncounterInProgress")
assert(#spawnedWaves == 4, "roadblock follow-up should start after its authored five-second delay")
assert(#spawnedWaves[4].Definitions == 2, "roadblock follow-up must remain a two-enemy wave")
local roadblockHasBasic = false
local roadblockHasSpitter = false
for _, definition in spawnedWaves[4].Definitions do
	if definition.archetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker then
		roadblockHasBasic = definition.hordeRoleId == hordeConfig.Roles.Basic.Id
	elseif definition.archetypeId == enemyContracts.EnemyArchetypeIds.BlightSpitter then
		roadblockHasSpitter = definition.hordeRoleId == nil
	end
end
assert(roadblockHasBasic and roadblockHasSpitter, "roadblock follow-up must introduce the canonical ranged special")
assertApproachPlacement(spawnedWaves[4])

local _, roadblockFollowupPendingReason = step()
assert(roadblockFollowupPendingReason == "EncounterInProgress")
killTrackedEnemies()
local _, finalRecoveryStartReason = step()
assert(finalRecoveryStartReason == "EncounterInProgress", "roadblock clear must begin the pre-dungeon reset")
local _, finalRecoveryPendingReason = step()
assert(finalRecoveryPendingReason == "EncounterInProgress", "pre-dungeon reset must last through the authored window")
local approachDone, approachReason = step()
assert(approachDone == true, "approach completes after all four authored stages and final recovery")
assert(approachReason == "EncounterCompletedAndPhaseAdvanced", "approach completion advances the phase")
assert(service:getSnapshot().PhaseId == "Dungeon", "approach advances into Dungeon")

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

for waveOrdinal = 5, #spawnedWaves do
	local spawned = spawnedWaves[waveOrdinal]
	local placement = if spawned.WaveIndex == 90
		then layout.Placements[#layout.Placements - 1]
		else layout.Placements[spawned.WaveIndex]
	assert(placement ~= nil, "every dungeon/elite wave must map to a room placement")
	for _, definition in spawned.Definitions do
		assert(definition.archetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker)
		assert(definition.hordeRoleId == hordeConfig.Roles.Basic.Id)
		assert(math.abs(definition.x - placement.Center.x) <= 18, "enemy X must stay inside its room footprint")
		assert(math.abs(definition.z - placement.Center.z) <= 24, "enemy Z must stay inside its room footprint")
	end
end
local bossPlacement = layout.Placements[#layout.Placements]
assert(bossPosition ~= nil, "boss spawn position must be captured")
assert(bossPosition.x == bossPlacement.Center.x, "boss X must use the boss-room center")
assert(bossPosition.z == bossPlacement.Center.z, "boss Z must use the boss-room center")

local rewardsAdvanced, rewardsReason = step()
assert(rewardsAdvanced == true and rewardsReason == "PhaseAdvanced", "rewards advances without an encounter")
assert(service:getSnapshot().PhaseId == "Results", "rewards advances into Results")
local finalized, finalizedReason = step()
assert(finalized == true and finalizedReason == "RunFinished", "the results phase finalizes the run")
assert(service:getSnapshot().OutcomeId == "Completed", "a full expedition completes")
local replayed, replayedReason = step()
assert(replayed == false and replayedReason == "RunTerminal", "a finished run rejects further steps")
service:destroy()
assert(service:getSnapshot() == nil, "a destroyed bootstrap discloses no snapshot")
assert(service:step(600).ReasonId == "BootstrapDestroyed", "a destroyed bootstrap rejects further steps")

print("ExpeditionServerBootstrap: authored Approach sequence and room-local full run passed")
