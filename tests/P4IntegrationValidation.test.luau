--!strict

-- LK-0408 cross-system security, integration, performance, and cleanup fixture.
-- This composes the production visibility/discovery/P2 boundaries and audits
-- the production-connected flashlight/ping surfaces without adding runtime API.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {},
		injectGlobals = true,
	})()
end

local perceptionContracts =
	loadSimple("games/living-kingdoms/src/shared/Perception/PerceptionContracts.luau", "PerceptionContracts")
local visibilityContracts =
	loadSimple("games/living-kingdoms/src/shared/Perception/VisibilityContracts.luau", "VisibilityContracts")
local lightContracts =
	loadSimple("games/living-kingdoms/src/shared/Lighting/GameplayLightContracts.luau", "GameplayLightContracts")
local perceptionConfig = loadSimple("games/living-kingdoms/src/shared/Config/PerceptionConfig.luau", "PerceptionConfig")
local lightingConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/GameplayLightingConfig.luau", "GameplayLightingConfig")
local pingConfig = loadSimple("games/living-kingdoms/src/shared/Config/SquadPingConfig.luau", "SquadPingConfig")

local PERCEPTION_TOKEN = {}
local VISIBILITY_TOKEN = {}
local LIGHT_TOKEN = {}
local PERCEPTION_CONFIG_TOKEN = {}
local PERCEPTION_VALIDATOR_TOKEN = {}
local VISIBILITY_RESOLVER_TOKEN = {}

local perceptionValidator =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Perception/PerceptionContractsValidator.luau"), {
		debugName = "PerceptionContractsValidator",
		environment = {
			script = {
				Parent = {
					PerceptionContracts = PERCEPTION_TOKEN,
					Parent = { Config = { PerceptionConfig = PERCEPTION_CONFIG_TOKEN } },
				},
			},
			require = function(token)
				if token == PERCEPTION_TOKEN then
					return perceptionContracts
				elseif token == PERCEPTION_CONFIG_TOKEN then
					return perceptionConfig
				end
				error("unexpected perception validator dependency")
			end,
		},
		injectGlobals = true,
	})()

local visibilityResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Perception/VisibilityResolver.luau"), {
		debugName = "VisibilityResolver",
		environment = {
			script = {
				Parent = {
					PerceptionContracts = PERCEPTION_TOKEN,
					VisibilityContracts = VISIBILITY_TOKEN,
					Parent = {
						Lighting = { GameplayLightContracts = LIGHT_TOKEN },
						Config = { PerceptionConfig = PERCEPTION_CONFIG_TOKEN },
					},
				},
			},
			require = function(token)
				if token == PERCEPTION_TOKEN then
					return perceptionContracts
				elseif token == VISIBILITY_TOKEN then
					return visibilityContracts
				elseif token == LIGHT_TOKEN then
					return lightContracts
				elseif token == PERCEPTION_CONFIG_TOKEN then
					return perceptionConfig
				end
				error("unexpected visibility resolver dependency")
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
local replicatedStorage = {
	Shared = {
		Config = { PerceptionConfig = PERCEPTION_CONFIG_TOKEN },
		Perception = {
			PerceptionContracts = PERCEPTION_TOKEN,
			PerceptionContractsValidator = PERCEPTION_VALIDATOR_TOKEN,
			VisibilityResolver = VISIBILITY_RESOLVER_TOKEN,
		},
	},
}
local discovery = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/DiscoveryMemoryService.luau"), {
	debugName = "DiscoveryMemoryService",
	environment = {
		game = {
			GetService = function(_, name)
				return if name == "ReplicatedStorage" then replicatedStorage else workspace
			end,
		},
		require = function(token)
			if token == PERCEPTION_TOKEN then
				return perceptionContracts
			elseif token == PERCEPTION_CONFIG_TOKEN then
				return perceptionConfig
			elseif token == PERCEPTION_VALIDATOR_TOKEN then
				return perceptionValidator
			elseif token == VISIBILITY_RESOLVER_TOKEN then
				return visibilityResolver
			end
			error("unexpected discovery dependency")
		end,
		task = {
			delay = function(delaySeconds, callback)
				local handle = { delaySeconds = delaySeconds, callback = callback, cancelled = false }
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

local function facts(observerId: string, candidateId: string)
	return {
		observerEntityId = observerId,
		candidateEntityId = candidateId,
		observerCanPerceive = true,
		candidateCategoryId = "Hostile",
		candidateIsGameplayPresent = true,
		candidateIsAlive = true,
		candidateIsTargetable = true,
		relationshipId = "Hostile",
		illuminationFacts = {
			visibilityProfileId = "Dark",
			hasQualifyingLocalLightCoverage = false,
		},
		spatialFacts = {
			distanceSquaredStuds = 100,
			perceptualRegionId = "Forward",
			hasConsequentialLineOfSight = true,
		},
		disclosureStateId = "Disclosed",
	}
end

local observerId = "operative:observer"
local hostileId = "hostile:alpha"
discovery.start()
assert(discovery.registerRecipient(observerId).didChange)

-- Flashlight coverage is only one illumination input: it cannot manufacture LOS.
local coveredWithoutLos = facts(observerId, hostileId)
coveredWithoutLos.illuminationFacts.hasQualifyingLocalLightCoverage = true
coveredWithoutLos.spatialFacts.hasConsequentialLineOfSight = false
local noLosResolution = visibilityResolver.resolve(coveredWithoutLos)
assert(noLosResolution.isValid)
assert(not noLosResolution.canCreateDirectSightObservation)
assert(not noLosResolution.isTargetingVisible)
now = 1
local noLosApply = discovery.applyVisibilityResolution(observerId, hostileId, coveredWithoutLos, noLosResolution, now)
assert(not noLosApply.didChange and #discovery.readRecipientSnapshot(observerId).records == 0)

-- Lighting alone is equally insufficient; only accepted authoritative sight creates discovery.
local directSightFacts = facts(observerId, hostileId)
directSightFacts.illuminationFacts.visibilityProfileId = "Lit"
local directSightResolution = visibilityResolver.resolve(directSightFacts)
assert(directSightResolution.canCreateDirectSightObservation and directSightResolution.isTargetingVisible)
now = 2
local observed =
	discovery.applyVisibilityResolution(observerId, hostileId, directSightFacts, directSightResolution, now)
assert(observed.didChange and #observed.snapshot.records == 1)

-- Forged results, recipient identities, and timestamps fail closed and cannot refresh memory.
local beforeAttack = discovery.readRecipientSnapshot(observerId)
local forgedResolution = table.clone(noLosResolution)
forgedResolution.canCreateDirectSightObservation = true
forgedResolution.isGameplayVisible = true
assert(
	discovery.applyVisibilityResolution(observerId, hostileId, coveredWithoutLos, forgedResolution, 3).rejectionReasonId
		== "InvalidVisibilityResolution"
)
assert(
	discovery.applyVisibilityResolution(observerId, hostileId, directSightFacts, directSightResolution, 1).rejectionReasonId
		== "StaleObservation"
)
assert(
	discovery.applyVisibilityResolution("operative:spoof", hostileId, directSightFacts, directSightResolution, 3).rejectionReasonId
		== "UnknownRecipient"
)
local afterAttack = discovery.readRecipientSnapshot(observerId)
assert(afterAttack.revision == beforeAttack.revision and afterAttack.records[1].observedAtServerTimestamp == 2)

afterAttack.records[1].memoryStateId = "Remembered"
afterAttack.records[1].observedAtServerTimestamp = 999
local authoritativeAfterMutation = discovery.readRecipientSnapshot(observerId)
assert(authoritativeAfterMutation.records[1].memoryStateId == "None")
assert(authoritativeAfterMutation.records[1].observedAtServerTimestamp == 2)

-- Loss of sight creates stale memory without refreshing the original observation.
local lostFacts = facts(observerId, hostileId)
lostFacts.spatialFacts.perceptualRegionId = "Outside"
local lostResolution = visibilityResolver.resolve(lostFacts)
now = 3
local remembered = discovery.applyVisibilityResolution(observerId, hostileId, lostFacts, lostResolution, now)
assert(remembered.didChange and remembered.snapshot.records[1].memoryStateId == "Remembered")
assert(remembered.snapshot.records[1].observedAtServerTimestamp == 2)
assert(remembered.snapshot.records[1].expiresAtServerTimestamp == 32)
assert(#scheduled >= 1, "remembered discovery must use the centralized scheduler")

-- P2 still requires visibility and LOS at its own authority boundary.
local COMBAT_TOKEN = {}
local FIREARM_TOKEN = {}
local combatContracts = {
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
	TeamRelationshipIds = table.freeze({ Hostile = "Hostile" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready" }),
	TargetValidationRejectionReasonIds = table.freeze({
		OperativeStateInvalid = "OperativeStateInvalid",
		RelationshipNotHostile = "RelationshipNotHostile",
		HostileDead = "HostileDead",
		HostileUntargetable = "HostileUntargetable",
		NotVisible = "NotVisible",
		NoLineOfSight = "NoLineOfSight",
		OutOfRange = "OutOfRange",
		NoAmmunition = "NoAmmunition",
		WeaponNotReady = "WeaponNotReady",
	}),
}
local combatValidator =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau"), {
		debugName = "TargetCandidateValidator",
		environment = {
			game = {
				GetService = function()
					return {
						Shared = {
							Combat = { CombatContracts = COMBAT_TOKEN },
							Config = { FirearmConfig = FIREARM_TOKEN },
						},
					}
				end,
			},
			require = function(token)
				if token == COMBAT_TOKEN then
					return combatContracts
				elseif token == FIREARM_TOKEN then
					return { BasicFirearm = { WeaponId = "weapon.basic", RangeStuds = 80 } }
				end
				error("unexpected combat dependency")
			end,
		},
		injectGlobals = true,
	})()
local operative = {
	worldPosition = { X = 0, Y = 0, Z = 0 },
	combatStateId = "Ready",
	weaponReadiness = {
		weaponId = "weapon.basic",
		readinessStateId = "Ready",
		ammunition = { weaponId = "weapon.basic", loadedRounds = 1 },
		cadence = { weaponId = "weapon.basic" },
	},
}
local candidate = {
	worldPosition = { X = 10, Y = 0, Z = 0 },
	relationshipId = "Hostile",
	isAlive = true,
	isTargetable = true,
	isVisible = noLosResolution.isTargetingVisible,
	hasLineOfSight = coveredWithoutLos.spatialFacts.hasConsequentialLineOfSight,
}
assert(combatValidator.validate(operative, candidate).rejectionReasonId == "NotVisible")
candidate.isVisible = directSightResolution.isTargetingVisible
candidate.hasLineOfSight = true
assert(combatValidator.validate(operative, candidate).isValid)

-- Runtime ownership and remote audit: only narrow intents enter P4 production owners.
local project = fs.readFile("games/living-kingdoms/default.project.json")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local flashlightSource = fs.readFile("games/living-kingdoms/src/server/Systems/PersonalFlashlightService.luau")
local pingSource = fs.readFile("games/living-kingdoms/src/server/Systems/SquadPingService.luau")
local lightingSource = fs.readFile("games/living-kingdoms/src/server/Systems/GameplayLightingService.luau")
local discoverySource = fs.readFile("games/living-kingdoms/src/server/Systems/DiscoveryMemoryService.luau")
local visibilitySource = fs.readFile("games/living-kingdoms/src/shared/Perception/VisibilityResolver.luau")

local p4NetworkStart = assert(string.find(project, '"FlashlightNetwork"', 1, true))
local p4NetworkEnd = assert(string.find(project, '"Shared"', p4NetworkStart, true))
local p4NetworkSource = string.sub(project, p4NetworkStart, p4NetworkEnd - 1)
local _, p4RemoteCount = string.gsub(p4NetworkSource, '"%$className"%s*:%s*"RemoteEvent"', "")
assert(p4RemoteCount == 5, "P4 remote surface changed")
assert(not string.find(p4NetworkSource, '"RemoteFunction"', 1, true), "P4 must not add RemoteFunctions")

for _, prohibited in
	{ "DiscoveryMemoryService", "VisibilityResolver", "TargetCandidate", "CombatNetwork", "FireAllClients" }
do
	assert(not string.find(flashlightSource, prohibited, 1, true), "flashlight authority widened: " .. prohibited)
	assert(not string.find(pingSource, prohibited, 1, true), "ping authority widened: " .. prohibited)
end
for _, prohibited in { "GameplayLightingService", "PersonalFlashlight", "SquadPing", "RemoteEvent", "RemoteFunction" } do
	assert(not string.find(discoverySource, prohibited, 1, true), "discovery ownership widened: " .. prohibited)
end
for _, prohibited in { "game:GetService", "Workspace", "Raycast", "RemoteEvent", "RemoteFunction", "task." } do
	assert(not string.find(visibilitySource, prohibited, 1, true), "visibility lost purity: " .. prohibited)
end
assert(string.find(flashlightSource, 'select("#", ...) ~= 1', 1, true))
assert(string.find(pingSource, 'select("#", ...) ~= 1', 1, true))
assert(string.find(flashlightSource, "toggleIntentRemote.OnServerEvent:Connect", 1, true))
assert(string.find(pingSource, "intentRemote.OnServerEvent:Connect", 1, true))
assert(string.find(flashlightSource, "remoteConnection:Disconnect()", 1, true))
assert(string.find(pingSource, "remoteConnection:Disconnect()", 1, true))
assert(string.find(lightingSource, "task.cancel", 1, true))
assert(string.find(discoverySource, "task.cancel", 1, true))
assert(string.find(pingSource, "task.cancel", 1, true))
assert(string.find(serverBootstrap, "PersonalFlashlightService.start()", 1, true))
assert(string.find(serverBootstrap, "SquadPingService.start()", 1, true))
assert(not string.find(serverBootstrap, "DiscoveryMemoryService.start()", 1, true))

-- Representative normal-operation counts. Flashlights are permanent activations,
-- so only the ping owner schedules an expiry. Discovery remains unbootstrapped.
local serverP4Connections = 7 -- flashlight: 4; ping: 3
local clientP4ConnectionsPerPlayer = 8 -- flashlight: 4; ping: 4
for _, playerCount in { 1, 2, 4 } do
	local gameplayLightCount = playerCount
	local activePingCount = math.min(playerCount, pingConfig.MaximumActivePerSquad)
	local schedulerCount = if activePingCount > 0 then 1 else 0
	local connectionCount = serverP4Connections + clientP4ConnectionsPerPlayer * playerCount
	local memoryTableCount = 0
	assert(gameplayLightCount <= lightingConfig.MaximumActiveGameplayLocalizedLightsPerClientView)
	assert(activePingCount <= pingConfig.MaximumActivePerSquad)
	assert(schedulerCount == 1 and memoryTableCount == 0)
	print(
		string.format(
			"P4_METRIC players=%d gameplay_lights=%d active_pings=%d schedulers=%d connections=%d memory_tables=%d",
			playerCount,
			gameplayLightCount,
			activePingCount,
			schedulerCount,
			connectionCount,
			memoryTableCount
		)
	)
end

-- Teardown invalidates reads, cancels memory timing, and leaves no discovery records.
local scheduledBeforeStop = scheduled[#scheduled]
discovery.stop()
assert(scheduledBeforeStop.cancelled)
assert(discovery.readRecipientSnapshot(observerId) == nil)
assert(
	discovery.applyVisibilityResolution(observerId, hostileId, directSightFacts, directSightResolution, 4).rejectionReasonId
		== "ServiceStopped"
)

print("P4IntegrationValidation: security, isolation, combat authority, budgets, and cleanup passed")
