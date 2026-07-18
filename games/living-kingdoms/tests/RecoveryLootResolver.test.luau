--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local CONTRACTS_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Loot/LootDropContracts.luau"), {
	debugName = "LootDropContracts",
	injectGlobals = true,
})()
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/LootDropConfig.luau"), {
	debugName = "LootDropConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Loot = { LootDropContracts = CONTRACTS_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected recovery config dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

assertThat(config.DropRollPercentByKind[contracts.LootKindIds.AmmunitionBundle] == 0, "recovery service duplicated ammo")
assertThat(config.DropRollPercentByKind[contracts.LootKindIds.FieldDressing] == 5, "field dressing chance drifted")
assertThat(config.DropRollPercentByKind[contracts.LootKindIds.FieldIntel] == 2, "field intel chance drifted")
assertThat(config.NoDropPercent == 93, "recovery no-drop chance drifted")

local CONFIG_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/LootDropResolver.luau"), {
	debugName = "RecoveryLootResolver",
	environment = {
		game = {
			GetService = function(_self, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "unexpected service")
				return {
					Shared = {
						Config = { LootDropConfig = CONFIG_TOKEN },
						Loot = { LootDropContracts = CONTRACTS_TOKEN },
					},
				}
			end,
		},
		require = function(token: unknown)
			if token == CONFIG_TOKEN then
				return config
			end
			assertThat(token == CONTRACTS_TOKEN, "unexpected recovery resolver dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local invalid = resolver.resolve({
	enemyEntityId = "",
	worldPosition = { x = 0, y = 0, z = 0 },
	activeDropCount = 0,
	serverTimestamp = 1,
})
assertThat(not invalid.didDrop and invalid.rejectionReasonId == "InvalidDeathFact", "invalid facts must reject")

local capped = resolver.resolve({
	enemyEntityId = "enemy.capped",
	worldPosition = { x = 0, y = 0, z = 0 },
	activeDropCount = config.MaximumActiveDrops,
	serverTimestamp = 1,
})
assertThat(not capped.didDrop and capped.rejectionReasonId == "ActiveDropCapReached", "active cap must reject")

local dressing = nil
local intel = nil
local noDrop = nil
local ammunition = nil
for index = 1, 10000 do
	local result = resolver.resolve({
		enemyEntityId = "enemy.recovery:" .. tostring(index),
		worldPosition = { x = index, y = 2, z = -index },
		activeDropCount = 0,
		serverTimestamp = 10,
	})
	if result.didDrop and result.kindId == contracts.LootKindIds.FieldDressing and dressing == nil then
		dressing = result
	elseif result.didDrop and result.kindId == contracts.LootKindIds.FieldIntel and intel == nil then
		intel = result
	elseif result.didDrop and result.kindId == contracts.LootKindIds.AmmunitionBundle then
		ammunition = result
	elseif not result.didDrop and result.rejectionReasonId == "NoDropRoll" and noDrop == nil then
		noDrop = result
	end
	if dressing ~= nil and intel ~= nil and noDrop ~= nil then
		break
	end
end

assertThat(dressing ~= nil, "bounded sample must expose a field dressing")
assertThat(intel ~= nil, "bounded sample must expose field intel")
assertThat(noDrop ~= nil, "bounded sample must preserve no-drop")
assertThat(ammunition == nil, "recovery resolver emitted duplicate ammunition")
assertThat(dressing.expiresAtServerTimestamp == 28, "recovery lifetime drifted")
assertThat(intel.expiresAtServerTimestamp == 28, "intel lifetime drifted")
assertThat(table.isfrozen(dressing) and table.isfrozen(intel) and table.isfrozen(noDrop), "resolutions must be immutable")

print("RecoveryLootResolver: five-percent healing, two-percent Field Intel, zero ammo duplication, cap, and expiry passed")
