--!strict

export type WeaponVisualStatus = "PlannedCustomModel" | "SourceReady" | "ProductionApproved"
export type WeaponVisualFamily = "Scavenged" | "MilitarySurplus" | "FrontierBuilt" | "Experimental" | "RelicGrade"
export type WeaponSocketKind =
	"Grip"
	| "SupportGrip"
	| "Muzzle"
	| "Ejection"
	| "Magazine"
	| "Optic"
	| "Barrel"
	| "Stock"
	| "Underbarrel"
	| "Ornament"

export type WeaponSocketDefinition = {
	id: string,
	kind: WeaponSocketKind,
	required: boolean,
}

export type WeaponVisualDefinition = {
	visualId: string,
	weaponId: string,
	family: WeaponVisualFamily,
	status: WeaponVisualStatus,
	viewModelPath: string,
	worldModelPath: string,
	animationSetId: string,
	sockets: { WeaponSocketDefinition },
	compatibleSkinIds: { string },
	presentationOnly: boolean,
	gameplayAuthorityOwnerId: string?,
}

export type WeaponSkinDefinition = {
	skinId: string,
	displayName: string,
	materialSetId: string,
	paletteId: string,
	compatibleVisualIds: { string },
	presentationOnly: boolean,
	gameplayModifiers: { [string]: number }?,
}

export type ValidationIssue = {
	entryId: string?,
	code: string,
	message: string,
}

local Contracts = {}

local VALID_FAMILIES = table.freeze({
	Scavenged = true,
	MilitarySurplus = true,
	FrontierBuilt = true,
	Experimental = true,
	RelicGrade = true,
})
local VALID_STATUSES = table.freeze({
	PlannedCustomModel = true,
	SourceReady = true,
	ProductionApproved = true,
})
local VALID_SOCKET_KINDS = table.freeze({
	Grip = true,
	SupportGrip = true,
	Muzzle = true,
	Ejection = true,
	Magazine = true,
	Optic = true,
	Barrel = true,
	Stock = true,
	Underbarrel = true,
	Ornament = true,
})

local function hasRequiredSocket(definition: WeaponVisualDefinition, kind: WeaponSocketKind): boolean
	for _, socket in definition.sockets do
		if socket.kind == kind and socket.required then
			return true
		end
	end
	return false
end

function Contracts.validate(
	visuals: { WeaponVisualDefinition },
	skins: { WeaponSkinDefinition },
	knownWeaponIds: { [string]: boolean }
): { ValidationIssue }
	local issues = {}
	local visualById = {}
	local skinById = {}
	local weaponToVisual = {}

	local function issue(entryId: string?, code: string, message: string)
		table.insert(issues, { entryId = entryId, code = code, message = message })
	end

	for _, visual in visuals do
		if visual.visualId == "" then
			issue(nil, "MissingVisualId", "weapon visual id must be non-empty")
		elseif visualById[visual.visualId] then
			issue(visual.visualId, "DuplicateVisualId", "weapon visual ids must be unique")
		else
			visualById[visual.visualId] = visual
		end

		if not knownWeaponIds[visual.weaponId] then
			issue(visual.visualId, "UnknownWeaponId", "weapon visual must reference a canonical firearm id")
		elseif weaponToVisual[visual.weaponId] then
			issue(visual.visualId, "DuplicateDefaultVisual", "canonical firearms may declare only one default visual")
		else
			weaponToVisual[visual.weaponId] = visual.visualId
		end

		if not VALID_FAMILIES[visual.family] then
			issue(visual.visualId, "InvalidVisualFamily", "weapon visual family is invalid")
		end
		if not VALID_STATUSES[visual.status] then
			issue(visual.visualId, "InvalidVisualStatus", "weapon visual status is invalid")
		end
		if
			string.sub(visual.viewModelPath, 1, 8) ~= "Weapons/"
			or string.sub(visual.worldModelPath, 1, 8) ~= "Weapons/"
		then
			issue(visual.visualId, "InvalidModelPath", "weapon models must stay under Weapons/")
		end
		if visual.animationSetId == "" then
			issue(visual.visualId, "MissingAnimationSet", "weapon visuals require an animation set id")
		end
		if not visual.presentationOnly or visual.gameplayAuthorityOwnerId ~= nil then
			issue(visual.visualId, "GameplayAuthorityForbidden", "weapon visuals may not own gameplay authority")
		end

		local socketIds = {}
		for _, socket in visual.sockets do
			if socket.id == "" then
				issue(visual.visualId, "MissingSocketId", "weapon socket ids must be non-empty")
			elseif socketIds[socket.id] then
				issue(visual.visualId, "DuplicateSocketId", "weapon socket ids must be unique within a visual")
			else
				socketIds[socket.id] = true
			end
			if not VALID_SOCKET_KINDS[socket.kind] then
				issue(visual.visualId, "InvalidSocketKind", "weapon socket kind is invalid")
			end
		end
		for _, kind in { "Grip", "Muzzle", "Magazine", "Ejection" } do
			if not hasRequiredSocket(visual, kind :: WeaponSocketKind) then
				issue(
					visual.visualId,
					"RequiredSocketMissing",
					"weapon visual is missing required socket kind: " .. kind
				)
			end
		end
	end

	for _, skin in skins do
		if skin.skinId == "" then
			issue(nil, "MissingSkinId", "weapon skin id must be non-empty")
		elseif skinById[skin.skinId] then
			issue(skin.skinId, "DuplicateSkinId", "weapon skin ids must be unique")
		else
			skinById[skin.skinId] = skin
		end
		if skin.displayName == "" or skin.materialSetId == "" or skin.paletteId == "" then
			issue(
				skin.skinId,
				"IncompleteSkinPresentation",
				"weapon skins require display, material-set, and palette ids"
			)
		end
		if not skin.presentationOnly or skin.gameplayModifiers ~= nil then
			issue(skin.skinId, "SkinGameplayModifierForbidden", "weapon skins are cosmetic and may not modify gameplay")
		end
	end

	for _, visual in visuals do
		local seenSkinIds = {}
		for _, skinId in visual.compatibleSkinIds do
			if seenSkinIds[skinId] then
				issue(visual.visualId, "DuplicateCompatibleSkin", "compatible skin ids must not repeat")
			elseif not skinById[skinId] then
				issue(visual.visualId, "UnknownSkinId", "weapon visual references an unknown skin")
			else
				seenSkinIds[skinId] = true
			end
		end
	end

	for _, skin in skins do
		local seenVisualIds = {}
		for _, visualId in skin.compatibleVisualIds do
			if seenVisualIds[visualId] then
				issue(skin.skinId, "DuplicateCompatibleVisual", "compatible visual ids must not repeat")
			elseif not visualById[visualId] then
				issue(skin.skinId, "UnknownVisualId", "weapon skin references an unknown visual")
			else
				seenVisualIds[visualId] = true
			end
		end
	end

	return issues
end

return table.freeze(Contracts)
