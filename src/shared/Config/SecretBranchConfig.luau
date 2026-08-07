--!strict

--[[
	VS-0106 bounded optional secret branch configuration.
	The branch is supplemental: it never replaces or blocks the required linear
	entry-to-boss route and grants only one run-scoped reward claim.
]]

local SecretBranchConfig = {
	Version = "VS-0106-v1",
	BranchChancePercent = 45,
	EligibleHostRoles = table.freeze({
		Traversal = true,
		Combat = true,
	}),
	MinimumHostDepth = 2,
	MaximumHostDepth = 5,
	SecretRoom = table.freeze({
		Id = "sealed-reliquary",
		Version = "1.0.0",
		DisplayName = "Sealed Reliquary",
	}),
	Reward = table.freeze({
		RewardId = "secret-reliquary-cache",
		RewardVersion = "1.0.0",
		RunCurrencyAmount = 25,
		MaximumClaimsPerRun = 1,
	}),
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
assert(
	SecretBranchConfig.Reward.RunCurrencyAmount > 0 and SecretBranchConfig.Reward.RunCurrencyAmount <= 50,
	"secret reward must remain useful but bounded"
)
assert(SecretBranchConfig.Reward.MaximumClaimsPerRun == 1, "the secret reward must be one-time per run")

return table.freeze(SecretBranchConfig)
