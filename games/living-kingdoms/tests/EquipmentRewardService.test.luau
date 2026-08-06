--!strict

-- VS-0107 deterministic authoritative equipment reward fixture.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "VS-0107 equipment reward assertion failed", 2)
	end
end

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
	debugName = "EquipmentRewardContracts",
	injectGlobals = true,
})()

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau"), {
	debugName = "EquipmentRewardConfig",
	environment = {
		script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected reward config dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local replicatedStorage = {
	Shared = {
		Equipment = { EquipmentRewardContracts = CONTRACTS_TOKEN },
		Config = { EquipmentRewardConfig = CONFIG_TOKEN },
	},
}

local serviceModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentRewardService.luau"), {
	debugName = "EquipmentRewardService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected equipment reward dependency")
		end,
	},
	injectGlobals = true,
})()

local SourceIds = contracts.SourceIds
local RarityIds = contracts.RarityIds

local function rewardSignature(reward): string
	return table.concat({
		reward.InstanceId,
		reward.DefinitionId,
		reward.DefinitionVersion,
		reward.Slot,
		reward.Rarity,
		tostring(reward.Power),
		reward.SourceId,
		tostring(reward.Seed),
	}, "|")
end

local function findDefinition(id: string)
	for _, definition in config.Definitions do
		if definition.Id == id then
			return definition
		end
	end
	return nil
end

local runId = "run-vs0107-fixture"
local seed = 73_991
local service = serviceModule.new(runId, seed)

local elite = service:claimReward(SourceIds.Elite)
assert(elite.Accepted and elite.ReasonId == "RewardClaimed", "elite reward should be accepted")
assert(elite.Reward ~= nil and elite.Reward.SourceId == SourceIds.Elite, "elite reward source mismatch")
assert(elite.Reward.RunId == runId, "reward must preserve run provenance")
assert(elite.Reward.Power >= config.Sources[SourceIds.Elite].MinimumPower, "elite reward below source floor")
assert(elite.Reward.Power <= config.Sources[SourceIds.Elite].MaximumPower, "elite reward above source ceiling")
local eliteDefinition = findDefinition(elite.Reward.DefinitionId)
assert(eliteDefinition ~= nil, "elite reward must use a known definition")
assert(eliteDefinition.Version == elite.Reward.DefinitionVersion, "definition version must be preserved")
assert(elite.Reward.Power >= eliteDefinition.MinimumPower and elite.Reward.Power <= eliteDefinition.MaximumPower, "elite power outside item bounds")

local duplicateElite = service:claimReward(SourceIds.Elite)
assert(not duplicateElite.Accepted and duplicateElite.ReasonId == "SourceAlreadyClaimed", "elite source must grant once")
assert(rewardSignature(service:getClaimedReward(SourceIds.Elite)) == rewardSignature(elite.Reward), "stored elite reward must remain stable")

local boss = service:claimReward(SourceIds.Boss)
assert(boss.Accepted and boss.Reward ~= nil, "boss reward should be accepted")
assert(boss.Reward.SourceId == SourceIds.Boss, "boss source mismatch")
assert(boss.Reward.Power >= config.Sources[SourceIds.Boss].MinimumPower, "boss reward below source floor")
assert(boss.Reward.Power <= config.Sources[SourceIds.Boss].MaximumPower, "boss reward above source ceiling")
assert(boss.Reward.InstanceId ~= elite.Reward.InstanceId, "reward instances must be source-unique")
assert(boss.Reward.Rarity == RarityIds.Common or boss.Reward.Rarity == RarityIds.Uncommon or boss.Reward.Rarity == RarityIds.Rare, "unknown rarity")

local replay = serviceModule.new(runId, seed)
local replayElite = replay:claimReward(SourceIds.Elite)
local replayBoss = replay:claimReward(SourceIds.Boss)
assert(rewardSignature(replayElite.Reward) == rewardSignature(elite.Reward), "elite reward must reproduce from the same run seed")
assert(rewardSignature(replayBoss.Reward) == rewardSignature(boss.Reward), "boss reward must reproduce from the same run seed")

local variationFound = false
for candidateSeed = seed + 1, seed + 100 do
	local candidate = serviceModule.new(runId .. "-candidate", candidateSeed)
	local candidateReward = candidate:claimReward(SourceIds.Boss)
	if candidateReward.Reward.DefinitionId ~= boss.Reward.DefinitionId
		or candidateReward.Reward.Rarity ~= boss.Reward.Rarity
		or candidateReward.Reward.Power ~= boss.Reward.Power
	then
		variationFound = true
		break
	end
end
assert(variationFound, "different seeds should produce bounded reward variation")

local unknown = service:claimReward("TreasureChest" :: any)
assert(not unknown.Accepted and unknown.ReasonId == "UnknownSource", "unknown reward source must be rejected")

service:destroy()
assert(service:getClaimedReward(SourceIds.Elite) == nil, "destroyed service must disclose no reward")
local afterDestroy = service:claimReward(SourceIds.Boss)
assert(not afterDestroy.Accepted and afterDestroy.ReasonId == "ServiceDestroyed", "destroyed service must reject grants")

local invalidSeedAccepted = pcall(function()
	serviceModule.new("run-invalid-seed", 0)
end)
assert(not invalidSeedAccepted, "zero reward seed must be rejected")

print("VS-0107 EquipmentRewardService fixture passed")
