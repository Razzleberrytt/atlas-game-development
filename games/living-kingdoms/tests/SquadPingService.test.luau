--!strict

-- LK-0407 server ownership, isolation, validation, limits, expiry, and cleanup.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "LK-0407 service fixture assertion failed", 2)
	end
end

local function robloxTypeof(value: unknown): string
	if type(value) == "userdata" then
		return "Vector3"
	end
	return type(value)
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = { typeof = robloxTypeof },
		injectGlobals = true,
	})()
end

local config = loadSimple("games/living-kingdoms/src/shared/Config/SquadPingConfig.luau", "SquadPingConfig")
local contracts =
	loadSimple("games/living-kingdoms/src/shared/Navigation/SquadPingContracts.luau", "SquadPingContracts")

assert(config.LifetimeSeconds == 6)
assert(config.CooldownSeconds == 1.5)
assert(config.MaximumActivePerSender == 1)
assert(config.MaximumActivePerSquad == 4)
assert(config.MaximumDistanceStuds == 120)
assert(config.QuantizationStuds >= 2 and config.QuantizationStuds <= 4)
assert(config.KeyboardKeyCodeName ~= "F" and config.GamepadKeyCodeName ~= "ButtonY")

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
	function value:Listeners()
		return table.clone(listeners)
	end
	return value
end

local now = 0
local scheduled = {}
local workspace = {
	GetServerTimeNow = function()
		return now
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
local runService = {
	IsStudio = function()
		return false
	end,
}
local serverStorage = {}
local intentSignal = signal()
local stateMessages = {}
local intentRemote = { OnServerEvent = intentSignal }
local stateRemote = {
	FireClient = function(_, player, payload)
		table.insert(stateMessages, { player = player, payload = payload })
	end,
}
local network = {
	WaitForChild = function(_, name)
		return if name == "Intent" then intentRemote else stateRemote
	end,
}

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local LIFE_TOKEN = {}
local PROGRESSION_CONFIG_TOKEN = {}
local PROGRESSION_SERVICE_TOKEN = {}
local progressionConfig = {
	UnlockIds = {
		SquadRallyPing = "squad-rally-ping",
	},
}
local replicatedStorage = {
	Shared = {
		Config = {
			SquadPingConfig = CONFIG_TOKEN,
			OperativeProgressionConfig = PROGRESSION_CONFIG_TOKEN,
		},
		Navigation = { SquadPingContracts = CONTRACTS_TOKEN },
	},
	WaitForChild = function(_, name)
		assert(name == "SquadPingNetwork")
		return network
	end,
}

local lifeByPlayer = {}
local playerById = {}
local roster = {}
local lifeSignal = signal()
local rosterSignal = signal()
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
	subscribe = function(callback)
		return lifeSignal:Connect(callback)
	end,
	subscribeRoster = function(callback)
		return rosterSignal:Connect(callback)
	end,
}

local unlockedByUserId = {}
local progressionCalls = {}
local progressionService = {
	hasOwnedUnlock = function(requesterId, ownerId, unlockId)
		table.insert(progressionCalls, {
			requesterId = requesterId,
			ownerId = ownerId,
			unlockId = unlockId,
		})
		return unlockedByUserId[ownerId] == true
	end,
}

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/SquadPingService.luau"), {
	debugName = "SquadPingService",
	environment = {
		game = {
			GetService = function(_, name)
				if name == "ReplicatedStorage" then
					return replicatedStorage
				elseif name == "RunService" then
					return runService
				elseif name == "ServerStorage" then
					return serverStorage
				end
				return workspace
			end,
		},
		script = {
			Parent = {
				OperativeLifeService = LIFE_TOKEN,
				OperativeProgressionService = PROGRESSION_SERVICE_TOKEN,
			},
		},
		require = function(token)
			if token == CONFIG_TOKEN then
				return config
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == LIFE_TOKEN then
				return lifeService
			elseif token == PROGRESSION_CONFIG_TOKEN then
				return progressionConfig
			elseif token == PROGRESSION_SERVICE_TOKEN then
				return progressionService
			end
			error("unexpected SquadPingService dependency")
		end,
		task = taskMock,
		typeof = robloxTypeof,
		Vector3 = roblox.Vector3,
	},
	injectGlobals = true,
})()

local function makePlayer(userId, position)
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

local function admit(player, operativeEntityId, lifeStateId)
	playerById[operativeEntityId] = player
	lifeByPlayer[player] = {
		revision = 0,
		snapshot = { operativeEntityId = operativeEntityId, lifeStateId = lifeStateId or "Alive" },
	}
	table.insert(roster, operativeEntityId)
