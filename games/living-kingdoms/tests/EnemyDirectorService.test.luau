--!strict

-- P5-0105 enemy director runtime: fair spawning with deferral, waves, roaming
-- pressure with recovery windows, pursuit movement intent, authoritative
-- attacks, the revisioned health boundary, death and corpse cleanup, stand-down,
-- performance bounds, and teardown.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0105 enemy director fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local presentationContracts =
	loadSimple("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau", "EnemyPresentationContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local CONTRACTS_TOKEN = {}
local RPG_CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local CONFIG_TOKEN = {}
local RPG_CONFIG_TOKEN = {}
local PRESENTATION_TOKEN = {}
local RESOLVER_TOKEN = {}
local ELITE_RESOLVER_TOKEN = {}
local LIFE_TOKEN = {}

local rpgContracts = loadSimple("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau", "RunRpgContracts")
local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = RPG_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == RPG_CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return rpgContracts
		end,
	},
	injectGlobals = true,
})()

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
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
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local progressionAttributes = { RunIncomingDamageMultiplier = 1 }
local progressionNetwork = {
	GetAttribute = function(_self: unknown, attributeName: string)
		return progressionAttributes[attributeName]
	end,
}
local sharedReplicatedStorage = {
	Shared = {
		Combat = { EnemyContracts = CONTRACTS_TOKEN },
		Config = {
			EnemyConfig = CONFIG_TOKEN,
			RunRpgConfig = RPG_CONFIG_TOKEN,
			WorldFoundationConfig = WORLD_TOKEN,
		},
		RPG = { RunRpgContracts = RPG_CONTRACTS_TOKEN },
		Visual = { EnemyPresentationContracts = PRESENTATION_TOKEN },
	},
	FindFirstChild = function(_self: unknown, name: string)
		return if name == "ProgressionNetwork" then progressionNetwork else nil
	end,
}

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau"), {
	debugName = "EnemyBehaviorResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return sharedReplicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local eliteResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EliteAffixResolver.luau"), {
	debugName = "EliteAffixResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return sharedReplicatedStorage
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
			error("unexpected EliteAffixResolver dependency")
		end,
	},
	injectGlobals = true,
})()

local function signal()
	local listeners = {}
	local value = {}
	function value:Connect(callback)
		table.insert(listeners, callback)
		local connected = true
		return {
			Disconnect = function()
				if not connected then
					return
				end
				connected = false
				local index = table.find(listeners, callback)
				if index ~= nil then
					table.remove(listeners, index)
				end
			end,
		}
	end
	function value:Fire(...)
		for _, listener in table.clone(listeners) do
			listener(...)
		end
	end
	function value:count()
		return #listeners
	end
	return value
end

-- Instance double with settable properties and destroy tracking.
local createdInstances = {}
local function fakeInstance(className: string)
	local attributes = {}
	local instance: any = {}
	instance.ClassName = className
	instance.Name = className
	instance._destroyed = false
	function instance.SetAttribute(_, attributeName, value)
		attributes[attributeName] = value
	end
	function instance.GetAttribute(_, attributeName)
		return attributes[attributeName]
	end
	function instance.Destroy(self)
		self._destroyed = true
	end
	function instance.IsA(_, otherClassName)
		return otherClassName == className
	end
	if className == "Part" then
		instance.movedTo = {}
		function instance.SetNetworkOwner(_, _owner) end
	end
	if className == "Humanoid" then
		instance.movedTo = {}
		function instance.MoveTo(self, targetPosition)
			table.insert(self.movedTo, targetPosition)
		end
	end
	table.insert(createdInstances, instance)
	return instance
end

local now = 0
local heartbeatSignal = signal()
local workspaceMock = {
	GetServerTimeNow = function()
		return now
	end,
	FindFirstChild = function()
		return nil
	end,
}
local runServiceMock = { Heartbeat = heartbeatSignal }

