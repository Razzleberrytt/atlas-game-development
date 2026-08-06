--!strict

local Adapter = require("../src/server/Systems/EnemyDirectorEncounterAdapter")

local activeEnemyCount = 0
local bossState = { exists = false, isAlive = false, isDefeated = false }
local stoodDown = 0

local director = {
	spawnAuthoredWave = function(_waveIndex: number, definitions: { any }): number
		activeEnemyCount += #definitions
		return #definitions
	end,
	spawnBoss = function(_position: any, _floodlightsRestored: boolean): boolean
		bossState = { exists = true, isAlive = true, isDefeated = false }
		return true
	end,
	readActiveEnemyCount = function(): number
		return activeEnemyCount
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
		return {
			Kind = "Boss",
			BossPosition = { x = 0, y = 4, z = 80 },
			FloodlightsRestored = true,
		}
	end
	return {
		Kind = "Wave",
		WaveIndex = encounterContext.RoomIndex or 1,
		Wave = {
			{ id = encounterContext.Token .. ":1", name = "Warden", x = 0, y = 4, z = 0 },
			{ id = encounterContext.Token .. ":2", name = "Warden", x = 8, y = 4, z = 0 },
		},
	}
end)

assert(adapter:start(context("wave-token", "Dungeon")) == true)
assert(adapter:start(context("parallel-token", "Dungeon")) == false)
local completed, reason = adapter:pollCompletion()
assert(completed == false and reason == "EncounterInProgress")
activeEnemyCount = 0
local waveDone, waveToken = adapter:pollCompletion()
assert(waveDone == true and waveToken == "wave-token")
local duplicate, duplicateReason = adapter:pollCompletion()
assert(duplicate == false and duplicateReason == "CompletionAlreadyReported")

adapter:cancel(context("wrong-token", "Dungeon"), "Wrong")
assert(adapter:getActiveToken() == "wave-token")
adapter:cancel(context("wave-token", "Dungeon"), "CoordinatorAdvanced")
assert(adapter:getActiveToken() == nil)
assert(stoodDown == 1)

assert(adapter:start(context("boss-token", "Boss")) == true)
local bossPending = adapter:pollCompletion()
assert(bossPending == false)
bossState = { exists = true, isAlive = false, isDefeated = true }
local bossDone, bossToken = adapter:pollCompletion()
assert(bossDone == true and bossToken == "boss-token")

adapter:destroy()
assert(stoodDown == 2)
assert(adapter:getActiveToken() == nil)
local afterDestroy, afterDestroyReason = adapter:pollCompletion()
assert(afterDestroy == false and afterDestroyReason == "AdapterDestroyed")

print("EnemyDirectorEncounterAdapter fixture passed")
