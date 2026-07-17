--!strict

-- LK-0406 server ownership, activation, coverage, replication, and security fixtures.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "LK-0406 fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, environment = {}, injectGlobals = true })()
end

local lightConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/GameplayLightingConfig.luau", "GameplayLightingConfig")
local flashlightConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/PersonalFlashlightConfig.luau", "PersonalFlashlightConfig")
local lightContracts =
	loadSimple("games/living-kingdoms/src/shared/Lighting/GameplayLightContracts.luau", "GameplayLightContracts")
local flashlightContracts = loadSimple(
	"games/living-kingdoms/src/shared/Lighting/PersonalFlashlightContracts.luau",
	"PersonalFlashlightContracts"
)
local coverage =
	loadSimple("games/living-kingdoms/src/server/Systems/PersonalFlashlightCoverage.luau", "PersonalFlashlightCoverage")

local LIGHT_CONFIG_TOKEN = {}
local FLASHLIGHT_CONFIG_TOKEN = {}
local LIGHT_CONTRACTS_TOKEN = {}
local FLASHLIGHT_CONTRACTS_TOKEN = {}
local VALIDATOR_TOKEN = {}
local LIGHTING_TOKEN = {}
local LIFE_TOKEN = {}
local COVERAGE_TOKEN = {}
local FAILURE_TOKEN = {}

local validator =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Lighting/GameplayLightDescriptorValidator.luau"), {
		debugName = "GameplayLightDescriptorValidator",
		environment = {
			script = {
				Parent = {
					GameplayLightContracts = LIGHT_CONTRACTS_TOKEN,
					Parent = { Config = { GameplayLightingConfig = LIGHT_CONFIG_TOKEN } },
				},
			},
			require = function(token)
				if token == LIGHT_CONTRACTS_TOKEN then
					return lightContracts
				elseif token == LIGHT_CONFIG_TOKEN then
					return lightConfig
				end
				error("unexpected validator dependency")
			end,
		},
		injectGlobals = true,
	})()

local now = 0
local scheduled = {}
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
local runService = {
	IsStudio = function()
		return false
	end,
}
local serverStorage = {}
local replicatedStorageForLighting = {
	Shared = {
		Config = { GameplayLightingConfig = LIGHT_CONFIG_TOKEN },
		Lighting = {
			GameplayLightContracts = LIGHT_CONTRACTS_TOKEN,
			GameplayLightDescriptorValidator = VALIDATOR_TOKEN,
		},
	},
}
local lightingService =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/GameplayLightingService.luau"), {
		debugName = "GameplayLightingService",
		environment = {
			game = {
				GetService = function(_, name)
					return if name == "ReplicatedStorage" then replicatedStorageForLighting else workspace
				end,
			},
			require = function(token)
				if token == LIGHT_CONFIG_TOKEN then
					return lightConfig
				elseif token == LIGHT_CONTRACTS_TOKEN then
					return lightContracts
				elseif token == VALIDATOR_TOKEN then
					return validator
				end
				error("unexpected lighting dependency")
			end,
			task = {
				delay = function(delaySeconds, callback)
					local handle = { delay = delaySeconds, callback = callback, cancelled = false }
					table.insert(scheduled, handle)
					return handle
				end,
				cancel = function(handle)
					handle.cancelled = true
				end,
			},
		},
		injectGlobals = true,
	})()

local function signal()
	local listeners = {}
	local result = {}
	function result:Connect(callback)
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
	function result:Fire(...)
		for _, callback in table.clone(listeners) do
			callback(...)
		end
	end
	function result:Listeners()
		return table.clone(listeners)
	end
	return result
end

local intentSignal = signal()
local stateMessages = {}
local toggleIntentRemote = { OnServerEvent = intentSignal }
local stateRemote = {
	FireClient = function(_, player, payload)
		table.insert(stateMessages, { player = player, payload = payload })
	end,
}
local network = {
	WaitForChild = function(_, name)
		return if name == "ToggleIntent" then toggleIntentRemote else stateRemote
	end,
}
local replicatedStorage = {
	Shared = {
		Config = {
			GameplayLightingConfig = LIGHT_CONFIG_TOKEN,
			PersonalFlashlightConfig = FLASHLIGHT_CONFIG_TOKEN,
		},
		Lighting = {
			GameplayLightContracts = LIGHT_CONTRACTS_TOKEN,
			PersonalFlashlightContracts = FLASHLIGHT_CONTRACTS_TOKEN,
		},
	},
	WaitForChild = function(_, name)
		assert(name == "FlashlightNetwork")
		return network
	end,
}

