--!strict

-- P5-0103 mission orchestration: phase machine, authoritative objective,
-- extraction unlock, holdout resolution, wipe/disconnect handling, cleanup.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0103 director fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local config = loadSimple("games/living-kingdoms/src/shared/Config/MissionConfig.luau", "MissionConfig")

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
	return value
end

-- Instance double: enough surface for the mission director's graybox objects.
local createdInstances = {}
local function fakeInstance(className: string)
	local attributes = {}
	local instance = {}
	instance.ClassName = className
	instance.Name = className
	function instance.SetAttribute(_, attributeName, value)
		attributes[attributeName] = value
	end
	function instance.GetAttribute(_, attributeName)
		return attributes[attributeName]
	end
	function instance.Destroy(_)
		instance._destroyed = true
	end
	function instance.FindFirstChild(_, _childName)
		return nil
	end
	function instance.IsA(_, otherClassName)
		return otherClassName == className
	end
	table.insert(createdInstances, instance)
	return instance
end

local function findCreated(name: string)
	for index = #createdInstances, 1, -1 do
		if createdInstances[index].Name == name then
			return createdInstances[index]
		end
	end
	return nil
end

local now = 0
local scheduled = {}
local broadcasts = {}
local directMessages = {}
local spawnedHostiles = {}
local spawnedWaveIndexes = {}
local pressureBeginCalls = 0
local pressureEndCalls = 0
local beginOperationCalls = 0

local workspaceMock = {
	GetServerTimeNow = function()
		return now
	end,
	FindFirstChild = function()
		return nil
	end,
}
local taskMock = {
	delay = function(delaySeconds, callback)
		local handle = { delaySeconds = delaySeconds, callback = callback, cancelled = false }
		table.insert(scheduled, handle)
		return handle
	end,
	cancel = function(handle)
		handle.cancelled = true
	end,
}
local playersSignal = signal()
local heartbeatSignal = signal()
local failureSignal = signal()
local connectedPlayers = {}
local playersMock = {
	PlayerAdded = playersSignal,
	GetPlayers = function()
		return table.clone(connectedPlayers)
	end,
}
local runServiceMock = { Heartbeat = heartbeatSignal }
local stateRemote = {
	FireAllClients = function(_, payload)
		table.insert(broadcasts, payload)
	end,
	FireClient = function(_, player, payload)
		table.insert(directMessages, { player = player, payload = payload })
	end,
}
local missionNetwork = {
	WaitForChild = function(_, name)
		assert(name == "State")
		return stateRemote
	end,
}

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local ENEMY_TOKEN = {}
local LIFE_TOKEN = {}
local FAILURE_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Config = { MissionConfig = CONFIG_TOKEN },
		Mission = { MissionContracts = CONTRACTS_TOKEN },
	},
	WaitForChild = function(_, name)
		assert(name == "MissionNetwork")
		return missionNetwork
	end,
}

local lifeByPlayer = {}
local playerById = {}
local roster = {}
local admitted = {}
local lifeService = {
	read = function(player)
		return lifeByPlayer[player]
	end,
	readAll = function()
		local reads = {}
		for _, operativeEntityId in roster do
			local player = playerById[operativeEntityId]
			local read = if player == nil then nil else lifeByPlayer[player]
			if read ~= nil then
				table.insert(reads, {
					operativeEntityId = operativeEntityId,
					revision = read.revision,
					snapshot = read.snapshot,
				})
			end
		end
		return reads
	end,
	playerForOperativeEntityId = function(operativeEntityId)
		return playerById[operativeEntityId]
	end,
}
local failureService = {
	beginOperation = function()
		beginOperationCalls += 1
		table.clear(admitted)
		for _, operativeEntityId in roster do
			admitted[operativeEntityId] = true
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
local enemyDirector = {
	spawnAuthoredWave = function(waveIndex, definitions)
		table.insert(spawnedWaveIndexes, waveIndex)
		for _, definition in definitions do
			table.insert(spawnedHostiles, definition)
		end
		return #definitions
	end,
	beginOperationPressure = function()
		pressureBeginCalls += 1
	end,
	endOperationPressure = function()
		pressureEndCalls += 1
	end,
}

local autoEnum = setmetatable({}, {
	__index = function(self, key)
		local value = setmetatable({}, getmetatable(self))
		rawset(self, key, value)
		return value
	end,
})

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau"), {
	debugName = "MissionDirectorService",
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return playersMock
				elseif name == "ReplicatedStorage" then
					return replicatedStorage
				elseif name == "RunService" then
					return runServiceMock
				end
				return workspaceMock
			end,
		},
		script = {
			Parent = {
				EnemyDirectorService = ENEMY_TOKEN,
				OperativeLifeService = LIFE_TOKEN,
				SquadFailureService = FAILURE_TOKEN,
			},
		},
		require = function(token)
			if token == CONFIG_TOKEN then
				return config
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == ENEMY_TOKEN then
				return enemyDirector
			elseif token == LIFE_TOKEN then
				return lifeService
			elseif token == FAILURE_TOKEN then
				return failureService
			end
			error("unexpected MissionDirectorService dependency")
		end,
		task = taskMock,
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
		Enum = autoEnum,
		print = function() end,
	},
	injectGlobals = true,
})()

