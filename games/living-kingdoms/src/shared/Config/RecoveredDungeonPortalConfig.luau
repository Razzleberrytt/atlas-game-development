--!strict

-- BA-005 property-backed reconstruction contract for the Studio-authored
-- Workspace/HubTown/DungeonPortal group.
--
-- This is presentation evidence only. The recovered portal must never revive
-- the legacy dungeon authority; a future overworld interaction delegates to the
-- canonical expedition flow.

local CommonPartFlags = table.freeze({
	Anchored = true,
	CanQuery = true,
	CanTouch = true,
	CastShadow = true,
})

local Config = {
	Version = "BA-005-DUNGEON-PORTAL-v1",
	SourcePath = "Workspace/HubTown/DungeonPortal",
	CoordinateSpaceId = "authored-overworld",
	SourceHold = true,
	RuntimeEnabled = false,
	Interaction = table.freeze({
		CanonicalContentId = "portal.expedition.primary",
		CanonicalAuthority = "ExpeditionLobbyService",
		LegacyGameplayAuthority = false,
		RuntimeEnabled = false,
	}),
	Evidence = table.freeze({
		SourceRbxlSha256 = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16",
		IdentityRows = 10,
		PropertyBackedRows = 6,
		PendingPropertyRows = 3,
		GeneratedContainerRows = 1,
	}),
	Parts = table.freeze({
		table.freeze({
			name = "PortalFrame",
			sourceId = 202,
			parent = "DungeonPortal",
			position = table.freeze({ x = 0.0, y = 8.0, z = 22.0 }),
			rotationId = 2,
			size = table.freeze({ x = 10.0, y = 16.0, z = 4.0 }),
			colorBytes = table.freeze({ r = 70, g = 65, b = 60 }),
			materialEnumValue = 800,
			transparency = 0.0,
			reflectance = 0.0,
			shapeEnumValue = 1,
			canCollide = true,
			flags = CommonPartFlags,
		}),
		table.freeze({
			name = "PortalEffect",
			sourceId = 204,
			parent = "DungeonPortal",
			position = table.freeze({ x = 0.0, y = 8.0, z = 22.0 }),
			rotationId = 2,
			size = table.freeze({ x = 8.0, y = 14.0, z = 2.0 }),
			colorBytes = table.freeze({ r = 100, g = 200, b = 255 }),
			materialEnumValue = 288,
			transparency = 0.4000000059604645,
			reflectance = 0.0,
			shapeEnumValue = 1,
			canCollide = false,
			flags = CommonPartFlags,
		}),
		table.freeze({
			name = "PortalSign",
			sourceId = 208,
			parent = "DungeonPortal",
			position = table.freeze({ x = 0.0, y = 17.0, z = 22.0 }),
			rotationId = 2,
			size = table.freeze({ x = 8.0, y = 2.0, z = 0.5 }),
			colorBytes = table.freeze({ r = 80, g = 55, b = 25 }),
			materialEnumValue = 528,
			transparency = 0.0,
			reflectance = 0.0,
			shapeEnumValue = 1,
			canCollide = true,
			flags = CommonPartFlags,
		}),
	}),
	PointLights = table.freeze({
		table.freeze({
			name = "PortalGlow",
			sourceId = 203,
			parent = "PortalFrame",
			brightness = 3.0,
			color = table.freeze({ r = 0.5882353186607361, g = 0.19607843458652496, b = 1.0 }),
			enabled = true,
			range = 25.0,
			shadows = false,
		}),
		table.freeze({
			name = "PointLight",
			sourceId = 205,
			parent = "PortalEffect",
			brightness = 3.0,
			color = table.freeze({ r = 0.3921568691730499, g = 0.7843137383460999, b = 1.0 }),
			enabled = true,
			range = 20.0,
			shadows = false,
		}),
	}),
	Attachments = table.freeze({
		table.freeze({
			name = "PortalSwirlAttach",
			sourceId = 206,
			parent = "PortalEffect",
			position = table.freeze({ x = 0.0, y = 0.0, z = 0.0 }),
			rotationId = 2,
		}),
	}),
	PendingPropertyNodes = table.freeze({
		table.freeze({
			path = "PortalEffect/PortalSwirlAttach/PortalSwirl",
			className = "ParticleEmitter",
			sourceId = 207,
			reason = "number/color sequence properties are outside BA-005 property decoder v1",
		}),
		table.freeze({
			path = "PortalSign/SurfaceGui",
			className = "SurfaceGui",
			sourceId = 209,
			reason = "UI layout properties are outside BA-005 property decoder v1",
		}),
		table.freeze({
			path = "PortalSign/SurfaceGui/TextLabel",
			className = "TextLabel",
			sourceId = 210,
			reason = "UI layout/font properties are outside BA-005 property decoder v1",
		}),
	}),
}

return table.freeze(Config)