local lifeByPlayer = {}
local playerById = {}
local roster = {}
local lifeSignal = signal()
local rosterSignal = signal()
local failureSignal = signal()
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
local failureService = {
	subscribe = function(callback)
		return failureSignal:Connect(callback)
	end,
}

local registeredDescriptors = {}
local lightingCalls = { register = 0, activate = 0, deactivate = 0, remove = 0 }
local lightingAdapter = {}
function lightingAdapter.start()
	lightingService.start()
end
function lightingAdapter.registerLight(lightId, descriptor)
	lightingCalls.register += 1
	registeredDescriptors[lightId] = descriptor
	return lightingService.registerLight(lightId, descriptor)
end
function lightingAdapter.activateLight(...)
	lightingCalls.activate += 1
	return lightingService.activateLight(...)
end
function lightingAdapter.deactivateLight(...)
	lightingCalls.deactivate += 1
	return lightingService.deactivateLight(...)
end
function lightingAdapter.removeLight(...)
	lightingCalls.remove += 1
	return lightingService.removeLight(...)
end
function lightingAdapter.readSnapshot()
	return lightingService.readSnapshot()
end

local parentTokens = {
	GameplayLightingService = LIGHTING_TOKEN,
	OperativeLifeService = LIFE_TOKEN,
	PersonalFlashlightCoverage = COVERAGE_TOKEN,
	SquadFailureService = FAILURE_TOKEN,
}
local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/PersonalFlashlightService.luau"), {
	debugName = "PersonalFlashlightService",
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
		script = { Parent = parentTokens },
		require = function(token)
			if token == FLASHLIGHT_CONFIG_TOKEN then
				return flashlightConfig
			elseif token == LIGHT_CONTRACTS_TOKEN then
				return lightContracts
			elseif token == FLASHLIGHT_CONTRACTS_TOKEN then
				return flashlightContracts
			elseif token == LIGHTING_TOKEN then
				return lightingAdapter
			elseif token == LIFE_TOKEN then
				return lifeService
			elseif token == COVERAGE_TOKEN then
				return coverage
			elseif token == FAILURE_TOKEN then
				return failureService
			end
			error("unexpected flashlight service dependency")
		end,
	},
	injectGlobals = true,
})()

local function makePlayer(userId, operativeEntityId)
	local root = {
		Position = { X = 0, Y = 0, Z = 0 },
		CFrame = { LookVector = { X = 0, Y = 0, Z = -1 } },
		IsA = function(_, className)
			return className == "BasePart"
		end,
	}
	local character = {
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
	}
	return { UserId = userId, Character = character, operativeEntityId = operativeEntityId }
end

local function admit(player, operativeEntityId, lifeState, revision)
	playerById[operativeEntityId] = player
	lifeByPlayer[player] = {
		revision = revision or 0,
		snapshot = { operativeEntityId = operativeEntityId, lifeStateId = lifeState or "Alive" },
	}
	table.insert(roster, operativeEntityId)
end

local function lightingRecord(lightId)
	local snapshot = lightingService.readSnapshot()
	assert(snapshot ~= nil)
	for _, record in snapshot.records do
		if record.lightId == lightId then
			return record
		end
	end
	return nil
end

local function reset()
	service.stop()
	lightingService.stop()
	table.clear(lifeByPlayer)
	table.clear(playerById)
	table.clear(roster)
	table.clear(stateMessages)
	table.clear(registeredDescriptors)
	table.clear(scheduled)
	for key in lightingCalls do
		lightingCalls[key] = 0
	end
	now = 0
	lightingService.start()
	service.start()
end

reset()
local owner = makePlayer(1, "operative.player:1")
local other = makePlayer(2, "operative.player:2")
admit(owner, owner.operativeEntityId)
admit(other, other.operativeEntityId)

