--!strict

-- Source-managed preparation shell attached to the current Ranger Station.
-- This is deliberately a presentation/access layer: gameplay mutations remain
-- owned by the existing class, weapon, progression, inventory, and expedition
-- services.

local HubPreparationConfig = {
	Version = "HUB-SHELL-v1",
	RootName = "ForwardOperationsHub",
	AnchorLandmarkId = "RangerStation",
	ZoneContentId = "zone.hub.forward_operations",
	PromptMaxDistance = 12,
	Stations = table.freeze({
		table.freeze({
			contentId = "station.hub.character",
			actionId = "OpenCharacter",
			displayName = "Operative Console",
			promptText = "Review Operative",
			x = -12,
			y = 1.15,
			z = 30,
		}),
		table.freeze({
			contentId = "station.hub.inventory",
			actionId = "OpenInventory",
			displayName = "Field Locker",
			promptText = "Open Inventory",
			x = 0,
			y = 1.15,
			z = 30,
		}),
		table.freeze({
			contentId = "station.hub.skills",
			actionId = "OpenSkills",
			displayName = "Training Board",
			promptText = "Review Skills",
			x = 12,
			y = 1.15,
			z = 30,
		}),
		table.freeze({
			contentId = "station.hub.class",
			actionId = "OpenClass",
			displayName = "Specialist Assignment",
			promptText = "Choose Specialist",
			x = -12,
			y = 1.15,
			z = 40,
		}),
		table.freeze({
			contentId = "station.hub.weapon",
			actionId = "OpenWeapon",
			displayName = "Armory Rack",
			promptText = "Choose Loadout",
			x = 0,
			y = 1.15,
			z = 40,
		}),
		table.freeze({
			contentId = "portal.expedition.primary",
			actionId = "OpenExpedition",
			displayName = "Expedition Terminal",
			promptText = "Open Expedition Lobby",
			x = 12,
			y = 1.15,
			z = 40,
		}),
	}),
}

return table.freeze(HubPreparationConfig)
