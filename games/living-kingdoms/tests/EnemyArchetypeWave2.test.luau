--!strict

-- Wave 2 enemy archetypes / elites / deterministic composition.
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

local contracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local worldConfig = loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")
local rpgContracts = loadSimple("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau", "RunRpgContracts")

local CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local ENEMY_CONFIG_TOKEN = {}
local SPECIAL_CONTRACTS_TOKEN = {}
local SPECIAL_CONFIG_TOKEN = {}
local ARCHETYPE_CONFIG_TOKEN = {}
local RPG_CONTRACTS_TOKEN = {}
local RPG_CONFIG_TOKEN = {}

local enemyConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local specialContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/SpecialEnemyContracts.luau"), {
	debugName = "SpecialEnemyContracts",
	environment = {
		script = { Parent = { EnemyContracts = CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected SpecialEnemyContracts dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local specialConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/SpecialEnemyConfig.luau"), {
	debugName = "SpecialEnemyConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				Parent = { Combat = { SpecialEnemyContracts = SPECIAL_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			elseif token == SPECIAL_CONTRACTS_TOKEN then
				return specialContracts
			end
			error("unexpected SpecialEnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local archetypeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyArchetypeConfig.luau"), {
	debugName = "EnemyArchetypeConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				SpecialEnemyConfig = SPECIAL_CONFIG_TOKEN,
				Parent = { Combat = { EnemyContracts = CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			elseif token == SPECIAL_CONFIG_TOKEN then
				return specialConfig
			end
			error("unexpected EnemyArchetypeConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local replicatedStorageForBehavior = {
	Shared = {
		Combat = { EnemyContracts = CONTRACTS_TOKEN },
		Config = { EnemyConfig = ENEMY_CONFIG_TOKEN },
	},
}
local behaviorResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau"), {
	debugName = "EnemyBehaviorResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, name: string)
				assertThat(name == "ReplicatedStorage", "unexpected behavior service")
				return replicatedStorageForBehavior
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			error("unexpected behavior dependency")
		end,
	},
	injectGlobals = true,
})()

local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = RPG_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == RPG_CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return rpgContracts
		end,
	},
	injectGlobals = true,
})()

local replicatedStorageForElite = {
	Shared = {
		Combat = { EnemyContracts = CONTRACTS_TOKEN },
		Config = { RunRpgConfig = RPG_CONFIG_TOKEN },
		RPG = { RunRpgContracts = RPG_CONTRACTS_TOKEN },
	},
}
local eliteResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EliteAffixResolver.luau"), {
	debugName = "EliteAffixResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, name: string)
				assertThat(name == "ReplicatedStorage", "unexpected elite service")
				return replicatedStorageForElite
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == RPG_CONFIG_TOKEN then
				return rpgConfig
			elseif token == RPG_CONTRACTS_TOKEN then
				return rpgContracts
			end
			error("unexpected elite dependency")
		end,
	},
	injectGlobals = true,
})()

local replicatedStorageForComposer = { Shared = { Config = { EnemyArchetypeConfig = ARCHETYPE_CONFIG_TOKEN } } }
local composer = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyEncounterComposer.luau"), {
	debugName = "EnemyEncounterComposer",
	environment = {
		game = {
			GetService = function(_self: unknown, name: string)
				assertThat(name == "ReplicatedStorage", "unexpected composer service")
				return replicatedStorageForComposer
			end,
		},
		require = function(token: unknown)
			assertThat(token == ARCHETYPE_CONFIG_TOKEN, "unexpected composer dependency")
			return archetypeConfig
		end,
	},
	injectGlobals = true,
})()

