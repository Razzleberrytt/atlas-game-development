--!strict

export type ProductionStatus = "PlannedCustomModel" | "SourceReady" | "ProductionApproved"
export type SilhouetteClass = "HumanoidBroken" | "LowPredator" | "TallBeacon" | "SwollenHazard" | "HeavyJuggernaut" | "RazorSprinter"
export type LocomotionClass = "Stalk" | "Sprint" | "Crawl" | "Lurch" | "HeavyAdvance" | "SignalPace"

export type EnemyPresentationDefinition = {
	presentationId: string,
	archetypeId: string,
	roleId: string,
	status: ProductionStatus,
	modelFamilyId: string,
	modelPath: string,
	silhouetteClass: SilhouetteClass,
	locomotionClass: LocomotionClass,
	animationSetId: string,
	audioSetId: string,
	vfxSetId: string,
	weakPointPresentationId: string?,
	skinVariantIds: { string },
	horrorTags: { string },
	attackTellTags: { string },
	presentationOnly: boolean,
	gameplayAuthorityOwnerId: string?,
}

export type EnemySkinVariant = {
	skinVariantId: string,
	displayName: string,
	modelFamilyId: string,
	materialSetId: string,
	paletteId: string,
	mutationTags: { string },
	presentationOnly: boolean,
	gameplayModifiers: { [string]: number }?,
}

export type ValidationIssue = {
	entryId: string?,
	code: string,
	message: string,
}

local Contracts = {}

local VALID_STATUSES = table.freeze({ PlannedCustomModel = true, SourceReady = true, ProductionApproved = true })
local VALID_SILHOUETTES = table.freeze({
	HumanoidBroken = true,
	LowPredator = true,
	TallBeacon = true,
	SwollenHazard = true,
	HeavyJuggernaut = true,
	RazorSprinter = true,
})
local VALID_LOCOMOTION = table.freeze({
	Stalk = true,
	Sprint = true,
	Crawl = true,
	Lurch = true,
	HeavyAdvance = true,
	SignalPace = true,
})

function Contracts.validate(
	definitions: { EnemyPresentationDefinition },
	skins: { EnemySkinVariant },
	knownArchetypeIds: { [string]: boolean },
	knownRoleIds: { [string]: boolean }
): { ValidationIssue }
	local issues = {}
	local presentationById = {}
	local skinById = {}
	local roleCoverage = {}

	local function issue(entryId: string?, code: string, message: string)
		table.insert(issues, { entryId = entryId, code = code, message = message })
	end

	for _, definition in definitions do
		if definition.presentationId == "" then
			issue(nil, "MissingPresentationId", "enemy presentation id must be non-empty")
		elseif presentationById[definition.presentationId] then
			issue(definition.presentationId, "DuplicatePresentationId", "enemy presentation ids must be unique")
		else
			presentationById[definition.presentationId] = definition
		end

		if not knownArchetypeIds[definition.archetypeId] then
			issue(definition.presentationId, "UnknownArchetypeId", "presentation must bind a canonical enemy archetype")
		end
		if not knownRoleIds[definition.roleId] then
			issue(definition.presentationId, "UnknownRoleId", "presentation must bind a canonical horde role")
		elseif roleCoverage[definition.roleId] then
			issue(definition.presentationId, "DuplicateRolePresentation", "each horde role has one default presentation identity")
		else
			roleCoverage[definition.roleId] = definition.presentationId
		end
		if not VALID_STATUSES[definition.status] then
			issue(definition.presentationId, "InvalidProductionStatus", "enemy presentation status is invalid")
		end
		if not VALID_SILHOUETTES[definition.silhouetteClass] then
			issue(definition.presentationId, "InvalidSilhouetteClass", "enemy silhouette class is invalid")
		end
		if not VALID_LOCOMOTION[definition.locomotionClass] then
			issue(definition.presentationId, "InvalidLocomotionClass", "enemy locomotion class is invalid")
		end
		if string.sub(definition.modelPath, 1, 8) ~= "Enemies/" then
			issue(definition.presentationId, "InvalidModelPath", "enemy custom models must stay under Enemies/")
		end
		if definition.modelFamilyId == "" or definition.animationSetId == "" or definition.audioSetId == "" or definition.vfxSetId == "" then
			issue(definition.presentationId, "IncompletePresentationIdentity", "model, animation, audio, and VFX identities are required")
		end
		if #definition.horrorTags < 2 then
			issue(definition.presentationId, "HorrorIdentityTooThin", "enemy presentation requires at least two horror identity tags")
		end
		if #definition.attackTellTags == 0 then
			issue(definition.presentationId, "AttackTellRequired", "scary presentation must still expose a readable attack tell")
		end
		if not definition.presentationOnly or definition.gameplayAuthorityOwnerId ~= nil then
			issue(definition.presentationId, "GameplayAuthorityForbidden", "enemy presentation may not own enemy gameplay authority")
		end
	end

	for _, skin in skins do
		if skin.skinVariantId == "" then
			issue(nil, "MissingSkinVariantId", "enemy skin variant id must be non-empty")
		elseif skinById[skin.skinVariantId] then
			issue(skin.skinVariantId, "DuplicateSkinVariantId", "enemy skin variant ids must be unique")
		else
			skinById[skin.skinVariantId] = skin
		end
		if skin.modelFamilyId == "" or skin.materialSetId == "" or skin.paletteId == "" then
			issue(skin.skinVariantId, "IncompleteSkinIdentity", "enemy skins require model-family, material-set, and palette identities")
		end
		if #skin.mutationTags == 0 then
			issue(skin.skinVariantId, "MutationIdentityRequired", "enemy skins require at least one physical mutation tag")
		end
		if not skin.presentationOnly or skin.gameplayModifiers ~= nil then
			issue(skin.skinVariantId, "SkinGameplayModifierForbidden", "enemy skins may not change gameplay")
		end
	end

	for _, definition in definitions do
		local seenSkinIds = {}
		for _, skinId in definition.skinVariantIds do
			if seenSkinIds[skinId] then
				issue(definition.presentationId, "DuplicateSkinReference", "enemy skin references must not repeat")
			elseif not skinById[skinId] then
				issue(definition.presentationId, "UnknownSkinVariantId", "enemy presentation references an unknown skin variant")
			else
				seenSkinIds[skinId] = true
			end
		end
	end

	return issues
end

return table.freeze(Contracts)
