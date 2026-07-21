--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local players = {}
local ammunitionByUserId = {}
local collectionByUserId = {}

local CACHE_CONFIG_TOKEN = {}
local FIREARM_CONFIG_TOKEN = {}
local CACHE_SERVICE_TOKEN = {}
local COMBAT_SERVICE_TOKEN = {}

local playersService = {
	GetPlayers = function()
		return table.clone(players)
	end,
}

local replicatedStorage = {
	Shared = {
		Config = {
			AmmunitionCacheConfig = CACHE_CONFIG_TOKEN,
			FirearmConfig = FIREARM_CONFIG_TOKEN,
		},
	},
}

local cacheService = {
	readCollectionState = function(player)
		local state = collectionByUserId[player.UserId]
		if state == nil then
			return {
				processedCacheIds = {},
				grantedRoundsByCacheId = {},
			}
		end
		return {
			processedCacheIds = table.clone(state.processedCacheIds),
			grantedRoundsByCacheId = table.clone(state.grantedRoundsByCacheId),
		}
	end,
}

local combatService = {
	readReviveCombatState = function(player)
		local ammunition = ammunitionByUserId[player.UserId]
		if ammunition == nil then
			return nil
		end
		return {
			combatState = {
				weaponState = {
					ammunition = table.clone(ammunition),
				},
			},
		}
	end,
}

local service =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionScarcityTelemetryService.luau"), {
		debugName = "AmmunitionScarcityTelemetryService",
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					if serviceName == "Players" then
						return playersService
					end
					if serviceName == "ReplicatedStorage" then
						return replicatedStorage
					end
					error("unexpected service " .. serviceName)
				end,
			},
			script = {
				Parent = {
					AmmunitionCacheService = CACHE_SERVICE_TOKEN,
					OperativeCombatRuntimeService = COMBAT_SERVICE_TOKEN,
				},
			},
			require = function(token: unknown)
				if token == CACHE_CONFIG_TOKEN then
					return {
						Caches = {
							{ cacheId = "cache.a" },
							{ cacheId = "cache.b" },
							{ cacheId = "cache.c" },
						},
					}
				end
				if token == FIREARM_CONFIG_TOKEN then
					return {
						BasicFirearm = {
							PrototypeInitialLoadedRounds = 12,
							PrototypeInitialReserveRounds = 24,
						},
					}
				end
				if token == CACHE_SERVICE_TOKEN then
					return cacheService
				end
				if token == COMBAT_SERVICE_TOKEN then
					return combatService
				end
				error("unexpected module request")
			end,
		},
		injectGlobals = true,
	})()

local playerOne = { UserId = 101 }
local playerTwo = { UserId = 202 }
players = { playerOne, playerTwo }
ammunitionByUserId[101] = { loadedRounds = 12, reserveRounds = 24 }
ammunitionByUserId[202] = { loadedRounds = 12, reserveRounds = 24 }

service.resetSampling()
local initial = service.sample(10)
check(initial.sampleCount == 1, "initial sample count")
check(initial.observedOperativeCount == 2 and initial.activeOperativeCount == 2, "initial operative counts")
check(initial.acceptedShotCount == 0, "initial shots must be zero")
check(initial.totalCacheOpportunityCount == 6, "two operatives must have six cache opportunities")
check(initial.remainingCacheOpportunityCount == 6, "initial cache opportunities must remain unused")
check(initial.minimumTotalRoundsObserved == 36, "initial minimum ammunition")

collectionByUserId[101] = {
	processedCacheIds = { ["cache.a"] = true },
	grantedRoundsByCacheId = { ["cache.a"] = 12 },
}
ammunitionByUserId[101] = { loadedRounds = 10, reserveRounds = 32 }
local afterCollection = service.sample(20)
check(afterCollection.acceptedShotCount == 6, "shots must derive from conserved ammunition")
check(afterCollection.cacheCollectionCount == 1, "collection count")
check(afterCollection.cacheRoundsGranted == 12, "exact committed grant total")
check(afterCollection.remainingCacheOpportunityCount == 5, "one cache opportunity consumed")
check(afterCollection.operatives[1].userId == 101, "operative snapshots must sort by user ID")
check(afterCollection.operatives[1].consumedCacheIds[1] == "cache.a", "consumed cache identity")

ammunitionByUserId[101] = { loadedRounds = 0, reserveRounds = 0 }
local firstDry = service.sample(30)
check(firstDry.dryOperativeCount == 1, "dry operative count")
check(firstDry.dryAmmunitionTransitionCount == 1, "first dry transition")
check(firstDry.minimumTotalRoundsObserved == 0, "minimum ammunition must reach zero")
local repeatedDry = service.sample(31)
check(repeatedDry.dryAmmunitionTransitionCount == 1, "repeated dry samples must deduplicate")

collectionByUserId[101] = {
	processedCacheIds = { ["cache.a"] = true, ["cache.b"] = true },
	grantedRoundsByCacheId = { ["cache.a"] = 12, ["cache.b"] = 12 },
}
ammunitionByUserId[101] = { loadedRounds = 0, reserveRounds = 12 }
service.sample(40)
ammunitionByUserId[101] = { loadedRounds = 0, reserveRounds = 0 }
local secondDry = service.sample(50)
check(secondDry.dryAmmunitionTransitionCount == 2, "recovery followed by dry must count twice")
check(secondDry.acceptedShotCount == 60, "derived shots must remain cumulative")
check(secondDry.cacheCollectionCount == 2 and secondDry.cacheRoundsGranted == 24, "two exact grants")

players = { playerOne }
local afterLeave = service.sample(60)
check(afterLeave.observedOperativeCount == 2, "observed operatives must persist for the validation run")
check(afterLeave.activeOperativeCount == 1, "active operative count must follow the current roster")
check(afterLeave.totalCacheOpportunityCount == 6, "opportunities remain tied to observed run size")
check(afterLeave.remainingCacheOpportunityCount == 4, "two of six opportunities consumed")

local mutationSucceeded = pcall(function()
	afterLeave.sampleCount = 999
end)
check(not mutationSucceeded, "snapshot must be frozen")

service.resetSampling()
local reset = service.read()
check(reset.sampleCount == 0 and reset.observedOperativeCount == 0, "reset must clear validation history")

print("AmmunitionScarcityTelemetryService: derivation, sampling, dry transitions, and immutable reads passed")
