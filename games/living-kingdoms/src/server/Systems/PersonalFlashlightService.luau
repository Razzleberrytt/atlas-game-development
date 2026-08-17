--!strict

--[[
	Production owner for one approved personal flashlight per eligible operative.
	It derives identity, life state, timing, descriptor, facing, and ownership on
	the server and delegates every gameplay activation to GameplayLightingService.
	Only owner-safe state is replicated; coverage never implies visibility.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local NETWORK_WAIT_SECONDS = 20

local OperativeProgressionConfig = require(ReplicatedStorage.Shared.Config.OperativeProgressionConfig)
local PersonalFlashlightConfig = require(ReplicatedStorage.Shared.Config.PersonalFlashlightConfig)
local GameplayLightContracts = require(ReplicatedStorage.Shared.Lighting.GameplayLightContracts)
local PersonalFlashlightContracts = require(ReplicatedStorage.Shared.Lighting.PersonalFlashlightContracts)
local GameplayLightingService = require(script.Parent.GameplayLightingService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local OperativeProgressionService = require(script.Parent.OperativeProgressionService)
local PersonalFlashlightCoverage = require(script.Parent.PersonalFlashlightCoverage)
local SquadFailureService = require(script.Parent.SquadFailureService)

type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

export type OperativeFlashlightState = {
	operativeEntityId: string,
	lightId: string,
	stateId: string,
	revision: number,
	eligible: boolean,
	coverageProfileId: string,
}

export type CoverageProfile = {
	coverageProfileId: string,
	rangeStuds: number,
	coneAngleDegrees: number,
}

export type OperationResult = {
	statusId: string,
	didChange: boolean,
	rejectionReasonId: string?,
	state: OperativeFlashlightState?,
}

type Entry = {
	operativeEntityId: string,
	player: Player,
	lightId: string,
	stateId: string,
	revision: number,
	eligible: boolean,
	lightRegistered: boolean,
	generation: number,
	lastAcceptedToggleTimestamp: number?,
	lastLightingTransitionTimestamp: number?,
	lastLifeRevision: number,
	coverage: CoverageProfile,
}

type Listener = (state: OperativeFlashlightState) -> ()

local PersonalFlashlightService = {}

PersonalFlashlightService.RejectionReasonIds = PersonalFlashlightContracts.RejectionReasonIds

local ACTIVE = PersonalFlashlightContracts.StateIds.Active
local INACTIVE = PersonalFlashlightContracts.StateIds.Inactive
local CHANGED = PersonalFlashlightContracts.ToggleResultStatusIds.Changed
local EQUIVALENT = PersonalFlashlightContracts.ToggleResultStatusIds.Equivalent
local REJECTED = PersonalFlashlightContracts.ToggleResultStatusIds.Rejected
local LIGHT_ACTIVE = GameplayLightContracts.GameplayLightActivationStateIds.Active
local LIGHT_INACTIVE = GameplayLightContracts.GameplayLightActivationStateIds.Inactive
local BUDGET_EXCEEDED = GameplayLightContracts.GameplayLightRejectionReasonIds.BudgetExceeded
local TRANSITION_EPSILON_SECONDS = 0.000001

local flashlightNetwork = ReplicatedStorage:WaitForChild("FlashlightNetwork", NETWORK_WAIT_SECONDS)
assert(flashlightNetwork ~= nil, "FlashlightNetwork did not become available before the server bootstrap timeout")
local toggleIntentRemote = flashlightNetwork:WaitForChild("ToggleIntent", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	toggleIntentRemote ~= nil,
	"flashlightNetwork.ToggleIntent did not become available before the server bootstrap timeout"
)
local stateRemote = flashlightNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(stateRemote ~= nil, "flashlightNetwork.State did not become available before the server bootstrap timeout")

local entriesByOperativeId: { [string]: Entry } = {}
local entryByPlayer: { [Player]: Entry } = {}
local listeners: { [number]: Listener } = {}
local nextListenerId = 0
local nextGeneration = 0
local serviceGeneration = 0
local started = false
local remoteConnection: RBXScriptConnection? = nil
local lifeConnection: ListenerConnection? = nil
local rosterConnection: ListenerConnection? = nil
local failureConnection: ListenerConnection? = nil
local developmentHarness: Folder? = nil

local STANDARD_PROFILE_ID = PersonalFlashlightContracts.CoverageProfileIds.Standard
local FOCUSED_PROFILE_ID = PersonalFlashlightContracts.CoverageProfileIds.Focused

local STANDARD_COVERAGE: CoverageProfile = table.freeze({
	coverageProfileId = STANDARD_PROFILE_ID,
	rangeStuds = PersonalFlashlightConfig.RangeStuds,
	coneAngleDegrees = PersonalFlashlightConfig.ConeAngleDegrees,
})
local FOCUSED_COVERAGE: CoverageProfile = table.freeze({
	coverageProfileId = FOCUSED_PROFILE_ID,
	rangeStuds = PersonalFlashlightConfig.FocusedRangeStuds,
	coneAngleDegrees = PersonalFlashlightConfig.FocusedConeAngleDegrees,
})

--[[
	Derives the operative's authored coverage profile from durable progression.

	The profile is read from the owner-bound progression adapter using the
	operative's own UserId as both requester and owner, so no cross-player
	progression is ever consulted and no client intent participates. A missing or
	unloaded durable record fails safe to the standard profile, and a partial
	runtime without the progression adapter behaves exactly as before.

	Coverage is resolved once per registration because the light descriptor is
	registered with GameplayLightingService at that moment. Durable rank only
	advances between expeditions, so a run cannot rewrite its own coverage.
]]
local function resolveCoverage(player: Player): CoverageProfile
	local playerAsAny = player :: any
	if type(playerAsAny.UserId) ~= "number" then
		return STANDARD_COVERAGE
	end
	local userId = playerAsAny.UserId :: number
	local didRead, hasUnlock = pcall(function()
		return OperativeProgressionService.hasOwnedUnlock(
			userId,
			userId,
			OperativeProgressionConfig.UnlockIds.FocusedFlashlightBeam
		)
	end)
	return if didRead and hasUnlock == true then FOCUSED_COVERAGE else STANDARD_COVERAGE
end

local function copyState(entry: Entry): OperativeFlashlightState
	return table.freeze({
		operativeEntityId = entry.operativeEntityId,
		lightId = entry.lightId,
		stateId = entry.stateId,
		revision = entry.revision,
		eligible = entry.eligible,
		coverageProfileId = entry.coverage.coverageProfileId,
	})
end

local function result(statusId: string, entry: Entry?, rejectionReasonId: string?): OperationResult
	return table.freeze({
		statusId = statusId,
		didChange = statusId == CHANGED,
		rejectionReasonId = rejectionReasonId,
		state = if entry == nil then nil else copyState(entry),
	})
end

local function notify(entry: Entry)
	for _, listener in listeners do
		pcall(listener, copyState(entry))
	end
end

local function safePayload(entry: Entry, statusId: string, rejectionReasonId: string?): any
	return table.freeze({
		stateId = entry.stateId,
		revision = entry.revision,
		resultStatusId = statusId,
		rejectionReasonId = rejectionReasonId,
		coverageProfileId = entry.coverage.coverageProfileId,
	})
end

local function publish(entry: Entry, statusId: string, rejectionReasonId: string?)
	stateRemote:FireClient(entry.player, safePayload(entry, statusId, rejectionReasonId))
end

local function rejectEntry(entry: Entry?, rejectionReasonId: string): OperationResult
	if entry ~= nil then
		publish(entry, REJECTED, rejectionReasonId)
	end
	return result(REJECTED, entry, rejectionReasonId)
end

local function deterministicLightId(operativeEntityId: string): string
	return PersonalFlashlightConfig.LightIdPrefix .. operativeEntityId
end

local function descriptor(operativeEntityId: string, coverage: CoverageProfile): any
	return {
		sourceId = PersonalFlashlightConfig.SourceId,
		sourceTypeId = GameplayLightContracts.GameplayLightSourceTypeIds.ApprovedPersonal,
		visibilityProfileId = PersonalFlashlightConfig.VisibilityProfileId,
		activation = {
			stateId = GameplayLightContracts.GameplayLightActivationStateIds.Inactive,
			activatedAtServerTimestamp = nil,
			expiresAtServerTimestamp = nil,
		},
		coverage = {
			kind = GameplayLightContracts.GameplayLightCoverageKindIds.ForwardCone,
			rangeStuds = coverage.rangeStuds,
			angleDegrees = coverage.coneAngleDegrees,
		},
		ownerEntityId = operativeEntityId,
	}
end

local function lightingRecord(lightId: string): any?
	local snapshot = GameplayLightingService.readSnapshot()
	if snapshot == nil then
		return nil
	end
	for _, record in snapshot.records do
		if record.lightId == lightId then
			return record
		end
	end
	return nil
end

local function registerLight(entry: Entry): string?
	local registered =
		GameplayLightingService.registerLight(entry.lightId, descriptor(entry.operativeEntityId, entry.coverage))
	if not registered.didChange then
		return registered.rejectionReasonId or PersonalFlashlightContracts.RejectionReasonIds.LightingRejected
	end
	local record = lightingRecord(entry.lightId)
	if record == nil or record.activationStateId ~= LIGHT_INACTIVE then
		GameplayLightingService.removeLight(entry.lightId)
		return PersonalFlashlightContracts.RejectionReasonIds.LightingRejected
	end
	entry.lightRegistered = true
	return nil
end

local function nextTransitionTimestamp(entry: Entry, serverTimestamp: number): number
	local previous = entry.lastLightingTransitionTimestamp
	if previous ~= nil and serverTimestamp <= previous then
		return previous + TRANSITION_EPSILON_SECONDS
	end
	return serverTimestamp
end

local function commitState(entry: Entry, stateId: string)
	entry.stateId = stateId
	entry.revision += 1
	notify(entry)
	publish(entry, CHANGED, nil)
end

local function forceInactive(entry: Entry, serverTimestamp: number)
	if entry.stateId ~= ACTIVE then
		return
	end
	if entry.lightRegistered then
		local transitionTimestamp = nextTransitionTimestamp(entry, serverTimestamp)
		local deactivated = GameplayLightingService.deactivateLight(entry.lightId, transitionTimestamp)
		if deactivated.didChange or deactivated.rejectionReasonId == nil then
			entry.lastLightingTransitionTimestamp = transitionTimestamp
		end
	end
	commitState(entry, INACTIVE)
end

local function removeRegisteredLight(entry: Entry, serverTimestamp: number)
	forceInactive(entry, serverTimestamp)
	if entry.lightRegistered then
		GameplayLightingService.removeLight(entry.lightId)
		entry.lightRegistered = false
	end
end

local function createDevelopmentHarness()
	if not RunService:IsStudio() or developmentHarness ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "LK0406PersonalFlashlightDevelopment"
	local readSnapshot = Instance.new("BindableFunction")
	readSnapshot.Name = "ReadSnapshot"
	readSnapshot.OnInvoke = function()
		local states = {}
		local operativeIds = {}
		for operativeEntityId in entriesByOperativeId do
			table.insert(operativeIds, operativeEntityId)
		end
		table.sort(operativeIds)
		for _, operativeEntityId in operativeIds do
			table.insert(states, copyState(entriesByOperativeId[operativeEntityId]))
		end
		return table.freeze({
			states = table.freeze(states),
			lightingSnapshot = GameplayLightingService.readSnapshot(),
		})
	end
	readSnapshot.Parent = folder
	folder.Parent = ServerStorage
	developmentHarness = folder
end

function PersonalFlashlightService.start()
	if started then
		return
	end
	GameplayLightingService.start()
	started = true
	serviceGeneration += 1
	local generation = serviceGeneration
	remoteConnection = toggleIntentRemote.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 1 then
			local entry = entryByPlayer[player]
			rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.MalformedRequest)
			return
		end
		PersonalFlashlightService.requestToggle(player, select(1, ...))
	end)
	lifeConnection = OperativeLifeService.subscribe(function(player, snapshot, revision)
		if not started or generation ~= serviceGeneration then
			return
		end
		local entry = entryByPlayer[player]
		if entry == nil or snapshot.operativeEntityId ~= entry.operativeEntityId then
			return
		end
		local current = OperativeLifeService.read(player)
		if current == nil or current.revision ~= revision or current.snapshot.lifeStateId ~= snapshot.lifeStateId then
			return
		end
		entry.lastLifeRevision = revision
		if snapshot.lifeStateId ~= "Alive" then
			forceInactive(entry, Workspace:GetServerTimeNow())
		end
	end)
	rosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
		if not started or generation ~= serviceGeneration then
			return
		end
		if eventName == "Registered" then
			local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
			if player ~= nil and entriesByOperativeId[operativeEntityId] == nil then
				PersonalFlashlightService.registerOperative(operativeEntityId, player)
			end
		elseif OperativeLifeService.playerForOperativeEntityId(operativeEntityId) == nil then
			PersonalFlashlightService.unregisterOperative(operativeEntityId)
		end
	end)
	failureConnection = SquadFailureService.subscribe(function(failureState)
		if not started or generation ~= serviceGeneration or failureState.statusId ~= "Failed" then
			return
		end
		local operativeIds = {}
		for operativeEntityId in entriesByOperativeId do
			table.insert(operativeIds, operativeEntityId)
		end
		table.sort(operativeIds)
		for _, operativeEntityId in operativeIds do
			PersonalFlashlightService.setOperativeEligibility(operativeEntityId, false)
		end
	end)
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			PersonalFlashlightService.registerOperative(read.operativeEntityId, player)
		end
	end
	createDevelopmentHarness()
