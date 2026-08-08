--!strict

-- BA-012: canonical hub interaction registry.
--
-- This registry adds no prompt, remote, bootstrap, placement, or gameplay
-- mutation. Active entries describe the existing Forward Operations Hub
-- bridge; every authored Main World entry remains held.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubInteractionContracts = require(ReplicatedStorage.Shared.World.HubInteractionContracts)
local MainWorldRepresentationConfig = require(ReplicatedStorage.Shared.Config.MainWorldRepresentationConfig)
local WorldContentConfig = require(ReplicatedStorage.Shared.Config.WorldContentConfig)

type AnchorDefinition = HubInteractionContracts.AnchorDefinition

local anchors: { AnchorDefinition } = {
	table.freeze({
		id = "hub.anchor.class_assignment",
		worldContentId = "station.hub.class",
		displayName = "Specialist Assignment",
		surfaceKindId = "Preparation",
		worldSpaceId = "CurrentOperationBridge",
		placementStatusId = "ActiveSourceManaged",
		interactionIntentId = "hub.intent.open_class_selection",
		presentationOwnerId = "ClassSelectionController",
		mutationOwnerId = "ClassService",
		authorityStatusId = "ExistingCanonical",
		runtimeEnabled = true,
		bridgeActionId = "OpenClass",
		dependencyIds = table.freeze({}),
	}),
	table.freeze({
		id = "hub.anchor.weapon_loadout",
		worldContentId = "station.hub.weapon",
		displayName = "Armory Rack",
		surfaceKindId = "Preparation",
		worldSpaceId = "CurrentOperationBridge",
		placementStatusId = "ActiveSourceManaged",
		interactionIntentId = "hub.intent.open_weapon_loadout",
		presentationOwnerId = "WeaponSelectionController",
		mutationOwnerId = "WeaponLoadoutService",
		authorityStatusId = "ExistingCanonical",
		runtimeEnabled = true,
		bridgeActionId = "OpenWeapon",
		dependencyIds = table.freeze({}),
	}),
	table.freeze({
		id = "hub.anchor.expedition_terminal",
		worldContentId = "portal.expedition.primary",
		displayName = "Expedition Terminal",
		surfaceKindId = "Portal",
		worldSpaceId = "CurrentOperationBridge",
		placementStatusId = "ActiveSourceManaged",
		interactionIntentId = "hub.intent.open_expedition_lobby",
		presentationOwnerId = "ExpeditionLobbyController",
		mutationOwnerId = "ExpeditionLobbyService",
		authorityStatusId = "ExistingCanonical",
		runtimeEnabled = true,
		bridgeActionId = "OpenExpedition",
		dependencyIds = table.freeze({}),
		notes = "Launch remains server-owned by ExpeditionLobbyService.",
	}),
	table.freeze({
		id = "hub.anchor.character",
		worldContentId = "station.hub.character",
		displayName = "Operative Console",
		surfaceKindId = "Preparation",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.open_character",
		presentationOwnerId = "RPGMenuController",
		authorityStatusId = "PresentationOnly",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-014" }),
	}),
	table.freeze({
		id = "hub.anchor.inventory",
		worldContentId = "station.hub.inventory",
		displayName = "Field Locker",
		surfaceKindId = "Preparation",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.open_inventory",
		presentationOwnerId = "RPGMenuController",
		authorityStatusId = "PresentationOnly",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-014" }),
	}),
	table.freeze({
		id = "hub.anchor.skills",
		worldContentId = "station.hub.skills",
		displayName = "Training Board",
		surfaceKindId = "Preparation",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.open_skills",
		presentationOwnerId = "RPGMenuController",
		authorityStatusId = "PresentationOnly",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-014" }),
	}),
	table.freeze({
		id = "hub.anchor.operation_board",
		worldContentId = "station.hub.operation_board",
		displayName = "Operation Board",
		surfaceKindId = "OperationBoard",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "RecoveredHeld",
		sourcePath = "Workspace/HubTown/quest_board",
		interactionIntentId = "hub.intent.open_operation_selection",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-020", "BA-034" }),
		notes = "Recovered board presentation supplies no prompt or mission authority.",
	}),
	table.freeze({
		id = "hub.anchor.vendor.apothecary",
		worldContentId = "vendor.hub.apothecary",
		displayName = "Apothecary",
		surfaceKindId = "Vendor",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "RecoveredHeld",
		sourcePath = "Workspace/HubTown/apothecary",
		interactionIntentId = "hub.intent.open_vendor.apothecary",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-021", "BA-024", "BA-026" }),
	}),
	table.freeze({
		id = "hub.anchor.vendor.armor_smith",
		worldContentId = "vendor.hub.armor_smith",
		displayName = "Armor Smith",
		surfaceKindId = "Vendor",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "RecoveredHeld",
		sourcePath = "Workspace/HubTown/armor_smith",
		interactionIntentId = "hub.intent.open_vendor.armor_smith",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-021", "BA-024", "BA-026" }),
	}),
	table.freeze({
		id = "hub.anchor.vendor.weapon_smith",
		worldContentId = "vendor.hub.weapon_smith",
		displayName = "Weapon Smith",
		surfaceKindId = "Vendor",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "RecoveredHeld",
		sourcePath = "Workspace/HubTown/weapon_smith",
		interactionIntentId = "hub.intent.open_vendor.weapon_smith",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-021", "BA-024", "BA-026" }),
	}),
	table.freeze({
		id = "hub.anchor.vendor.merchant",
		worldContentId = "vendor.hub.merchant",
		displayName = "Merchant",
		surfaceKindId = "Vendor",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "RecoveredHeld",
		sourcePath = "Workspace/HubTown/merchant",
		interactionIntentId = "hub.intent.open_vendor.merchant",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-021", "BA-024", "BA-026" }),
	}),
	table.freeze({
		id = "hub.anchor.npc.guide",
		worldContentId = "station.hub.npc_guide",
		displayName = "Hub Guide",
		surfaceKindId = "Npc",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.talk_to_guide",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-021" }),
		notes = "Reserved spatial anchor only; BA-012 does not invent an NPC identity or dialogue.",
	}),
	table.freeze({
		id = "hub.anchor.crafting",
		worldContentId = "station.hub.crafting",
		displayName = "Crafting Station",
		surfaceKindId = "Crafting",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.open_crafting",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-022", "BA-026" }),
	}),
	table.freeze({
		id = "hub.anchor.gathering",
		worldContentId = "station.hub.gathering",
		displayName = "Gathering Station",
		surfaceKindId = "Gathering",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.open_gathering",
		authorityStatusId = "DomainContractRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-023", "BA-026" }),
	}),
	table.freeze({
		id = "hub.anchor.expedition_portal",
		worldContentId = "portal.expedition.primary",
		displayName = "Expedition Portal",
		surfaceKindId = "Portal",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "RecoveredHeld",
		sourcePath = "Workspace/HubTown/DungeonPortal",
		interactionIntentId = "hub.intent.open_expedition_lobby",
		mutationOwnerId = "ExpeditionLobbyService",
		authorityStatusId = "ExistingCanonical",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-031", "BA-034", "BA-035" }),
		notes = "Presentation is held; future launch still delegates to ExpeditionLobbyService.",
	}),
	table.freeze({
		id = "hub.anchor.social",
		worldContentId = "station.hub.social",
		displayName = "Social Gathering Point",
		surfaceKindId = "Social",
		worldSpaceId = "AuthoredMainWorld",
		placementStatusId = "UnassignedHeld",
		interactionIntentId = "hub.intent.open_social_surface",
		authorityStatusId = "PolicyRequired",
		runtimeEnabled = false,
		dependencyIds = table.freeze({ "BA-035" }),
		notes = "No party leader, matchmaking, invitation, or session authority is implied.",
	}),
}

