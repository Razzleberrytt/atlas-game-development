--!strict

-- P5-0107 integration validation: the real mission director drives the real
-- enemy director end-to-end — infiltration pressure, all three authored waves,
-- fair holdout spawns, resolution stand-down, squad-wipe stand-down — with
-- bounded connections and no widened client surface.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0107 integration fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local missionContracts =
	loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local missionConfig = loadSimple("games/living-kingdoms/src/shared/Config/MissionConfig.luau", "MissionConfig")
local enemyContracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local presentationContracts =
	loadSimple("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau", "EnemyPresentationContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local ENEMY_CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local ENEMY_CONFIG_TOKEN = {}
local PRESENTATION_TOKEN = {}
local MISSION_CONFIG_TOKEN = {}
local MISSION_CONTRACTS_TOKEN = {}
local RESOLVER_TOKEN = {}
local LIFE_TOKEN = {}
local FAILURE_TOKEN = {}
local ENEMY_DIRECTOR_TOKEN = {}

local enemyConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local sharedReplicatedStorage = {
	Shared = {
		Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN },
		Config = {
			EnemyConfig = ENEMY_CONFIG_TOKEN,
			WorldFoundationConfig = WORLD_TOKEN,
			MissionConfig = MISSION_CONFIG_TOKEN,
		},
		Mission = { MissionContracts = MISSION_CONTRACTS_TOKEN },
		Visual = { EnemyPresentationContracts = PRESENTATION_TOKEN },
	},
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
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			error("unexpected resolver dependency")
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
	function instance.FindFirstChild(_, _childName)
		return nil
	end
	if className == "Part" then
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
local workspaceMock = {
	GetServerTimeNow = function()
		return now
	end,
	FindFirstChild = function()
		return nil
	end,
}
local heartbeatSignal = signal()
local runServiceMock = { Heartbeat = heartbeatSignal }

-- Shared life/failure mocks used by both real services.
local roster = {}
local playersById = {}
local admitted = {}
local damageCalls = {}
local failureSignal = signal()
local lifeService = {
	read = function(player)
		for _, entry in roster do
			if playersById[entry.operativeEntityId] == player then
				return { revision = entry.revision, snapshot = entry.snapshot }
			end
		end
		return nil
	end,
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
	applyAuthoritativeDamage = function(operativeEntityId, _expectedRevision, damage)
		table.insert(damageCalls, { operativeEntityId = operativeEntityId, damage = damage })
		for _, entry in roster do
			if entry.operativeEntityId == operativeEntityId then
				entry.revision += 1
			end
		end
		return { didCommit = true }
	end,
}
local failureService = {
	beginOperation = function()
		table.clear(admitted)
		for _, entry in roster do
			admitted[entry.operativeEntityId] = true
		end
		return { didCommit = true }
	end,
	isOperativeAdmitted = function(operativeEntityId)
		return admitted[operativeEntityId] == true
	end,
	subscribe = function(callback)
		return failureSignal:Connect(callback)
	end,
}

local enemyDirector = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau"), {
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
				OperativeLifeService = LIFE_TOKEN,
			},
		},
		require = function(token)
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			elseif token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			elseif token == PRESENTATION_TOKEN then
				return presentationContracts
			elseif token == WORLD_TOKEN then
				return worldConfig
			elseif token == RESOLVER_TOKEN then
				return resolver
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
		Enum = setmetatable({}, {
			__index = function(self, key)
				local value = setmetatable({}, getmetatable(self))
				rawset(self, key, value)
				return value
			end,
		}),
		print = function() end,
	},
	injectGlobals = true,
})()

local scheduled = {}
local broadcasts = {}
local playersSignal = signal()
local missionHeartbeat = signal()
local stateRemote = {
	FireAllClients = function(_, payload)
		table.insert(broadcasts, payload)
	end,
	FireClient = function() end,
}
local missionNetwork = {
	WaitForChild = function(_, name)
		assert(name == "State")
		return stateRemote
	end,
}
local missionReplicatedStorage = setmetatable({
	WaitForChild = function(_, name)
		assert(name == "MissionNetwork")
		return missionNetwork
	end,
}, { __index = sharedReplicatedStorage })

