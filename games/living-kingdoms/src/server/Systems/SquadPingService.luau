--!strict

--[[
	Server owner for LK-0407's bounded location squad ping slice. Client intent
	contains only a Location category and candidate position. Identity, squad,
	time, limits, canonical position, durable Rally identity, marker capacity,
	ping identity, recipients, and revisions are derived here. No discovery,
	perception, targeting, or combat service is read or mutated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local OperativeProgressionConfig = require(ReplicatedStorage.Shared.Config.OperativeProgressionConfig)
local SquadPingConfig = require(ReplicatedStorage.Shared.Config.SquadPingConfig)
local SquadPingContracts = require(ReplicatedStorage.Shared.Navigation.SquadPingContracts)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local OperativeProgressionService = require(script.Parent.OperativeProgressionService)

type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

export type SafePing = {
	pingId: string,
	categoryId: string,
	position: Vector3,
	senderOperativeEntityId: string,
	expiresAtServerTimestamp: number,
	revision: number,
	sequence: number,
}

export type OperationResult = {
	didChange: boolean,
	rejectionReasonId: string?,
	lifecycleId: string?,
	ping: SafePing?,
	revision: number,
}

type OperativeEntry = {
	operativeEntityId: string,
	player: Player,
	squadId: string,
	generation: number,
	lastAcceptedTimestamp: number?,
}

type PingEntry = SafePing & {
	squadId: string,
	createdAtServerTimestamp: number,
}

type RecipientListener = (snapshot: any) -> ()

local Service = {}

Service.RejectionReasonIds = SquadPingContracts.RejectionReasonIds

local pingNetwork = ReplicatedStorage:WaitForChild("SquadPingNetwork")
local intentRemote = pingNetwork:WaitForChild("Intent") :: RemoteEvent
local stateRemote = pingNetwork:WaitForChild("State") :: RemoteEvent

local entriesByOperativeId: { [string]: OperativeEntry } = {}
local entryByPlayer: { [Player]: OperativeEntry } = {}
local pingsById: { [string]: PingEntry } = {}
local recipientListeners: { [Player]: { [number]: RecipientListener } } = {}
local nextListenerId = 0
local nextOperativeGeneration = 0
local nextPingSequence = 0
local revision = 0
local started = false
local serviceGeneration = 0
local expiryGeneration = 0
local expiryThread: thread? = nil
local remoteConnection: RBXScriptConnection? = nil
local lifeConnection: ListenerConnection? = nil
local rosterConnection: ListenerConnection? = nil
local developmentHarness: Folder? = nil

local function result(
	didChange: boolean,
	rejectionReasonId: string?,
	lifecycleId: string?,
	ping: SafePing?
): OperationResult
	return table.freeze({
		didChange = didChange,
		rejectionReasonId = rejectionReasonId,
		lifecycleId = lifecycleId,
		ping = ping,
		revision = revision,
	})
end

local function copyPing(ping: PingEntry): SafePing
	return table.freeze({
		pingId = ping.pingId,
		categoryId = ping.categoryId,
		position = ping.position,
		senderOperativeEntityId = ping.senderOperativeEntityId,
		expiresAtServerTimestamp = ping.expiresAtServerTimestamp,
		revision = ping.revision,
		sequence = ping.sequence,
	})
end

local function sortedSquadPings(squadId: string): { SafePing }
	local pings = {}
	for _, ping in pingsById do
		if ping.squadId == squadId then
			table.insert(pings, copyPing(ping))
		end
	end
	table.sort(pings, function(left, right)
		return left.sequence < right.sequence
	end)
	return table.freeze(pings)
end

local function snapshotForSquad(squadId: string): any
	return table.freeze({
		operationId = SquadPingContracts.StateOperationIds.Snapshot,
		revision = revision,
		pings = sortedSquadPings(squadId),
	})
end

local function rejectionPayload(reasonId: string): any
	return table.freeze({
		operationId = SquadPingContracts.StateOperationIds.Rejected,
		revision = revision,
		rejectionReasonId = reasonId,
	})
end

local function notifyRecipient(entry: OperativeEntry, snapshot: any)
	pcall(function()
		stateRemote:FireClient(entry.player, snapshot)
	end)
	local listeners = recipientListeners[entry.player]
	if listeners ~= nil then
		for _, listener in listeners do
			pcall(listener, snapshot)
		end
	end
end

local function publishSquads(squadIds: { [string]: boolean })
	local snapshots: { [string]: any } = {}
	for squadId in squadIds do
		if squadId ~= "" then
			snapshots[squadId] = snapshotForSquad(squadId)
		end
	end
	for _, entry in entriesByOperativeId do
		local snapshot = snapshots[entry.squadId]
		if snapshot ~= nil then
			notifyRecipient(entry, snapshot)
		end
	end
end

local function reject(player: Player?, reasonId: string): OperationResult
	if player ~= nil then
		pcall(function()
			stateRemote:FireClient(player, rejectionPayload(reasonId))
		end)
	end
	return result(false, reasonId, nil, nil)
end

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function validPosition(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local position = value :: Vector3
	return isFiniteNumber(position.X) and isFiniteNumber(position.Y) and isFiniteNumber(position.Z)
end

local function authoritativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	return if validPosition(position) then position else nil
end

local function quantizeTowardSender(senderPosition: Vector3, candidatePosition: Vector3): Vector3
	local quantum = SquadPingConfig.QuantizationStuds
	local delta = candidatePosition - senderPosition
	local function component(value: number): number
		return math.sign(value) * math.floor(math.abs(value) / quantum) * quantum
	end
	return senderPosition + Vector3.new(component(delta.X), component(delta.Y), component(delta.Z))
end

local function activeCountForSquad(squadId: string): number
	local count = 0
	for _, ping in pingsById do
		if ping.squadId == squadId then
			count += 1
		end
	end
	return count
end

local function ownedPings(operativeEntityId: string): { PingEntry }
	local owned = {}
	for _, ping in pingsById do
		if ping.senderOperativeEntityId == operativeEntityId then
			table.insert(owned, ping)
		end
	end
	table.sort(owned, function(left, right)
		return left.sequence < right.sequence
	end)
	return owned
end

local function publishedCategoryFor(player: Player): string
	local unlocked = false
	local ok = pcall(function()
		unlocked = OperativeProgressionService.hasOwnedUnlock(
			player.UserId,
			player.UserId,
			OperativeProgressionConfig.UnlockIds.SquadRallyPing
		)
	end)
	if ok and unlocked then
		return SquadPingContracts.CategoryIds.Rally
	end
	return SquadPingContracts.CategoryIds.Location
end

local function maximumActiveFor(player: Player): number
	local unlockId = OperativeProgressionConfig.UnlockIds.DualTacticalMarkers
	if unlockId == nil then
		return SquadPingConfig.MaximumActivePerSender
	end
	local unlocked = false
	local ok = pcall(function()
		unlocked = OperativeProgressionService.hasOwnedUnlock(player.UserId, player.UserId, unlockId)
	end)
	if ok and unlocked then
		return SquadPingConfig.DualTacticalMaximumActivePerSender
	end
	return SquadPingConfig.MaximumActivePerSender
end

local function cancelExpiry()
	expiryGeneration += 1
	if expiryThread ~= nil then
		pcall(task.cancel, expiryThread)
		expiryThread = nil
	end
end

local scheduleExpiry: () -> ()

local function removeInternal(pingId: string): PingEntry?
	local ping = pingsById[pingId]
	if ping ~= nil then
		pingsById[pingId] = nil
	end
	return ping
end

function Service.evaluateExpiriesAt(serverTimestamp: number): OperationResult
	if not started then
		return result(false, SquadPingContracts.RejectionReasonIds.ServiceStopped, nil, nil)
	end
	if not isFiniteNumber(serverTimestamp) or serverTimestamp < 0 then
		return result(false, SquadPingContracts.RejectionReasonIds.InvalidPayload, nil, nil)
	end
	local expired = {}
	for _, ping in pingsById do
		if ping.expiresAtServerTimestamp <= serverTimestamp then
			table.insert(expired, ping)
		end
	end
	table.sort(expired, function(left, right)
		return left.sequence < right.sequence
	end)
	if #expired == 0 then
		scheduleExpiry()
		return result(false, nil, nil, nil)
	end
	local affectedSquads = {}
	for _, ping in expired do
		removeInternal(ping.pingId)
		affectedSquads[ping.squadId] = true
	end
	revision += 1
	scheduleExpiry()
	publishSquads(affectedSquads)
	return result(true, nil, SquadPingContracts.LifecycleIds.Expired, nil)
end

scheduleExpiry = function()
	cancelExpiry()
	if not started then
		return
	end
	local earliest: number? = nil
	for _, ping in pingsById do
		if earliest == nil or ping.expiresAtServerTimestamp < earliest then
			earliest = ping.expiresAtServerTimestamp
		end
	end
	if earliest == nil then
		return
	end
	local generation = expiryGeneration
	expiryThread = task.delay(math.max(0, earliest - Workspace:GetServerTimeNow()), function()
		if started and generation == expiryGeneration then
			expiryThread = nil
			Service.evaluateExpiriesAt(Workspace:GetServerTimeNow())
		end
	end)
end

local function removeOwnedWithoutPublish(operativeEntityId: string, affectedSquads: { [string]: boolean }): boolean
	local didRemove = false
	for _, ping in ownedPings(operativeEntityId) do
		removeInternal(ping.pingId)
		affectedSquads[ping.squadId] = true
		didRemove = true
	end
	return didRemove
end

function Service.removePing(pingId: string): OperationResult
	if not started then
		return result(false, SquadPingContracts.RejectionReasonIds.ServiceStopped, nil, nil)
	end
	if type(pingId) ~= "string" or pingId == "" then
		return result(false, SquadPingContracts.RejectionReasonIds.InvalidPayload, nil, nil)
	end
	local ping = removeInternal(pingId)
	if ping == nil then
		return result(false, SquadPingContracts.RejectionReasonIds.InvalidEntityReference, nil, nil)
	end
	revision += 1
	scheduleExpiry()
	publishSquads({ [ping.squadId] = true })
	return result(true, nil, SquadPingContracts.LifecycleIds.Removed, nil)
end

function Service.removeSquad(squadId: string): OperationResult
	if not started then
		return result(false, SquadPingContracts.RejectionReasonIds.ServiceStopped, nil, nil)
	end
	if type(squadId) ~= "string" or squadId == "" then
		return result(false, SquadPingContracts.RejectionReasonIds.InvalidSquad, nil, nil)
	end
	local affectedEntries = {}
	for _, entry in entriesByOperativeId do
		if entry.squadId == squadId then
			table.insert(affectedEntries, entry)
		end
	end
	local didChange = false
	for pingId, ping in pingsById do
		if ping.squadId == squadId then
			pingsById[pingId] = nil
			didChange = true
		end
	end
	if #affectedEntries > 0 then
		didChange = true
	end
	if not didChange then
		return result(false, nil, nil, nil)
	end
	revision += 1
	local emptySnapshot = snapshotForSquad(squadId)
	for _, entry in affectedEntries do
		notifyRecipient(entry, emptySnapshot)
		entry.squadId = ""
		entry.lastAcceptedTimestamp = nil
	end
	scheduleExpiry()
	return result(true, nil, SquadPingContracts.LifecycleIds.Removed, nil)
end

function Service.registerOperative(operativeEntityId: string, player: Player, squadId: string): OperationResult
	if not started then
		return result(false, SquadPingContracts.RejectionReasonIds.ServiceStopped, nil, nil)
	end
	if type(operativeEntityId) ~= "string" or operativeEntityId == "" or player == nil then
		return reject(player, SquadPingContracts.RejectionReasonIds.InvalidSender)
	end
	if type(squadId) ~= "string" or squadId == "" then
		return reject(player, SquadPingContracts.RejectionReasonIds.InvalidSquad)
	end
	if entriesByOperativeId[operativeEntityId] ~= nil or entryByPlayer[player] ~= nil then
		return reject(player, SquadPingContracts.RejectionReasonIds.StateMismatch)
	end
	local read = OperativeLifeService.read(player)
	if
		read == nil
		or read.snapshot.operativeEntityId ~= operativeEntityId
		or OperativeLifeService.playerForOperativeEntityId(operativeEntityId) ~= player
	then
		return reject(player, SquadPingContracts.RejectionReasonIds.StateMismatch)
	end
	nextOperativeGeneration += 1
	local entry = {
		operativeEntityId = operativeEntityId,
		player = player,
		squadId = squadId,
		generation = nextOperativeGeneration,
		lastAcceptedTimestamp = nil,
	}
	entriesByOperativeId[operativeEntityId] = entry
	entryByPlayer[player] = entry
	notifyRecipient(entry, snapshotForSquad(squadId))
	return result(true, nil, nil, nil)
end

function Service.unregisterOperative(operativeEntityId: string): OperationResult
	local entry = entriesByOperativeId[operativeEntityId]
	if entry == nil then
		return result(false, SquadPingContracts.RejectionReasonIds.UnknownOperative, nil, nil)
	end
	local affectedSquads = { [entry.squadId] = true }
	removeOwnedWithoutPublish(operativeEntityId, affectedSquads)
	entriesByOperativeId[operativeEntityId] = nil
	entryByPlayer[entry.player] = nil
	entry.generation += 1
	revision += 1
	scheduleExpiry()
	publishSquads(affectedSquads)
	return result(true, nil, SquadPingContracts.LifecycleIds.Removed, nil)
end

function Service.setOperativeSquad(operativeEntityId: string, squadId: string): OperationResult
	local entry = entriesByOperativeId[operativeEntityId]
	if entry == nil then
		return result(false, SquadPingContracts.RejectionReasonIds.UnknownOperative, nil, nil)
	end
	if type(squadId) ~= "string" or squadId == "" then
		return reject(entry.player, SquadPingContracts.RejectionReasonIds.InvalidSquad)
	end
	if entry.squadId == squadId then
		return result(false, nil, nil, nil)
	end
	local oldSquadId = entry.squadId
	local affectedSquads = { [oldSquadId] = true, [squadId] = true }
	removeOwnedWithoutPublish(operativeEntityId, affectedSquads)
	entry.squadId = squadId
	entry.lastAcceptedTimestamp = nil
	revision += 1
	scheduleExpiry()
	publishSquads(affectedSquads)
	return result(true, nil, SquadPingContracts.LifecycleIds.Removed, nil)
end

function Service.requestPing(player: Player, intent: unknown): OperationResult
	if not started then
		return result(false, SquadPingContracts.RejectionReasonIds.ServiceStopped, nil, nil)
	end
	if player == nil then
		return result(false, SquadPingContracts.RejectionReasonIds.InvalidSender, nil, nil)
	end
	local entry = entryByPlayer[player]
	if entry == nil then
		return reject(player, SquadPingContracts.RejectionReasonIds.UnknownOperative)
	end
	if entry.squadId == "" then
		return reject(player, SquadPingContracts.RejectionReasonIds.InvalidSquad)
	end
	local intentIsValid, intentReason = SquadPingContracts.validateClientIntent(intent)
	if not intentIsValid then
		return reject(player, intentReason or SquadPingContracts.RejectionReasonIds.MalformedIntent)
	end
	local payload = intent :: any
	if not validPosition(payload.candidatePosition) then
		return reject(player, SquadPingContracts.RejectionReasonIds.InvalidLocation)
	end
	local read = OperativeLifeService.read(player)
	if
		read == nil
		or read.snapshot.operativeEntityId ~= entry.operativeEntityId
		or OperativeLifeService.playerForOperativeEntityId(entry.operativeEntityId) ~= player
	then
		return reject(player, SquadPingContracts.RejectionReasonIds.StateMismatch)
	end
	local lifeStateId = read.snapshot.lifeStateId
	if lifeStateId == "Incapacitated" then
		return reject(player, SquadPingContracts.RejectionReasonIds.IncapacitatedSender)
	elseif lifeStateId == "Dead" then
		return reject(player, SquadPingContracts.RejectionReasonIds.DeadSender)
	elseif lifeStateId ~= "Alive" then
		return reject(player, SquadPingContracts.RejectionReasonIds.InvalidLifeState)
	end
	local senderPosition = authoritativePosition(player)
	if senderPosition == nil then
		return reject(player, SquadPingContracts.RejectionReasonIds.InvalidLocation)
	end
	local candidatePosition = payload.candidatePosition :: Vector3
	local delta = candidatePosition - senderPosition
	local maximumDistance = SquadPingConfig.MaximumDistanceStuds
	if delta:Dot(delta) > maximumDistance * maximumDistance then
		return reject(player, SquadPingContracts.RejectionReasonIds.OutOfRangeLocation)
	end
	local now = Workspace:GetServerTimeNow()
	if not isFiniteNumber(now) or now < 0 then
		return reject(player, SquadPingContracts.RejectionReasonIds.InternalError)
	end
	Service.evaluateExpiriesAt(now)
	local lastAccepted = entry.lastAcceptedTimestamp
	if lastAccepted ~= nil and now - lastAccepted < SquadPingConfig.CooldownSeconds then
		return reject(player, SquadPingContracts.RejectionReasonIds.RateLimited)
	end
	local owned = ownedPings(entry.operativeEntityId)
	local maximumActive = maximumActiveFor(player)
	if #owned > maximumActive then
		return reject(player, SquadPingContracts.RejectionReasonIds.SenderLimitExceeded)
	end
	local replacing = if #owned >= maximumActive then owned[1] else nil
	local squadCountAfterReplacement = activeCountForSquad(entry.squadId) - (if replacing == nil then 0 else 1)
	if squadCountAfterReplacement >= SquadPingConfig.MaximumActivePerSquad then
		return reject(player, SquadPingContracts.RejectionReasonIds.SquadLimitExceeded)
	end
	if entry ~= entriesByOperativeId[entry.operativeEntityId] then
		return reject(player, SquadPingContracts.RejectionReasonIds.StateMismatch)
	end
	local categoryId = publishedCategoryFor(player)
	if replacing ~= nil then
		removeInternal(replacing.pingId)
	end
	revision += 1
	nextPingSequence += 1
	local pingId = "ping:" .. tostring(nextPingSequence)
	local ping: PingEntry = {
		pingId = pingId,
		categoryId = categoryId,
		position = quantizeTowardSender(senderPosition, candidatePosition),
		senderOperativeEntityId = entry.operativeEntityId,
		expiresAtServerTimestamp = now + SquadPingConfig.LifetimeSeconds,
		revision = revision,
		sequence = nextPingSequence,
		squadId = entry.squadId,
		createdAtServerTimestamp = now,
	}
	pingsById[pingId] = ping
	entry.lastAcceptedTimestamp = now
	scheduleExpiry()
	publishSquads({ [entry.squadId] = true })
	return result(true, nil, SquadPingContracts.LifecycleIds.Active, copyPing(ping))
end

function Service.readRecipientSnapshot(player: Player): any?
	local entry = entryByPlayer[player]
	return if entry == nil or entry.squadId == "" then nil else snapshotForSquad(entry.squadId)
end

function Service.subscribeRecipient(player: Player, listener: RecipientListener): ListenerConnection?
	local entry = entryByPlayer[player]
	if entry == nil or type(listener) ~= "function" then
		return nil
	end
	nextListenerId += 1
	local listenerId = nextListenerId
	local listeners = recipientListeners[player]
	if listeners == nil then
		listeners = {}
		recipientListeners[player] = listeners
	end
	listeners[listenerId] = listener
	pcall(listener, snapshotForSquad(entry.squadId))
	local connected = true
	local connection = {} :: ListenerConnection
	function connection:Disconnect()
		if not connected then
			return
		end
		connected = false
		local current = recipientListeners[player]
		if current ~= nil then
			current[listenerId] = nil
			if next(current) == nil then
				recipientListeners[player] = nil
			end
		end
	end
	return connection
end

local function createDevelopmentHarness()
	if not RunService:IsStudio() or developmentHarness ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "LK0407SquadPingDevelopment"
	local readSnapshots = Instance.new("BindableFunction")
	readSnapshots.Name = "ReadSnapshots"
	readSnapshots.OnInvoke = function()
		local snapshots = {}
		for operativeEntityId, entry in entriesByOperativeId do
			snapshots[operativeEntityId] = snapshotForSquad(entry.squadId)
		end
		return snapshots
	end
	readSnapshots.Parent = folder
	folder.Parent = ServerStorage
	developmentHarness = folder
end

function Service.start()
	if started then
		return
	end
	started = true
	serviceGeneration += 1
	local generation = serviceGeneration
	remoteConnection = intentRemote.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 1 then
			reject(player, SquadPingContracts.RejectionReasonIds.MalformedIntent)
			return
		end
		local ok = pcall(Service.requestPing, player, select(1, ...))
		if not ok then
			reject(player, SquadPingContracts.RejectionReasonIds.InternalError)
		end
	end)
	lifeConnection = OperativeLifeService.subscribe(function(player, snapshot, lifeRevision)
		if not started or generation ~= serviceGeneration then
			return
		end
		local entry = entryByPlayer[player]
		if entry == nil or snapshot.operativeEntityId ~= entry.operativeEntityId then
			return
		end
		local current = OperativeLifeService.read(player)
		if
			current == nil
			or current.revision ~= lifeRevision
			or current.snapshot.lifeStateId ~= snapshot.lifeStateId
		then
			return
		end
		if snapshot.lifeStateId ~= "Alive" and #ownedPings(entry.operativeEntityId) > 0 then
			local affected = { [entry.squadId] = true }
			removeOwnedWithoutPublish(entry.operativeEntityId, affected)
			revision += 1
			scheduleExpiry()
			publishSquads(affected)
		end
	end)
	rosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
		if not started or generation ~= serviceGeneration then
			return
		end
		if eventName == "Registered" then
			local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
			if player ~= nil and entriesByOperativeId[operativeEntityId] == nil then
				Service.registerOperative(operativeEntityId, player, SquadPingConfig.ProductionSquadId)
			end
		elseif entriesByOperativeId[operativeEntityId] ~= nil then
			Service.unregisterOperative(operativeEntityId)
		end
	end)
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			Service.registerOperative(read.operativeEntityId, player, SquadPingConfig.ProductionSquadId)
		end
	end
	createDevelopmentHarness()
end

function Service.stop()
	if not started then
		return
	end
	started = false
	serviceGeneration += 1
	cancelExpiry()
	if remoteConnection ~= nil then
		remoteConnection:Disconnect()
		remoteConnection = nil
	end
	if lifeConnection ~= nil then
		lifeConnection:Disconnect()
		lifeConnection = nil
	end
	if rosterConnection ~= nil then
		rosterConnection:Disconnect()
		rosterConnection = nil
	end
	if developmentHarness ~= nil then
		developmentHarness:Destroy()
		developmentHarness = nil
	end
	for _, entry in entriesByOperativeId do
		notifyRecipient(
			entry,
			table.freeze({
				operationId = SquadPingContracts.StateOperationIds.Snapshot,
				revision = revision + 1,
				pings = table.freeze({}),
			})
		)
	end
	table.clear(entriesByOperativeId)
	table.clear(entryByPlayer)
	table.clear(pingsById)
	table.clear(recipientListeners)
	revision = 0
	nextListenerId = 0
	nextPingSequence = 0
end

return Service