local ids = contracts.EnemyArchetypeIds
local runner = archetypeConfig.get(ids.RazorRunner)
local brute = archetypeConfig.get(ids.GriefBrute)
local walker = archetypeConfig.get(ids.ExclusionWalker)
local spitter = archetypeConfig.get(ids.BlightSpitter)
assertThat(runner ~= nil and runner.RuntimeKind == "Ordinary", "Runner definition missing")
assertThat(brute ~= nil and brute.RuntimeKind == "Ordinary", "Brute definition missing")
assertThat(spitter ~= nil and spitter.RuntimeKind == "Special", "Spitter must keep dedicated special runtime")
assertThat(runner.PursuitSpeedStudsPerSecond > walker.PursuitSpeedStudsPerSecond, "Runner must be meaningfully faster")
assertThat(runner.MaximumHealth < walker.MaximumHealth, "Runner speed must trade durability")
assertThat(brute.MaximumHealth > walker.MaximumHealth * 2, "Brute must be meaningfully tougher")
assertThat(brute.AttackDamage > walker.AttackDamage, "Brute must hit harder")
assertThat(brute.PursuitSpeedStudsPerSecond < walker.PursuitSpeedStudsPerSecond, "Brute must be slower")
assertThat(archetypeConfig.validateDefinition(nil) == false, "missing definitions must fail validation")

local function operative(distance: number)
	return { operativeEntityId = "operative:test", isAlive = true, position = { x = distance, y = 0, z = 0 } }
end
local function facts(entityId: string, state: string, overrides: { [string]: any }?)
	local result = {
		entityId = entityId,
		behaviorStateId = state,
		position = { x = 0, y = 0, z = 0 },
		targetOperativeEntityId = nil,
		lastAttackServerTimestamp = nil,
		attackWindupTargetOperativeEntityId = nil,
		attackWindupStartedServerTimestamp = nil,
	}
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end

contracts.ServerRuntimeMetadataByEntityId["enemy.wave2.runner"] = { archetypeId = ids.RazorRunner }
contracts.ServerRuntimeMetadataByEntityId["enemy.wave2.brute"] = { archetypeId = ids.GriefBrute }
local runnerDetects = behaviorResolver.resolveBehavior(facts("enemy.wave2.runner", "Roaming"), { operative(130) }, 10)
local bruteMisses = behaviorResolver.resolveBehavior(facts("enemy.wave2.brute", "Roaming"), { operative(130) }, 10)
assertThat(runnerDetects.behaviorStateIdAfter == "Pursuing", "Runner should detect at its larger radius")
assertThat(bruteMisses.behaviorStateIdAfter == "Roaming", "Brute should not inherit Runner detection")

local runnerBegin = behaviorResolver.resolveBehavior(facts("enemy.wave2.runner", "Roaming"), { operative(5) }, 10)
assertThat(runnerBegin.attackWindupActionId == "Begin", "Runner must start shared melee windup")
local runnerCommit = behaviorResolver.resolveBehavior(
	facts("enemy.wave2.runner", "WindingUp", {
		targetOperativeEntityId = "operative:test",
		attackWindupTargetOperativeEntityId = "operative:test",
		attackWindupStartedServerTimestamp = 10,
	}),
	{ operative(5) },
	10.46
)
assertThat(runnerCommit.shouldAttack and runnerCommit.attack.damageAmount == 13, "Runner damage must come from its definition")

local bruteCommit = behaviorResolver.resolveBehavior(
	facts("enemy.wave2.brute", "WindingUp", {
		targetOperativeEntityId = "operative:test",
		attackWindupTargetOperativeEntityId = "operative:test",
		attackWindupStartedServerTimestamp = 20,
	}),
	{ operative(8) },
	21.06
)
assertThat(bruteCommit.shouldAttack and bruteCommit.attack.damageAmount == 34, "Brute damage must come from its definition")