local mission = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau"), {
	debugName = "MissionDirectorService",
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return { PlayerAdded = playersSignal }
				elseif name == "ReplicatedStorage" then
					return missionReplicatedStorage
				elseif name == "RunService" then
					return { Heartbeat = missionHeartbeat }
				end
				return workspaceMock
			end,
		},
		script = {
			Parent = {
				EnemyDirectorService = ENEMY_DIRECTOR_TOKEN,
				OperativeLifeService = LIFE_TOKEN,
				SquadFailureService = FAILURE_TOKEN,
			},
		},
		require = function(token)
			if token == MISSION_CONFIG_TOKEN then
				return missionConfig
			elseif token == MISSION_CONTRACTS_TOKEN then
				return missionContracts
			elseif token == ENEMY_DIRECTOR_TOKEN then
				return enemyDirector
			elseif token == LIFE_TOKEN then
				return lifeService
			elseif token == FAILURE_TOKEN then
				return failureService
			end
			error("unexpected MissionDirectorService dependency")
		end,
		task = {
			delay = function(delaySeconds, callback)
				local handle = { delaySeconds = delaySeconds, callback = callback }
				table.insert(scheduled, handle)
				return handle
			end,
			cancel = function() end,
		},
		Instance = { new = fakeInstance },
		Vector3 = roblox.Vector3,
		CFrame = {
			new = function(...)
				return { ... }
			end,
		},
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
		Enum = setmetatable({}, {
			__index = function(self, key)
				local value = setmetatable({}, getmetatable(self))
				rawset(self, key, value)
				return value
			end,
		}),
		print = function() end,
	},
	injectGlobals = true,
})()

local function addOperative(operativeEntityId: string, userId: number, x: number, z: number)
	local root = {
		Position = roblox.Vector3.new(x, 2, z),
		IsA = function(_, className)
			return className == "BasePart"
		end,
	}
	local player = {
		UserId = userId,
		Character = {
			FindFirstChild = function(_, name)
				return if name == "HumanoidRootPart" then root else nil
			end,
		},
	}
	local entry = {
		operativeEntityId = operativeEntityId,
		revision = 0,
		snapshot = { operativeEntityId = operativeEntityId, lifeStateId = "Alive" },
	}
	table.insert(roster, entry)
	playersById[operativeEntityId] = player
	return player, root, entry
end

-- Full operation: insertion → infiltration pressure → three waves → holdout →
-- success stand-down.
enemyDirector.start()
mission.start()
local alpha, alphaRoot = addOperative("operative.player:1", 1, -224, -208)
local _bravo, bravoRoot = addOperative("operative.player:2", 2, -224, -200)

assert(not enemyDirector.readPressureState().isPressureActive, "pressure must wait for infiltration")
now = missionConfig.InsertionHoldSeconds
assert(mission.evaluateTimersAt(now).didChange)
local pressure = enemyDirector.readPressureState()
assert(pressure.isPressureActive and pressure.escalationLevel == 0, "infiltration must begin level-0 roaming pressure")

