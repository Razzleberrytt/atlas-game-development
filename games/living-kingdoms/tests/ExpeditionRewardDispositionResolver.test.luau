--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local EXPEDITION_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionContracts.luau"), {
	debugName = "ExpeditionContracts",
	injectGlobals = true,
})()
local resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionRewardDispositionResolver.luau"), {
		debugName = "ExpeditionRewardDispositionResolver",
		environment = {
			script = { Parent = { ExpeditionContracts = EXPEDITION_TOKEN } },
			require = function(token: unknown)
				assert(token == EXPEDITION_TOKEN, "unexpected reward disposition dependency")
				return contracts
			end,
		},
		injectGlobals = true,
	})()

local ids = resolver.RewardDispositionIds
assert(resolver.resolve(contracts.OutcomeIds.InProgress) == ids.Pending, "active run rewards must remain pending")
assert(resolver.resolve(contracts.OutcomeIds.Completed) == ids.Banked, "completed run rewards must bank")
assert(resolver.resolve(contracts.OutcomeIds.Failed) == ids.Forfeited, "failed run rewards must be forfeited")
assert(resolver.resolve(contracts.OutcomeIds.Abandoned) == ids.Forfeited, "abandoned run rewards must be forfeited")
assert(resolver.resolve("Bogus") == nil, "unknown outcomes must fail closed")

assert(resolver.shouldPersist(contracts.OutcomeIds.Completed), "completed rewards must reach persistence")
assert(not resolver.shouldPersist(contracts.OutcomeIds.Failed), "failed rewards must not reach persistence")
assert(not resolver.shouldPersist(contracts.OutcomeIds.Abandoned), "abandoned rewards must not reach persistence")
assert(not resolver.shouldPersist(contracts.OutcomeIds.InProgress), "active rewards must not reach persistence")

print("ExpeditionRewardDispositionResolver: completed banks; failed and abandoned forfeit")