-- Life-service mock: roster, players, characters, and an auditable
-- authoritative damage boundary.
local roster = {}
local playersById = {}
local damageCalls = {}
local rejectNextDamage = false
local lifeService = {
	readAll = function()
		local reads = {}
		for _, entry in roster do
			table.insert(reads, {
				operativeEntityId = entry.operativeEntityId,
				revision = entry.revision,
				snapshot = entry.snapshot,
			})
		end
		return reads
	end,
	readByOperativeEntityId = function(operativeEntityId)
		for _, entry in roster do
			if entry.operativeEntityId == operativeEntityId then
				return { revision = entry.revision, snapshot = entry.snapshot }
			end
		end
		return nil
	end,
	playerForOperativeEntityId = function(operativeEntityId)
		return playersById[operativeEntityId]
	end,
	applyAuthoritativeDamage = function(operativeEntityId, expectedRevision, damage)
		table.insert(damageCalls, {
			operativeEntityId = operativeEntityId,
			expectedRevision = expectedRevision,
			damage = damage,
		})
		if rejectNextDamage then
			rejectNextDamage = false
			return { didCommit = false, rejectionReason = "StaleRevision" }
		end
		for _, entry in roster do
			if entry.operativeEntityId == operativeEntityId then
				entry.revision += 1
			end
		end
		return { didCommit = true }
	end,
}

local function addOperative(operativeEntityId: string, x: number, z: number, lifeStateId: string?)
	local root = {
		Position = roblox.Vector3.new(x, 2, z),
		IsA = function(_, className)
			return className == "BasePart"
		end,
	}
	local player = {
		Character = {
			FindFirstChild = function(_, name)
				return if name == "HumanoidRootPart" then root else nil
			end,
		},
		root = root,
	}
	local entry = {
		operativeEntityId = operativeEntityId,
		revision = 0,
		snapshot = { operativeEntityId = operativeEntityId, lifeStateId = lifeStateId or "Alive" },
	}
	table.insert(roster, entry)
	playersById[operativeEntityId] = player
	return entry, root
end

local function clearOperatives()
	table.clear(roster)
	table.clear(playersById)
end

local autoEnum = setmetatable({}, {
	__index = function(self, key)
		local value = setmetatable({}, getmetatable(self))
		rawset(self, key, value)
		return value
	end,
})

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau"), {
	debugName = "EnemyDirectorService",
	environment = {
		game = {
			GetService = function(_, name)
				if name == "ReplicatedStorage" then
					return sharedReplicatedStorage
				elseif name == "RunService" then
					return runServiceMock
				end
				return workspaceMock
			end,
		},
		script = {
			Parent = {
				EnemyBehaviorResolver = RESOLVER_TOKEN,
				EliteAffixResolver = ELITE_RESOLVER_TOKEN,
				OperativeLifeService = LIFE_TOKEN,
			},
		},
		require = function(token)
			if token == CONFIG_TOKEN then
				return config
			elseif token == RPG_CONFIG_TOKEN then
				return rpgConfig
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == RPG_CONTRACTS_TOKEN then
				return rpgContracts
			elseif token == PRESENTATION_TOKEN then
				return presentationContracts
			elseif token == WORLD_TOKEN then
				return worldConfig
			elseif token == RESOLVER_TOKEN then
				return resolver
			elseif token == ELITE_RESOLVER_TOKEN then
				return eliteResolver
			elseif token == LIFE_TOKEN then
				return lifeService
			end
			error("unexpected EnemyDirectorService dependency")
		end,
		Instance = { new = fakeInstance },
		Vector3 = roblox.Vector3,
		Color3 = {
			fromRGB = function(...)
				return { ... }
			end,
		},
		UDim2 = {
			fromOffset = function(...)
				return { ... }
			end,
			fromScale = function(...)
				return { ... }
			end,
		},
		Enum = autoEnum,
		print = function() end,
	},
	injectGlobals = true,
})()

local walker = config.Walker
local minimumSpawn = config.FairSpawn.MinimumOperativeDistanceStuds

local function findCreated(name: string)
	for index = #createdInstances, 1, -1 do
		if createdInstances[index].Name == name and not createdInstances[index]._destroyed then
			return createdInstances[index]
		end
	end
	return nil
end

local function request(entityId: string, x: number, z: number, sourceId: string?)
	return {
		entityId = entityId,
		archetypeId = walker.ArchetypeId,
		spawnSourceId = sourceId or "AuthoredWave",
		displayName = "Test Walker",
		position = { x = x, y = 3, z = z },
	}
end