local forcedEliteId = "enemy.wave2.forced-elite"
contracts.ServerRuntimeMetadataByEntityId[forcedEliteId] = {
	archetypeId = ids.RazorRunner,
	eliteEligible = true,
	eliteChance = 0,
	requestedEliteAffixId = rpgContracts.EliteAffixIds.Frenzied,
}
local forcedElite = eliteResolver.resolveAssignment({
	entityId = forcedEliteId,
	spawnSourceId = contracts.EnemySpawnSourceIds.AuthoredWave,
	operationElapsedSeconds = 0,
	activeEliteCount = 0,
	isBoss = false,
	isHordePulse = false,
	hordeRoleId = "horde.role.infected",
})
assertThat(forcedElite.affixId == rpgContracts.EliteAffixIds.Frenzied, "authored compatible affix must resolve deterministically")
local ineligibleId = "enemy.wave2.ineligible"
contracts.ServerRuntimeMetadataByEntityId[ineligibleId] = {
	archetypeId = ids.BlightSpitter,
	eliteEligible = false,
	eliteChance = 1,
	requestedEliteAffixId = rpgContracts.EliteAffixIds.Frenzied,
}
assertThat(eliteResolver.resolveAssignment({
	entityId = ineligibleId,
	spawnSourceId = contracts.EnemySpawnSourceIds.AuthoredWave,
	operationElapsedSeconds = 100,
	activeEliteCount = 0,
	isBoss = false,
	isHordePulse = false,
	hordeRoleId = "horde.role.infected",
}).affixId == nil, "ineligible special archetypes must reject encounter elite overrides")

local spawnPoints = {
	{ x = 70, y = 3, z = 0 },
	{ x = 75, y = 3, z = 5 },
	{ x = 80, y = 3, z = 10 },
	{ x = 85, y = 3, z = 15 },
	{ x = 90, y = 3, z = 20 },
}
local encounter = {
	Id = "encounter.wave2.fixture",
	Budget = 8,
	MinimumCount = 4,
	MaximumCount = 4,
	ArchetypeIds = { ids.GriefBrute, ids.RazorRunner, ids.ExclusionWalker },
	RequiredCounts = { [ids.GriefBrute] = 1, [ids.RazorRunner] = 2 },
	SpawnWeights = { [ids.GriefBrute] = 0.5, [ids.RazorRunner] = 2, [ids.ExclusionWalker] = 4 },
	EliteChance = 0.2,
	DifficultyMultiplier = 1,
}
local firstPlan = composer.compose(encounter, spawnPoints, { Seed = 4242, CompositionIdentity = "room:a" })
local replayPlan = composer.compose(encounter, spawnPoints, { Seed = 4242, CompositionIdentity = "room:a" })
assertThat(firstPlan.isValid and #firstPlan.spawns == 4, "valid budgeted encounter must compose")
assertThat(firstPlan.usedBudget <= firstPlan.effectiveBudget, "composition must never exceed budget")
assertThat(firstPlan.spawns[1].archetypeId == ids.GriefBrute, "required Brute anchor must be emitted first")
assertThat(firstPlan.spawns[2].archetypeId == ids.RazorRunner and firstPlan.spawns[3].archetypeId == ids.RazorRunner, "required Runner support must be exact")
for index, spawn in firstPlan.spawns do
	assertThat(spawn.entityId == replayPlan.spawns[index].entityId, "same seed must replay entity identity")
	assertThat(spawn.archetypeId == replayPlan.spawns[index].archetypeId, "same seed must replay composition")
end
assertThat(not composer.compose({ Id = "bad", Budget = 2, MinimumCount = 1, MaximumCount = 1, ArchetypeIds = { "enemy.unknown" } }, spawnPoints, { Seed = 1 }).isValid, "unknown archetypes must fail closed")
assertThat(not composer.compose({
	Id = "too-cheap",
	Budget = 2,
	MinimumCount = 1,
	MaximumCount = 1,
	ArchetypeIds = { ids.GriefBrute },
	RequiredCounts = { [ids.GriefBrute] = 1 },
}, spawnPoints, { Seed = 1 }).isValid, "required composition must not exceed budget")

contracts.ServerRuntimeMetadataByEntityId["enemy.wave2.runner"] = nil
contracts.ServerRuntimeMetadataByEntityId["enemy.wave2.brute"] = nil
contracts.ServerRuntimeMetadataByEntityId[forcedEliteId] = nil
contracts.ServerRuntimeMetadataByEntityId[ineligibleId] = nil

print("EnemyArchetypeWave2: definitions, behavior diversity, authored elites, budgets, determinism, and invalid-input handling passed")
