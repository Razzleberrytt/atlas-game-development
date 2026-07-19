--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contractsPath = "games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"

local contracts = luau.load(fs.readFile(contractsPath), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile(configPath), {
	debugName = "RunRpgConfigRewardSources",
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

local knownSourceIds = {}
for _, sourceId in contracts.RewardSourceIds do
	knownSourceIds[sourceId] = true
end

local seenSourceIds = {}
for _, definition in config.RewardSourceCatalog do
	assertThat(knownSourceIds[definition.sourceId], "reward catalog contains an unknown source ID")
	assertThat(not seenSourceIds[definition.sourceId], "reward source IDs must be unique")
	assertThat(
		definition.implementationStateId == contracts.ImplementationStateIds.Planned,
		"RPG-0101 reward sources must remain declarations only"
	)
	seenSourceIds[definition.sourceId] = true
end

for _, sourceId in contracts.RewardSourceIds do
	assertThat(seenSourceIds[sourceId], "every stable reward source requires one catalog definition")
end

assertThat(#config.RewardSourceCatalog == 6, "the initial RPG reward source vocabulary must remain bounded")
assertThat(not config.EliteAssignmentPlanning.isRuntimeEnabled, "reward declarations must not enable elite runtime")
