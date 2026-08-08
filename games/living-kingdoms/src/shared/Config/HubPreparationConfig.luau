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
	ControlsBoardText = "FIELD MENU\nC  OPERATIVE   I  INVENTORY   K  SKILLS",
	Stations = table.freeze({
		table.freeze({
			contentId = "station.hub.class",
			actionId = "OpenClass",
			displayName = "Specialist Assignment",
			promptText = "Choose Specialist",
			x = -12,
			y = 1.15,
			z = 36,
		}),
		table.freeze({
			contentId = "station.hub.weapon",
			actionId = "OpenWeapon",
			displayName = "Armory Rack",
			promptText = "Choose Loadout",
			x = 0,
			y = 1.15,
			z = 36,
		}),
		table.freeze({
			contentId = "portal.expedition.primary",
			actionId = "OpenExpedition",
			displayName = "Expedition Terminal",
			promptText = "Open Expedition Lobby",
			x = 12,
			y = 1.15,
			z = 36,
		}),
	}),
}

return table.freeze(HubPreparationConfig)
