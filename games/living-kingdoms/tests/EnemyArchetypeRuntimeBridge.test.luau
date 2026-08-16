--!strict

-- Wave 2 runtime compatibility bridge: proportional authoritative health,
-- trusted damage-source hook, reward metadata, teardown, and no extra loops.
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
local presentationContracts =
	loadSimple("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau", "EnemyPresentationContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local ENEMY_CONFIG_TOKEN = {}
local ARCHETYPE_CONFIG_TOKEN = {}
local PRESENTATION_TOKEN = {}

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

local ids = contracts.EnemyArchetypeIds
local bruteDefinition = {
	ArchetypeId = ids.GriefBrute,
	DisplayName = "Grief Brute",
	RuntimeKind = "Ordinary",
	MaximumHealth = 150,
	PursuitSpeedStudsPerSecond = 10.5,
	RoamSpeedStudsPerSecond = 4,
	MovementBehaviorId = "HeavyPressure",
	AttackBehaviorId = "Melee",
	FactionId = "faction.exclusion",
	SpawnCost = 3,
	RewardMetadata = { baseFieldXp = 28, lootProfileId = "enemy.heavy" },
	WeakPoint = { partName = "Head", damageMultiplier = 1.35 },
	EliteEligible = true,
	AttackWindupSeconds = 1.05,
}
local fakeArchetypeConfig = {
	get = function(archetypeId)
		return if archetypeId == ids.GriefBrute then bruteDefinition else nil
	end,
}

local replicatedStorage = {
	Shared = {
		Combat = { EnemyContracts = CONTRACTS_TOKEN },
		Config = {
			EnemyConfig = ENEMY_CONFIG_TOKEN,
			EnemyArchetypeConfig = ARCHETYPE_CONFIG_TOKEN,
		},
		Visual = { EnemyPresentationContracts = PRESENTATION_TOKEN },
	},
}
local bridgeSource = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyArchetypeRuntimeBridge.luau")
assertThat(string.find(bridgeSource, "RunService", 1, true) == nil, "bridge must not add a second RunService loop")
assertThat(string.find(bridgeSource, ":Connect(", 1, true) == nil, "bridge must not add per-enemy connections")

local bridge = luau.load(bridgeSource, {
	debugName = "EnemyArchetypeRuntimeBridge",
	environment = {
		game = {
			GetService = function(_self: unknown, name: string)
				assertThat(name == "ReplicatedStorage", "unexpected bridge service")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			elseif token == ARCHETYPE_CONFIG_TOKEN then
				return fakeArchetypeConfig
			elseif token == PRESENTATION_TOKEN then
				return presentationContracts
			end
			error("unexpected bridge dependency")
		end,
	},
	injectGlobals = true,
})()

local revision = 1
local currentHealth = enemyConfig.Walker.MaximumHealth
local isAlive = true
local processedShotIds = {}
local function readUnderlying(_entityId)
	return {
		revision = revision,
		isAlive = isAlive,
		maximumHealth = enemyConfig.Walker.MaximumHealth,
		healthState = {
			entityId = "enemy.bridge.brute",
			currentHealth = currentHealth,
			processedShotIds = table.clone(processedShotIds),
		},
	}
end
local fakeDirector = {
	readHealthState = readUnderlying,
	commitHealthState = function(_entityId, expectedRevision, after, _serverTimestamp)
		if expectedRevision ~= revision or type(after) ~= "table" or after.currentHealth > currentHealth then
			return false, nil
		end
		local damage = currentHealth - after.currentHealth
		currentHealth = math.max(0, after.currentHealth)
		processedShotIds = table.clone(after.processedShotIds)
		revision += 1
		isAlive = currentHealth > 0
		return true, damage
	end,
	evaluateAt = function(_timestamp)
		return { activeEnemyCount = if isAlive then 1 else 0 }
	end,
	readEnemyCombatFacts = function()
		return {}
	end,
	stop = function()
		return nil
	end,
}

assertThat(bridge.install(fakeDirector), "bridge must install on the production-shaped director boundary")
assertThat(
	bridge.registerSpawn({
		entityId = "enemy.bridge.brute",
		archetypeId = ids.GriefBrute,
		encounterId = "encounter:bridge",
		compositionIdentity = "room:bridge",
		eliteChance = 0.25,
	}),
	"authored runtime metadata must register"
)
assertThat(table.isfrozen(contracts), "shared contract vocabulary must remain frozen")
assertThat(
	contracts.ServerRuntimeMetadataByEntityId["enemy.bridge.brute"] ~= nil,
	"nested VM-local registry must remain mutable"
)

local initial = fakeDirector.readHealthState("enemy.bridge.brute")
assertThat(
	math.abs(initial.maximumHealth - 150) < 0.001,
	"Brute max health must resolve through the authoritative health seam"
)
assertThat(math.abs(initial.healthState.currentHealth - 150) < 0.001, "Brute starts at resolved max health")

local didDamage, committedDamage = fakeDirector.commitHealthState("enemy.bridge.brute", initial.revision, {
	entityId = "enemy.bridge.brute",
	currentHealth = 116,
	processedShotIds = { "shot:1" },
}, 10, "operative:test")
assertThat(
	didDamage and math.abs(committedDamage - 34) < 0.001,
	"virtual Brute damage must map proportionally to underlying authoritative health"
)
local afterDamage = fakeDirector.readHealthState("enemy.bridge.brute")
assertThat(
	math.abs(afterDamage.healthState.currentHealth - 116) < 0.001,
	"resolved health must round-trip after damage"
)

local rewardContext = bridge.readRewardContext("enemy.bridge.brute")
assertThat(
	rewardContext.baseFieldXp == 28 and rewardContext.lootProfileId == "enemy.heavy",
	"reward hook must expose archetype metadata"
)
assertThat(rewardContext.encounterId == "encounter:bridge", "reward hook must retain encounter identity")
assertThat(
	rewardContext.lastDamagingOperativeEntityId == "operative:test",
	"trusted optional damage source must be retained"
)
assertThat(rewardContext.isAlive == true, "reward context must report current life state")

local didKill, lethalDamage = fakeDirector.commitHealthState("enemy.bridge.brute", afterDamage.revision, {
	entityId = "enemy.bridge.brute",
	currentHealth = 0,
	processedShotIds = { "shot:1", "shot:2" },
}, 11, "operative:test")
assertThat(didKill and math.abs(lethalDamage - 116) < 0.001, "lethal damage must preserve resolved health semantics")
assertThat(
	fakeDirector.readHealthState("enemy.bridge.brute").isAlive == false,
	"underlying director death invariant must remain authoritative"
)
assertThat(
	bridge.readRewardContext("enemy.bridge.brute").isAlive == false,
	"reward hook must observe authoritative death"
)

assertThat(bridge.unregisterSpawn("enemy.bridge.brute"), "explicit rejected/cleanup path must unregister metadata")
assertThat(bridge.readRewardContext("enemy.bridge.brute") == nil, "unregistered metadata must not leak")
fakeDirector.stop()

print(
	"EnemyArchetypeRuntimeBridge: health scaling, reward attribution hook, teardown, and no extra loops/connections passed"
)