local registered = service.registerOperative(owner.operativeEntityId, owner)
assert(registered.didChange and registered.state.stateId == "Inactive" and registered.state.revision == 0)
local lightId = flashlightConfig.LightIdPrefix .. owner.operativeEntityId
assert(registered.state.lightId == lightId, "light identity must be deterministic")
local descriptor = registeredDescriptors[lightId]
assert(descriptor ~= nil and validator.validate(descriptor).isValid, "descriptor must remain LK-0401-valid")
assert(descriptor.ownerEntityId == owner.operativeEntityId)
assert(descriptor.sourceId == flashlightConfig.SourceId)
assert(descriptor.sourceTypeId == "ApprovedPersonal")
assert(descriptor.coverage.kind == "ForwardCone")
assert(descriptor.coverage.rangeStuds == 48 and descriptor.coverage.angleDegrees == 50)
assert(lightingRecord(lightId).activationStateId == "Inactive")
assert(service.registerOperative(owner.operativeEntityId, owner).rejectionReasonId == "DuplicateOperative")
assert(service.registerOperative(other.operativeEntityId, owner).rejectionReasonId == "PlayerAlreadyRegistered")
assert(service.registerOperative("invented", other).rejectionReasonId == "OwnershipMismatch")

now = 1
local activated = service.requestToggle(owner, true)
assert(activated.didChange and activated.state.stateId == "Active" and activated.state.revision == 1)
assert(lightingCalls.activate == 1 and lightingRecord(lightId).activationStateId == "Active")
now = 1.25
local equivalent = service.requestToggle(owner, true)
assert(equivalent.statusId == "Equivalent" and equivalent.state.revision == 1)
now = 1.5
local deactivated = service.requestToggle(owner, false)
assert(deactivated.didChange and deactivated.state.stateId == "Inactive" and deactivated.state.revision == 2)
assert(lightingCalls.deactivate == 1 and lightingRecord(lightId).activationStateId == "Inactive")
now = 1.75
assert(service.requestToggle(owner, false).statusId == "Equivalent")
now = 2
assert(service.requestToggle(owner, true).state.revision == 3, "reactivation must succeed")

now = 2.1
local cooldown = service.requestToggle(owner, false)
assert(
	cooldown.rejectionReasonId == "Cooldown" and service.readOperativeState(owner.operativeEntityId).stateId == "Active"
)
now = 2.25
assert(service.requestToggle(owner, false).didChange, "exact cooldown boundary must succeed")
local beforeMalformed = service.readOperativeState(owner.operativeEntityId)
for _, malformed in { nil, "true", 1, {}, { requestedActive = true }, { lightId = lightId }, { timestamp = 999 } } do
	local rejected = service.requestToggle(owner, malformed)
	assert(rejected.rejectionReasonId == "MalformedRequest")
end
local afterMalformed = service.readOperativeState(owner.operativeEntityId)
assert(afterMalformed.stateId == beforeMalformed.stateId and afterMalformed.revision == beforeMalformed.revision)
assert(service.requestToggle({}, true).rejectionReasonId == "UnknownOperative")

local otherRegistration = service.registerOperative(other.operativeEntityId, other)
assert(otherRegistration.didChange)
now = 3
assert(service.requestToggle(other, true).didChange)
assert(service.readOperativeState(owner.operativeEntityId).stateId == "Inactive")
assert(service.readOperativeState(other.operativeEntityId).stateId == "Active")
now = 3.25
assert(service.requestToggle(owner, true).didChange, "rate limiting must be isolated per operative")

local ownerRead = lifeByPlayer[owner]
ownerRead.revision = 1
ownerRead.snapshot = { operativeEntityId = owner.operativeEntityId, lifeStateId = "Incapacitated" }
lifeSignal:Fire(owner, ownerRead.snapshot, ownerRead.revision)
assert(service.readOperativeState(owner.operativeEntityId).stateId == "Inactive")
assert(lightingRecord(lightId).activationStateId == "Inactive", "incapacitation must force gameplay light off")
now = 4
assert(service.requestToggle(owner, true).rejectionReasonId == "NotAlive")
ownerRead.revision = 2
ownerRead.snapshot = { operativeEntityId = owner.operativeEntityId, lifeStateId = "Alive" }
lifeSignal:Fire(owner, ownerRead.snapshot, ownerRead.revision)
assert(service.readOperativeState(owner.operativeEntityId).stateId == "Inactive", "revival must not reactivate")
now = 4.25
assert(service.requestToggle(owner, true).didChange)
ownerRead.revision = 3
ownerRead.snapshot = { operativeEntityId = owner.operativeEntityId, lifeStateId = "Dead" }
lifeSignal:Fire(owner, ownerRead.snapshot, ownerRead.revision)
assert(service.readOperativeState(owner.operativeEntityId).stateId == "Inactive")
now = 5
assert(service.requestToggle(owner, true).rejectionReasonId == "NotAlive")

