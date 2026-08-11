--!strict

-- Presentation-only custom-model/skin planning registry. Combat stats and weapon
-- behavior remain authoritative in FirearmConfig and existing combat owners.

local sharedSkins = table.freeze({
	"skin.weapon.blackwater_issue",
	"skin.weapon.frontier_worn",
	"skin.weapon.corruption_scarred",
	"skin.weapon.mine_rescue",
	"skin.weapon.rust_bloom",
	"skin.weapon.ash_church",
	"skin.weapon.night_signal",
	"skin.weapon.marrow_white",
	"skin.weapon.creek_mud",
	"skin.weapon.hazard_stripe",
	"skin.weapon.relic_brass",
	"skin.weapon.frostbite",
})

local function sockets(includeSupportGrip: boolean)
	local result = {
		table.freeze({ id = "RightGripAttachment", kind = "Grip", required = true }),
		table.freeze({ id = "Muzzle", kind = "Muzzle", required = true }),
		table.freeze({ id = "Magazine", kind = "Magazine", required = true }),
		table.freeze({ id = "Ejection", kind = "Ejection", required = true }),
		table.freeze({ id = "socket.optic", kind = "Optic", required = false }),
		table.freeze({ id = "socket.barrel", kind = "Barrel", required = false }),
		table.freeze({ id = "socket.ornament", kind = "Ornament", required = false }),
	}
	if includeSupportGrip then
		table.insert(result, table.freeze({ id = "LeftGripAttachment", kind = "SupportGrip", required = true }))
	end
	return table.freeze(result)
end

local Visuals = table.freeze({
	table.freeze({
		visualId = "weapon.visual.service_pistol.vigil_v1",
		weaponId = "weapon.service-pistol",
		family = "MilitarySurplus",
		status = "PlannedCustomModel",
		viewModelPath = "Weapons/ServicePistol/VigilV1/ViewModel",
		worldModelPath = "Weapons/ServicePistol/VigilV1/WorldModel",
		animationSetId = "weapon.anim.service_pistol.v1",
		sockets = sockets(false),
		compatibleSkinIds = sharedSkins,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		visualId = "weapon.visual.breach_shotgun.morrow_v1",
		weaponId = "weapon.breach-shotgun",
		family = "FrontierBuilt",
		status = "PlannedCustomModel",
		viewModelPath = "Weapons/BreachShotgun/MorrowV1/ViewModel",
		worldModelPath = "Weapons/BreachShotgun/MorrowV1/WorldModel",
		animationSetId = "weapon.anim.breach_shotgun.v1",
		sockets = sockets(true),
		compatibleSkinIds = sharedSkins,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		visualId = "weapon.visual.sniper_rifle.longwatch_v1",
		weaponId = "weapon.sniper-rifle",
		family = "MilitarySurplus",
		status = "PlannedCustomModel",
		viewModelPath = "Weapons/SniperRifle/LongwatchV1/ViewModel",
		worldModelPath = "Weapons/SniperRifle/LongwatchV1/WorldModel",
		animationSetId = "weapon.anim.sniper_rifle.v1",
		sockets = sockets(true),
		compatibleSkinIds = sharedSkins,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		visualId = "weapon.visual.submachine_gun.razor_v1",
		weaponId = "weapon.submachine-gun",
		family = "Scavenged",
		status = "PlannedCustomModel",
		viewModelPath = "Weapons/SubmachineGun/RazorV1/ViewModel",
		worldModelPath = "Weapons/SubmachineGun/RazorV1/WorldModel",
		animationSetId = "weapon.anim.submachine_gun.v1",
		sockets = sockets(true),
		compatibleSkinIds = sharedSkins,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		visualId = "weapon.visual.light_machine_gun.blackwater_v1",
		weaponId = "weapon.light-machine-gun",
		family = "MilitarySurplus",
		status = "PlannedCustomModel",
		viewModelPath = "Weapons/LightMachineGun/BlackwaterV1/ViewModel",
		worldModelPath = "Weapons/LightMachineGun/BlackwaterV1/WorldModel",
		animationSetId = "weapon.anim.light_machine_gun.v1",
		sockets = sockets(true),
		compatibleSkinIds = sharedSkins,
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

local allVisualIds = table.freeze({
	"weapon.visual.service_pistol.vigil_v1",
	"weapon.visual.breach_shotgun.morrow_v1",
	"weapon.visual.sniper_rifle.longwatch_v1",
	"weapon.visual.submachine_gun.razor_v1",
	"weapon.visual.light_machine_gun.blackwater_v1",
})

local Skins = table.freeze({
	table.freeze({
		skinId = "skin.weapon.blackwater_issue",
		displayName = "Blackwater Issue",
		materialSetId = "weapon.material.blackened_steel_oiled_wood",
		paletteId = "weapon.palette.blackwater_issue",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.frontier_worn",
		displayName = "Frontier Worn",
		materialSetId = "weapon.material.worn_steel_weathered_wood",
		paletteId = "weapon.palette.frontier_worn",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.corruption_scarred",
		displayName = "Corruption Scarred",
		materialSetId = "weapon.material.scarred_metal_resin",
		paletteId = "weapon.palette.corruption_scarred",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.mine_rescue",
		displayName = "Mine Rescue",
		materialSetId = "weapon.material.chipped_enamel_black_steel",
		paletteId = "weapon.palette.mine_rescue",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.rust_bloom",
		displayName = "Rust Bloom",
		materialSetId = "weapon.material.oxidized_steel_dark_wood",
		paletteId = "weapon.palette.rust_bloom",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.ash_church",
		displayName = "Ash Church",
		materialSetId = "weapon.material.charcoal_steel_bone_inlay",
		paletteId = "weapon.palette.ash_church",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.night_signal",
		displayName = "Night Signal",
		materialSetId = "weapon.material.matte_black_signal_tape",
		paletteId = "weapon.palette.night_signal",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.marrow_white",
		displayName = "Marrow White",
		materialSetId = "weapon.material.pale_ceramic_black_steel",
		paletteId = "weapon.palette.marrow_white",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.creek_mud",
		displayName = "Creek Mud",
		materialSetId = "weapon.material.mud_stained_steel_canvas",
		paletteId = "weapon.palette.creek_mud",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.hazard_stripe",
		displayName = "Hazard Stripe",
		materialSetId = "weapon.material.industrial_steel_safety_paint",
		paletteId = "weapon.palette.hazard_stripe",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.relic_brass",
		displayName = "Relic Brass",
		materialSetId = "weapon.material.tarnished_brass_dark_wood",
		paletteId = "weapon.palette.relic_brass",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
	table.freeze({
		skinId = "skin.weapon.frostbite",
		displayName = "Frostbite",
		materialSetId = "weapon.material.frosted_steel_pale_polymer",
		paletteId = "weapon.palette.frostbite",
		compatibleVisualIds = allVisualIds,
		presentationOnly = true,
		gameplayModifiers = nil,
	}),
})

return table.freeze({
	Version = "WEAPON-VISUAL-SKIN-v2",
	Visuals = Visuals,
	Skins = Skins,
})
