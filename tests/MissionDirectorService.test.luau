--!strict

-- Mission orchestration: phase machine, the authored objective chain
-- (relay -> booster -> optional floodlights), presence-driven server-owned
-- progression, extraction unlock, holdout resolution, wipe/disconnect handling,
-- 1/2/4-operative validation, and cleanup.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "mission director fixture assertion failed", 2)
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
local objectiveConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/ObjectiveChainConfig.luau", "ObjectiveChainConfig")
local objectiveResolver =
	loadSimple("games/living-kingdoms/src/shared/Mission/ObjectiveChainResolver.luau", "ObjectiveChainResolver")

-- The P10 terminal vocabulary, extraction window, and pure terminal resolver are
-- the production modules: the extraction sequence must be proven against the real
-- decision, not a stand-in.
local M_MISSION_TOKEN = {}
local M_LIFE_TOKEN = {}
local matchResultContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Mission/MatchResultContracts.luau"), {
		debugName = "MatchResultContracts",
		environment = {
			script = {
				Parent = {
					MissionContracts = M_MISSION_TOKEN,
					Parent = { Health = { OperativeLifeContracts = M_LIFE_TOKEN } },
				},
			},
			require = function(token)
				if token == M_MISSION_TOKEN then
					return contracts
				end
				return loadSimple(
					"games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau",
					"OperativeLifeContracts"
				)
			end,
		},
		injectGlobals = true,
	})()
local MATCH_CONTRACTS_TOKEN = {}
local matchResultConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MatchResultConfig.luau"), {
	debugName = "MatchResultConfig",
	environment = {
		script = { Parent = { Parent = { Mission = { MatchResultContracts = MATCH_CONTRACTS_TOKEN } } } },
		require = function()
			return matchResultContracts
		end,
	},
	injectGlobals = true,
})()
local terminalResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/TerminalResultResolver.luau"), {
		debugName = "TerminalResultResolver",
		environment = {
			game = {
				GetService = function()
					return { Shared = { Mission = { MatchResultContracts = MATCH_CONTRACTS_TOKEN } } }
				end,
			},
			require = function()
				return matchResultContracts
			end,
		},
		injectGlobals = true,
	})()

local relayCenter = objectiveConfig.Objectives[1].center
local boosterCenter = objectiveConfig.Objectives[2].center
local floodCenter = objectiveConfig.Objectives[3].center
local ENGINEER_CLASS_ID = objectiveConfig.AssistingClassId

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
local spawnedBosses = {}
local pressureBeginCalls = 0
local pressureEndCalls = 0
-- P10-0103: the extraction sequence begins only on the boss's authoritative defeat.
local bossDefeated = false
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
local resultBroadcasts = {}
local resultRemote = {
	FireAllClients = function(_, snapshot)
		table.insert(resultBroadcasts, snapshot)
	end,
	FireClient = function(_, player, snapshot)
		table.insert(resultBroadcasts, snapshot)
	end,
}
local missionNetwork = {
	WaitForChild = function(_, name)
		if name == "Result" then
			return resultRemote
		end
		assert(name == "State")
		return stateRemote
	end,
}

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local OBJECTIVE_CONFIG_TOKEN = {}
local OBJECTIVE_RESOLVER_TOKEN = {}
local CLASS_TOKEN = {}
local ENEMY_TOKEN = {}
local LIFE_TOKEN = {}
local FAILURE_TOKEN = {}
local MATCH_RESULT_TOKEN = {}
-- The P10-0104 contribution ledger is inert authority: these fixtures only need
-- to prove the owner records through it, never that recording changes gameplay.
local matchResultCalls = {}
local committedResultFacts = nil
local matchResultService = setmetatable({
	commitResult = function(facts)
		table.insert(matchResultCalls, { name = "commitResult", arguments = { facts } })
		committedResultFacts = facts
		return true
	end,
	readSafeResultSnapshot = function()
		return committedResultFacts
	end,
}, {
	__index = function(_self, key)
		return function(...)
			table.insert(matchResultCalls, { name = key, arguments = { ... } })
			return true
		end
	end,
})
local MATCH_CONFIG_TOKEN = {}
local TERMINAL_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Config = {
			MissionConfig = CONFIG_TOKEN,
			ObjectiveChainConfig = OBJECTIVE_CONFIG_TOKEN,
			MatchResultConfig = MATCH_CONFIG_TOKEN,
		},
		Mission = {
			MissionContracts = CONTRACTS_TOKEN,
			ObjectiveChainResolver = OBJECTIVE_RESOLVER_TOKEN,
			MatchResultContracts = MATCH_CONTRACTS_TOKEN,
		},
	},
	WaitForChild = function(_, name)
		assert(name == "MissionNetwork")
		return missionNetwork
	end,
}

