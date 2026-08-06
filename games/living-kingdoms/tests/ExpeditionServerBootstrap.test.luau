--!strict

local Bootstrap = require("../src/server/Systems/ExpeditionServerBootstrap")

local alive: { [string]: boolean } = {}
local bossState = { exists = false, isAlive = false, isDefeated = false }

local director = {
	spawnAuthoredWave = function(_waveIndex: number, definitions: { any }): number
		for _, definition in definitions do alive[definition.id] = true end
		return #definitions
	end,
	spawnBoss = function(_position: any, _floodlightsRestored: boolean): boolean
		bossState = { exists = true, isAlive = true, isDefeated = false }
		return true
	end,
	readEnemyCombatFacts = function(): { any }
		local facts = {}
		for entityId, isAlive in alive do
			if isAlive then table.insert(facts, { entityId = entityId, isAlive = true }) end
		end
		return facts
	end,
	readBossState = function(): any return bossState end,
	endOperationPressure = function() end,
}

local service = Bootstrap.new(director, {
	RunId = "run-bootstrap-001",
	Seed = 321,
	PartySize = 1,
	StartedAtUnix = 100,
})

local plan = service:getRoomPlan()
assert(plan ~= nil and plan.Seed == 321 and #plan.Nodes >= 6)
assert(service:getSnapshot().PhaseId == "Preparation")

-- Preparation has no encounter and advances immediately.
local preparation = service:step(100)
assert(preparation.Accepted == true)
assert(service:getSnapshot().PhaseId == "Approach")

-- Approach starts, remains active, then completes after its exact authored IDs die.
assert(service:step(110).Accepted == true)
assert(service:step(111).ReasonId == "EncounterInProgress")
for entityId in alive do alive[entityId] = false end
assert(service:step(120).Accepted == true)
assert(service:getSnapshot().PhaseId == "Dungeon")

-- Walk every deterministic dungeon node; traversal resolves immediately and
-- combat rooms resolve only after their authored IDs are dead.
local guard = 0
while service:getSnapshot().PhaseId == "Dungeon" do
	guard += 1
	assert(guard < 30)
	local current = service:step(160 + guard * 40)
	if current.ReasonId == "EncounterInProgress" then
		for entityId in alive do alive[entityId] = false end
	else
		service:step(161 + guard * 40)
	end
end
assert(service:getSnapshot().PhaseId == "Elite")

assert(service:step(500).Accepted == true)
for entityId in alive do alive[entityId] = false end
assert(service:step(520).Accepted == true)
assert(service:getSnapshot().PhaseId == "Boss")

assert(service:step(540).Accepted == true)
bossState = { exists = true, isAlive = false, isDefeated = true }
assert(service:step(560).Accepted == true)
assert(service:getSnapshot().PhaseId == "Rewards")

service:destroy()
assert(service:getSnapshot() == nil)
assert(service:step(600).ReasonId == "BootstrapDestroyed")

print("ExpeditionServerBootstrap fixture passed")
