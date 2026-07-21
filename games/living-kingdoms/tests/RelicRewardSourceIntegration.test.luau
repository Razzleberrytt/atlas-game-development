--!strict

-- RPG-0110 live relic-reward sources: confirmed elite deaths, a squad-kill
-- milestone, and confirmed special interrupts open bounded choices through the
-- existing run-build owner. Every offer keeps a deterministic per-operative
-- request ID, so replays and queue ceilings still reject.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local rewardSourceConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RelicRewardSourceConfig.luau"), {
		debugName = "RelicRewardSourceConfig",
		injectGlobals = true,
	})()

assertThat(rewardSourceConfig.Version == "RPG-0110-v1-live-reward-sources", "reward source pacing version drifted")
assertThat(
	rewardSourceConfig.EliteKillsPerReward >= 1 and rewardSourceConfig.EliteKillsPerReward <= 3,
	"elite rewards must stay frequent enough to matter"
)
assertThat(
	rewardSourceConfig.SpecialInterruptsPerReward >= 2,
	"special interrupts must pay on an interval, not per interrupt"
)
assertThat(
	rewardSourceConfig.HordeKillsPerReward >= 40 and rewardSourceConfig.HordeKillsPerReward <= 250,
	"the horde milestone must remain a reachable floor"
)

-- The fan-out derives one distinct request ID per operative from the event ID,
-- and only offers to registered operatives.
local rpgContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = CONTRACTS_TOKEN } } } },
		require = function()
			return rpgContracts
		end,
	},
	injectGlobals = true,
})()

local players = {}
local firedSnapshots = {}
local function makeRemote(name: string)
	return {
		Name = name,
		FireClient = function(_self, player, payload)
			table.insert(firedSnapshots, { player = player, payload = payload })
		end,
		OnServerEvent = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
	}
end
local runBuildNetwork = {
	State = makeRemote("State"),
	ReadState = { Name = "ReadState" },
	SubmitRelicChoice = makeRemote("SubmitRelicChoice"),
	SubmitRelicReplacement = makeRemote("SubmitRelicReplacement"),
}
runBuildNetwork.WaitForChild = function(_self, name: string)
	return runBuildNetwork[name]
end
local STORE_TOKEN = {}
local RPG_CONTRACTS = {}
local FIREARM_TOKEN = {}
local COMBAT_TOKEN = {}
local RPG_CONFIG_TOKEN = {}
local offers = {}
local storeStub = {
	new = function()
		return {
			startOperation = function()
				return 1
			end,
			stopOperation = function() end,
			registerOperative = function()
				return true
			end,
			disconnectOperative = function()
				return true
			end,
			readOperationGeneration = function()
				return 1
			end,
			readSafeSnapshot = function()
				return { operationId = "Snapshot", operationGeneration = 1, revision = 1 }
			end,
			enqueueRelicReward = function(_self, _generation, requestId, operativeId, sourceId)
				table.insert(offers, { requestId = requestId, operativeId = operativeId, sourceId = sourceId })
				-- The second operative in these fixtures always has a full queue,
				-- proving one rejection cannot suppress another operative's offer.
				if operativeId == "2" then
					return false, "RewardQueueFull", nil
				end
				return true, nil, #offers
			end,
		}
	end,
}

local runBuildService = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildService.luau"), {
	debugName = "RunBuildService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				if serviceName == "Players" then
					return {
						GetPlayers = function()
							return players
						end,
						PlayerAdded = { Connect = function() end },
						PlayerRemoving = { Connect = function() end },
					}
				end
				return {
					Shared = {
						RPG = { RunRpgContracts = RPG_CONTRACTS },
						Config = { FirearmConfig = FIREARM_TOKEN, RunRpgConfig = RPG_CONFIG_TOKEN },
						Combat = { CombatContracts = COMBAT_TOKEN },
					},
					WaitForChild = function(_self, name: string)
						assertThat(name == "RunBuildNetwork", "the run-build owner may only claim its own network")
						return runBuildNetwork
					end,
				}
			end,
		},
		script = { Parent = { RunBuildStateStore = STORE_TOKEN } },
		require = function(token: unknown)
			if token == STORE_TOKEN then
				return storeStub
			elseif token == RPG_CONTRACTS then
				return rpgContracts
			elseif token == FIREARM_TOKEN then
				return {
					BasicFirearm = { WeaponId = "weapon.basic_firearm" },
					isKnownWeaponId = function()
						return true
					end,
				}
			elseif token == RPG_CONFIG_TOKEN then
				return rpgConfig
			elseif token == COMBAT_TOKEN then
				return {
					WeaponIds = {
						LightMachineGun = "weapon.light-machine-gun",
						SubmachineGun = "weapon.submachine-gun",
						BreachShotgun = "weapon.breach-shotgun",
						SniperRifle = "weapon.sniper-rifle",
					},
				}
			end
			error("unexpected RunBuildService dependency")
		end,
	},
	injectGlobals = true,
})()