local function reset()
	service.stop()
	clearOperatives()
	table.clear(damageCalls)
	table.clear(createdInstances)
	now = 0
	service.start()
end

-- Stopped service refuses spawns.
assert(service.spawnEnemy(request("enemy.a", 0, 0)).rejectionReasonId == "ServiceStopped")

-- Basic spawn lifecycle.
reset()
assert(findCreated("EnemyEntities") ~= nil, "start must create the enemy folder")
local firstSpawn = service.spawnEnemy(request("enemy.a", 0, 0))
assert(firstSpawn.didSpawn and not firstSpawn.wasDeferred)
assert(service.readActiveEnemyCount() == 1)
assert(service.spawnEnemy(request("enemy.a", 40, 0)).rejectionReasonId == "DuplicateEntityId")
local facts = service.readEnemyCombatFacts()
assert(#facts == 1 and facts[1].entityId == "enemy.a" and facts[1].isAlive)
assert(facts[1].worldPosition.Y == 6, "bodies must spawn lifted above the authored ground point")
local walkerModel = findCreated("Test Walker")
assert(walkerModel ~= nil and walkerModel:GetAttribute("CombatEntityId") == "enemy.a")
local presentationAttributes = presentationContracts.AttributeNames
assert(walkerModel:GetAttribute(presentationAttributes.BehaviorStateId) == "Roaming")
assert(walkerModel:GetAttribute(presentationAttributes.LifeStateId) == presentationContracts.LifeStateIds.Alive)
assert(walkerModel:GetAttribute(presentationAttributes.AttackSequence) == 0)
assert(walkerModel:GetAttribute(presentationAttributes.AttackServerTimestamp) == 0)
assert(walkerModel:GetAttribute(presentationAttributes.HitSequence) == 0)
assert(walkerModel:GetAttribute(presentationAttributes.HitServerTimestamp) == 0)

-- RPG-0105 assignment remains off during the protected opening, then applies
-- one deterministic Frenzied identity with bounded health and replicated safe
-- presentation facts. Death immediately releases the simultaneous-elite slot.
reset()
service.beginOperationPressure()
now = rpgConfig.EliteAssignmentPlanning.protectedOpeningSeconds - 0.01
assert(service.spawnEnemy(request("enemy.protected", 0, 0)).didSpawn)
local protectedModel = findCreated("Test Walker")
assert(protectedModel ~= nil and protectedModel:GetAttribute(presentationAttributes.EliteAffixId) == nil)

local eliteEntityId = nil
for index = 1, 1000 do
	local candidate = "enemy.director-elite:" .. tostring(index)
	local assignment = eliteResolver.resolveAssignment({
		entityId = candidate,
		spawnSourceId = contracts.EnemySpawnSourceIds.AuthoredWave,
		operationElapsedSeconds = rpgConfig.EliteAssignmentPlanning.protectedOpeningSeconds,
		activeEliteCount = 0,
		isBoss = false,
		isHordePulse = false,
	})
	if assignment.affixId ~= nil then
		eliteEntityId = candidate
		break
	end
end
assert(eliteEntityId ~= nil, "fixture range must contain one deterministic elite")
now = rpgConfig.EliteAssignmentPlanning.protectedOpeningSeconds
assert(service.spawnEnemy(request(eliteEntityId :: string, 20, 0)).didSpawn)
local eliteModel = findCreated("Test Walker")
assert(eliteModel ~= nil and eliteModel:GetAttribute("CombatEntityId") == eliteEntityId)
assert(
	eliteModel:GetAttribute(presentationAttributes.EliteAffixId) == rpgContracts.EliteAffixIds.Frenzied,
	"server must replicate only the safe Frenzied identity"
)
assert(eliteModel:GetAttribute(presentationAttributes.EliteDisplayName) == "FRENZIED")
assert(
	eliteModel:GetAttribute(presentationAttributes.EliteMovementSpeedMultiplier)
		== rpgConfig.FrenziedRuntime.movementSpeedMultiplier
)
assert(
	eliteModel:GetAttribute(presentationAttributes.EliteAttackCadenceMultiplier)
		== rpgConfig.FrenziedRuntime.attackCadenceMultiplier
)
assert(eliteModel:GetAttribute(presentationAttributes.EliteBonusFieldXp) == rpgConfig.FrenziedRuntime.bonusFieldXp)
assert(findCreated("EliteTelegraph") ~= nil, "Frenzied requires an unmistakable highlight")
local eliteHealth = service.readHealthState(eliteEntityId :: string)
local expectedEliteHealth = math.floor(walker.MaximumHealth * rpgConfig.FrenziedRuntime.maximumHealthMultiplier + 0.5)
assert(eliteHealth ~= nil and eliteHealth.healthState.currentHealth == expectedEliteHealth)
assert(service.commitHealthState(eliteEntityId :: string, eliteHealth.revision, {
	entityId = eliteEntityId,
	currentHealth = 0,
	processedShotIds = { ["shot:elite"] = true },
}, now + 1))

-- Unfair authored spawn defers, then lands once the operative moves away.
reset()
assert(service.spawnEnemy(request("enemy.a", 0, 0)).didSpawn)
local victim, victimRoot = addOperative("operative.player:1", 100, 0)
local unfair = service.spawnEnemy(request("enemy.deferred", 100 + minimumSpawn - 1, 0))
assert(not unfair.didSpawn and unfair.wasDeferred and unfair.rejectionReasonId == "TooCloseToOperative")
assert(service.readPressureState().pendingSpawnCount == 1)
now = config.FairSpawn.DeferredRetryIntervalSeconds * 0.5
local early = service.evaluateAt(now)
assert(early.spawnedCount == 0 and service.readPressureState().pendingSpawnCount == 1, "retry must wait its interval")
now = config.FairSpawn.DeferredRetryIntervalSeconds
victimRoot.Position = roblox.Vector3.new(250, 2, 250)
local retried = service.evaluateAt(now)
assert(retried.spawnedCount == 1 and service.readPressureState().pendingSpawnCount == 0)
assert(service.readActiveEnemyCount() == 2)

-- Roaming spawn proposals never defer.
local unfairRoam = service.spawnEnemy(request("enemy.roam-unfair", 250 + minimumSpawn - 1, 250, "RoamingPressure"))
assert(not unfairRoam.didSpawn and not unfairRoam.wasDeferred)

-- Population caps: representative 1/2/4-operative caps, then cap deferral.
assert(service.readPressureState().activeEnemyCount == 2)
local capForOne =
	math.min(config.Population.AbsoluteMaximumConcurrent, config.Population.MaximumConcurrentPerOperative * 1)
for index = service.readActiveEnemyCount() + 1, capForOne do
	assert(service.spawnEnemy(request("enemy.fill:" .. index, -200 + index * 8, -200)).didSpawn)
end
local overCap = service.spawnEnemy(request("enemy.overflow", -100, -100))
assert(not overCap.didSpawn and overCap.wasDeferred and overCap.rejectionReasonId == "PopulationCapReached")

-- Pursuit: an operative inside detection (but beyond the fair-spawn floor at
-- spawn time) draws movement intent toward them.
reset()
addOperative("operative.player:1", 66, 0)
assert(service.spawnEnemy(request("enemy.hunter", 0, 0)).didSpawn)
now = 1
service.evaluateAt(now)
local hunterModel = findCreated("Test Walker")
local hunterHumanoid = nil
for _, instance in createdInstances do
	if instance.ClassName == "Humanoid" and not instance._destroyed then
		hunterHumanoid = instance
	end
end
assert(hunterHumanoid ~= nil)
assert(#hunterHumanoid.movedTo >= 1, "pursuit must issue movement intent")
local lastMove = hunterHumanoid.movedTo[#hunterHumanoid.movedTo]
assert(lastMove.X == 66 and lastMove.Z == 0, "pursuit must move toward the server-read operative position")
assert(hunterHumanoid.WalkSpeed == walker.PursuitSpeedStudsPerSecond)

-- Attacks: a server-owned windup precedes every commit and can be canceled.
-- The spawn is fair; the operative then walks into melee range.
reset()
local target, targetRoot = addOperative("operative.player:7", 300, 300)
assert(service.spawnEnemy(request("enemy.biter", 0, 0)).didSpawn)
targetRoot.Position = roblox.Vector3.new(3, 2, 0)
local biterModel = findCreated("Test Walker")
assert(biterModel ~= nil)
now = 10
local windup = service.evaluateAt(now)
assert(windup.attackCommittedCount == 0 and #damageCalls == 0)
assert(biterModel:GetAttribute("EnemyPresentationBehaviorStateId") == "WindingUp")
assert(biterModel:GetAttribute("EnemyPresentationWindupSequence") == 1)
assert(biterModel:GetAttribute("EnemyPresentationWindupStartedServerTimestamp") == 10)
assert(biterModel:GetAttribute("EnemyPresentationWindupCommitServerTimestamp") == 10 + walker.AttackWindupSeconds)
now = 10 + walker.AttackWindupSeconds - 0.01
assert(service.evaluateAt(now).attackCommittedCount == 0 and #damageCalls == 0)
now = 10 + walker.AttackWindupSeconds
local swing = service.evaluateAt(now)
assert(swing.attackCommittedCount == 1 and #damageCalls == 1)
assert(damageCalls[1].operativeEntityId == "operative.player:7")
assert(damageCalls[1].expectedRevision == 0)
assert(damageCalls[1].damage.damageEventId == "enemyattack:enemy.biter:operative.player:7:10")
assert(damageCalls[1].damage.damageAmount == walker.AttackDamage)
assert(damageCalls[1].damage.sourceEntityId == "enemy.biter")
assert(damageCalls[1].damage.serverTimestamp == now)
assert(biterModel:GetAttribute("EnemyPresentationAttackSequence") == 1)
assert(biterModel:GetAttribute("EnemyPresentationAttackServerTimestamp") == now)
assert(biterModel:GetAttribute("EnemyPresentationBehaviorStateId") == "Attacking")

-- Iron Hide: a squad incoming-damage multiplier published on ProgressionNetwork
-- reduces the amount committed at the enemy attack source while the P3 boundary
-- still receives one authoritative event. Absent the attribute the amount is the
-- unmodified configured attack damage (asserted above).
reset()
progressionAttributes.RunIncomingDamageMultiplier = 0.5
local _mitigatedTarget, mitigatedRoot = addOperative("operative.player:9", 300, 300)
assert(service.spawnEnemy(request("enemy.ironhide", 0, 0)).didSpawn)
mitigatedRoot.Position = roblox.Vector3.new(3, 2, 0)
now = 40
service.evaluateAt(now)
now = 40 + walker.AttackWindupSeconds
local mitigatedSwing = service.evaluateAt(now)
assert(mitigatedSwing.attackCommittedCount == 1 and #damageCalls == 1)
assert(
	damageCalls[1].damage.damageAmount == math.max(1, math.floor(walker.AttackDamage * 0.5 + 0.5)),
	"Iron Hide mitigation must reduce committed enemy damage"
)
assert(damageCalls[1].damage.damageAmount < walker.AttackDamage, "mitigated damage must be below the base attack")
progressionAttributes.RunIncomingDamageMultiplier = 1

-- Leaving melee range during windup cancels damage and resumes pursuit.
reset()
target, targetRoot = addOperative("operative.player:7", 300, 300)
assert(service.spawnEnemy(request("enemy.cancel", 0, 0)).didSpawn)
targetRoot.Position = roblox.Vector3.new(3, 2, 0)
now = 20
assert(service.evaluateAt(now).attackCommittedCount == 0)
local cancelModel = findCreated("Test Walker")
assert(cancelModel ~= nil and cancelModel:GetAttribute("EnemyPresentationWindupSequence") == 1)
targetRoot.Position = roblox.Vector3.new(walker.AttackRangeStuds + 1, 2, 0)
now += 0.2
assert(service.evaluateAt(now).attackCommittedCount == 0 and #damageCalls == 0)
assert(cancelModel:GetAttribute("EnemyPresentationBehaviorStateId") == "Pursuing")
assert(cancelModel:GetAttribute("EnemyPresentationAttackSequence") == 0)

-- Cooldown starts at the committed strike, then another complete windup is required.
reset()
target, targetRoot = addOperative("operative.player:7", 300, 300)
assert(service.spawnEnemy(request("enemy.retry", 0, 0)).didSpawn)
targetRoot.Position = roblox.Vector3.new(3, 2, 0)
now = 30
service.evaluateAt(now)
now += walker.AttackWindupSeconds
assert(service.evaluateAt(now).attackCommittedCount == 1)
local firstCommitAt = now
now = firstCommitAt + walker.AttackCooldownSeconds - 0.01
assert(service.evaluateAt(now).attackCommittedCount == 0, "cooldown must block a new windup")
now = firstCommitAt + walker.AttackCooldownSeconds
assert(service.evaluateAt(now).attackCommittedCount == 0, "cooldown deadline starts a windup, not instant damage")
local retryModel = findCreated("Test Walker")
assert(retryModel ~= nil and retryModel:GetAttribute("EnemyPresentationWindupSequence") == 2)

-- A rejected life commit keeps the same windup pending and retries without a hidden instant attack.
rejectNextDamage = true
now += walker.AttackWindupSeconds
assert(service.evaluateAt(now).attackCommittedCount == 0)
assert(retryModel:GetAttribute("EnemyPresentationBehaviorStateId") == "WindingUp")
assert(retryModel:GetAttribute("EnemyPresentationAttackSequence") == 1)
now += 0.2
assert(service.evaluateAt(now).attackCommittedCount == 1, "rejected commits must retry the disclosed windup")
assert(retryModel:GetAttribute("EnemyPresentationAttackSequence") == 2)
-- Downed operatives never begin a windup.
target.snapshot.lifeStateId = "Incapacitated"
now += walker.AttackCooldownSeconds
assert(service.evaluateAt(now).attackCommittedCount == 0, "only Alive operatives receive enemy damage")

-- Health commit boundary: revision gate, monotonic health, ShotId retention,
-- death, corpse cleanup.
reset()
addOperative("operative.player:1", 300, 300)
assert(service.spawnEnemy(request("enemy.mark", 0, 0)).didSpawn)
local markModel = findCreated("Test Walker")
assert(markModel ~= nil)
local read = service.readHealthState("enemy.mark")
assert(read ~= nil and read.revision == 1 and read.isAlive)
assert(read.healthState.currentHealth == walker.MaximumHealth)
assert(service.readHealthState("enemy.unknown") == nil)
assert(not service.commitHealthState("enemy.mark", 99, {
	entityId = "enemy.mark",
	currentHealth = 40,
	processedShotIds = {},
}, 5), "stale revisions must be rejected")
assert(not service.commitHealthState("enemy.mark", read.revision, {
	entityId = "enemy.mark",
	currentHealth = walker.MaximumHealth + 10,
	processedShotIds = {},
}, 5), "enemy health must never increase")
assert(service.commitHealthState("enemy.mark", read.revision, {
	entityId = "enemy.mark",
	currentHealth = 40,
	processedShotIds = { ["shot:a"] = true },
}, 5))
local afterHit = service.readHealthState("enemy.mark")
assert(afterHit ~= nil and afterHit.revision == 2 and afterHit.healthState.currentHealth == 40)
assert(markModel:GetAttribute(presentationAttributes.HitSequence) == 1)
assert(markModel:GetAttribute(presentationAttributes.HitServerTimestamp) == 5)
assert(not service.commitHealthState("enemy.mark", afterHit.revision, {
	entityId = "enemy.mark",
	currentHealth = 20,
	processedShotIds = {},
}, 6), "processed ShotIds must be retained across commits")
assert(service.commitHealthState("enemy.mark", afterHit.revision, {
	entityId = "enemy.mark",
	currentHealth = 0,
	processedShotIds = { ["shot:a"] = true, ["shot:b"] = true },
}, 7))
local dead = service.readHealthState("enemy.mark")
assert(dead ~= nil and not dead.isAlive)
assert(markModel:GetAttribute(presentationAttributes.HitSequence) == 2)
assert(markModel:GetAttribute(presentationAttributes.HitServerTimestamp) == 7)
assert(markModel:GetAttribute(presentationAttributes.LifeStateId) == presentationContracts.LifeStateIds.Dead)
assert(markModel:GetAttribute(presentationAttributes.BehaviorStateId) == "Dead")
assert(service.readActiveEnemyCount() == 0, "death must free population capacity")
assert(#service.readEnemyCombatFacts() == 0, "dead enemies are no longer combat facts")
assert(markModel ~= nil and not markModel._destroyed, "the corpse must persist through the cleanup window")
now = 7 + config.Cleanup.CorpseCleanupSeconds - 0.01
assert(service.evaluateAt(now).cleanedCount == 0)
now = 7 + config.Cleanup.CorpseCleanupSeconds
assert(service.evaluateAt(now).cleanedCount == 1)
assert(markModel._destroyed, "corpse cleanup must destroy the body")
assert(service.readHealthState("enemy.mark") == nil)

-- Roaming pressure, escalation cadence, and recovery windows.
reset()
addOperative("operative.player:1", 0, 0)
service.beginOperationPressure()
local pressure = service.readPressureState()
assert(pressure.isPressureActive and not pressure.isStoodDown and pressure.escalationLevel == 0)
local level0 = config.Pressure.RoamingByEscalationLevel[0]
assert(pressure.nextRoamingSpawnServerTimestamp == level0.IntervalSeconds)
now = level0.IntervalSeconds - 0.01
assert(service.evaluateAt(now).spawnedCount == 0)
now = level0.IntervalSeconds
local roamSummary = service.evaluateAt(now)
assert(roamSummary.spawnedCount == level0.SpawnCount, "roaming must spawn on its cadence")
local roamFacts = service.readEnemyCombatFacts()
assert(#roamFacts == level0.SpawnCount)
for _, fact in roamFacts do
	local dx = fact.worldPosition.X - 0
	local dz = fact.worldPosition.Z - 0
	local distance = math.sqrt(dx * dx + dz * dz)
	assert(distance >= minimumSpawn, "roaming spawns must honor fairness")
	assert(
		math.abs(fact.worldPosition.X) <= worldConfig.PlayableHalfExtentStuds
			and math.abs(fact.worldPosition.Z) <= worldConfig.PlayableHalfExtentStuds,
		"roaming spawns must stay inside the world"
	)
end

-- An authored wave just before the next scheduled roam raises escalation and
-- opens a recovery window that pauses that roam.
local scheduledRoamAt = service.readPressureState().nextRoamingSpawnServerTimestamp :: number
now = scheduledRoamAt - 1
local waveAccepted = service.spawnAuthoredWave(2, {
	{ id = "enemy.wave2-a", name = "Wave Walker", x = 200, y = 3, z = 200 },
	{ id = "enemy.wave2-b", name = "Wave Walker", x = -200, y = 3, z = 200 },
})
assert(waveAccepted == 2)
local afterWave = service.readPressureState()
assert(afterWave.escalationLevel == 2)
local recoveryEnd = afterWave.recoveryWindowEndServerTimestamp :: number
assert(recoveryEnd == now + config.Pressure.RecoveryWindowSeconds)
local level2 = config.Pressure.RoamingByEscalationLevel[2]
now = scheduledRoamAt
assert(now < recoveryEnd, "this scenario must land the roam inside the recovery window")
assert(service.evaluateAt(now).spawnedCount == 0, "recovery windows must pause roaming pressure")
-- After the recovery window the escalated cadence resumes.
local resumeAt = service.readPressureState().nextRoamingSpawnServerTimestamp
assert(resumeAt == now + level2.IntervalSeconds, "escalation must tighten the roaming interval")
now = math.max(resumeAt, recoveryEnd)
local resumed = service.evaluateAt(now)
assert(resumed.spawnedCount == level2.SpawnCount, "roaming resumes after the recovery window")

-- Escalation level never regresses.
service.spawnAuthoredWave(1, { { id = "enemy.wave1-late", name = "Wave Walker", x = 250, y = 3, z = -250 } })
assert(service.readPressureState().escalationLevel == 2, "escalation is monotonic")

-- Stand-down: spawning stops, pending clears, and every enemy becomes inert.
reset()
local standTarget, standRoot = addOperative("operative.player:1", 300, 300)
assert(service.spawnEnemy(request("enemy.stood", 0, 0)).didSpawn)
service.beginOperationPressure()
standRoot.Position = roblox.Vector3.new(3, 2, 0)
service.spawnEnemy(request("enemy.stuck", 10, 0))
assert(service.readPressureState().pendingSpawnCount == 1)
service.endOperationPressure()
local stoodState = service.readPressureState()
assert(stoodState.isStoodDown and not stoodState.isPressureActive and stoodState.pendingSpawnCount == 0)
now = 500
assert(service.evaluateAt(now).attackCommittedCount == 0, "stood-down enemies never attack")
assert(#damageCalls == 0)
assert(service.readEnemyCombatFacts()[1].targetOperativeEntityId == nil)
-- Pressure can begin again (a fresh operation) and enemies wake.
service.beginOperationPressure()
now = 501
assert(service.evaluateAt(now).attackCommittedCount == 0, "pressure restart must begin a disclosed windup")
local wokeModel = findCreated("Test Walker")
assert(wokeModel ~= nil and wokeModel:GetAttribute(presentationAttributes.BehaviorStateId) == "WindingUp")
now += walker.AttackWindupSeconds
assert(service.evaluateAt(now).attackCommittedCount == 1, "woken enemies commit only after windup")
assert(standTarget.snapshot.lifeStateId == "Alive")

-- Performance bounds: one heartbeat connection, no timers, no raycasts, no
-- remotes, bounded caps for 1/2/4 operatives.
assert(heartbeatSignal:count() == 1, "the director must own exactly one heartbeat connection")
local directorSource = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
for _, prohibited in
	{
		"task.delay",
		"task.spawn",
		"task.defer",
		"Raycast",
		"OnServerEvent",
		"FireClient",
		"FireAllClients",
		"RemoteEvent",
		"math.random",
		"Random.new",
	}
do
	assert(
		not string.find(directorSource, prohibited, 1, true),
		"director must stay bounded and server-only: " .. prohibited
	)
end
-- Representative caps recomputed through the same public surface.
reset()
local function fillToCap(): number
	local spawned = 0
	for index = 1, config.Population.AbsoluteMaximumConcurrent + 4 do
		local result = service.spawnEnemy(request("enemy.cap:" .. index, -300 + index * 6, -300, "RoamingPressure"))
		if result.didSpawn then
			spawned += 1
		end
	end
	return spawned
end
addOperative("operative.player:1", 300, 300)
assert(fillToCap() == config.Population.MaximumConcurrentPerOperative, "one-operative cap must follow configuration")
reset()
addOperative("operative.player:1", 300, 300)
addOperative("operative.player:2", 300, -300)
assert(
	fillToCap()
		== math.min(config.Population.AbsoluteMaximumConcurrent, config.Population.MaximumConcurrentPerOperative * 2),
	"two-operative cap must follow configuration"
)
reset()
addOperative("operative.player:1", 300, 300)
addOperative("operative.player:2", 250, 300)
addOperative("operative.player:3", 300, 250)
addOperative("operative.player:4", 250, 250)
assert(
	fillToCap() == config.Population.AbsoluteMaximumConcurrent,
	"four-operative cap must reach the configured absolute maximum"
)

-- Heartbeat wiring drives evaluation through the configured interval.
now = 1000
heartbeatSignal:Fire(config.EvaluationIntervalSeconds + 0.01)
-- (No assertion beyond not erroring: evaluation content is covered above.)

-- Teardown: folder destroyed, state cleared, heartbeat disconnected.
local folder = findCreated("EnemyEntities")
assert(folder ~= nil)
service.stop()
assert(folder._destroyed, "stop must destroy the enemy folder")
assert(heartbeatSignal:count() == 0, "stop must disconnect the heartbeat")
assert(service.readActiveEnemyCount() == 0)
assert(service.spawnEnemy(request("enemy.late", 0, 0)).rejectionReasonId == "ServiceStopped")
service.stop()

-- Bootstrap wiring: the production director starts before the mission director.
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local directorStart = string.find(bootstrap, "EnemyDirectorService.start()", 1, true)
local missionStart = string.find(bootstrap, "MissionDirectorService.start()", 1, true)
assert(directorStart ~= nil and missionStart ~= nil, "both directors must be bootstrapped")
assert(
	(directorStart :: number) < (missionStart :: number),
	"the enemy director must start before the mission director"
)

print(
	"EnemyDirectorService: P5-0105 fair spawns, waves, roaming, recovery, attacks, health, cleanup, and bounds passed"
)