end

function PersonalFlashlightService.stop()
	if not started then
		return
	end
	local operativeIds = {}
	for operativeEntityId in entriesByOperativeId do
		table.insert(operativeIds, operativeEntityId)
	end
	table.sort(operativeIds)
	for _, operativeEntityId in operativeIds do
		PersonalFlashlightService.unregisterOperative(operativeEntityId)
	end
	started = false
	serviceGeneration += 1
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
	if failureConnection ~= nil then
		failureConnection:Disconnect()
		failureConnection = nil
	end
	if developmentHarness ~= nil then
		developmentHarness:Destroy()
		developmentHarness = nil
	end
	table.clear(listeners)
	nextListenerId = 0
end

function PersonalFlashlightService.registerOperative(operativeEntityId: string, player: Player): OperationResult
	if not started then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.ServiceStopped)
	end
	if type(operativeEntityId) ~= "string" or operativeEntityId == "" or player == nil then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.InvalidPlayer)
	end
	if entriesByOperativeId[operativeEntityId] ~= nil then
		return result(
			REJECTED,
			entriesByOperativeId[operativeEntityId],
			PersonalFlashlightContracts.RejectionReasonIds.DuplicateOperative
		)
	end
	if entryByPlayer[player] ~= nil then
		return result(
			REJECTED,
			entryByPlayer[player],
			PersonalFlashlightContracts.RejectionReasonIds.PlayerAlreadyRegistered
		)
	end
	local read = OperativeLifeService.read(player)
	if
		OperativeLifeService.playerForOperativeEntityId(operativeEntityId) ~= player
		or read == nil
		or read.snapshot.operativeEntityId ~= operativeEntityId
	then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.OwnershipMismatch)
	end
	nextGeneration += 1
	local entry: Entry = {
		operativeEntityId = operativeEntityId,
		player = player,
		lightId = deterministicLightId(operativeEntityId),
		stateId = INACTIVE,
		revision = 0,
		eligible = true,
		lightRegistered = false,
		generation = nextGeneration,
		lastAcceptedToggleTimestamp = nil,
		lastLightingTransitionTimestamp = nil,
		lastLifeRevision = read.revision,
		coverage = resolveCoverage(player),
	}
	local rejectionReasonId = registerLight(entry)
	if rejectionReasonId ~= nil then
		return result(REJECTED, nil, rejectionReasonId)
	end
	entriesByOperativeId[operativeEntityId] = entry
	entryByPlayer[player] = entry
	notify(entry)
	publish(entry, EQUIVALENT, nil)
	return result(CHANGED, entry, nil)
