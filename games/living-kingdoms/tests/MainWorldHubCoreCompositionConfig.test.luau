--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldHubCoreCompositionConfig assertion failed", 2)
	end
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local composition = loadConfig("MainWorldHubCoreCompositionConfig")
local representation = loadConfig("MainWorldRepresentationConfig")
local arrival = loadConfig("RecoveredSpawnLocationConfig")
local fountain = loadConfig("RecoveredCentralFountainConfig")
local staircase = loadConfig("RecoveredGrandStaircaseConfig")
local archway = loadConfig("RecoveredHubArchwayConfig")
local portal = loadConfig("RecoveredDungeonPortalConfig")

check(composition.Version == "P0.5-MAIN-WORLD-HUB-CORE-COMPOSITION-v1")
check(composition.ContentId == "main_world.hub_core")
check(composition.CoordinateSpaceId == "authored-overworld")
check(composition.TargetPath == "Workspace/LivingKingdomsMainWorld/HubCore")
check(composition.SourceHold == true)
check(composition.RuntimeEnabled == false)
check(composition.DedicatedMainWorldOnly == true)
check(composition.OperationProjectMappingAllowed == false)
check(#composition.Components == 5)

local hubGroup = representation.streamingGroupForSourcePath("Workspace/HubTown/CentralFountain")
check(hubGroup ~= nil)
check(hubGroup.id == "main_world.hub_core")
check(hubGroup.targetPath == composition.TargetPath)

local expected = {
	["spawn.main_world.arrival"] = {
		contract = arrival,
		version = "BA-005-SPAWN-LOCATION-v1",
		sourcePath = "Workspace/SpawnLocation",
	},
	["main_world.hub_core.central_fountain"] = {
		contract = fountain,
		version = "P0.5-CENTRAL-FOUNTAIN-v1",
		sourcePath = "Workspace/HubTown/CentralFountain",
	},
	["main_world.hub_core.grand_staircase"] = {
		contract = staircase,
		version = "P0.5-GRAND-STAIRCASE-v1",
		sourcePath = "Workspace/HubTown/GrandStaircase",
	},
	["main_world.hub_core.archway"] = {
		contract = archway,
		version = "P0.5-HUB-ARCHWAY-v1",
		sourcePath = "Workspace/HubTown/HubArchway",
	},
	["portal.expedition.primary"] = {
		contract = portal,
		version = "BA-005-DUNGEON-PORTAL-v2",
		sourcePath = "Workspace/HubTown/DungeonPortal",
	},
}

local seen = {}
for _, component in composition.Components do
	check(seen[component.id] == nil, "duplicate component id: " .. component.id)
	seen[component.id] = true

	local item = expected[component.id]
	check(item ~= nil, "unexpected hub-core component: " .. component.id)
	check(component.sourceContractVersion == item.version, component.id .. " version drift")
	check(component.sourcePath == item.sourcePath, component.id .. " source path drift")
	check(item.contract.Version == item.version, component.id .. " contract version mismatch")
	check(item.contract.SourcePath == item.sourcePath, component.id .. " contract source mismatch")
	check(item.contract.SourceHold == true, component.id .. " must remain source-held")
	check(item.contract.RuntimeEnabled == false, component.id .. " must remain runtime-disabled")

	local group = representation.streamingGroupForSourcePath(component.sourcePath)
	check(group ~= nil and group.id == "main_world.hub_core", component.id .. " must route to hub_core")
end

check(composition.componentById("spawn.main_world.arrival") ~= nil)
check(composition.componentById("portal.expedition.primary") ~= nil)
check(composition.componentById("missing") == nil)
check(portal.Interaction.CanonicalContentId == "portal.expedition.primary")
check(portal.Interaction.CanonicalAuthority == composition.Authority.ExpeditionGameplayOwner)
check(portal.Interaction.LegacyGameplayAuthority == false)
check(composition.Authority.RecoveredGameplayAuthorityAllowed == false)
check(composition.Authority.LegacyBootstrapAllowed == false)
check(composition.Authority.WorldFoundationServiceAllowed == false)
check(composition.Rules.PreserveAuthoredCoordinatesOneToOne == true)
check(composition.Rules.AllComponentsMustRemainHeldUntilActivationGate == true)
check(composition.Rules.DoNotInventUnadmittedWorldContent == true)
