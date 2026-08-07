--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "reward distribution assertion failed", 2) end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRewardDistributionService.luau"), {
	debugName = "ExpeditionRewardDistributionService",
	environment = {},
	injectGlobals = true,
})()

local eliteReward = {
	InstanceId = "run-203:Elite:1",
	DefinitionId = "warden-rifle",
	DefinitionVersion = "1.0.0",
	DisplayName = "Warden Rifle",
	Slot = "Primary",
	Rarity = "Uncommon",
	Power = 12,
	SourceId = "Elite",
	RunId = "run-203",
	Seed = 71,
}

local bossReward = {
	InstanceId = "run-203:Boss:2",
	DefinitionId = "keeper-relic",
	DefinitionVersion = "1.0.0",
	DisplayName = "Keeper Relic",
	Slot = "Relic",
	Rarity = "Rare",
	Power = 18,
	SourceId = "Boss",
	RunId = "run-203",
	Seed = 72,
}

local owner = {
	loaded = { [101] = true, [202] = false, [303] = true },
	applied = {},
	calls = {},
	forcedFailure = { [303] = "SaveFailed" },
}

function owner:applyReward(playerId: number, reward: any, _nowUnix: number)
	self.calls[playerId] = (self.calls[playerId] or 0) + 1
	if not self.loaded[playerId] then
		return { Accepted = false, ReasonId = "PlayerNotLoaded" }
	end
	local forced = self.forcedFailure[playerId]
	if forced ~= nil then
		self.forcedFailure[playerId] = nil
		return { Accepted = false, ReasonId = forced }
	end
	self.applied[playerId] = self.applied[playerId] or {}
	if self.applied[playerId][reward.InstanceId] then
		return { Accepted = false, ReasonId = "RewardAlreadyApplied" }
	end
	self.applied[playerId][reward.InstanceId] = true
	return { Accepted = true, ReasonId = "RewardApplied" }
end

local service = module.new(owner, { 303, 101, 202, 101 })
local first = service:distribute({ eliteReward, bossReward }, 1000)
assert(not first.Complete, "distribution should remain pending while players fail")
assert(#first.CompletedPlayerIds == 1 and first.CompletedPlayerIds[1] == 101, "loaded successful player should complete")
assert(#first.PendingPlayerIds == 2, "two players should remain pending")
assert(first.FailureReasonsByPlayerId[202] == "PlayerNotLoaded", "unloaded player should remain retryable")
assert(first.FailureReasonsByPlayerId[303] == "SaveFailed", "save failure should remain retryable")
assert(owner.applied[101][eliteReward.InstanceId] and owner.applied[101][bossReward.InstanceId], "successful player should receive both rewards")

local callsAfterFirstFor101 = owner.calls[101]
owner.loaded[202] = true
local second = service:distribute({ eliteReward, bossReward }, 1001)
assert(second.Complete, "retry should complete remaining players")
assert(#second.CompletedPlayerIds == 3, "all unique participants should complete")
assert(#second.PendingPlayerIds == 0, "no players should remain pending")
assert(owner.calls[101] == callsAfterFirstFor101, "completed players must not be processed again")
assert(owner.applied[202][eliteReward.InstanceId] and owner.applied[202][bossReward.InstanceId], "previously unloaded player should recover")
assert(owner.applied[303][eliteReward.InstanceId] and owner.applied[303][bossReward.InstanceId], "temporary save failure should recover")

local callsAfterComplete = {
	[101] = owner.calls[101],
	[202] = owner.calls[202],
	[303] = owner.calls[303],
}
local third = service:distribute({ eliteReward, bossReward }, 1002)
assert(third.Complete and service:isComplete(), "completed distribution should remain complete")
for playerId, calls in callsAfterComplete do
	assert(owner.calls[playerId] == calls, "terminal retries must not duplicate inserts")
end

local duplicateOwner = {
	calls = 0,
	applyReward = function(self: any, _playerId: number, _reward: any, _nowUnix: number)
		self.calls += 1
		return { Accepted = false, ReasonId = "RewardAlreadyApplied" }
	end,
}
local duplicateService = module.new(duplicateOwner, { 404 })
local duplicateResult = duplicateService:distribute({ eliteReward, bossReward }, 2000)
assert(duplicateResult.Complete, "already-applied rewards should count as successful idempotent completion")
assert(duplicateOwner.calls == 2, "each reward should be checked once")

duplicateService:destroy()
assert(not duplicateService:isComplete(), "destroyed service should not report completion")

print("ExpeditionRewardDistributionService.test.luau passed")
