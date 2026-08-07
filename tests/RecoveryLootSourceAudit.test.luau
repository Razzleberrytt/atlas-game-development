--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
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

local service = fs.readFile("games/living-kingdoms/src/server/Systems/RecoveryLootService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/RecoveryLootBootstrap.server.luau")
local lifeService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local progressionService = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local ammoContracts = fs.readFile("games/living-kingdoms/src/shared/Combat/AmmunitionScarcityContracts.luau")
local primaryLootConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyLootConfig.luau"), {
	debugName = "EnemyLootConfig",
	injectGlobals = true,
})()

assertThat(primaryLootConfig.CommonDropRolls == 7, "primary common ammo chance changed")
assertThat(primaryLootConfig.RareDropRolls == 1, "primary rare ammo chance changed")
assertThat(config.MaximumActiveDrops == 8, "recovery active-drop ceiling drifted")
assertThat(config.DropRollPercentByKind[contracts.LootKindIds.AmmunitionBundle] == 0, "recovery duplicated ammo")
assertThat(config.DropRollPercentByKind[contracts.LootKindIds.FieldDressing] == 5, "field dressing chance drifted")
assertThat(config.DropRollPercentByKind[contracts.LootKindIds.FieldIntel] == 2, "field intel chance drifted")
assertThat(config.NoDropPercent == 93, "recovery no-drop chance drifted")
assertThat(config.Rewards.HealingAmount == 30, "healing grant drifted")
assertThat(config.Rewards.FieldIntelXp == 40, "Field Intel grant drifted")

assertThat(contains(service, "RunService.Heartbeat:Connect"), "recovery loot requires one bounded death/expiry scan")
assertThat(
	contains(service, "ProximityPromptService.PromptTriggered:Connect"),
	"recovery loot requires one global prompt listener"
)
assertThat(contains(service, "OperativeLifeService.isCombatAllowed"), "only living operatives may collect")
assertThat(contains(service, "OperativeLifeService.applyAuthoritativeHealing"), "healing must use the life owner")
assertThat(contains(service, "RunProgressionService.awardFieldIntel"), "Field Intel must use the progression owner")
assertThat(contains(service, "horizontalDistance"), "prompt collection must revalidate world distance")
assertThat(contains(service, "entry.claimed"), "collection must be single-claim")
assertThat(contains(service, 'Instance.new("Highlight")'), "recovery loot requires readable highlight")
assertThat(contains(service, 'Instance.new("PointLight")'), "recovery loot requires readable glow")
assertThat(contains(service, 'Instance.new("BillboardGui")'), "recovery loot requires reward disclosure")
assertThat(contains(service, 'Instance.new("ProximityPrompt")'), "recovery loot requires deliberate collection")
assertThat(not contains(service, ".Touched"), "touch collection is prohibited")
assertThat(not contains(service, "OnServerEvent"), "client-authored reward remotes are prohibited")
assertThat(not contains(service, "DataStoreService"), "recovery loot must remain run-only")
assertThat(not contains(service, "Humanoid.Health"), "recovery loot must not bypass canonical health")
assertThat(contains(lifeService, "OperativeHealingResolver.resolve"), "life owner must route through pure healing")
assertThat(
	contains(progressionService, "function RunProgressionService.awardFieldIntel"),
	"progression owner must expose server-only Intel awards"
)
assertThat(
	contains(ammoContracts, 'EnemyDrop = "EnemyLoot"'),
	"legacy recovery source must alias the current enemy-loot authority"
)
assertThat(contains(bootstrap, "task.defer(RecoveryLootService.start)"), "recovery bootstrap must start the service")

print(
	"RecoveryLootSourceAudit: primary ammo preserved, rare healing/intel, prompt authority, visuals, and bounded runtime passed"
)
