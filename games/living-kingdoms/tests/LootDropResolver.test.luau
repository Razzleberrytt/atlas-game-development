--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local contracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Loot/LootDropContracts.luau"),
	{ debugName = "LootDropContracts", injectGlobals = true }
)()
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/LootDropConfig.luau"), {
	debugName = "LootDropConfig",
	environment = {
		script = { Parent = { Parent = { Loot = { LootDropContracts = CONTRACTS_TOKEN } } } },
		require = function(token)
			assert(token == CONTRACTS_TOKEN)
			return contracts
		end,
	},
	injectGlobals = true,
})()
local replicatedStorage = {
	Shared = {
		Config = { LootDropConfig = CONFIG_TOKEN },
		Loot = { LootDropContracts = CONTRACTS_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/LootDropResolver.luau"), {
	debugName = "LootDropResolver",
	environment = {
		game = {
			GetService = function(_, serviceName)
				assert(serviceName == "ReplicatedStorage")
				return replicatedStorage
			end,
		},
		require = function(token)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == CONFIG_TOKEN then
				return config
			end
			error("unexpected loot resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local function fact(entityId: string, activeCount: number?)
	return {
		enemyEntityId = entityId,
		worldPosition = { x = 10, y = 3, z = -20 },
		activeDropCount = activeCount or 0,
		serverTimestamp = 100,
	}
end

local first = resolver.resolve(fact("enemy.fixture:deterministic"))
local second = resolver.resolve(fact("enemy.fixture:deterministic"))
assert(first.didDrop == second.didDrop)
assert(first.kindId == second.kindId and first.dropId == second.dropId)
assert(first.expiresAtServerTimestamp == second.expiresAtServerTimestamp)
assert(table.isfrozen(first), "drop decisions must be immutable")

local discovered = {}
local noDropFound = false
for index = 1, 500 do
	local result = resolver.resolve(fact("enemy.fixture:" .. tostring(index)))
	if result.didDrop then
		discovered[result.kindId] = true
		assert(result.dropId == "loot:enemy.fixture:" .. tostring(index))
		assert(result.worldPosition ~= nil and result.worldPosition.y == 3 + config.Presentation.FloatHeightStuds)
		assert(result.expiresAtServerTimestamp == 100 + config.DropLifetimeSeconds)
	else
		noDropFound = noDropFound or result.rejectionReasonId == "NoDropRoll"
	end
end
assert(discovered[contracts.LootKindIds.AmmunitionBundle])
assert(discovered[contracts.LootKindIds.FieldDressing])
assert(discovered[contracts.LootKindIds.FieldIntel])
assert(noDropFound, "the deterministic table must preserve the configured no-drop band")

local capped = resolver.resolve(fact("enemy.fixture:capped", config.MaximumActiveDrops))
assert(not capped.didDrop and capped.rejectionReasonId == "ActiveDropCapReached")

local invalid = resolver.resolve({
	enemyEntityId = "",
	worldPosition = { x = 0, y = 0, z = 0 },
	activeDropCount = 0,
	serverTimestamp = 1,
})
assert(not invalid.didDrop and invalid.rejectionReasonId == "InvalidDeathFact")

print("LootDropResolver: deterministic pool, no-drop band, placement, lifetime, and cap passed")