end

local function intent(position, categoryId)
	return {
		categoryId = categoryId or contracts.CategoryIds.Location,
		candidatePosition = position,
	}
end

local function latestFor(player)
	for index = #stateMessages, 1, -1 do
		if stateMessages[index].player == player then
			return stateMessages[index].payload
		end
	end
	return nil
end

local function reset()
	service.stop()
	table.clear(lifeByPlayer)
	table.clear(playerById)
	table.clear(roster)
	table.clear(stateMessages)
	table.clear(scheduled)
	table.clear(unlockedByUserId)
	table.clear(progressionCalls)
	now = 0
	service.start()
end

reset()
local alpha = makePlayer(1)
local bravo = makePlayer(2)
local outsider = makePlayer(3)
admit(alpha, "operative:alpha")
admit(bravo, "operative:bravo")
admit(outsider, "operative:outsider")
assert(service.registerOperative("operative:alpha", alpha, "squad:a").didChange)
assert(service.registerOperative("operative:bravo", bravo, "squad:a").didChange)
assert(service.registerOperative("operative:outsider", outsider, "squad:b").didChange)
assert(service.registerOperative("operative:alpha", alpha, "squad:a").rejectionReasonId == "StateMismatch")
assert(service.registerOperative("missing", {}, "squad:a").rejectionReasonId == "StateMismatch")
assert(service.registerOperative("valid", nil, "squad:a").rejectionReasonId == "InvalidSender")
assert(service.setOperativeSquad("missing", "squad:a").rejectionReasonId == "UnknownOperative")
assert(service.setOperativeSquad("operative:alpha", "").rejectionReasonId == "InvalidSquad")

