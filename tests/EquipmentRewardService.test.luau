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
local COMBAT_CONTRACTS_TOKEN = {}

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
	debugName = "EquipmentRewardContracts",
	injectGlobals = true,
})()

local combatContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau"), {
	debugName = "CombatContracts",
	injectGlobals = true,
})()

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau"), {
	debugName = "EquipmentRewardConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Equipment = { EquipmentRewardContracts = CONTRACTS_TOKEN },
					Combat = { CombatContracts = COMBAT_CONTRACTS_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			if token == COMBAT_CONTRACTS_TOKEN then
				return combatContracts
			end
			assert(token == CONTRACTS_TOKEN, "unexpected reward config dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

-- Every weapon-slot definition must drive a real combat weapon, and non-weapon
-- slots must drive none, or an item could equip and change nothing.
local weaponSlots = { [contracts.SlotIds.Primary] = true, [contracts.SlotIds.Secondary] = true }
local weaponLinks = 0
for _, definition in config.Definitions do
	if weaponSlots[definition.Slot] then
		assert(type(definition.WeaponId) == "string", definition.Id .. " must name the weapon it equips")
		assert(combatContracts.WeaponIds ~= nil, "weapon ids must be declared in the combat contracts")
		weaponLinks += 1
	else
		assert(definition.WeaponId == nil, definition.Id .. " must not name a weapon")
	end
end
assert(weaponLinks >= 3, "the authored roster must link at least the rifle, shotgun, and sidearm")

local replicatedStorage = {
	Shared = {
		Equipment = { EquipmentRewardContracts = CONTRACTS_TOKEN },
		Config = { EquipmentRewardConfig = CONFIG_TOKEN },
	},
}

-- The server mints one globally unique instance ID per created item. The stub
-- counts issued IDs so the fixture can prove uniqueness without a real GUID source.
local issuedInstanceIds = 0
local httpService = {
	GenerateGUID = function(_self: unknown, withBraces: boolean): string
		assert(withBraces == false, "reward instance IDs must be generated without braces")
		issuedInstanceIds += 1
		return string.format("00000000-0000-4000-8000-%012d", issuedInstanceIds)
	end,
}

local serviceModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentRewardService.luau"), {
	debugName = "EquipmentRewardService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				if serviceName == "HttpService" then
					return httpService
				end
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

-- Content identity is deterministic from the reward context. It deliberately
-- excludes InstanceId, which is a globally unique server-minted item identity.
local function rewardSignature(reward): string
	return table.concat({
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
assert(
	elite.Reward.Power >= eliteDefinition.MinimumPower and elite.Reward.Power <= eliteDefinition.MaximumPower,
	"elite power outside item bounds"
)

local duplicateElite = service:claimReward(SourceIds.Elite)
assert(
	not duplicateElite.Accepted and duplicateElite.ReasonId == "SourceAlreadyClaimed",
	"elite source must grant once"
)
assert(
	rewardSignature(service:getClaimedReward(SourceIds.Elite)) == rewardSignature(elite.Reward),
	"stored elite reward must remain stable"
)

local boss = service:claimReward(SourceIds.Boss)
assert(boss.Accepted and boss.Reward ~= nil, "boss reward should be accepted")
assert(boss.Reward.SourceId == SourceIds.Boss, "boss source mismatch")
assert(boss.Reward.Power >= config.Sources[SourceIds.Boss].MinimumPower, "boss reward below source floor")
assert(boss.Reward.Power <= config.Sources[SourceIds.Boss].MaximumPower, "boss reward above source ceiling")
assert(boss.Reward.InstanceId ~= elite.Reward.InstanceId, "reward instances must be source-unique")
assert(
	boss.Reward.Rarity == RarityIds.Common
		or boss.Reward.Rarity == RarityIds.Uncommon
		or boss.Reward.Rarity == RarityIds.Rare,
	"unknown rarity"
)

local replay = serviceModule.new(runId, seed)
local replayElite = replay:claimReward(SourceIds.Elite)
local replayBoss = replay:claimReward(SourceIds.Boss)
assert(
	rewardSignature(replayElite.Reward) == rewardSignature(elite.Reward),
	"elite reward must reproduce from the same run seed"
)
assert(
	rewardSignature(replayBoss.Reward) == rewardSignature(boss.Reward),
	"boss reward must reproduce from the same run seed"
)

-- The declared ContentSignature is the deterministic identity and must agree
-- with the reproduced content on every field the signature covers.
assert(replayElite.Reward.ContentSignature == elite.Reward.ContentSignature, "elite content signature must reproduce")
assert(replayBoss.Reward.ContentSignature == boss.Reward.ContentSignature, "boss content signature must reproduce")
assert(elite.Reward.ContentSignature ~= boss.Reward.ContentSignature, "distinct sources must sign distinct content")

-- GrantId is the idempotency key for a run/source pair and must also reproduce.
assert(replayElite.Reward.GrantId == elite.Reward.GrantId, "elite grant id must reproduce")
assert(replayBoss.Reward.GrantId == boss.Reward.GrantId, "boss grant id must reproduce")
assert(elite.Reward.GrantId ~= boss.Reward.GrantId, "distinct sources must use distinct grant ids")

-- Instance identity must stay globally unique even when the content repeats.
local mintedInstanceIds =
	{ elite.Reward.InstanceId, boss.Reward.InstanceId, replayElite.Reward.InstanceId, replayBoss.Reward.InstanceId }
local seenInstanceIds = {}
for _, instanceId in mintedInstanceIds do
	assert(type(instanceId) == "string" and #instanceId >= 8, "reward instance id must be a durable string")
	assert(seenInstanceIds[instanceId] == nil, "reward instance ids must never repeat")
	seenInstanceIds[instanceId] = true
end

local variationFound = false
for candidateSeed = seed + 1, seed + 100 do
	local candidate = serviceModule.new(runId .. "-candidate", candidateSeed)
	local candidateReward = candidate:claimReward(SourceIds.Boss)
	if
		candidateReward.Reward.DefinitionId ~= boss.Reward.DefinitionId
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
assert(
	not afterDestroy.Accepted and afterDestroy.ReasonId == "ServiceDestroyed",
	"destroyed service must reject grants"
)

local invalidSeedAccepted = pcall(function()
	serviceModule.new("run-invalid-seed", 0)
end)
assert(not invalidSeedAccepted, "zero reward seed must be rejected")

print("VS-0107 EquipmentRewardService fixture passed")