end

function PersonalFlashlightService.unregisterOperative(operativeEntityId: string): OperationResult
	local entry = entriesByOperativeId[operativeEntityId]
	if entry == nil then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.UnknownOperative)
	end
	removeRegisteredLight(entry, Workspace:GetServerTimeNow())
	publish(entry, EQUIVALENT, nil)
	entriesByOperativeId[operativeEntityId] = nil
	entryByPlayer[entry.player] = nil
	entry.generation += 1
	return result(CHANGED, entry, nil)
end

function PersonalFlashlightService.setOperativeEligibility(
	operativeEntityId: string,
	eligible: boolean
): OperationResult
	local entry = entriesByOperativeId[operativeEntityId]
	if entry == nil then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.UnknownOperative)
	end
	if type(eligible) ~= "boolean" then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.Ineligible)
	end
	if entry.eligible == eligible then
		return result(EQUIVALENT, entry, nil)
	end
	entry.eligible = eligible
	if eligible then
		local rejectionReasonId = registerLight(entry)
		if rejectionReasonId ~= nil then
			entry.eligible = false
			return rejectEntry(entry, rejectionReasonId)
		end
	else
		removeRegisteredLight(entry, Workspace:GetServerTimeNow())
	end
	publish(entry, EQUIVALENT, nil)
	return result(CHANGED, entry, nil)
