--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "VS-0106 secret branch fixture assertion failed", 2)
	end
end

local CONFIG_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/SecretBranchConfig.luau"), {
	debugName = "SecretBranchConfig",
	injectGlobals = true,
})()

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/SecretBranchResolver.luau"), {
	debugName = "SecretBranchResolver",
	environment = {
		script = { Parent = { Parent = { Config = { SecretBranchConfig = CONFIG_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONFIG_TOKEN, "unexpected resolver dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

local function makePlan(seed: number)
	return {
		Seed = seed,
		Nodes = {
			{ Index = 1, Depth = 0, RoomId = "entry", Role = "Entry", PreviousIndex = nil, NextIndex = 2 },
			{ Index = 2, Depth = 1, RoomId = "early", Role = "Traversal", PreviousIndex = 1, NextIndex = 3 },
			{ Index = 3, Depth = 2, RoomId = "host-a", Role = "Traversal", PreviousIndex = 2, NextIndex = 4 },
			{ Index = 4, Depth = 3, RoomId = "host-b", Role = "Combat", PreviousIndex = 3, NextIndex = 5 },
			{ Index = 5, Depth = 6, RoomId = "elite", Role = "Elite", PreviousIndex = 4, NextIndex = 6 },
			{ Index = 6, Depth = 7, RoomId = "boss", Role = "Boss", PreviousIndex = 5, NextIndex = nil },
		},
	}
end

local chosenPlan = nil
local chosenSeed = nil
for seed = 1, 500 do
	local candidate = resolver.plan(makePlan(seed))
	if candidate ~= nil then
		chosenPlan = candidate
		chosenSeed = seed
		break
	end
end
assert(chosenPlan ~= nil and chosenSeed ~= nil, "fixture requires at least one deterministic secret seed")

local repeated = resolver.plan(makePlan(chosenSeed :: number))
assert(repeated ~= nil, "same seed should reproduce a secret")
assert(repeated.HostIndex == chosenPlan.HostIndex, "same seed must reproduce host index")
assert(repeated.HostRoomId == chosenPlan.HostRoomId, "same seed must reproduce host room")
assert(repeated.SecretRoomId == chosenPlan.SecretRoomId, "same seed must reproduce secret room")

local original = makePlan(chosenSeed :: number)
local beforeLinks = {}
for _, node in original.Nodes do
	beforeLinks[node.Index] = { node.PreviousIndex, node.NextIndex }
end
resolver.plan(original)
for _, node in original.Nodes do
	assert(node.PreviousIndex == beforeLinks[node.Index][1], "secret planning must not rewrite previous links")
	assert(node.NextIndex == beforeLinks[node.Index][2], "secret planning must not rewrite next links")
end

local state = resolver.newState(chosenPlan)
local wrongOk, wrongReason = resolver.discover(state, chosenPlan.HostIndex + 100)
assert(not wrongOk and wrongReason == "WrongHost", "wrong room must not discover secret")

local earlyClaim, earlyReason, earlyAmount = resolver.claim(state)
assert(
	not earlyClaim and earlyReason == "SecretUndiscovered" and earlyAmount == 0,
	"undiscovered reward must be blocked"
)

local discovered, discoveredReason = resolver.discover(state, chosenPlan.HostIndex)
assert(discovered and discoveredReason == "SecretDiscovered", "correct host should discover secret")

local duplicateDiscovery, duplicateDiscoveryReason = resolver.discover(state, chosenPlan.HostIndex)
assert(not duplicateDiscovery and duplicateDiscoveryReason == "AlreadyDiscovered", "discovery must be one-time")

local claimed, claimReason, amount = resolver.claim(state)
assert(claimed and claimReason == "RewardClaimed", "first claim should succeed")
assert(amount == config.Reward.RunCurrencyAmount, "claim amount must use bounded config")

local duplicateClaim, duplicateClaimReason, duplicateAmount = resolver.claim(state)
assert(
	not duplicateClaim and duplicateClaimReason == "RewardAlreadyClaimed" and duplicateAmount == 0,
	"reward must not duplicate"
)

local noSecretSeed = nil
for seed = 1, 500 do
	if resolver.plan(makePlan(seed)) == nil then
		noSecretSeed = seed
		break
	end
end
assert(noSecretSeed ~= nil, "fixture requires at least one no-secret seed")
local emptyState = resolver.newState(nil)
local emptyDiscovery, emptyReason = resolver.discover(emptyState, 3)
assert(not emptyDiscovery and emptyReason == "NoSecretBranch", "missing branch must stay absent")

print("VS-0106 SecretBranchResolver fixture passed")
