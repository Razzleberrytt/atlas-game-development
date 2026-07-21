--!strict

-- RPG-0102 reset, disconnect/reconnect, replay, stale-generation, and copy safety.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					RPG = {
						RunRpgContracts = CONTRACTS_TOKEN,
					},
				},
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			error("unexpected RunRpgConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local RESOLVER_CONTRACTS_TOKEN = {}
local RESOLVER_CONFIG_TOKEN = {}
local resolverReplicatedStorage = {
	Shared = {
		RPG = { RunRpgContracts = RESOLVER_CONTRACTS_TOKEN },
		Config = { RunRpgConfig = RESOLVER_CONFIG_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RelicRewardResolver.luau"), {
	debugName = "RelicRewardResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "resolver may only require replicated declarations")
				return resolverReplicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == RESOLVER_CONTRACTS_TOKEN then
				return contracts
			elseif token == RESOLVER_CONFIG_TOKEN then
				return config
			end
			error("unexpected RelicRewardResolver dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local STORE_CONTRACTS_TOKEN = {}
local STORE_CONFIG_TOKEN = {}
local STORE_RESOLVER_TOKEN = {}
local replicatedStorage = {
	Shared = {
		RPG = { RunRpgContracts = STORE_CONTRACTS_TOKEN, RelicRewardResolver = STORE_RESOLVER_TOKEN },
		Config = { RunRpgConfig = STORE_CONFIG_TOKEN },
	},
}
local storeModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildStateStore.luau"), {
	debugName = "RunBuildStateStore",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "state store may only require replicated declarations")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == STORE_CONTRACTS_TOKEN then
				return contracts
			elseif token == STORE_CONFIG_TOKEN then
				return config
			elseif token == STORE_RESOLVER_TOKEN then
				return resolver
			end
			error("unexpected RunBuildStateStore dependency", 2)
		end,
	},
	injectGlobals = true,
})()

local store = storeModule.new()
local firstGeneration = store:startOperation()
assertThat(firstGeneration == 1, "first operation generation must be positive")
assertThat(store:registerOperative("operative-a"), "first operative registration failed")
assertThat(store:registerOperative("operative-b"), "second operative registration failed")

local initial = store:readSafeSnapshot("operative-a")
assertThat(initial ~= nil and contracts.validateSafeRunBuildSnapshot(initial), "initial safe snapshot is invalid")
assertThat(#initial.relicSlots == 3, "every operative must begin with the bounded three empty relic slots")
assertThat(#initial.pendingRewards == 0, "RPG-0102 must not invent relic rewards")
assertThat(next(initial.upgradeStacks) == nil, "operation must begin without upgrade stacks")

local firstStacks = { [contracts.RunUpgradeIds.OverpressureRounds] = 1 }
local didCommit, rejection = store:commitUpgradeStacks(firstGeneration, "upgrade:1", firstStacks)
assertThat(didCommit and rejection == nil, "valid upgrade-stack commit failed")
firstStacks[contracts.RunUpgradeIds.OverpressureRounds] = 4
local snapshotA = store:readSafeSnapshot("operative-a")
local snapshotB = store:readSafeSnapshot("operative-b")
assertThat(snapshotA.revision == 1 and snapshotB.revision == 1, "one commit must revise every operative build")
assertThat(snapshotA.upgradeStacks[contracts.RunUpgradeIds.OverpressureRounds] == 1, "caller mutated owned state")
assertThat(snapshotB.upgradeStacks[contracts.RunUpgradeIds.OverpressureRounds] == 1, "squad stacks diverged")

local replayApplied, replayReason = store:commitUpgradeStacks(firstGeneration, "upgrade:1", {
	[contracts.RunUpgradeIds.OverpressureRounds] = 2,
})
assertThat(not replayApplied and replayReason == contracts.RunRpgRejectionReasonIds.DuplicateRequest, "replay applied")
assertThat(store:readSafeSnapshot("operative-a").revision == 1, "replay changed revision")

assertThat(store:disconnectOperative("operative-a"), "disconnect was not recorded")
local disconnectedSnapshot = store:readSafeSnapshot("operative-a")
assertThat(disconnectedSnapshot ~= nil, "disconnect must retain the operation-scoped build for reconnect")
assertThat(
	store:commitUpgradeStacks(firstGeneration, "upgrade:2", {
		[contracts.RunUpgradeIds.OverpressureRounds] = 1,
		[contracts.RunUpgradeIds.CombatLoader] = 1,
	}),
	"second squad commit failed"
)
assertThat(store:registerOperative("operative-a"), "same-operation reconnect failed")
local reconnected = store:readSafeSnapshot("operative-a")
assertThat(reconnected.revision == 2, "reconnect did not recover the current build revision")
assertThat(reconnected.upgradeStacks[contracts.RunUpgradeIds.CombatLoader] == 1, "reconnect rerolled build state")

assertThat(store:registerOperative("operative-c") and store:registerOperative("operative-d"), "MVP roster fill failed")
assertThat(not store:registerOperative("operative-e"), "run-build records exceeded the four-operative ceiling")

local secondGeneration = store:startOperation()
assertThat(secondGeneration == firstGeneration + 1, "operation reset did not advance generation")
assertThat(store:readSafeSnapshot("operative-a") == nil, "reset retained an operative build")
assertThat(next(store:readUpgradeStacks()) == nil, "reset retained shared upgrade stacks")
local staleApplied, staleReason = store:commitUpgradeStacks(firstGeneration, "stale", {})
assertThat(
	not staleApplied and staleReason == contracts.RunRpgRejectionReasonIds.StaleOperationGeneration,
	"stale generation mutated the replacement operation"
)
assertThat(store:registerOperative("operative-a"), "replacement operation registration failed")
assertThat(store:commitUpgradeStacks(secondGeneration, "upgrade:1", {}), "new operation inherited replay history")

store:stopOperation()
assertThat(store:readSafeSnapshot("operative-a") == nil, "teardown retained a safe snapshot")
local stoppedApplied, stoppedReason = store:commitUpgradeStacks(secondGeneration, "after-stop", {})
assertThat(
	not stoppedApplied and stoppedReason == contracts.RunRpgRejectionReasonIds.ServiceStopped,
	"stopped owner accepted a commit"
)

print("RunBuildStateStore: reset, reconnect, replay, generation, bounds, and teardown passed")
