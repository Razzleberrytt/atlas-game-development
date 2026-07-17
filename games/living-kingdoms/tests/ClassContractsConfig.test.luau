--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contractsPath = "games/living-kingdoms/src/shared/Classes/ClassContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/ClassConfig.luau"
local serverBootstrapPath = "games/living-kingdoms/src/server/init.server.luau"
local clientBootstrapPath = "games/living-kingdoms/src/client/init.client.luau"

local contracts = luau.load(fs.readFile(contractsPath), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local AMMUNITION_CONFIG_TOKEN = {}
local LIFE_CONFIG_TOKEN = {}

local ammunitionConfig = {
	BasicFirearm = {
		InitialLoadedRounds = 12,
		InitialReserveRounds = 24,
		MaximumReserveRounds = 48,
		AuthoredCacheRounds = 12,
	},
}

local lifeConfig = {
	MaximumHealth = 100,
	ReviveRangeStuds = 8,
	ReviveDurationSeconds = 4,
	ReviveHealth = 30,
}

local config = luau.load(fs.readFile(configPath), {
	debugName = "ClassConfig",
	environment = {
		script = {
			Parent = {
				AmmunitionScarcityConfig = AMMUNITION_CONFIG_TOKEN,
				OperativeLifeConfig = LIFE_CONFIG_TOKEN,
				Parent = {
					Classes = {
						ClassContracts = CONTRACTS_TOKEN,
					},
				},
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
		elseif token == AMMUNITION_CONFIG_TOKEN then
				return ammunitionConfig
		elseif token == LIFE_CONFIG_TOKEN then
				return lifeConfig
		end
			error("unexpected ClassConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

assertThat(contracts.ClassIds.CombatSpecialist == "class.combat-specialist", "combat class ID must be stable")
assertThat(contracts.ClassIds.Medic == "class.medic", "medic class ID must be stable")
assertThat(contracts.ClassIds.Engineer == "class.engineer", "engineer class ID must be stable")
assertThat(contracts.ClassActionIds.Brace == "class-action.brace", "Brace ID must be stable")
assertThat(contracts.ClassActionIds.FieldTreatment == "class-action.field-treatment", "treatment ID must be stable")
assertThat(contracts.ClassActionIds.ReviveAssistance == "class-action.revive-assistance", "revive ID must be stable")
assertThat(contracts.ClassActionIds.FieldResupply == "class-action.field-resupply", "resupply ID must be stable")
assertThat(contracts.ClassActionStateIds.Starting == nil, "unused Starting state must not enter the initial vocabulary")
assertThat(contracts.ClassActionStateIds.Idle == "Idle", "Idle state must be stable")
assertThat(contracts.ClassActionStateIds.Active == "Active", "Active state must be stable")
assertThat(contracts.ClassActionStateIds.Cooldown == "Cooldown", "Cooldown state must be stable")

local contractsMutationSucceeded = pcall(function()
	contracts.ClassIds.Engineer = "forged"
end)
assertThat(not contractsMutationSucceeded, "class ID vocabulary must be frozen")

assertThat(config.Version == "P7-0101-v1", "class config version must be stable")
assertThat(config.Selection.allowDuplicateStartingClasses, "duplicate starting classes must remain allowed")
assertThat(#config.Selection.startingClassIds == 3, "exactly three starting classes must be declared")
assertThat(#config.ClassDefinitions == 3, "each starting class requires one definition")
assertThat(config.Resources.MedicalCharge.maximumAmount == 3, "medical supply must be finite")
assertThat(config.Resources.ResupplyCharge.maximumAmount == 2, "resupply supply must be finite")
assertThat(config.Actions.Brace.targetKindId == contracts.ClassTargetKindIds.None, "Brace must not trust a target")
assertThat(config.Actions.FieldTreatment.healAmount == 25, "treatment starting heal must be configuration-driven")
assertThat(
	config.Actions.ReviveAssistance.restoredHealth > lifeConfig.ReviveHealth,
	"medic revive benefit must improve but not replace base revive"
)
assertThat(
	config.Actions.FieldResupply.roundsPerCharge == ammunitionConfig.BasicFirearm.AuthoredCacheRounds,
	"provisional resupply must use one bounded cache-sized grant"
)
assertThat(
	config.Actions.FieldResupply.isScarcityTuningProvisional,
	"engineer resupply must remain visibly provisional while P6 evidence is deferred"
)

local configMutationSucceeded = pcall(function()
	config.Actions.FieldResupply.roundsPerCharge = 999
end)
assertThat(not configMutationSucceeded, "class action configuration must be frozen")

local seenClasses = {}
local seenActions = {}
local seenResources = {}
for _, definition in config.ClassDefinitions do
	assertThat(not seenClasses[definition.classId], "class definitions must be unique")
	seenClasses[definition.classId] = true
	assertThat(#definition.actionIds > 0, "every starting class needs a frequent contribution")
	for _, actionId in definition.actionIds do
		assertThat(not seenActions[actionId], "each action must have one owning class")
		seenActions[actionId] = true
	end
	for _, resourceId in definition.resourceIds do
		assertThat(not seenResources[resourceId], "each resource must have one owning class")
		seenResources[resourceId] = true
	end
end

for _, classId in config.Selection.startingClassIds do
	assertThat(seenClasses[classId], "every selectable class requires a definition")
end

local contractsSource = fs.readFile(contractsPath)
local configSource = fs.readFile(configPath)
local combinedDeclarations = contractsSource .. "\n" .. configSource
for _, forbidden in {
	"game:GetService",
	"Instance.new",
	"RemoteEvent",
	"RemoteFunction",
	"Heartbeat",
	"RenderStepped",
	"task.delay",
	"task.spawn",
	"FireServer",
	"FireClient",
	"OnServerEvent",
} do
	assertThat(not string.find(combinedDeclarations, forbidden, 1, true), "P7-0101 declarations must not contain " .. forbidden)
end

local serverBootstrap = fs.readFile(serverBootstrapPath)
local clientBootstrap = fs.readFile(clientBootstrapPath)
assertThat(not string.find(serverBootstrap, "ClassService", 1, true), "P7-0101 must not bootstrap a class runtime")
assertThat(not string.find(serverBootstrap, "ClassNetwork", 1, true), "P7-0101 must not create a class network")
assertThat(not string.find(clientBootstrap, "Class", 1, true), "P7-0101 must not bootstrap class presentation")