local function makePlayer(userId: number)
	return {
		UserId = userId,
		GetAttribute = function()
			return nil
		end,
	} :: any
end

assertThat(
	runBuildService.offerRelicRewardToParticipants("elite:hostile.1", rpgContracts.RewardSourceIds.EliteKill) == 0,
	"a stopped operation must offer nothing"
)
assertThat(#offers == 0, "a stopped operation must not reach the run-build owner")

players = { makePlayer(1), makePlayer(2) }
runBuildService.start()
local offeredCount =
	runBuildService.offerRelicRewardToParticipants("elite:hostile.1", rpgContracts.RewardSourceIds.EliteKill)
assertThat(offeredCount == 1, "only operatives whose offer was accepted may be counted")
assertThat(#offers == 2, "every registered operative must be considered")
assertThat(
	offers[1].requestId == "elite:hostile.1:1" and offers[2].requestId == "elite:hostile.1:2",
	"each operative must receive a distinct deterministic request ID derived from the event"
)
assertThat(offers[1].sourceId == rpgContracts.RewardSourceIds.EliteKill, "the offer must carry the confirming source")
assertThat(
	runBuildService.offerRelicRewardToParticipants("", rpgContracts.RewardSourceIds.EliteKill) == 0,
	"an empty event ID must offer nothing"
)

-- Source audits: the live sources are applied by the owners that already observe
-- the confirmed events, and the unavailable sources stay unimplemented.
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local interrupts = fs.readFile("games/living-kingdoms/src/server/Systems/ScreamerInterruptRewardService.luau")

assertThat(
	contains(progression, "RunBuildService.offerRelicRewardToParticipants"),
	"confirmed enemy deaths must offer through the existing run-build owner"
)
assertThat(
	contains(progression, "RewardSourceIds.EliteKill") and contains(progression, "RewardSourceIds.HordeClear"),
	"the death observer must own both the elite and the milestone source"
)
assertThat(
	contains(progression, 'then "elite:" .. entityId'),
	"elite reward IDs must derive from the enemy's own server identity"
)
assertThat(
	contains(progression, "if applyFieldXpAward(boosted, true) then"),
	"a relic reward may only follow an accepted confirmed death"
)
assertThat(
	contains(interrupts, "interruptsSinceReward >= RelicRewardSourceConfig.SpecialInterruptsPerReward"),
	"special interrupts must pay on the configured interval"
)
assertThat(
	contains(interrupts, "RunRpgContracts.RewardSourceIds.SpecialInterrupt"),
	"the interrupt observer must offer under its own source"
)

local rewardStates = {}
for _, definition in rpgConfig.RewardSourceCatalog do
	rewardStates[definition.sourceId] = definition.implementationStateId
end
local Implemented = rpgContracts.ImplementationStateIds.Implemented
local Planned = rpgContracts.ImplementationStateIds.Planned
assertThat(rewardStates[rpgContracts.RewardSourceIds.EliteKill] == Implemented, "elite kills must be live")
assertThat(rewardStates[rpgContracts.RewardSourceIds.SpecialInterrupt] == Implemented, "interrupts must be live")
assertThat(rewardStates[rpgContracts.RewardSourceIds.HordeClear] == Implemented, "horde milestones must be live")
assertThat(
	rewardStates[rpgContracts.RewardSourceIds.ObjectiveCompletion] == Planned
		and rewardStates[rpgContracts.RewardSourceIds.AuthoredContainer] == Planned
		and rewardStates[rpgContracts.RewardSourceIds.BossMilestone] == Planned,
	"sources without an authoritative owner must remain planned"
)

print("RelicRewardSourceIntegration: bounded live reward sources, deterministic IDs, and deferrals passed")