local lifeByPlayer = {}
local playerById = {}
local classByOperative = {}
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
local classService = {
	readRoster = function()
		local assignments = {}
		for _, operativeEntityId in roster do
			table.insert(assignments, {
				operativeEntityId = operativeEntityId,
				classId = classByOperative[operativeEntityId] or "class.medic",
			})
		end
		return assignments
	end,
}
local failureState = { statusId = "Viable" }
local isAbandoned = false
local failureService = {
	read = function()
		return { revision = 1, state = { statusId = failureState.statusId } }
	end,
	readParticipationFacts = function()
		return { isAuthoritativelyAbandoned = isAbandoned }
	end,
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
	spawnBoss = function(position, floodlightsRestored)
		table.insert(spawnedBosses, { position = position, floodlightsRestored = floodlightsRestored })
		return true
	end,
	readBossState = function()
		return {
			exists = #spawnedBosses > 0,
			isAlive = not bossDefeated,
			isDefeated = bossDefeated,
			phaseId = "Carapace",
			isVulnerable = false,
		}
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
				ClassService = CLASS_TOKEN,
				EnemyDirectorService = ENEMY_TOKEN,
				MatchResultService = MATCH_RESULT_TOKEN,
				OperativeLifeService = LIFE_TOKEN,
				SquadFailureService = FAILURE_TOKEN,
				TerminalResultResolver = TERMINAL_TOKEN,
			},
		},
		require = function(token)
			if token == CONFIG_TOKEN then
				return config
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == OBJECTIVE_CONFIG_TOKEN then
				return objectiveConfig
			elseif token == OBJECTIVE_RESOLVER_TOKEN then
				return objectiveResolver
			elseif token == CLASS_TOKEN then
				return classService
			elseif token == ENEMY_TOKEN then
				return enemyDirector
			elseif token == LIFE_TOKEN then
				return lifeService
			elseif token == FAILURE_TOKEN then
				return failureService
			elseif token == MATCH_RESULT_TOKEN then
				return matchResultService
			elseif token == MATCH_CONTRACTS_TOKEN then
				return matchResultContracts
			elseif token == MATCH_CONFIG_TOKEN then
				return matchResultConfig
			elseif token == TERMINAL_TOKEN then
				return terminalResolver
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

local function admit(player, operativeEntityId: string, classId: string?, lifeStateId: string?)
	playerById[operativeEntityId] = player
	classByOperative[operativeEntityId] = classId or "class.medic"
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
	classByOperative[operativeEntityId] = nil
	local index = table.find(roster, operativeEntityId)
	if index ~= nil then
		table.remove(roster, index)
	end
	admitted[operativeEntityId] = nil
end

