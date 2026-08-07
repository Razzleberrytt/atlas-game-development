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

-- RPG-0110 connects the three sources whose authoritative owners exist today.
-- Authored objectives, authored containers, and boss milestones wait for P8/P9.
local liveSourceIds = {
	[contracts.RewardSourceIds.EliteKill] = true,
	[contracts.RewardSourceIds.SpecialInterrupt] = true,
	[contracts.RewardSourceIds.HordeClear] = true,
}
local seenSourceIds = {}
local implementedSourceCount = 0
for _, definition in config.RewardSourceCatalog do
	assertThat(knownSourceIds[definition.sourceId], "reward catalog contains an unknown source ID")
	assertThat(not seenSourceIds[definition.sourceId], "reward source IDs must be unique")
	if definition.implementationStateId == contracts.ImplementationStateIds.Implemented then
		implementedSourceCount += 1
		assertThat(liveSourceIds[definition.sourceId] == true, "only sources with a live owner may be implemented")
	else
		assertThat(
			definition.implementationStateId == contracts.ImplementationStateIds.Planned,
			"invalid reward source implementation state"
		)
		assertThat(liveSourceIds[definition.sourceId] == nil, "every live reward source must be implemented")
	end
	seenSourceIds[definition.sourceId] = true
end
assertThat(implementedSourceCount == 3, "exactly the three live reward sources may be implemented")

for _, sourceId in contracts.RewardSourceIds do
	assertThat(seenSourceIds[sourceId], "every stable reward source requires one catalog definition")
end

assertThat(#config.RewardSourceCatalog == 6, "the initial RPG reward source vocabulary must remain bounded")
assertThat(config.EliteAssignmentPlanning.isRuntimeEnabled, "RPG-0106 must enable elite runtime")