-- Objective completion spawns wave 1 as real production enemies.
alphaRoot.Position = roblox.Vector3.new(
	missionConfig.Objective.ConsolePosition.x - 2,
	missionConfig.Objective.ConsolePosition.y,
	missionConfig.Objective.ConsolePosition.z - 2
)
assert(mission.requestObjectiveInteraction(alpha).didChange)
assert(enemyDirector.readActiveEnemyCount() == #missionConfig.Escalation.Waves[1], "wave 1 must spawn immediately")
assert(enemyDirector.readPressureState().escalationLevel == 1)
assert(
	enemyDirector.readPressureState().recoveryWindowEndServerTimestamp
		== now + enemyConfig.Pressure.RecoveryWindowSeconds,
	"authored waves must open the recovery window"
)

-- Wave 2 on its deadline.
now += missionConfig.Escalation.SecondWaveDelaySeconds
assert(mission.evaluateTimersAt(now).didChange)
assert(enemyDirector.readActiveEnemyCount() == #missionConfig.Escalation.Waves[1] + #missionConfig.Escalation.Waves[2])
assert(enemyDirector.readPressureState().escalationLevel == 2)

-- Holdout begins when a survivor stands in the clearing; wave 3 spawns fairly
-- outside the darkness radius and immediately.
alphaRoot.Position = roblox.Vector3.new(missionConfig.Extraction.Position.x, 3, missionConfig.Extraction.Position.z)
bravoRoot.Position = roblox.Vector3.new(-224, 2, -200)
now += 5
assert(mission.evaluateExtractionPresenceAt(now).didChange)
assert(mission.read().phaseId == "Holdout")
local expectedTotal = #missionConfig.Escalation.Waves[1]
	+ #missionConfig.Escalation.Waves[2]
	+ #missionConfig.Escalation.Waves[3]
assert(
	enemyDirector.readActiveEnemyCount() == expectedTotal,
	"the holdout wave must spawn immediately from its fair authored positions"
)
assert(enemyDirector.readPressureState().pendingSpawnCount == 0, "no holdout spawn may defer against a centered squad")
assert(enemyDirector.readPressureState().escalationLevel == 3)

-- Enemies evaluate against the mission squad without erroring and stay
-- server-bounded.
local summary = enemyDirector.evaluateAt(now + 0.2)
assert(summary.attackCommittedCount == 0, "no enemy starts inside attack range")

-- Success resolution stands every enemy down.
now = mission.read().holdoutDeadlineServerTimestamp
assert(mission.evaluateTimersAt(now).didChange)
assert(mission.read().outcomeId == "Success")
local stood = enemyDirector.readPressureState()
assert(stood.isStoodDown and not stood.isPressureActive, "resolution must stand pressure down")
-- Even an adjacent operative draws no attacks after stand-down.
alphaRoot.Position = roblox.Vector3.new(300, 3, 110)
local afterStandDown = enemyDirector.evaluateAt(now + 1)
assert(afterStandDown.attackCommittedCount == 0 and #damageCalls == 0, "stood-down enemies never attack")
for _, fact in enemyDirector.readEnemyCombatFacts() do
	assert(fact.targetOperativeEntityId == nil, "stand-down must clear threat facts")
end

-- Squad wipe from any phase also stands pressure down.
mission.stop()
enemyDirector.stop()
table.clear(roster)
table.clear(playersById)
table.clear(admitted)
table.clear(damageCalls)
now = 1000
enemyDirector.start()
mission.start()
addOperative("operative.player:9", 9, -224, -208)
now = 1000 + missionConfig.InsertionHoldSeconds
mission.evaluateTimersAt(now)
assert(enemyDirector.readPressureState().isPressureActive)
failureSignal:Fire({ statusId = "Failed" })
assert(mission.read().outcomeId == "Failure")
assert(enemyDirector.readPressureState().isStoodDown, "squad wipe must stand pressure down")

-- Performance and surface audits: one heartbeat per director, no new remotes,
-- no client-side enemy authority.
assert(heartbeatSignal:count() == 1, "the enemy director owns exactly one heartbeat connection")
assert(missionHeartbeat:count() == 1, "the mission director owns exactly one heartbeat connection")
local project = fs.readFile("games/living-kingdoms/default.project.json")
assert(not string.find(project, "EnemyNetwork", 1, true), "P5 must not add an enemy remote surface")
local _, projectRemoteCount = string.gsub(project, '"%$className"%s*:%s*"RemoteEvent"', "")
assert(projectRemoteCount == 7, "the committed remote surface changed size")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
assert(
	string.find(clientBootstrap, "EnemyPresentationController.start()", 1, true) ~= nil,
	"clients may bootstrap bounded enemy presentation"
)
for _, prohibitedClientAuthority in
	{ "EnemyDirectorService", "EnemyBehaviorResolver", "EnemyCombatRuntime", "EnemyNetwork" }
do
	assert(
		not string.find(clientBootstrap, prohibitedClientAuthority, 1, true),
		"client bootstrap gained enemy authority: " .. prohibitedClientAuthority
	)
end
local directorSource = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local missionSource = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
for _, prohibited in { "OnServerEvent", "FireServer", "InvokeServer" } do
	assert(not string.find(directorSource, prohibited, 1, true), "enemy director gained a client path: " .. prohibited)
	assert(not string.find(missionSource, prohibited, 1, true), "mission director gained a client path: " .. prohibited)
end

mission.stop()
enemyDirector.stop()
assert(heartbeatSignal:count() == 0 and missionHeartbeat:count() == 0)

print(
	"P5IntegrationValidation: P5-0107 mission-driven pressure, waves, holdout fairness, stand-down, and audits passed"
)