local byId = HubInteractionContracts.indexById(anchors)
local byWorldContentId = HubInteractionContracts.indexByWorldContentId(anchors)

for _, anchor in anchors do
	local descriptor = WorldContentConfig.ById[anchor.worldContentId]
	assert(descriptor ~= nil, "hub anchor references unknown world content: " .. anchor.worldContentId)
	if anchor.runtimeEnabled then
		assert(descriptor.active, "runtime-enabled hub anchor requires active world content")
	end
	if anchor.sourcePath ~= nil then
		local streamingGroup = MainWorldRepresentationConfig.streamingGroupForSourcePath(anchor.sourcePath)
		assert(streamingGroup ~= nil and streamingGroup.id == "main_world.hub_core", "hub source must map to hub core")
	end
end

return table.freeze({
	Version = "BA-012-v1",
	AddsRuntimeBehavior = false,
	AuthoredMainWorldRuntimeEnabled = false,
	Anchors = table.freeze(anchors),
	ById = table.freeze(byId),
	ByWorldContentId = table.freeze(byWorldContentId),
	Rules = table.freeze({
		ClientSurfaceNeverOwnsConsequentialMutation = true,
		RecoveredPromptInferenceForbidden = true,
		StreamOutNeverCompletesInteraction = true,
		LegacyGameplayServicesRemainInert = true,
		FutureOwnerMustBeAssignedBeforeActivation = true,
	}),
})