ownerRead.revision = 4
ownerRead.snapshot = { operativeEntityId = owner.operativeEntityId, lifeStateId = "Alive" }
lifeSignal:Fire(owner, ownerRead.snapshot, ownerRead.revision)
now = 5.25
assert(service.requestToggle(owner, true).didChange)
local facts = service.readCoverageFacts(owner.operativeEntityId)
assert(facts ~= nil and facts.rangeStuds == 48 and facts.coneAngleDegrees == 50)
assert(coverage.qualifiesPoint(facts, { x = 0, y = 0, z = -48 }), "range/cone boundary must qualify")
assert(coverage.qualifiesPoint(facts, { x = 0, y = 0, z = -20 }))
assert(not coverage.qualifiesPoint(facts, { x = 0, y = 0, z = -48.001 }))
assert(not coverage.qualifiesPoint(facts, { x = 30, y = 0, z = 0 }))
assert(facts.cameraDirection == nil and facts.hasLineOfSight == nil and facts.targetEntityId == nil)
now = 5.5
assert(service.requestToggle(owner, false).didChange)
assert(service.readCoverageFacts(owner.operativeEntityId) == nil)

local observedStates = {}
local subscription = service.subscribe(function(state)
	table.insert(observedStates, state)
end)
assert(subscription ~= nil and #observedStates == 2, "late subscriber must receive current safe snapshots")
local mutationOk = pcall(function()
	observedStates[1].stateId = "Active"
end)
assert(not mutationOk and service.readOperativeState(observedStates[1].operativeEntityId).stateId ~= "Active")
subscription:Disconnect()

local latestPayload = stateMessages[#stateMessages].payload
assert(flashlightContracts.validateSafeState(latestPayload))
assert(latestPayload.radius == nil and latestPayload.cone == nil and latestPayload.operativeEntityId == nil)
assert(latestPayload.discovery == nil and latestPayload.targetEntityId == nil and latestPayload.timestamp == nil)
local acceptedNew, reconciledState, reconciledRevision =
	flashlightContracts.reconcilePresentation(latestPayload.revision, latestPayload)
assert(acceptedNew and reconciledState == latestPayload.stateId and reconciledRevision == latestPayload.revision)
local acceptedStale = flashlightContracts.reconcilePresentation(latestPayload.revision + 1, latestPayload)
assert(not acceptedStale, "stale state must not override newer presentation")

local ownerRevisionBeforeRemoteAttacks = service.readOperativeState(owner.operativeEntityId).revision
intentSignal:Fire(other, { operativeEntityId = owner.operativeEntityId, requestedActive = true })
intentSignal:Fire(owner, true, lightId)
for _, payload in
	{
		{ operativeEntityId = owner.operativeEntityId },
		{ lightId = lightId },
		{ sourceId = "invented" },
		{ profile = "Lit" },
		{ radius = 64 },
		{ cone = 120 },
		{ timestamp = 1000 },
		{ revision = 1000 },
		{ targetEntityId = "hidden.enemy" },
		{ requestedActive = true, padding = string.rep("x", 10000) },
	}
do
	intentSignal:Fire(owner, payload)
end
assert(service.readOperativeState(owner.operativeEntityId).revision == ownerRevisionBeforeRemoteAttacks)
assert(service.readOperativeState(owner.operativeEntityId).stateId == "Inactive")

reset()
local budgetOwner = makePlayer(10, "operative.player:10")
admit(budgetOwner, budgetOwner.operativeEntityId)
assert(service.registerOperative(budgetOwner.operativeEntityId, budgetOwner).didChange)
for index = 1, lightConfig.MaximumActiveGameplayLocalizedLightsPerClientView do
	local id = "budget:" .. tostring(index)
	assert(lightingService.registerLight(id, {
		sourceId = id,
		sourceTypeId = "AuthoredEnvironmental",
		visibilityProfileId = "Lit",
		activation = { stateId = "Inactive" },
		coverage = { kind = "Radius", radiusStuds = 1 },
	}).didChange)
	assert(lightingService.activateLight(id, index, nil).didChange)
end
now = 20
local budgetRejected = service.requestToggle(budgetOwner, true)
assert(budgetRejected.rejectionReasonId == "BudgetExceeded")
assert(budgetRejected.state.stateId == "Inactive" and budgetRejected.state.revision == 0)
assert(lightingRecord(flashlightConfig.LightIdPrefix .. budgetOwner.operativeEntityId).activationStateId == "Inactive")

reset()
local lifecycleOwner = makePlayer(20, "operative.player:20")
admit(lifecycleOwner, lifecycleOwner.operativeEntityId)
assert(service.registerOperative(lifecycleOwner.operativeEntityId, lifecycleOwner).didChange)
local staleLifeCallback = lifeSignal:Listeners()[1]
local lifecycleLightId = flashlightConfig.LightIdPrefix .. lifecycleOwner.operativeEntityId
now = 1
assert(service.requestToggle(lifecycleOwner, true).didChange)
assert(service.unregisterOperative(lifecycleOwner.operativeEntityId).didChange)
assert(lightingRecord(lifecycleLightId) == nil, "unregister must remove the light")
lifeByPlayer[lifecycleOwner] = {
	revision = 0,
	snapshot = { operativeEntityId = lifecycleOwner.operativeEntityId, lifeStateId = "Alive" },
}
assert(service.registerOperative(lifecycleOwner.operativeEntityId, lifecycleOwner).didChange)
staleLifeCallback(lifecycleOwner, {
	operativeEntityId = lifecycleOwner.operativeEntityId,
	lifeStateId = "Dead",
}, 1)
assert(service.readOperativeState(lifecycleOwner.operativeEntityId).stateId == "Inactive")
now = 2
assert(service.requestToggle(lifecycleOwner, true).didChange, "stale life callback must not poison replacement")
failureSignal:Fire({ statusId = "Failed" })
local failedState = service.readOperativeState(lifecycleOwner.operativeEntityId)
assert(not failedState.eligible and failedState.stateId == "Inactive")
assert(lightingRecord(lifecycleLightId) == nil, "squad failure must remove gameplay light")
service.stop()
assert(service.readOperativeState(lifecycleOwner.operativeEntityId) == nil)
assert(lightingService.readSnapshot().records[1] == nil, "stop must clear registrations it owns")
assert(service.requestToggle(lifecycleOwner, true).rejectionReasonId == "ServiceStopped")

local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/PersonalFlashlightService.luau")
local coverageSource = fs.readFile("games/living-kingdoms/src/server/Systems/PersonalFlashlightCoverage.luau")
local bootstrapSource = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local projectSource = fs.readFile("games/living-kingdoms/default.project.json")
assert(string.find(bootstrapSource, "PersonalFlashlightService.start()", 1, true))
assert(string.find(projectSource, '"ToggleIntent"', 1, true) and string.find(projectSource, '"State"', 1, true))
assert(not string.find(serviceSource, ":Raycast", 1, true) and not string.find(coverageSource, ":Raycast", 1, true))
assert(not string.find(serviceSource, "VisibilityResolver", 1, true))
assert(not string.find(serviceSource, "DiscoveryMemoryService", 1, true))
assert(not string.find(serviceSource, "TargetCandidate", 1, true))
assert(not string.find(serviceSource, "GetPlayers", 1, true), "flashlight service must not iterate players/enemies")
assert(not string.find(serviceSource, "RemoteFunction", 1, true))
for _, excluded in { "battery", "durability", "inventory", "DataStore", "enemy" } do
	assert(not string.find(string.lower(serviceSource), string.lower(excluded), 1, true))
end

print("PersonalFlashlightService: LK-0406 ownership, lifecycle, budget, coverage, replication, and security passed")
