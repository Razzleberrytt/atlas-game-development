--!strict

--[[
	Server owner for insertion loadout selection. Clients submit only a request
	ID and one known weapon ID. The server derives identity, participation,
	mission timing, lock state, replay/rate limits, assignment, and disclosure.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponLoadoutConfig = require(ReplicatedStorage.Shared.Config.WeaponLoadoutConfig)
local WeaponLoadoutContracts = require(ReplicatedStorage.Shared.Weapons.WeaponLoadoutContracts)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local WeaponLoadoutSelectionResolver = require(script.Parent.WeaponLoadoutSelectionResolver)

local Service = {}
local States = WeaponLoadoutContracts.SelectionStateIds
local Operations = WeaponLoadoutContracts.NetworkOperationIds
local Reasons = WeaponLoadoutContracts.RejectionReasonIds

local network = ReplicatedStorage:WaitForChild("WeaponLoadoutNetwork")
local selectionIntentRemote = network:WaitForChild("SelectionIntent") :: RemoteEvent
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local readStateFunction = network:WaitForChild("ReadState") :: RemoteFunction

type Entry = {
	player: Player,
	assignment: WeaponLoadoutContracts.AuthoritativeAssignment,
	processedRequestIds: { [string]: boolean },
	processedRequestOrder: { string },
	lastRequestTimestamp: number?,
}

local started = false
local selectionStateId: WeaponLoadoutContracts.SelectionStateId = States.Locked
local rosterRevision = 0
local entriesByPlayer: { [Player]: Entry } = {}
local remoteConnection: RBXScriptConnection? = nil
local rosterConnection: { Disconnect: (self: any) -> () }? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local lockThread: thread? = nil
local lockGeneration = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function copyAssignment(assignment: WeaponLoadoutContracts.AuthoritativeAssignment)
	return table.freeze({
		operativeEntityId = assignment.operativeEntityId,
		weaponId = assignment.weaponId,
		selectionStateId = assignment.selectionStateId,
		revision = assignment.revision,
	})
end

local function snapshotFor(player: Player): WeaponLoadoutContracts.SafeSnapshot
	local entry = entriesByPlayer[player]
	return table.freeze({
		operationId = Operations.Snapshot,
		rosterRevision = rosterRevision,
		selectionStateId = selectionStateId,
		ownerAssignment = if entry == nil then nil else copyAssignment(entry.assignment),
	})
end

local function publishAll()
	for player in entriesByPlayer do
		stateRemote:FireClient(player, snapshotFor(player))
	end
end

local function cancelLock()
	lockGeneration += 1
	if lockThread ~= nil then
		pcall(task.cancel, lockThread)
		lockThread = nil
	end
end

local function lockSelections()
	if selectionStateId == States.Locked then
		cancelLock()
		return
	end
	selectionStateId = States.Locked
	for _, entry in entriesByPlayer do
		entry.assignment = table.freeze({
			operativeEntityId = entry.assignment.operativeEntityId,
			weaponId = entry.assignment.weaponId,
			selectionStateId = States.Locked,
			revision = entry.assignment.revision + 1,
		})
	end
	rosterRevision += 1
	cancelLock()
	publishAll()
end

local function scheduleLock(deadline: number)
	cancelLock()
	local generation = lockGeneration
	lockThread = task.delay(math.max(0, deadline - now()), function()
		if started and generation == lockGeneration then
			lockThread = nil
			lockSelections()
		end
	end)
end

local function registerPlayer(player: Player): boolean
	if entriesByPlayer[player] ~= nil then
		return false
	end
	local lifeRead = OperativeLifeService.read(player)
	if lifeRead == nil then
		return false
	end
	entriesByPlayer[player] = {
		player = player,
		assignment = table.freeze({
			operativeEntityId = lifeRead.snapshot.operativeEntityId,
			weaponId = WeaponLoadoutConfig.DefaultWeaponId,
			selectionStateId = selectionStateId,
			revision = 1,
		}),
		processedRequestIds = {},
		processedRequestOrder = {},
		lastRequestTimestamp = nil,
	}
	rosterRevision += 1
	return true
end

local function removePlayer(player: Player)
	if entriesByPlayer[player] == nil then
		return
	end
	entriesByPlayer[player] = nil
	rosterRevision += 1
	publishAll()
end

local function recordRequest(entry: Entry, requestId: string)
	entry.processedRequestIds[requestId] = true
	table.insert(entry.processedRequestOrder, requestId)
	while #entry.processedRequestOrder > WeaponLoadoutConfig.MaximumProcessedRequestIdsPerOperative do
		local expired = table.remove(entry.processedRequestOrder, 1)
		if expired ~= nil then
			entry.processedRequestIds[expired] = nil
		end
	end
end

function Service.requestSelection(player: Player, payload: unknown)
	if not started then
		return false, Reasons.ServiceStopped
	end
	local entry = entriesByPlayer[player]
	if entry == nil then
		return false, Reasons.NotParticipant
	end
	local mission = MissionDirectorService.read()
	local deadline = mission.insertionDeadlineServerTimestamp
	local timestamp = now()
	local selectionOpen = mission.phaseId == WeaponLoadoutConfig.OpenMissionPhaseId
		and deadline ~= nil
		and timestamp < deadline
		and selectionStateId == States.Open
	if not selectionOpen then
		lockSelections()
	end
	local requestId = if type(payload) == "table" and type((payload :: any).requestId) == "string"
		then (payload :: any).requestId
		else ""
	local previous = entry.lastRequestTimestamp
	local rateLimited = previous ~= nil and timestamp - previous < WeaponLoadoutConfig.MinimumRequestIntervalSeconds
	entry.lastRequestTimestamp = timestamp
	local resolution = WeaponLoadoutSelectionResolver.resolve(entry.assignment, payload, {
		selectionOpen = selectionOpen,
		isDuplicateRequest = requestId ~= "" and entry.processedRequestIds[requestId] == true,
		isRateLimited = rateLimited,
	})
	if not resolution.didSelect then
		return false, resolution.rejectionReasonId
	end
	entry.assignment = copyAssignment(resolution.assignmentAfter)
	if resolution.requestId ~= nil then
		recordRequest(entry, resolution.requestId)
	end
	rosterRevision += 1
	publishAll()
	return true, nil
end

function Service.read(player: Player): WeaponLoadoutContracts.AuthoritativeAssignment?
	local entry = entriesByPlayer[player]
	return if entry == nil then nil else copyAssignment(entry.assignment)
end

function Service.readSafeSnapshot(player: Player): WeaponLoadoutContracts.SafeSnapshot
	return snapshotFor(player)
end

function Service.start()
	if started then
		return
	end
	started = true
	rosterRevision = 0
	local mission = MissionDirectorService.read()
	local deadline = mission.insertionDeadlineServerTimestamp
	selectionStateId = if mission.phaseId == WeaponLoadoutConfig.OpenMissionPhaseId
			and deadline ~= nil
			and now() < deadline
		then States.Open
		else States.Locked
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			registerPlayer(player)
		end
	end
	rosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
		if not started then
			return
		end
		if eventName == "Registered" then
			local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
			if player ~= nil and registerPlayer(player) then
				publishAll()
			end
		end
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	remoteConnection = selectionIntentRemote.OnServerEvent:Connect(function(player, payload)
		Service.requestSelection(player, payload)
	end)
	readStateFunction.OnServerInvoke = function(player)
		return snapshotFor(player)
	end
	if selectionStateId == States.Open and deadline ~= nil then
		scheduleLock(deadline)
	end
	publishAll()
end

function Service.stop()
	if not started then
		return
	end
	started = false
	cancelLock()
	if remoteConnection ~= nil then
		remoteConnection:Disconnect()
		remoteConnection = nil
	end
	if rosterConnection ~= nil then
		rosterConnection:Disconnect()
		rosterConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	readStateFunction.OnServerInvoke = nil
	table.clear(entriesByPlayer)
	selectionStateId = States.Locked
	rosterRevision = 0
end

return Service
