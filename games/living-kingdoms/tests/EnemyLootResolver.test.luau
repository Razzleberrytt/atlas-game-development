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
assertThat(not invalid.wasGuaranteed and invalid.guaranteeReasonId == nil, "rejections cannot claim a guarantee")

local capped = resolver.resolveDrop("enemy.fixture", 1, config.MaximumActiveDrops)
assertThat(not capped.didDrop and capped.rejectionReasonId == "ActiveDropCapReached", "active drop cap must reject")
assertThat(not capped.wasGuaranteed, "the active-drop ceiling must override first-blood guarantee")

local firstBlood = resolver.resolveDrop("enemy.first-blood", 1, 0)
assertThat(firstBlood.didDrop, "the first confirmed death must immediately reward the run")
assertThat(firstBlood.rarityId == "Common", "first blood must guarantee the bounded common reward")
assertThat(firstBlood.wasGuaranteed and firstBlood.guaranteeReasonId == "FirstConfirmedDeath", "first-blood reason drifted")
assertThat(firstBlood.rounds == config.Definitions.Common.Rounds, "first blood must use the common ammunition grant")

local cadenceSequence = config.GuaranteedCommonDropEveryDeaths
local cadenceDrop = resolver.resolveDrop("enemy.cadence", cadenceSequence, 0)
assertThat(cadenceDrop.didDrop and cadenceDrop.rarityId == "Common", "cadence floor must guarantee common salvage")
assertThat(cadenceDrop.wasGuaranteed and cadenceDrop.guaranteeReasonId == "CadenceFloor", "cadence reason drifted")

for sequence = cadenceSequence, cadenceSequence * 12, cadenceSequence do
	local result = resolver.resolveDrop("enemy.cadence:" .. tostring(sequence), sequence, 0)
	assertThat(result.didDrop and result.wasGuaranteed, "every configured cadence checkpoint must create salvage")
	assertThat(result.rarityId == "Common", "cadence checkpoints must never mint rare rewards")
end

local first = resolver.resolveDrop("enemy.fixture", 17, 0)
local repeated = resolver.resolveDrop("enemy.fixture", 17, 0)
assertThat(first.didDrop == repeated.didDrop, "identical death facts must produce an identical drop decision")
assertThat(first.rejectionReasonId == repeated.rejectionReasonId, "identical rejection must be stable")
assertThat(first.dropId == repeated.dropId and first.roll == repeated.roll, "drop identity and roll must be deterministic")
assertThat(
	first.wasGuaranteed == repeated.wasGuaranteed and first.guaranteeReasonId == repeated.guaranteeReasonId,
	"guarantee disclosure must be deterministic"
)

local common = nil
local rare = nil
local noDrop = nil
for sequence = 2, 500 do
	if sequence % cadenceSequence == 0 then
		continue
	end
	local result = resolver.resolveDrop("enemy.roam:fixture", sequence, 0)
	if result.didDrop and result.rarityId == "Common" and not result.wasGuaranteed and common == nil then
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

assertThat(common ~= nil, "bounded deterministic sample must expose a natural common drop")
assertThat(rare ~= nil, "bounded deterministic sample must expose a rare drop")
assertThat(noDrop ~= nil, "bounded deterministic sample must preserve a no-drop outcome between guarantees")
assertThat(common.rounds == config.Definitions.Common.Rounds, "common ammunition grant drifted")
assertThat(common.lifetimeSeconds == config.Definitions.Common.LifetimeSeconds, "common lifetime drifted")
assertThat(rare.rounds == config.Definitions.Rare.Rounds, "rare ammunition grant drifted")
assertThat(rare.lifetimeSeconds == config.Definitions.Rare.LifetimeSeconds, "rare lifetime drifted")
assertThat(common.dropId ~= rare.dropId, "separate deaths require separate pickup identities")
assertThat(not common.wasGuaranteed and not rare.wasGuaranteed, "natural rarity outcomes must not claim pity protection")
assertThat(
	table.isfrozen(firstBlood)
		and table.isfrozen(cadenceDrop)
		and table.isfrozen(common)
		and table.isfrozen(rare)
		and table.isfrozen(noDrop),
	"loot resolutions must be immutable"
)

print("EnemyLootResolver: first blood, guaranteed cadence, deterministic rarity, grants, lifetime, and cap passed")
