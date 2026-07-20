--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local enemyContracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local rpgContracts = loadSimple("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau", "RunRpgContracts")
local ENEMY_TOKEN = {}
local RPG_TOKEN = {}
local CONFIG_TOKEN = {}

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = RPG_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == RPG_TOKEN, "unexpected config dependency")
			return rpgContracts
		end,
	},
	injectGlobals = true,
})()

local replicatedStorage = {
	Shared = {
		Combat = { EnemyContracts = ENEMY_TOKEN },
		Config = { RunRpgConfig = CONFIG_TOKEN },
		RPG = { RunRpgContracts = RPG_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EliteAffixResolver.luau"), {
	debugName = "EliteAffixResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, name: string)
				assertThat(name == "ReplicatedStorage", "unexpected service")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == ENEMY_TOKEN then
				return enemyContracts
			elseif token == CONFIG_TOKEN then
				return config
			elseif token == RPG_TOKEN then
				return rpgContracts
			end
			error("unexpected resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local function facts(entityId: string, overrides: { [string]: any }?)
	local result = {
		entityId = entityId,
		spawnSourceId = enemyContracts.EnemySpawnSourceIds.RoamingPressure,
		operationElapsedSeconds = config.EliteAssignmentPlanning.protectedOpeningSeconds,
		activeEliteCount = 0,
		isBoss = false,
		isHordePulse = false,
	}
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end

assertThat(resolver.resolveAssignment(nil :: any).affixId == nil, "malformed facts must fail closed")
assertThat(
	resolver.resolveAssignment(facts("enemy.opening", { operationElapsedSeconds = 9.999 })).affixId == nil,
	"protected opening must reject elites"
)
assertThat(
	resolver.resolveAssignment(facts("enemy.boss", { isBoss = true })).affixId == nil,
	"bosses must reject elite assignment"
)
assertThat(
	resolver.resolveAssignment(facts("enemy.capped", { activeEliteCount = config.Limits.maximumSimultaneousElites })).affixId
		== nil,
	"simultaneous elite cap must reject assignment"
)

local chosenId = nil
local eliteCount = 0
for index = 1, 10000 do
	local entityId = "enemy.fixture:" .. tostring(index)
	local assignment = resolver.resolveAssignment(facts(entityId))
	if assignment.affixId ~= nil then
		chosenId = chosenId or entityId
		eliteCount += 1
		assertThat(assignment.affixId == rpgContracts.EliteAffixIds.Frenzied, "only Frenzied may be assigned")
		assertThat(
			assignment.movementSpeedMultiplier == config.FrenziedRuntime.movementSpeedMultiplier,
			"movement drift"
		)
		assertThat(
			assignment.attackCadenceMultiplier == config.FrenziedRuntime.attackCadenceMultiplier,
			"cadence drift"
		)
		assertThat(assignment.maximumHealthMultiplier == config.FrenziedRuntime.maximumHealthMultiplier, "health drift")
		assertThat(assignment.bonusFieldXp == config.FrenziedRuntime.bonusFieldXp, "XP drift")
	end
end
assertThat(chosenId ~= nil, "deterministic fixture range must contain an elite")
assertThat(eliteCount >= 400 and eliteCount <= 600, "ordinary deterministic assignment must remain near five percent")
local hordeEliteCount = 0
for index = 1, 10000 do
	if resolver.resolveAssignment(facts("enemy.horde:" .. tostring(index), { isHordePulse = true })).affixId ~= nil then
		hordeEliteCount += 1
	end
end
assertThat(hordeEliteCount >= 600 and hordeEliteCount <= 800, "horde assignment must remain near seven percent")
local first = resolver.resolveAssignment(facts(chosenId :: string))
local replay = resolver.resolveAssignment(facts(chosenId :: string))
assertThat(first.affixId == replay.affixId, "same entity identity must not reroll")

print("EliteAffixResolver: protected opening, caps, deterministic assignment, and Frenzied bounds passed")
