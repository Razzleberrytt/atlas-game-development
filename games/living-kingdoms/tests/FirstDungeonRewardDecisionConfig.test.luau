--!strict

-- BA-033 fixture: the first dungeon's elite/boss reward beats must point at the
-- canonical run-build reward vocabulary without creating a second reward owner
-- or opting into the unresolved persistent-equipment path.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-033 first dungeon reward decision assertion failed", 2)
	end
end

local roomContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomAssemblyContracts.luau"), {
		debugName = "RoomAssemblyContracts",
		injectGlobals = true,
	})()

local enemyContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau"), {
	debugName = "EnemyContracts",
	injectGlobals = true,
})()

local hordeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau"), {
	debugName = "HordeExperienceConfig",
	injectGlobals = true,
})()

local ROOM_CONFIG_CONTRACTS_TOKEN = {}
local roomConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau"), {
	debugName = "RoomAssemblyConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { RoomAssemblyContracts = ROOM_CONFIG_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == ROOM_CONFIG_CONTRACTS_TOKEN, "unexpected RoomAssemblyConfig dependency")
			return roomContracts
		end,
	},
	injectGlobals = true,
})()

local ENEMY_CONTRACTS_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}
local FIRST_ROOM_CONFIG_TOKEN = {}
local FIRST_ROOM_CONTRACTS_TOKEN = {}
local firstDungeonContent =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau"), {
		debugName = "FirstDungeonContentConfig",
		environment = {
			script = {
				Parent = {
					Parent = {
						Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN },
						Expeditions = { RoomAssemblyContracts = FIRST_ROOM_CONTRACTS_TOKEN },
					},
					HordeExperienceConfig = HORDE_CONFIG_TOKEN,
					RoomAssemblyConfig = FIRST_ROOM_CONFIG_TOKEN,
				},
			},
			require = function(token: unknown)
				if token == ENEMY_CONTRACTS_TOKEN then
					return enemyContracts
				end
				if token == HORDE_CONFIG_TOKEN then
					return hordeConfig
				end
				if token == FIRST_ROOM_CONFIG_TOKEN then
					return roomConfig
				end
				if token == FIRST_ROOM_CONTRACTS_TOKEN then
					return roomContracts
				end
				error("unexpected FirstDungeonContentConfig dependency")
			end,
		},
		injectGlobals = true,
	})()

local runRpgContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local RUN_RPG_CONTRACTS_TOKEN = {}
local runRpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = RUN_RPG_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == RUN_RPG_CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return runRpgContracts
		end,
	},
	injectGlobals = true,
})()

local FIRST_CONTENT_TOKEN = {}
local RUN_CONFIG_TOKEN = {}
local ROOM_CONTRACTS_TOKEN = {}
local RUN_CONTRACTS_TOKEN = {}
local decisions =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonRewardDecisionConfig.luau"), {
		debugName = "FirstDungeonRewardDecisionConfig",
		environment = {
			script = {
				Parent = {
					FirstDungeonContentConfig = FIRST_CONTENT_TOKEN,
					RunRpgConfig = RUN_CONFIG_TOKEN,
					Parent = {
						Expeditions = { RoomAssemblyContracts = ROOM_CONTRACTS_TOKEN },
						RPG = { RunRpgContracts = RUN_CONTRACTS_TOKEN },
					},
				},
			},
			require = function(token: unknown)
				if token == FIRST_CONTENT_TOKEN then
					return firstDungeonContent
				end
				if token == RUN_CONFIG_TOKEN then
					return runRpgConfig
				end
				if token == ROOM_CONTRACTS_TOKEN then
					return roomContracts
				end
				if token == RUN_CONTRACTS_TOKEN then
					return runRpgContracts
				end
				error("unexpected FirstDungeonRewardDecisionConfig dependency")
			end,
		},
		injectGlobals = true,
	})()

assert(decisions.Version == "BA-033-v2-boss-live")
assert(decisions.SequenceId == firstDungeonContent.SequenceId, "reward data must follow the BA-032 dungeon identity")
assert(decisions.SequenceVersion == firstDungeonContent.SequenceVersion)
assert(decisions.RewardKind == "RunRelicChoice", "BA-033 must author run-build decisions, not persistent gear")
assert(decisions.ChoiceCount == runRpgConfig.Limits.relicChoiceCountPerReward)
assert(decisions.ChoiceCount == 2, "the canonical Run Relic reward remains a two-choice decision")
assert(decisions.RuntimeConsumptionEnabled == true, "BA-033 must disclose the live boss reward handoff")
assert(decisions.PersistentEquipmentEligible == false, "BA-043 still owns the persistent-equipment authority decision")
assert(#decisions.OrderedDecisions == 2, "the first dungeon must contain exactly the elite and boss decision beats")

local elite = decisions.OrderedDecisions[1]
assert(elite.DecisionId == "first-descent.elite-relic-choice")
assert(elite.RoomId == "warden-threshold")
assert(elite.RoomRewardSourceId == roomContracts.RoomRewardSourceIds.Elite)
assert(elite.RunRewardSourceId == runRpgContracts.RewardSourceIds.EliteKill)
assert(elite.SourceImplementationStateId == runRpgContracts.ImplementationStateIds.Implemented)
assert(elite.RuntimeConsumptionEnabled == false, "the authored elite room must not double-pay generic elite rewards")
assert(elite.PersistentEquipmentEligible == false)
assert(decisions.DecisionByRoomId[elite.RoomId] == elite)

local boss = decisions.OrderedDecisions[2]
assert(boss.DecisionId == "first-descent.boss-relic-choice")
assert(boss.RoomId == "keeper-core")
assert(boss.RoomRewardSourceId == roomContracts.RoomRewardSourceIds.Boss)
assert(boss.RunRewardSourceId == runRpgContracts.RewardSourceIds.BossMilestone)
assert(boss.SourceImplementationStateId == runRpgContracts.ImplementationStateIds.Implemented)
assert(boss.RuntimeConsumptionEnabled == true, "boss reward wiring must stay enabled for First Descent")
assert(boss.PersistentEquipmentEligible == false)
assert(decisions.DecisionByRoomId[boss.RoomId] == boss)

assert(
	firstDungeonContent.Encounters[elite.RoomId].RewardSourceId == elite.RoomRewardSourceId,
	"elite reward decision drifted away from BA-032 room content"
)
assert(
	firstDungeonContent.Encounters[boss.RoomId].RewardSourceId == boss.RoomRewardSourceId,
	"boss reward decision drifted away from BA-032 room content"
)

print("BA-033 FirstDungeonRewardDecisionConfig: boss Run Relic decision live")