end

function PersonalFlashlightService.requestToggle(player: Player, requestedActive: unknown): OperationResult
	if not started then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.ServiceStopped)
	end
	local entry = entryByPlayer[player]
	if entry == nil then
		return result(REJECTED, nil, PersonalFlashlightContracts.RejectionReasonIds.UnknownOperative)
	end
	local generation = entry.generation
	if type(requestedActive) ~= "boolean" then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.MalformedRequest)
	end
	if not entry.eligible or not entry.lightRegistered then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.Ineligible)
	end
	local read = OperativeLifeService.read(player)
	if
		read == nil
		or read.snapshot.operativeEntityId ~= entry.operativeEntityId
		or OperativeLifeService.playerForOperativeEntityId(entry.operativeEntityId) ~= player
	then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.OwnershipMismatch)
	end
	if read.snapshot.lifeStateId ~= "Alive" then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.NotAlive)
	end
	local now = Workspace:GetServerTimeNow()
	local lastAccepted = entry.lastAcceptedToggleTimestamp
	if lastAccepted ~= nil and now - lastAccepted < PersonalFlashlightConfig.ToggleCooldownSeconds then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.Cooldown)
	end
	if entry ~= entriesByOperativeId[entry.operativeEntityId] or generation ~= entry.generation then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.StaleLifecycle)
	end
	local requestedStateId = if requestedActive then ACTIVE else INACTIVE
	if entry.stateId == requestedStateId then
		return result(EQUIVALENT, entry, nil)
	end
	local transitionTimestamp = nextTransitionTimestamp(entry, now)
	local lightingResult = if requestedActive
		then GameplayLightingService.activateLight(entry.lightId, transitionTimestamp, nil)
		else GameplayLightingService.deactivateLight(entry.lightId, transitionTimestamp)
	if lightingResult.rejectionReasonId ~= nil then
		local reason = if lightingResult.rejectionReasonId == BUDGET_EXCEEDED
			then BUDGET_EXCEEDED
			else PersonalFlashlightContracts.RejectionReasonIds.LightingRejected
		return rejectEntry(entry, reason)
	end
	local record = lightingRecord(entry.lightId)
	local expectedLightingState = if requestedActive then LIGHT_ACTIVE else LIGHT_INACTIVE
	if record == nil or record.activationStateId ~= expectedLightingState then
		return rejectEntry(entry, PersonalFlashlightContracts.RejectionReasonIds.LightingRejected)
	end
	entry.lastAcceptedToggleTimestamp = now
	entry.lastLightingTransitionTimestamp = transitionTimestamp
	commitState(entry, requestedStateId)
	return result(CHANGED, entry, nil)