now = 10
local accepted = service.requestPing(alpha, intent(roblox.Vector3.new(9.9, 0, -5)))
assert(accepted.didChange and accepted.lifecycleId == "Active")
assert(accepted.ping.pingId == "ping:1" and accepted.ping.revision == 1)
assert(accepted.ping.categoryId == contracts.CategoryIds.Location, "locked player must publish Location")
assert(#progressionCalls == 1)
assert(progressionCalls[1].requesterId == alpha.UserId and progressionCalls[1].ownerId == alpha.UserId)
assert(progressionCalls[1].unlockId == progressionConfig.UnlockIds.SquadRallyPing)
assert(accepted.ping.position == roblox.Vector3.new(8, 0, -4), "position must be sender-relative quantized")
assert(accepted.ping.expiresAtServerTimestamp == 16)
local alphaSnapshot = service.readRecipientSnapshot(alpha)
local bravoSnapshot = service.readRecipientSnapshot(bravo)
local outsiderSnapshot = service.readRecipientSnapshot(outsider)
assert(#alphaSnapshot.pings == 1 and #bravoSnapshot.pings == 1)
assert(#outsiderSnapshot.pings == 0, "cross-squad state leaked")
assert(contracts.validateSafeSnapshot(alphaSnapshot))
assert(alphaSnapshot.pings[1].squadId == nil and alphaSnapshot.pings[1].createdAtServerTimestamp == nil)
assert(alphaSnapshot.pings[1].targetEntityId == nil and alphaSnapshot.pings[1].discovery == nil)
assert(latestFor(alpha).pings[1].pingId == "ping:1")
assert(latestFor(bravo).pings[1].pingId == "ping:1")
assert(#latestFor(outsider).pings == 0)

local observed = {}
local subscription = service.subscribeRecipient(bravo, function(snapshot)
	table.insert(observed, snapshot)
end)
assert(subscription ~= nil and #observed == 1 and #observed[1].pings == 1)
local late = makePlayer(4)
admit(late, "operative:late")
assert(service.registerOperative("operative:late", late, "squad:a").didChange)
assert(#latestFor(late).pings == 1, "late squadmate must receive only active state")

for _, malformed in
	{
		nil,
		"Location",
		{},
		{ categoryId = "Location" },
		{ categoryId = "Location", candidatePosition = roblox.Vector3.zero, timestamp = 1 },
		{ categoryId = "Location", candidatePosition = roblox.Vector3.zero, recipient = bravo },
	}
do
	assert(service.requestPing(alpha, malformed).rejectionReasonId == "MalformedIntent")
end
assert(service.requestPing(alpha, intent(roblox.Vector3.zero, "Invented")).rejectionReasonId == "InvalidCategory")
for _, categoryId in { "Rally", "Teammate", "Objective", "ObservedHostile" } do
	assert(service.requestPing(alpha, intent(roblox.Vector3.zero, categoryId)).rejectionReasonId == "InvalidCategory")
end
for _, hostileReason in
	{
		"InvalidEntityReference",
		"UndisclosedReference",
		"InvalidObservationState",
		"StaleObservation",
		"MissingDirectSight",
		"StaleDirectSight",
	}
do
	assert(contracts.RejectionReasonIds[hostileReason] == hostileReason, "hostile fail-closed taxonomy drift")
end
assert(service.requestPing(alpha, intent({})).rejectionReasonId == "InvalidLocation")
assert(service.requestPing(alpha, intent(roblox.Vector3.new(0 / 0, 0, 0))).rejectionReasonId == "InvalidLocation")
assert(service.requestPing(alpha, intent(roblox.Vector3.new(math.huge, 0, 0))).rejectionReasonId == "InvalidLocation")
assert(service.requestPing(alpha, intent(roblox.Vector3.new(120.01, 0, 0))).rejectionReasonId == "OutOfRangeLocation")
assert(service.requestPing({}, intent(roblox.Vector3.zero)).rejectionReasonId == "UnknownOperative")

now = 10.5
assert(service.requestPing(alpha, intent(roblox.Vector3.new(20, 0, 0))).rejectionReasonId == "RateLimited")
assert(service.readRecipientSnapshot(alpha).pings[1].pingId == "ping:1")
unlockedByUserId[alpha.UserId] = true
now = 11.5
local replacement = service.requestPing(alpha, intent(roblox.Vector3.new(20, 0, 0)))
assert(replacement.didChange and replacement.ping.pingId == "ping:2")
assert(replacement.ping.categoryId == contracts.CategoryIds.Rally, "unlocked player must publish Rally")
local replacementSnapshot = service.readRecipientSnapshot(alpha)
assert(#replacementSnapshot.pings == 1 and replacementSnapshot.pings[1].pingId == "ping:2")
assert(replacementSnapshot.pings[1].categoryId == contracts.CategoryIds.Rally)
assert(contracts.validateSafeSnapshot(replacementSnapshot), "Rally must remain a safe location-only snapshot")
assert(replacementSnapshot.pings[1].revision > accepted.ping.revision)

reset()
local squadPlayers = {}
for index = 1, 5 do
	local player = makePlayer(10 + index)
	local operativeEntityId = "operative:squad:" .. tostring(index)
	admit(player, operativeEntityId)
	assert(service.registerOperative(operativeEntityId, player, "squad:limit").didChange)
	table.insert(squadPlayers, player)
end
for index = 1, 4 do
	now = index
	assert(service.requestPing(squadPlayers[index], intent(roblox.Vector3.new(index * 4, 0, 0))).didChange)
end
now = 5
assert(
	service.requestPing(squadPlayers[5], intent(roblox.Vector3.new(20, 0, 0))).rejectionReasonId == "SquadLimitExceeded"
)
assert(#service.readRecipientSnapshot(squadPlayers[1]).pings == 4)

reset()
local lifecycle = makePlayer(30)
local mate = makePlayer(31)
admit(lifecycle, "operative:lifecycle")
admit(mate, "operative:mate")
assert(service.registerOperative("operative:lifecycle", lifecycle, "squad:old").didChange)
assert(service.registerOperative("operative:mate", mate, "squad:old").didChange)
now = 20
assert(service.requestPing(lifecycle, intent(roblox.Vector3.new(12, 0, 0))).didChange)
local lifeRead = lifeByPlayer[lifecycle]
lifeRead.revision = 1
lifeRead.snapshot = { operativeEntityId = "operative:lifecycle", lifeStateId = "Incapacitated" }
lifeSignal:Fire(lifecycle, lifeRead.snapshot, lifeRead.revision)
assert(#service.readRecipientSnapshot(mate).pings == 0, "incapacitation must clear owned ping")
assert(service.requestPing(lifecycle, intent(roblox.Vector3.zero)).rejectionReasonId == "IncapacitatedSender")
lifeRead.revision = 2
lifeRead.snapshot = { operativeEntityId = "operative:lifecycle", lifeStateId = "Alive" }
lifeSignal:Fire(lifecycle, lifeRead.snapshot, lifeRead.revision)
assert(#service.readRecipientSnapshot(lifecycle).pings == 0, "revival must not restore ping")
now = 22
assert(service.requestPing(lifecycle, intent(roblox.Vector3.new(12, 0, 0))).didChange)
lifeRead.revision = 3
lifeRead.snapshot = { operativeEntityId = "operative:lifecycle", lifeStateId = "Dead" }
lifeSignal:Fire(lifecycle, lifeRead.snapshot, lifeRead.revision)
assert(service.requestPing(lifecycle, intent(roblox.Vector3.zero)).rejectionReasonId == "DeadSender")
lifeRead.revision = 4
lifeRead.snapshot = { operativeEntityId = "operative:lifecycle", lifeStateId = "Unknown" }
lifeSignal:Fire(lifecycle, lifeRead.snapshot, lifeRead.revision)
assert(service.requestPing(lifecycle, intent(roblox.Vector3.zero)).rejectionReasonId == "InvalidLifeState")

lifeRead.revision = 5
lifeRead.snapshot = { operativeEntityId = "operative:lifecycle", lifeStateId = "Alive" }
lifeSignal:Fire(lifecycle, lifeRead.snapshot, lifeRead.revision)
now = 24
assert(service.requestPing(lifecycle, intent(roblox.Vector3.new(16, 0, 0))).didChange)
assert(service.setOperativeSquad("operative:lifecycle", "squad:new").didChange)
assert(#service.readRecipientSnapshot(mate).pings == 0)
assert(#service.readRecipientSnapshot(lifecycle).pings == 0, "squad change must clear owned ping")
now = 26
assert(service.requestPing(lifecycle, intent(roblox.Vector3.new(16, 0, 0))).didChange)
assert(#service.readRecipientSnapshot(mate).pings == 0, "old squad must not receive new ping")
assert(service.unregisterOperative("operative:lifecycle").didChange)
assert(service.readRecipientSnapshot(lifecycle) == nil)

reset()
local expiryOwner = makePlayer(40)
admit(expiryOwner, "operative:expiry")
assert(service.registerOperative("operative:expiry", expiryOwner, "squad:expiry").didChange)
now = 100
assert(service.requestPing(expiryOwner, intent(roblox.Vector3.new(8, 0, 0))).didChange)
local expirySnapshot = service.readRecipientSnapshot(expiryOwner)
assert(expirySnapshot.pings[1].expiresAtServerTimestamp == 106)
assert(#scheduled >= 1, "central expiry scheduler was not armed")
assert(not service.evaluateExpiriesAt(105.999).didChange)
local expired = service.evaluateExpiriesAt(106)
assert(expired.didChange and expired.lifecycleId == "Expired")
assert(#service.readRecipientSnapshot(expiryOwner).pings == 0)
assert(not service.evaluateExpiriesAt(106).didChange, "expiry must be idempotent")

now = 110
assert(service.requestPing(expiryOwner, intent(roblox.Vector3.new(8, 0, 0))).didChange)
local pingId = service.readRecipientSnapshot(expiryOwner).pings[1].pingId
assert(service.removePing(pingId).didChange)
assert(service.removePing(pingId).rejectionReasonId == "InvalidEntityReference")
now = 112
assert(service.requestPing(expiryOwner, intent(roblox.Vector3.new(8, 0, 0))).didChange)
assert(service.removeSquad("squad:expiry").didChange)
assert(service.readRecipientSnapshot(expiryOwner) == nil)
assert(service.requestPing(expiryOwner, intent(roblox.Vector3.zero)).rejectionReasonId == "InvalidSquad")

local staleLifeCallback = lifeSignal:Listeners()[1]
service.stop()
staleLifeCallback(expiryOwner, { operativeEntityId = "operative:expiry", lifeStateId = "Dead" }, 99)
assert(service.requestPing(expiryOwner, intent(roblox.Vector3.zero)).rejectionReasonId == "ServiceStopped")
assert(service.evaluateExpiriesAt(200).rejectionReasonId == "ServiceStopped")

local project = fs.readFile("games/living-kingdoms/default.project.json")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/SquadPingService.luau")
assert(string.find(project, '"SquadPingNetwork"', 1, true))
assert(string.find(serverBootstrap, "SquadPingService.start()", 1, true))
assert(string.find(clientBootstrap, "SquadPingController.start()", 1, true))
for _, prohibited in
	{
		"DiscoveryMemoryService",
		"VisibilityResolver",
		"TargetCandidate",
		"CombatNetwork",
		"FireAllClients",
		"Raycast",
	}
do
	assert(not string.find(serviceSource, prohibited, 1, true), "prohibited authority dependency: " .. prohibited)
end

print("SquadPingService: LK-0407 isolation, validation, limits, Rally identity, expiry, replication, and cleanup passed")
