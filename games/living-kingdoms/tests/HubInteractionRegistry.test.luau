--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "HubInteractionRegistry assertion failed", 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/World/HubInteractionContracts.luau"), {
	debugName = "HubInteractionContracts",
	injectGlobals = true,
})()

check(contracts.isValidStableId("hub.anchor.operation_board"))
check(not contracts.isValidStableId("Hub Anchor/Bad"))

local worldContractsToken = {}
local worldContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/World/WorldContentContracts.luau"), {
	debugName = "WorldContentContracts",
	injectGlobals = true,
})()
local replicatedStorageForWorld = {
	Shared = {
		World = {
			WorldContentContracts = worldContractsToken,
		},
	},
}
local worldContentConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/WorldContentConfig.luau"), {
	debugName = "WorldContentConfig",
	environment = {
		game = {
			GetService = function(_: unknown, serviceName: string)
				check(serviceName == "ReplicatedStorage")
				return replicatedStorageForWorld
			end,
		},
		require = function(token: unknown)
			check(token == worldContractsToken, "unexpected world-content dependency")
			return worldContracts
		end,
	},
	injectGlobals = true,
})()

local mainWorldRepresentationConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MainWorldRepresentationConfig.luau"), {
		debugName = "MainWorldRepresentationConfig",
		injectGlobals = true,
	})()

local contractsToken = {}
local mainWorldToken = {}
local worldContentToken = {}
local replicatedStorage = {
	Shared = {
		Config = {
			MainWorldRepresentationConfig = mainWorldToken,
			WorldContentConfig = worldContentToken,
		},
		World = {
			HubInteractionContracts = contractsToken,
		},
	},
}

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HubInteractionConfig.luau"), {
	debugName = "HubInteractionConfig",
	environment = {
		game = {
			GetService = function(_: unknown, serviceName: string)
				check(serviceName == "ReplicatedStorage")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == contractsToken then
				return contracts
			elseif token == mainWorldToken then
				return mainWorldRepresentationConfig
			elseif token == worldContentToken then
				return worldContentConfig
			end
			error("unexpected HubInteractionConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

check(config.Version == "BA-012-v1")
check(config.AddsRuntimeBehavior == false)
check(config.AuthoredMainWorldRuntimeEnabled == false)
check(table.isfrozen(config))
check(table.isfrozen(config.Anchors))
check(#config.Anchors == 16)

local expectedBridgeActions = {
	OpenClass = "ClassService",
	OpenWeapon = "WeaponLoadoutService",
	OpenExpedition = "ExpeditionLobbyService",
}
local bridgeCount = 0
local authoredCount = 0
for _, anchor in config.Anchors do
	local valid, reason = contracts.validateAnchor(anchor)
	check(valid, reason)
	check(config.ById[anchor.id] == anchor, "anchor must be indexed by id")
	check(worldContentConfig.ById[anchor.worldContentId] ~= nil, "anchor must reference registered world content")
	if anchor.runtimeEnabled then
		bridgeCount += 1
		check(anchor.worldSpaceId == contracts.WorldSpaceIds.CurrentOperationBridge)
		check(expectedBridgeActions[anchor.bridgeActionId] == anchor.mutationOwnerId)
		expectedBridgeActions[anchor.bridgeActionId] = nil
		check(worldContentConfig.ById[anchor.worldContentId].active == true)
	else
		check(anchor.bridgeActionId == nil)
	end
	if anchor.worldSpaceId == contracts.WorldSpaceIds.AuthoredMainWorld then
		authoredCount += 1
		check(anchor.runtimeEnabled == false, "authored Main World anchors must remain held")
	end
	if anchor.sourcePath ~= nil then
		check(mainWorldRepresentationConfig.streamingGroupForSourcePath(anchor.sourcePath).id == "main_world.hub_core")
	end
	if
		anchor.authorityStatusId == contracts.AuthorityStatusIds.DomainContractRequired
		or anchor.authorityStatusId == contracts.AuthorityStatusIds.PolicyRequired
	then
		check(anchor.mutationOwnerId == nil, "future domains must not receive invented mutation owners")
	end
end

check(bridgeCount == 3)
check(authoredCount == 13)
check(next(expectedBridgeActions) == nil, "all existing bridge actions must be represented exactly once")
check(config.ById["hub.anchor.operation_board"].sourcePath == "Workspace/HubTown/quest_board")
check(config.ById["hub.anchor.expedition_portal"].mutationOwnerId == "ExpeditionLobbyService")
check(config.ById["hub.anchor.npc.guide"].sourcePath == nil)
check(config.ById["hub.anchor.social"].authorityStatusId == "PolicyRequired")
check(#config.ByWorldContentId["portal.expedition.primary"] == 2)
check(config.Rules.ClientSurfaceNeverOwnsConsequentialMutation == true)
check(config.Rules.RecoveredPromptInferenceForbidden == true)
check(config.Rules.StreamOutNeverCompletesInteraction == true)

local invalidRecovered = table.clone(config.ById["hub.anchor.operation_board"])
invalidRecovered.sourcePath = nil
check(not contracts.validateAnchor(invalidRecovered))

local invalidFutureOwner = table.clone(config.ById["hub.anchor.crafting"])
invalidFutureOwner.mutationOwnerId = "InventedCraftingService"
check(not contracts.validateAnchor(invalidFutureOwner))

local invalidActive = table.clone(config.ById["hub.anchor.crafting"])
invalidActive.runtimeEnabled = true
check(not contracts.validateAnchor(invalidActive))

local duplicateDependency = table.clone(config.ById["hub.anchor.crafting"])
duplicateDependency.dependencyIds = { "BA-022", "BA-022" }
check(not contracts.validateAnchor(duplicateDependency))