end

function PersonalFlashlightService.readOperativeState(operativeEntityId: string): OperativeFlashlightState?
	local entry = entriesByOperativeId[operativeEntityId]
	return if entry == nil then nil else copyState(entry)
end

function PersonalFlashlightService.readCoverageFacts(
	operativeEntityId: string
): PersonalFlashlightCoverage.CoverageFacts?
	local entry = entriesByOperativeId[operativeEntityId]
	if entry == nil or entry.stateId ~= ACTIVE or not entry.eligible or not entry.lightRegistered then
		return nil
	end
	local read = OperativeLifeService.read(entry.player)
	if read == nil or read.snapshot.lifeStateId ~= "Alive" then
		return nil
	end
	local character = entry.player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	local direction = (root :: BasePart).CFrame.LookVector
	return PersonalFlashlightCoverage.buildFacts(
		{ x = position.X, y = position.Y, z = position.Z },
		{ x = direction.X, y = direction.Y, z = direction.Z },
		entry.coverage.rangeStuds,
		entry.coverage.coneAngleDegrees,
		PersonalFlashlightConfig.VisibilityProfileId
	)
end

function PersonalFlashlightService.qualifiesPoint(operativeEntityId: string, point: Vector3): boolean
	local facts = PersonalFlashlightService.readCoverageFacts(operativeEntityId)
	if facts == nil then
		return false
	end
	return PersonalFlashlightCoverage.qualifiesPoint(facts, { x = point.X, y = point.Y, z = point.Z })
end

function PersonalFlashlightService.subscribe(listener: Listener): ListenerConnection?
	if not started or type(listener) ~= "function" then
		return nil
	end
	nextListenerId += 1
	local listenerId = nextListenerId
	listeners[listenerId] = listener
	local operativeIds = {}
	for operativeEntityId in entriesByOperativeId do
		table.insert(operativeIds, operativeEntityId)
	end
	table.sort(operativeIds)
	for _, operativeEntityId in operativeIds do
		pcall(listener, copyState(entriesByOperativeId[operativeEntityId]))
	end
	local connected = true
	local connection = {} :: ListenerConnection
	function connection:Disconnect()
		if not connected then
			return
		end
		connected = false
		listeners[listenerId] = nil
	end
	return connection
end

return table.freeze(PersonalFlashlightService)