local function makePlayer(userId: number, position)
	local root = {
		Position = position or roblox.Vector3.zero,
		IsA = function(_, className)
			return className == "BasePart"
		end,
	}
	local character = {
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
	}
	return { UserId = userId, Character = character, root = root }
end

local function admit(player, operativeEntityId: string, lifeStateId: string?)
	playerById[operativeEntityId] = player
	lifeByPlayer[player] = {
		revision = 0,
		snapshot = { operativeEntityId = operativeEntityId, lifeStateId = lifeStateId or "Alive" },
	}
	table.insert(roster, operativeEntityId)
	table.insert(connectedPlayers, player)
	playersSignal:Fire(player)
end

local function disconnectOperative(operativeEntityId: string)
	local player = playerById[operativeEntityId]
	playerById[operativeEntityId] = nil
	if player ~= nil then
		lifeByPlayer[player] = nil
	end
	local index = table.find(roster, operativeEntityId)
	if index ~= nil then
		table.remove(roster, index)
	end
	admitted[operativeEntityId] = nil
end

local function latestBroadcast()
	return broadcasts[#broadcasts]
end

local function reset()
	service.stop()
	table.clear(lifeByPlayer)
	table.clear(playerById)
	table.clear(roster)
	table.clear(connectedPlayers)
	table.clear(admitted)
	table.clear(broadcasts)
	table.clear(directMessages)
	table.clear(spawnedHostiles)
	table.clear(spawnedWaveIndexes)
	table.clear(scheduled)
	table.clear(createdInstances)
	pressureBeginCalls = 0
	pressureEndCalls = 0
	beginOperationCalls = 0
	now = 0
	service.start()
end

local consolePosition = roblox.Vector3.new(
	config.Objective.ConsolePosition.x - 3,
	config.Objective.ConsolePosition.y,
	config.Objective.ConsolePosition.z - 3
)
local clearingPosition = roblox.Vector3.new(config.Extraction.Position.x, 3, config.Extraction.Position.z)
local farPosition = roblox.Vector3.new(-224, 5, -208)

-- Scenario A: full mission success with a mid-operation disconnect.
reset()
local alpha = makePlayer(1, farPosition)
local bravo = makePlayer(2, farPosition)
admit(alpha, "operative:alpha")
admit(bravo, "operative:bravo")

local startSnapshot = latestBroadcast()
assert(startSnapshot ~= nil and contracts.validateSafeMissionSnapshot(startSnapshot))
assert(startSnapshot.phaseId == "Insertion" and startSnapshot.revision == 1)
assert(startSnapshot.radio.lineId == "InsertionComplete")
assert(startSnapshot.extractionUnlocked == false)
assert(findCreated("RelayConsole") ~= nil, "objective console must exist from insertion")
assert(findCreated("RestoreRelayPrompt") ~= nil)
assert(findCreated("RestoreRelayPrompt").Enabled == false, "prompt must stay disabled during insertion")
assert(#scheduled >= 1, "insertion timer was not armed")

assert(service.requestObjectiveInteraction(alpha).rejectionReasonId == "InvalidPhase")
assert(service.evaluateTimersAt(0 / 0).rejectionReasonId == "InvalidTimestamp")
assert(service.evaluateTimersAt(-1).rejectionReasonId == "InvalidTimestamp")
assert(not service.evaluateTimersAt(config.InsertionHoldSeconds - 0.01).didChange)
assert(service.read().phaseId == "Insertion")

now = config.InsertionHoldSeconds
assert(service.evaluateTimersAt(now).didChange)
assert(service.read().phaseId == "Infiltration")
assert(service.read().objectiveStateId == "Active")
assert(beginOperationCalls == 1, "infiltration must freeze the operation roster exactly once")
assert(pressureBeginCalls == 1, "infiltration must begin roaming pressure exactly once")
assert(findCreated("RestoreRelayPrompt").Enabled == true)
assert(latestBroadcast().radio.lineId == "ProceedToObjective")
assert(contracts.validateSafeMissionSnapshot(latestBroadcast()))

-- New joiner receives the current snapshot directly.
local directMessageCountBeforeLateJoin = #directMessages
playersSignal:Fire(makePlayer(99))
assert(#directMessages == directMessageCountBeforeLateJoin + 1)
assert(directMessages[#directMessages].payload.phaseId == "Infiltration")

-- Objective validation chain.
local ghost = makePlayer(3, consolePosition)
assert(service.requestObjectiveInteraction(ghost).rejectionReasonId == "UnknownOperative")
lifeByPlayer[bravo].snapshot.lifeStateId = "Incapacitated"
bravo.root.Position = consolePosition
assert(service.requestObjectiveInteraction(bravo).rejectionReasonId == "InvalidLifeState")
lifeByPlayer[bravo].snapshot.lifeStateId = "Alive"
bravo.root.Position = farPosition
local savedCharacter = alpha.Character
alpha.Character = nil
assert(service.requestObjectiveInteraction(alpha).rejectionReasonId == "MissingPosition")
alpha.Character = savedCharacter
assert(service.requestObjectiveInteraction(alpha).rejectionReasonId == "OutOfRange")

alpha.root.Position = consolePosition
local completion = service.requestObjectiveInteraction(alpha)
assert(completion.didChange, completion.rejectionReasonId)
local afterObjective = service.read()
assert(afterObjective.phaseId == "Exfiltration")
assert(afterObjective.objectiveStateId == "Completed")
assert(afterObjective.extractionUnlocked == true)
assert(afterObjective.escalationLevel == 1)
assert(afterObjective.objectiveCompletedByOperativeEntityId == "operative:alpha")
assert(afterObjective.objectiveCompletedAtServerTimestamp == now)
assert(
	#spawnedHostiles == #config.Escalation.Waves[1],
	"objective completion spawns the configured first escalation wave"
)
assert(spawnedHostiles[1].id == config.Escalation.Waves[1][1].id)
assert(spawnedWaveIndexes[1] == 1, "the first wave must carry its escalation index to the director")
assert(latestBroadcast().radio.lineId == "ObjectiveComplete")
assert(latestBroadcast().extractionUnlocked == true)
assert(latestBroadcast().objectiveText == config.ObjectiveTextByPhase.Exfiltration)
assert(contracts.validateSafeMissionSnapshot(latestBroadcast()))
assert(findCreated("ExtractionBeacon") ~= nil, "extraction marker must exist once unlocked")
assert(findCreated("RestoreRelayPrompt")._destroyed == true, "objective cannot be interacted with twice")
assert(findCreated("StatusLamp"):GetAttribute("RelayRestored") == true)

assert(service.requestObjectiveInteraction(alpha).rejectionReasonId == "AlreadyCompleted")
assert(service.requestObjectiveInteraction(bravo).rejectionReasonId == "AlreadyCompleted")

-- The completing operative disconnecting must not regress mission state.
disconnectOperative("operative:alpha")
assert(service.read().phaseId == "Exfiltration")
assert(service.read().objectiveStateId == "Completed")

-- Second escalation wave fires on its authored deadline, exactly once.
local objectiveCompletedAt = afterObjective.objectiveCompletedAtServerTimestamp
now = objectiveCompletedAt + config.Escalation.SecondWaveDelaySeconds
assert(service.evaluateTimersAt(now).didChange)
assert(
	#spawnedHostiles == #config.Escalation.Waves[1] + #config.Escalation.Waves[2],
	"second escalation appends the configured second wave"
)
assert(service.read().escalationLevel == 2)
assert(latestBroadcast().radio.lineId == "PressureRising")
assert(not service.evaluateTimersAt(now + 1).didChange)
assert(#spawnedHostiles == #config.Escalation.Waves[1] + #config.Escalation.Waves[2], "second wave must not respawn")

-- Holdout requires an admitted, alive survivor inside the clearing.
assert(not service.evaluateExtractionPresenceAt(now).didChange)
bravo.root.Position = clearingPosition
lifeByPlayer[bravo].snapshot.lifeStateId = "Incapacitated"
assert(not service.evaluateExtractionPresenceAt(now).didChange, "downed operatives cannot trigger extraction")
lifeByPlayer[bravo].snapshot.lifeStateId = "Alive"
now += 2
heartbeatSignal:Fire(config.ExtractionPresenceIntervalSeconds + 0.1)
local holdoutRead = service.read()
assert(holdoutRead.phaseId == "Holdout", "presence heartbeat must begin holdout")
assert(holdoutRead.holdoutDeadlineServerTimestamp == now + config.Extraction.ArrivalSeconds)
assert(holdoutRead.escalationLevel == 3)
assert(#spawnedHostiles == #config.Escalation.Waves[1] + #config.Escalation.Waves[2] + #config.Escalation.Waves[3])
assert(latestBroadcast().radio.lineId == "HoldPosition")
assert(latestBroadcast().holdoutDeadlineServerTimestamp == holdoutRead.holdoutDeadlineServerTimestamp)
assert(service.evaluateExtractionPresenceAt(now).rejectionReasonId == "InvalidPhase")

-- Success: a survivor is still inside the clearing when extraction arrives.
local holdoutDeadline = holdoutRead.holdoutDeadlineServerTimestamp
assert(not service.evaluateTimersAt(holdoutDeadline - 0.01).didChange)
now = holdoutDeadline
assert(service.evaluateTimersAt(now).didChange)
local resolved = service.read()
assert(resolved.phaseId == "Resolved" and resolved.outcomeId == "Success")
assert(pressureEndCalls == 1, "resolution must stand enemy pressure down exactly once")
assert(latestBroadcast().outcomeId == "Success")
assert(latestBroadcast().radio.lineId == "MissionSuccess")
assert(contracts.validateSafeMissionSnapshot(latestBroadcast()))
assert(not service.evaluateTimersAt(now + 100).didChange, "resolution is terminal")
assert(service.evaluateExtractionPresenceAt(now + 100).rejectionReasonId == "InvalidPhase")
assert(service.requestObjectiveInteraction(bravo).rejectionReasonId == "AlreadyCompleted")

-- Scenario B: extraction arrives with nobody left inside the clearing.
reset()
local solo = makePlayer(10, farPosition)
admit(solo, "operative:solo")
now = config.InsertionHoldSeconds
service.evaluateTimersAt(now)
solo.root.Position = consolePosition
assert(service.requestObjectiveInteraction(solo).didChange)
solo.root.Position = clearingPosition
now += 5
assert(service.evaluateExtractionPresenceAt(now).didChange)
local soloDeadline = service.read().holdoutDeadlineServerTimestamp
solo.root.Position = farPosition
now = soloDeadline
assert(service.evaluateTimersAt(now).didChange)
assert(service.read().outcomeId == "Failure", "leaving the clearing before arrival fails the mission")
assert(latestBroadcast().radio.lineId == "MissionFailure")

-- Scenario B2: the only survivor dies inside the clearing during holdout.
reset()
local doomed = makePlayer(11, farPosition)
admit(doomed, "operative:doomed")
now = config.InsertionHoldSeconds
service.evaluateTimersAt(now)
doomed.root.Position = consolePosition
assert(service.requestObjectiveInteraction(doomed).didChange)
doomed.root.Position = clearingPosition
now += 5
assert(service.evaluateExtractionPresenceAt(now).didChange)
lifeByPlayer[doomed].snapshot.lifeStateId = "Dead"
now = service.read().holdoutDeadlineServerTimestamp
assert(service.evaluateTimersAt(now).didChange)
assert(service.read().outcomeId == "Failure", "a dead squad cannot extract")

-- Scenario C: squad wipe fails the mission from any phase.
reset()
local victim = makePlayer(20, farPosition)
admit(victim, "operative:victim")
now = config.InsertionHoldSeconds
service.evaluateTimersAt(now)
assert(service.read().phaseId == "Infiltration")
failureSignal:Fire({ statusId = "Failed" }, 3)
assert(service.read().phaseId == "Resolved" and service.read().outcomeId == "Failure")
assert(latestBroadcast().outcomeId == "Failure")
failureSignal:Fire({ statusId = "Viable" }, 4)
assert(service.read().outcomeId == "Failure", "later viability cannot undo resolution")

-- Scenario D: full-squad disconnect reported as failure surfaces the same way.
reset()
local leaver = makePlayer(30, farPosition)
admit(leaver, "operative:leaver")
disconnectOperative("operative:leaver")
failureSignal:Fire({ statusId = "Failed" }, 1)
assert(service.read().phaseId == "Resolved" and service.read().outcomeId == "Failure")

-- Scenario E: stop() cleans up and the service refuses further authority.
local folder = findCreated("MissionObjects")
assert(folder ~= nil)
service.stop()
assert(folder._destroyed == true, "mission objects must be destroyed on stop")
assert(service.requestObjectiveInteraction(leaver).rejectionReasonId == "ServiceStopped")
assert(service.evaluateTimersAt(1).rejectionReasonId == "ServiceStopped")
assert(service.evaluateExtractionPresenceAt(1).rejectionReasonId == "ServiceStopped")
assert(service.read().revision == 0 and service.read().phaseId == "Insertion")
service.stop()

-- Restart produces a fresh mission.
now = 500
table.clear(connectedPlayers)
service.start()
assert(service.read().revision == 1 and service.read().phaseId == "Insertion")
assert(service.read().insertionDeadlineServerTimestamp == nil, "empty servers must not consume insertion")
playersSignal:Fire(makePlayer(501, farPosition))
assert(service.read().insertionDeadlineServerTimestamp == 500 + config.InsertionHoldSeconds)
service.stop()

-- Bootstrap and authority-boundary wiring.
local project = fs.readFile("games/living-kingdoms/default.project.json")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local controllerSource = fs.readFile("games/living-kingdoms/src/client/Controllers/MissionController.luau")
assert(string.find(project, '"MissionNetwork"', 1, true))
assert(string.find(serverBootstrap, "MissionDirectorService.start()", 1, true))
local _, missionStartCount = string.gsub(serverBootstrap, "MissionDirectorService.start%(%s*%)", "")
local _, classStartCount = string.gsub(serverBootstrap, "ClassService.start%(%s*%)", "")
assert(missionStartCount == 1, "mission director must start exactly once")
assert(classStartCount == 1, "class service must start exactly once")
assert(string.find(clientBootstrap, "MissionController.start()", 1, true))
for _, prohibited in { "OnServerEvent", "FireServer", "InvokeServer", "RemoteFunction" } do
	assert(
		not string.find(serviceSource, prohibited, 1, true),
		"mission director must accept no client remote: " .. prohibited
	)
end
for _, prohibited in { "FireServer", "InvokeServer" } do
	assert(
		not string.find(controllerSource, prohibited, 1, true),
		"mission controller must send nothing: " .. prohibited
	)
end

print("MissionDirectorService: P5-0103 phases, objective, extraction, holdout, wipe, disconnect, and cleanup passed")
