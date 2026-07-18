--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyLootConfig.luau"), {
	debugName = "EnemyLootConfig",
	injectGlobals = true,
})()

assertThat(config.DropRollModulo == 100, "loot rolls must use percentage-scale resolution")
assertThat(config.CommonDropRolls == 7, "common drop chance must remain seven percent")
assertThat(config.RareDropRolls == 1, "rare drop chance must remain one percent")
assertThat(config.CommonDropRolls + config.RareDropRolls == 8, "enemy loot must remain an eight-percent event")

local CONFIG_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Loot/EnemyLootResolver.luau"), {
	debugName = "EnemyLootResolver",
	environment = {
		script = {
			Parent = {
				Parent = {
					Config = { EnemyLootConfig = CONFIG_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assertThat(token == CONFIG_TOKEN, "unexpected enemy loot resolver dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

local invalid = resolver.resolveDrop("", 0, -1)
assertThat(not invalid.didDrop and invalid.rejectionReasonId == "InvalidDeathFacts", "invalid deaths must reject")

local capped = resolver.resolveDrop("enemy.fixture", 1, config.MaximumActiveDrops)
assertThat(not capped.didDrop and capped.rejectionReasonId == "ActiveDropCapReached", "active drop cap must reject")

local first = resolver.resolveDrop("enemy.fixture", 17, 0)
local repeated = resolver.resolveDrop("enemy.fixture", 17, 0)
assertThat(first.didDrop == repeated.didDrop, "identical death facts must produce an identical drop decision")
assertThat(first.rejectionReasonId == repeated.rejectionReasonId, "identical rejection must be stable")
assertThat(first.dropId == repeated.dropId and first.roll == repeated.roll, "drop identity and roll must be deterministic")

local common = nil
local rare = nil
local noDrop = nil
for sequence = 1, 2000 do
	local result = resolver.resolveDrop("enemy.roam:fixture", sequence, 0)
	if result.didDrop and result.rarityId == "Common" and common == nil then
		common = result
	elseif result.didDrop and result.rarityId == "Rare" and rare == nil then
		rare = result
	elseif not result.didDrop and result.rejectionReasonId == "NoDropRolled" and noDrop == nil then
		noDrop = result
	end
	if common ~= nil and rare ~= nil and noDrop ~= nil then
		break
	end
end

assertThat(common ~= nil, "bounded deterministic sample must expose a common drop")
assertThat(rare ~= nil, "bounded deterministic sample must expose a rare drop")
assertThat(noDrop ~= nil, "bounded deterministic sample must preserve a no-drop outcome")
assertThat(common.rounds == config.Definitions.Common.Rounds, "common ammunition grant drifted")
assertThat(common.lifetimeSeconds == config.Definitions.Common.LifetimeSeconds, "common lifetime drifted")
assertThat(rare.rounds == config.Definitions.Rare.Rounds, "rare ammunition grant drifted")
assertThat(rare.lifetimeSeconds == config.Definitions.Rare.LifetimeSeconds, "rare lifetime drifted")
assertThat(common.dropId ~= rare.dropId, "separate deaths require separate pickup identities")
assertThat(table.isfrozen(common) and table.isfrozen(rare) and table.isfrozen(noDrop), "loot resolutions must be immutable")

print("EnemyLootResolver: hard eight-percent deterministic rarity rolls, no-drop outcomes, grants, lifetime, and cap passed")