local function latestBroadcast()
	return broadcasts[#broadcasts]
end

local function vec(center, y: number?)
	return roblox.Vector3.new(center.x, y or center.y, center.z)
end

local function reset()
	service.stop()
	table.clear(lifeByPlayer)
	table.clear(playerById)
	table.clear(classByOperative)
	table.clear(roster)
	table.clear(connectedPlayers)
	table.clear(admitted)
	table.clear(broadcasts)
	table.clear(directMessages)
	table.clear(spawnedHostiles)
	table.clear(spawnedWaveIndexes)
	table.clear(spawnedBosses)
	table.clear(scheduled)
	table.clear(createdInstances)
	bossDefeated = false
	table.clear(matchResultCalls)
	table.clear(resultBroadcasts)
	committedResultFacts = nil
	failureState.statusId = "Viable"
	isAbandoned = false
	pressureBeginCalls = 0
	pressureEndCalls = 0
	beginOperationCalls = 0
	now = 0
	service.start()
end

-- Drive `count` one-second objective-presence samples, advancing the clock.
local function sampleObjective(count: number)
	for _ = 1, count do
		now += 1
		service.evaluateObjectivePresenceAt(now)
	end
end

local farPosition = roblox.Vector3.new(-224, 5, -320)

-- ===========================================================================
-- Scenario A: the full authored chain succeeds, with a mid-operation disconnect
-- and the optional engineer floodlight repair.
-- ===========================================================================
reset()
local alpha = makePlayer(1, farPosition)
local bravo = makePlayer(2, farPosition)
admit(alpha, "operative:alpha", ENGINEER_CLASS_ID)
admit(bravo, "operative:bravo", "class.medic")

local startSnapshot = latestBroadcast()
assert(startSnapshot ~= nil and contracts.validateSafeMissionSnapshot(startSnapshot))
assert(startSnapshot.phaseId == "Insertion" and startSnapshot.revision == 1)
assert(startSnapshot.radio.lineId == "InsertionComplete")
assert(startSnapshot.extractionUnlocked == false)
assert(startSnapshot.floodlightsRestored == false)
assert(#startSnapshot.objectives == 3, "the snapshot discloses all three authored objectives")
assert(startSnapshot.objectives[1].objectiveId == objectiveConfig.Objectives[1].objectiveId)
assert(startSnapshot.objectives[2].stateId == "Locked", "booster is locked until the relay is restored")
assert(findCreated("RelayConsole") ~= nil, "relay marker exists from insertion")
assert(findCreated("SignalBooster") ~= nil, "booster marker exists from insertion")
assert(findCreated("FloodlightArray") ~= nil, "floodlight marker exists from insertion")
assert(#scheduled >= 1, "insertion timer was not armed")

-- Objectives cannot progress before infiltration.
assert(service.evaluateObjectivePresenceAt(1).rejectionReasonId == "InvalidPhase")
assert(service.evaluateObjectivePresenceAt(0 / 0).rejectionReasonId == "InvalidTimestamp")
assert(not service.evaluateTimersAt(config.InsertionHoldSeconds - 0.01).didChange)

now = config.InsertionHoldSeconds
assert(service.evaluateTimersAt(now).didChange)
assert(service.read().phaseId == "Infiltration")
assert(service.read().activeObjectiveId == objectiveConfig.Objectives[1].objectiveId)
assert(beginOperationCalls == 1, "infiltration freezes the roster exactly once")
assert(pressureBeginCalls == 1, "infiltration begins roaming pressure exactly once")
assert(latestBroadcast().radio.lineId == "ProceedToObjective")

-- A late joiner receives the current snapshot directly.
local directMessageCountBeforeLateJoin = #directMessages
playersSignal:Fire(makePlayer(99))
assert(#directMessages == directMessageCountBeforeLateJoin + 1)
assert(directMessages[#directMessages].payload.phaseId == "Infiltration")

-- Objective 1: nobody in range makes no progress; the booster stays locked.
alpha.root.Position = farPosition
bravo.root.Position = farPosition
sampleObjective(4)
assert(
	service.read().objectiveProgressById[objectiveConfig.Objectives[1].objectiveId] == 0,
	"out-of-range yields no progress"
)
assert(service.read().objectiveCompletedById[objectiveConfig.Objectives[2].objectiveId] == false)

-- Move the squad onto the relay console; it is a held channel (~4s).
alpha.root.Position = vec(relayCenter)
bravo.root.Position = vec(relayCenter)
sampleObjective(3)
assert(
	service.read().objectiveCompletedById[objectiveConfig.Objectives[1].objectiveId] == false,
	"relay needs its full channel"
)
-- A downed teammate does not count toward the channel.
lifeByPlayer[bravo].snapshot.lifeStateId = "Incapacitated"
sampleObjective(1)
lifeByPlayer[bravo].snapshot.lifeStateId = "Alive"
sampleObjective(1)
local afterRelay = service.read()
assert(afterRelay.objectiveCompletedById[objectiveConfig.Objectives[1].objectiveId] == true, "relay restored")
assert(afterRelay.phaseId == "Infiltration", "restoring the relay does not unlock extraction")
assert(afterRelay.extractionUnlocked == false)
assert(
	afterRelay.activeObjectiveId == objectiveConfig.Objectives[2].objectiveId,
	"the booster is now the active objective"
)
assert(afterRelay.escalationLevel == 1, "relay completion advances mission depth")
assert(#spawnedHostiles == 0, "objectives must not inject discrete enemy waves")
assert(#spawnedWaveIndexes == 0, "continuous night pressure owns spawning")
assert(latestBroadcast().radio.lineId == "RelayRestored", "radio directs the squad to relocate")

-- Objective 2: relocate to the roadblock. Prove the decaying hold.
alpha.root.Position = vec(boosterCenter)
bravo.root.Position = vec(boosterCenter)
sampleObjective(10)
local boosterMid = service.read().objectiveProgressById[objectiveConfig.Objectives[2].objectiveId]
assert(boosterMid >= 9.5 and boosterMid <= 10.5, "booster charges while held")
-- Abandon the point: the charge decays and the snapshot flags it.
alpha.root.Position = farPosition
bravo.root.Position = farPosition
sampleObjective(2)
local boosterAfterDecay = service.read().objectiveProgressById[objectiveConfig.Objectives[2].objectiveId]
assert(boosterAfterDecay < boosterMid, "an abandoned booster decays")
local decaySnapshot = latestBroadcast()
for _, objective in decaySnapshot.objectives do
	if objective.objectiveId == objectiveConfig.Objectives[2].objectiveId then
		assert(objective.decaying == true, "the snapshot discloses the decaying hold")
	end
end
-- Mid-operation disconnect: bravo leaves; alpha finishes the charge alone.
disconnectOperative("operative:bravo")
alpha.root.Position = vec(boosterCenter)
sampleObjective(30)
local afterBooster = service.read()
assert(afterBooster.objectiveCompletedById[objectiveConfig.Objectives[2].objectiveId] == true, "booster charged")
assert(afterBooster.requiredChainComplete == true)
assert(afterBooster.phaseId == "Exfiltration", "charging the booster unlocks extraction")
assert(afterBooster.extractionUnlocked == true)
assert(afterBooster.escalationLevel == 2, "booster completion advances mission depth")
assert(#spawnedHostiles == 0, "booster completion must not inject a combat pack")
assert(latestBroadcast().radio.lineId == "BoosterCharged")
assert(findCreated("ExtractionBeacon") ~= nil, "extraction marker exists once unlocked")
assert(latestBroadcast().extractionUnlocked == true)
assert(contracts.validateSafeMissionSnapshot(latestBroadcast()))

-- Objective 3 (optional): the engineer restores the floodlights fast (~6s).
alpha.root.Position = vec(floodCenter)
assert(not service.evaluateExtractionPresenceAt(now).didChange, "the engineer is not in the clearing yet")
sampleObjective(6)
local afterFlood = service.read()
assert(afterFlood.floodlightsRestored == true, "the engineer restored the floodlights")
assert(afterFlood.objectiveCompletedById[objectiveConfig.Objectives[3].objectiveId] == true)
assert(latestBroadcast().floodlightsRestored == true)
assert(latestBroadcast().radio.lineId == "FloodlightsRestored")
assert(afterFlood.phaseId == "Exfiltration", "the optional objective never advances the phase")

-- Extraction presence begins the holdout; wave three converges.
alpha.root.Position = vec(config.Extraction.Position, 3)
now += 2
heartbeatSignal:Fire(config.ExtractionPresenceIntervalSeconds + 0.1)
local holdoutRead = service.read()
assert(holdoutRead.phaseId == "Holdout", "presence heartbeat begins the holdout")
-- P10-0103: the holdout is won by defeating the boss, not by a bare timer, so no
-- arrival countdown is disclosed while the boss lives.
assert(holdoutRead.holdoutDeadlineServerTimestamp == nil, "no countdown runs during the boss fight")
assert(holdoutRead.extractionReadinessStateId == "Locked", "extraction stays locked while the boss lives")
assert(holdoutRead.escalationLevel == 3)
assert(#spawnedHostiles == 0, "holdout transition must not inject a discrete wave")
-- The authored Progenitor boss spawns at the extraction clearing when the holdout
-- begins, carrying the P8 floodlight-repair fact.
assert(#spawnedBosses == 1, "the boss anchors the holdout")
assert(
	spawnedBosses[1].position == config.Extraction.Position and spawnedBosses[1].floodlightsRestored == true,
	"the boss spawns at the arena with the floodlight fact"
)
assert(latestBroadcast().radio.lineId == "HoldPosition")
assert(service.evaluateExtractionPresenceAt(now).rejectionReasonId == "InvalidPhase")
assert(
	service.evaluateObjectivePresenceAt(now).rejectionReasonId == "InvalidPhase",
	"objectives do not progress during holdout"
)

-- A living boss never resolves the operation, however long the squad holds.
now += 600
assert(not service.evaluateTimersAt(now).didChange, "a living boss cannot be waited out")
assert(service.read().phaseId == "Holdout")

-- Boss defeated: extraction becomes inbound for the configured arrival window.
bossDefeated = true
now += 1
assert(service.evaluateTimersAt(now).didChange, "the boss's defeat opens the extraction window")
local inbound = service.read()
assert(inbound.extractionReadinessStateId == "Inbound")
assert(inbound.holdoutDeadlineServerTimestamp == now + matchResultConfig.ExtractionArrivalWindowSeconds)
assert(inbound.phaseId == "Holdout", "the extraction window is not a new phase")
assert(inbound.outcomeId == nil, "the boss's defeat alone does not resolve the operation")
assert(latestBroadcast().radio.lineId == "ExtractionInbound")
assert(contracts.validateSafeMissionSnapshot(latestBroadcast()))

-- Success: a survivor is still inside the clearing when extraction arrives.
local holdoutDeadline = inbound.holdoutDeadlineServerTimestamp
assert(not service.evaluateTimersAt(holdoutDeadline - 0.01).didChange, "extraction cannot arrive early")
now = holdoutDeadline
assert(service.evaluateTimersAt(now).didChange)
local resolved = service.read()
assert(resolved.phaseId == "Resolved" and resolved.outcomeId == "Success")
assert(resolved.causeId == "Extracted", "a completed extraction carries the Extracted cause")
assert(resolved.extractionReadinessStateId == "Arrived")
assert(pressureEndCalls == 1, "resolution stands enemy pressure down exactly once")
assert(latestBroadcast().outcomeId == "Success")
assert(latestBroadcast().radio.lineId == "MissionSuccess")
assert(contracts.validateSafeMissionSnapshot(latestBroadcast()))
assert(not service.evaluateTimersAt(now + 100).didChange, "resolution is terminal")
assert(service.evaluateExtractionPresenceAt(now + 100).rejectionReasonId == "InvalidPhase")

-- P10-0104: the terminal boundary freezes and discloses exactly one debrief.
assert(#resultBroadcasts == 1, "resolution must disclose the result exactly once")
assert(committedResultFacts ~= nil, "the result must be committed to the ledger")
assert(committedResultFacts.causeId == "Extracted" and committedResultFacts.outcomeId == "Success")
assert(committedResultFacts.phaseReachedId == "Holdout", "the reported phase is the one the squad reached")
assert(committedResultFacts.bossDefeated == true, "the debrief carries the boss outcome")
assert(committedResultFacts.objectivesCompleted == 3, "the debrief counts every completed objective")
assert(committedResultFacts.wavesSurvived == 3, "the debrief carries the authored waves reached")
assert(committedResultFacts.durationSeconds > 0, "the debrief carries a positive duration")
-- Objective contribution is credited to the operatives the server sampled.
local objectiveCredits = 0
for _, call in matchResultCalls do
	if call.name == "recordObjectiveContribution" then
		objectiveCredits += 1
	end
end
assert(objectiveCredits >= 3, "each completed objective credits its workers")

-- ===========================================================================
-- Scenario B: nobody is inside the clearing when extraction lands.
-- ===========================================================================
reset()
local solo = makePlayer(10, farPosition)
admit(solo, "operative:solo", "class.combat-specialist")
now = config.InsertionHoldSeconds
service.evaluateTimersAt(now)
solo.root.Position = vec(relayCenter)
sampleObjective(4)
assert(service.read().objectiveCompletedById[objectiveConfig.Objectives[1].objectiveId] == true)
solo.root.Position = vec(boosterCenter)
sampleObjective(24)
assert(service.read().phaseId == "Exfiltration", "solo squad can charge the booster (no class gate)")
solo.root.Position = vec(config.Extraction.Position, 3)
now += 5
assert(service.evaluateExtractionPresenceAt(now).didChange)
bossDefeated = true
now += 1
assert(service.evaluateTimersAt(now).didChange, "the boss's defeat opens the window")
local soloDeadline = service.read().holdoutDeadlineServerTimestamp
-- Stepping out of the clearing is not a terminal failure: the only failures are a
-- committed squad wipe and authoritative abandonment, so extraction simply has
-- not arrived yet.
solo.root.Position = farPosition
now = soloDeadline + 30
assert(not service.evaluateTimersAt(now).didChange, "an empty clearing cannot extract")
local waiting = service.read()
assert(waiting.phaseId == "Holdout" and waiting.outcomeId == nil, "a missed extraction is not a failure")
assert(waiting.extractionReadinessStateId == "Inbound", "extraction stays inbound until someone is present")
-- Walking back in extracts, however late.
solo.root.Position = vec(config.Extraction.Position, 3)
now += 5
assert(service.evaluateTimersAt(now).didChange)
assert(service.read().outcomeId == "Success" and service.read().causeId == "Extracted")

-- ===========================================================================
-- Scenario C: squad wipe fails the mission from any phase.
-- ===========================================================================
reset()
local victim = makePlayer(20, farPosition)
admit(victim, "operative:victim")
now = config.InsertionHoldSeconds
service.evaluateTimersAt(now)
assert(service.read().phaseId == "Infiltration")
failureState.statusId = "Failed"
failureSignal:Fire({ statusId = "Failed" }, 3)
assert(service.read().phaseId == "Resolved" and service.read().outcomeId == "Failure")
assert(service.read().causeId == "SquadWipe", "a committed wipe carries the SquadWipe cause")
assert(latestBroadcast().outcomeId == "Failure")
failureSignal:Fire({ statusId = "Viable" }, 4)
assert(service.read().outcomeId == "Failure", "later viability cannot undo resolution")

-- ===========================================================================
-- Scenario D: full-squad disconnect reported as failure surfaces the same way.
-- ===========================================================================
reset()
local leaver = makePlayer(30, farPosition)
admit(leaver, "operative:leaver")
disconnectOperative("operative:leaver")
failureState.statusId = "Failed"
isAbandoned = true
failureSignal:Fire({ statusId = "Failed" }, 1)
assert(service.read().phaseId == "Resolved" and service.read().outcomeId == "Failure")
assert(service.read().causeId == "Abandoned", "an authoritative abandonment resolves as Abandoned, not as a squad wipe")

-- ===========================================================================
-- Scenario E: stop() cleans up and the service refuses further authority.
-- ===========================================================================
local folder = findCreated("MissionObjects")
assert(folder ~= nil)
service.stop()
assert(folder._destroyed == true, "mission objects must be destroyed on stop")
assert(service.evaluateObjectivePresenceAt(1).rejectionReasonId == "ServiceStopped")
assert(service.evaluateTimersAt(1).rejectionReasonId == "ServiceStopped")
assert(service.evaluateExtractionPresenceAt(1).rejectionReasonId == "ServiceStopped")
assert(service.read().revision == 0 and service.read().phaseId == "Insertion")
service.stop()

-- Restart produces a fresh mission with a fresh chain.
now = 500
table.clear(connectedPlayers)
service.start()
assert(service.read().revision == 1 and service.read().phaseId == "Insertion")
assert(service.read().insertionDeadlineServerTimestamp == nil, "empty servers must not consume insertion")
assert(
	service.read().objectiveCompletedById[objectiveConfig.Objectives[1].objectiveId] == false,
	"chain resets on restart"
)
playersSignal:Fire(makePlayer(501, farPosition))
assert(service.read().insertionDeadlineServerTimestamp == 500 + config.InsertionHoldSeconds)
service.stop()

-- ===========================================================================
-- Scenario F: the full chain completes for 1, 2, and 4 operatives (P8-0108).
-- ===========================================================================
local function runFullChain(operativeCount: number)
	reset()
	local squad = {}
	for index = 1, operativeCount do
		local player = makePlayer(1000 + index, farPosition)
		-- Mixed composition; only the first is an engineer.
		local classId = if index == 1 then ENGINEER_CLASS_ID else "class.medic"
		admit(player, "operative:squad-" .. index, classId)
		table.insert(squad, player)
	end
	now = config.InsertionHoldSeconds
	service.evaluateTimersAt(now)
	assert(service.read().phaseId == "Infiltration")

	local function moveSquad(position)
		for _, player in squad do
			player.root.Position = position
		end
	end

	moveSquad(vec(relayCenter))
	sampleObjective(5)
	assert(
		service.read().objectiveCompletedById[objectiveConfig.Objectives[1].objectiveId] == true,
		"relay for " .. operativeCount
	)

	moveSquad(vec(boosterCenter))
	sampleObjective(26)
	assert(service.read().phaseId == "Exfiltration", "booster for " .. operativeCount)
	assert(service.read().extractionUnlocked == true)

	-- Skip the optional floodlights for the multi-operative runs to prove it is
	-- never required for extraction.
	moveSquad(vec(config.Extraction.Position, 3))
	now += 5
	assert(service.evaluateExtractionPresenceAt(now).didChange, "holdout for " .. operativeCount)
	bossDefeated = true
	now += 1
	assert(service.evaluateTimersAt(now).didChange, "boss defeat for " .. operativeCount)
	local deadline = service.read().holdoutDeadlineServerTimestamp
	now = deadline
	assert(service.evaluateTimersAt(now).didChange)
	assert(service.read().outcomeId == "Success", "the squad extracts for " .. operativeCount .. " operatives")
	assert(service.read().causeId == "Extracted", "extraction cause for " .. operativeCount)
	assert(service.read().floodlightsRestored == false, "the optional objective was skippable")
end

runFullChain(1)
runFullChain(2)
runFullChain(4)
service.stop()

-- ===========================================================================
-- Bootstrap and authority-boundary wiring.
-- ===========================================================================
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

print(
	"MissionDirectorService: phases, authored objective chain, relocation, extraction, holdout, wipe, disconnect, 1/2/4 validation, and cleanup passed"
)
