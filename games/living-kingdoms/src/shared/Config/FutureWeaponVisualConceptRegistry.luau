--!strict

-- Held visual concepts only. These are not canonical firearm definitions and
-- intentionally carry no damage, cadence, ammo, recoil, rarity, or unlock data.

local Concepts = table.freeze({
	table.freeze({
		id = "weapon.concept.revolver.gravesend_v1",
		displayName = "Gravesend Revolver",
		weaponClassHint = "Revolver",
		sourceModelPath = "Weapons/Concepts/GravesendRevolverV1",
		silhouetteTags = table.freeze({ "heavy-cylinder", "frontier-sidearm", "low-bore-axis" }),
		requiredSockets = table.freeze({ "Muzzle", "Grip", "Sight", "Cylinder" }),
		canonicalFirearmId = nil,
		runtimeMapped = false,
		studioApproval = false,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "weapon.concept.rifle.widowmaker_lever_v1",
		displayName = "Widowmaker Lever Rifle",
		weaponClassHint = "LeverRifle",
		sourceModelPath = "Weapons/Concepts/WidowmakerLeverRifleV1",
		silhouetteTags = table.freeze({ "long-barrel", "lever-loop", "frontier-stock" }),
		requiredSockets = table.freeze({ "Muzzle", "Grip", "Sight", "Lever" }),
		canonicalFirearmId = nil,
		runtimeMapped = false,
		studioApproval = false,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "weapon.concept.shotgun.harrow_auto_v1",
		displayName = "Harrow Auto Shotgun",
		weaponClassHint = "AutoShotgun",
		sourceModelPath = "Weapons/Concepts/HarrowAutoShotgunV1",
		silhouetteTags = table.freeze({ "industrial-receiver", "drum-magazine", "vented-shroud" }),
		requiredSockets = table.freeze({ "Muzzle", "Grip", "Sight", "Magazine", "ShellEject" }),
		canonicalFirearmId = nil,
		runtimeMapped = false,
		studioApproval = false,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "weapon.concept.carbine.cinder_v1",
		displayName = "Cinder Carbine",
		weaponClassHint = "Carbine",
		sourceModelPath = "Weapons/Concepts/CinderCarbineV1",
		silhouetteTags = table.freeze({ "compact-receiver", "folding-stock", "scavenged-handguard" }),
		requiredSockets = table.freeze({ "Muzzle", "Grip", "Sight", "Magazine", "ShellEject" }),
		canonicalFirearmId = nil,
		runtimeMapped = false,
		studioApproval = false,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

return table.freeze({ Version = "WEAPON-VISUAL-CONCEPT-v1", Concepts = Concepts })
