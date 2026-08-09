--!strict

local Adapter = require("../src/server/Systems/EnemyDirectorEncounterAdapter")

local liveFacts = {}
local bossState = { exists = false, isAlive = false, isDefeated = false }
local stoodDown = 0
local pressureWaveIndexes = {}
local spawnRequests = {}

local director = {
	spawnAuthoredWave = function(waveIndex: number, definitions: { any }): number
		table.insert(pressureWaveIndexes, waveIndex)
		assert(#definitions == 0, "typed adapter must not ask the legacy helper to mint generic walkers")
		return 0
	end,
	spawnEnemy = function(request: any): any
		table.insert(spawnRequests, request)
		table.insert(liveFacts, { entityId = request.entityId, isAlive = true })
		return { didSpawn = true, wasDeferred = false, rejectionReasonId = nil }
	end,
	spawnBoss = function(_position: any, _floodlightsRestored: boolean): boolean
		bossState = { exists = true, isAlive = true, isDefeated = false }
		return true
	end,
	readEnemyCombatFacts = function(): { any }
		return liveFacts
	end,
	readBossState = function(): any
		return bossState
	end,
	endOperationPressure = function()
		stoodDown += 1
	end,
}

local function context(token: string, phaseId: string): any
	return {
		Token = token,
		RunId = "run-adapter-001",
		PhaseId = phaseId,
		RoomIndex = if phaseId == "Dungeon" then 2 else nil,
		RoomId = if phaseId == "Dungeon" then "warden-barracks" else nil,
		RoomRoleId = if phaseId == "Dungeon" then "Combat" else nil,
		Seed = 42,
	}
end

local adapter = Adapter.new(director, function(encounterContext: any): any
	if encounterContext.PhaseId == "Boss" then
		return { Kind = "Boss", BossPosition = { x = 0, y = 4, z = 80 }, FloodlightsRestored = true }
	end
	return {
		Kind = "Wave",
		WaveIndex = encounterContext.RoomIndex or 1,
		Wave = {
			{
				id = encounterContext.Token .. ":1",
				name = "Rushing Stalker",
				x = 0,
				y = 4,
				z = 0,
				archetypeId = "enemy.exclusion_walker",
				hordeRoleId = "horde.role.runner",
			},
			{
				id = encounterContext.Token .. ":2",
				name = "Blight Spitter",
				x = 8,
				y = 4,
				z = 0,
				archetypeId = "enemy.blight_spitter",
				hordeRoleId = nil,
			},
		},
	}
end)

assert(rawget(adapter :: any, "start") ~= nil, "start must be bound on the adapter instance")
assert(rawget(adapter :: any, "cancel") ~= nil, "cancel must be bound on the adapter instance")

assert(adapter.start(context("wave-token", "Dungeon")) == true)
assert(#pressureWaveIndexes == 1 and pressureWaveIndexes[1] == 2, "typed wave must preserve authored pressure pacing")
assert(#spawnRequests == 2, "every typed authored definition must reach spawnEnemy")
assert(spawnRequests[1].archetypeId == "enemy.exclusion_walker")
assert(spawnRequests[1].hordeRoleId == "horde.role.runner")
assert(spawnRequests[1].spawnSourceId == "AuthoredWave")
assert(spawnRequests[1].isHordePulse == true)
assert(spawnRequests[2].archetypeId == "enemy.blight_spitter")
assert(spawnRequests[2].hordeRoleId == nil)
assert(spawnRequests[2].isHordePulse == false)
assert(adapter.start(context("parallel-token", "Dungeon")) == false)
local completed, reason = adapter:pollCompletion()
assert(completed == false and reason == "EncounterInProgress")

table.insert(liveFacts, { entityId = "unrelated-enemy", isAlive = true })
liveFacts = { { entityId = "unrelated-enemy", isAlive = true } }
local waveDone, waveToken = adapter:pollCompletion()
assert(waveDone == true and waveToken == "wave-token")
local duplicate, duplicateReason = adapter:pollCompletion()
assert(duplicate == false and duplicateReason == "CompletionAlreadyReported")

adapter.cancel(context("wrong-token", "Dungeon"), "Wrong")
assert(adapter:getActiveToken() == "wave-token")
adapter.cancel(context("wave-token", "Dungeon"), "CoordinatorAdvanced")
assert(adapter:getActiveToken() == nil and stoodDown == 1)

assert(adapter.start(context("boss-token", "Boss")) == true)
local bossPending = adapter:pollCompletion()
assert(bossPending == false)
bossState = { exists = true, isAlive = false, isDefeated = true }
local bossDone, bossToken = adapter:pollCompletion()
assert(bossDone == true and bossToken == "boss-token")

adapter:destroy()
assert(stoodDown == 2 and adapter:getActiveToken() == nil)
local afterDestroy, afterDestroyReason = adapter:pollCompletion()
assert(afterDestroy == false and afterDestroyReason == "AdapterDestroyed")

print("EnemyDirectorEncounterAdapter: typed authored archetype/role forwarding passed")
