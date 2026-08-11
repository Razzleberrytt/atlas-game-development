--!strict

--[[
	VS-0106 bounded optional secret branch configuration.
	A run may expose at most one supplemental branch, selected from this curated
	pool. Secrets never replace or block the required entry-to-boss route and each
	grants only one bounded, run-scoped reward claim.
]]

local SecretRooms = table.freeze({
	table.freeze({
		Id = "sealed-reliquary",
		Version = "1.0.0",
		DisplayName = "Sealed Reliquary",
		Reward = table.freeze({
			RewardId = "secret-reliquary-cache",
			RewardVersion = "1.0.0",
			RunCurrencyAmount = 25,
			MaximumClaimsPerRun = 1,
		}),
	}),
	table.freeze({
		Id = "abandoned-surveyor-cache",
		Version = "1.0.0",
		DisplayName = "Abandoned Surveyor Cache",
		Reward = table.freeze({
			RewardId = "secret-surveyor-cache",
			RewardVersion = "1.0.0",
			RunCurrencyAmount = 20,
			MaximumClaimsPerRun = 1,
		}),
	}),
	table.freeze({
		Id = "buried-chapel-vault",
		Version = "1.0.0",
		DisplayName = "Buried Chapel Vault",
		Reward = table.freeze({
			RewardId = "secret-chapel-cache",
			RewardVersion = "1.0.0",
			RunCurrencyAmount = 30,
			MaximumClaimsPerRun = 1,
		}),
	}),
})

local SecretBranchConfig = {
	Version = "VS-0106-v2",
	BranchChancePercent = 45,
	EligibleHostRoles = table.freeze({
		Traversal = true,
		Combat = true,
	}),
	MinimumHostDepth = 2,
	MaximumHostDepth = 5,
	SecretRooms = SecretRooms,

	-- Compatibility aliases for consumers that only need the original exemplar.
	-- New planning must select from SecretRooms instead of treating these as the
	-- only available secret.
	SecretRoom = SecretRooms[1],
	Reward = SecretRooms[1].Reward,
}

assert(
	SecretBranchConfig.BranchChancePercent >= 1 and SecretBranchConfig.BranchChancePercent <= 100,
	"secret branch chance must be a bounded integer percentage"
)
assert(SecretBranchConfig.BranchChancePercent % 1 == 0, "secret branch chance must be an integer")
assert(
	SecretBranchConfig.MinimumHostDepth >= 1
		and SecretBranchConfig.MaximumHostDepth >= SecretBranchConfig.MinimumHostDepth,
	"secret host depth bounds are invalid"
)
assert(#SecretBranchConfig.SecretRooms == 3, "Patch 0.6 requires a curated three-secret pool")

local seenRoomIds = {}
local seenRewardIds = {}
for _, secret in SecretBranchConfig.SecretRooms do
	assert(type(secret.Id) == "string" and secret.Id ~= "", "secret room id is required")
	assert(type(secret.Version) == "string" and secret.Version ~= "", "secret room version is required")
	assert(seenRoomIds[secret.Id] == nil, "secret room ids must be unique")
	seenRoomIds[secret.Id] = true

	local reward = secret.Reward
	assert(type(reward.RewardId) == "string" and reward.RewardId ~= "", "secret reward id is required")
	assert(seenRewardIds[reward.RewardId] == nil, "secret reward ids must be unique")
	seenRewardIds[reward.RewardId] = true
	assert(
		reward.RunCurrencyAmount > 0 and reward.RunCurrencyAmount <= 50,
		"secret reward must remain useful but bounded"
	)
	assert(reward.MaximumClaimsPerRun == 1, "each secret reward must be one-time per run")
end

return table.freeze(SecretBranchConfig)
