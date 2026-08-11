--!strict

export type ProductionStatus = "PlannedCustomModel" | "SourceReady" | "ProductionApproved"
export type CraftingVisualKind = "Workstation" | "Ingredient" | "Output" | "Tool" | "Container" | "RecipeResult"
export type ScaleClass = "Handheld" | "SmallProp" | "MediumProp" | "Station" | "LargeStation"
export type SocketKind = "VFX" | "Audio" | "Snap" | "IngredientDisplay" | "OutputDisplay" | "ToolRest"

export type SocketDefinition = {
	id: string,
	kind: SocketKind,
}

export type CraftingPresentationDefinition = {
	presentationId: string,
	kind: CraftingVisualKind,
	canonicalRefId: string?,
	modelFamilyId: string,
	modelPath: string,
	status: ProductionStatus,
	scaleClass: ScaleClass,
	materialSetId: string,
	variantIds: { string },
	sockets: { SocketDefinition },
	presentationOnly: boolean,
	gameplayAuthorityOwnerId: string?,
}

export type CraftingVisualVariant = {
	variantId: string,
	displayName: string,
	materialSetId: string,
	paletteId: string,
	variantTags: { string },
	presentationOnly: boolean,
	gameplayModifiers: { [string]: number }?,
}

export type ValidationIssue = {
	entryId: string?,
	code: string,
	message: string,
}

local Contracts = {}

local VALID_KINDS = table.freeze({
	Workstation = true,
	Ingredient = true,
	Output = true,
	Tool = true,
	Container = true,
	RecipeResult = true,
})
local VALID_STATUSES = table.freeze({ PlannedCustomModel = true, SourceReady = true, ProductionApproved = true })
local VALID_SCALE_CLASSES = table.freeze({
	Handheld = true,
	SmallProp = true,
	MediumProp = true,
	Station = true,
	LargeStation = true,
})
local VALID_SOCKET_KINDS = table.freeze({
	VFX = true,
	Audio = true,
	Snap = true,
	IngredientDisplay = true,
	OutputDisplay = true,
	ToolRest = true,
})

function Contracts.validate(
	definitions: { CraftingPresentationDefinition },
	variants: { CraftingVisualVariant },
	knownCanonicalRefs: { [string]: boolean }
): { ValidationIssue }
	local issues = {}
	local definitionById = {}
	local variantById = {}
	local boundRefIds = {}

	local function issue(entryId: string?, code: string, message: string)
		table.insert(issues, { entryId = entryId, code = code, message = message })
	end

	for _, definition in definitions do
		if definition.presentationId == "" then
			issue(nil, "MissingPresentationId", "crafting presentation id must be non-empty")
		elseif definitionById[definition.presentationId] then
			issue(definition.presentationId, "DuplicatePresentationId", "crafting presentation ids must be unique")
		else
			definitionById[definition.presentationId] = definition
		end

		if not VALID_KINDS[definition.kind] then
			issue(definition.presentationId, "InvalidVisualKind", "crafting visual kind is invalid")
		end
		if definition.canonicalRefId ~= nil then
			if not knownCanonicalRefs[definition.canonicalRefId] then
				issue(
					definition.presentationId,
					"UnknownCanonicalRef",
					"bound crafting presentation references an unknown canonical id"
				)
			elseif boundRefIds[definition.canonicalRefId] then
				issue(
					definition.presentationId,
					"DuplicateCanonicalBinding",
					"canonical crafting refs may have only one default presentation"
				)
			else
				boundRefIds[definition.canonicalRefId] = definition.presentationId
			end
		end
		if definition.kind == "Workstation" and definition.canonicalRefId == nil then
			issue(
				definition.presentationId,
				"WorkstationBindingRequired",
				"workstations must bind a canonical station id"
			)
		end
		if definition.modelFamilyId == "" or definition.materialSetId == "" then
			issue(
				definition.presentationId,
				"IncompleteModelIdentity",
				"model family and material set ids are required"
			)
		end
		if
			string.sub(definition.modelPath, 1, 9) ~= "Crafting/"
			or string.find(definition.modelPath, "..", 1, true) ~= nil
		then
			issue(definition.presentationId, "InvalidModelPath", "crafting models must remain under Crafting/")
		end
		if not VALID_STATUSES[definition.status] then
			issue(definition.presentationId, "InvalidProductionStatus", "crafting presentation status is invalid")
		end
		if not VALID_SCALE_CLASSES[definition.scaleClass] then
			issue(definition.presentationId, "InvalidScaleClass", "crafting presentation scale class is invalid")
		end
		if not definition.presentationOnly or definition.gameplayAuthorityOwnerId ~= nil then
			issue(
				definition.presentationId,
				"GameplayAuthorityForbidden",
				"crafting presentation may not own crafting or inventory gameplay authority"
			)
		end

		local socketIds = {}
		for _, socket in definition.sockets do
			if socket.id == "" then
				issue(definition.presentationId, "MissingSocketId", "crafting socket ids must be non-empty")
			elseif socketIds[socket.id] then
				issue(
					definition.presentationId,
					"DuplicateSocketId",
					"crafting socket ids must be unique within a presentation"
				)
			else
				socketIds[socket.id] = true
			end
			if not VALID_SOCKET_KINDS[socket.kind] then
				issue(definition.presentationId, "InvalidSocketKind", "crafting socket kind is invalid")
			end
		end
	end

	for _, variant in variants do
		if variant.variantId == "" then
			issue(nil, "MissingVariantId", "crafting visual variant id must be non-empty")
		elseif variantById[variant.variantId] then
			issue(variant.variantId, "DuplicateVariantId", "crafting visual variant ids must be unique")
		else
			variantById[variant.variantId] = variant
		end
		if variant.displayName == "" or variant.materialSetId == "" or variant.paletteId == "" then
			issue(
				variant.variantId,
				"IncompleteVariantIdentity",
				"crafting variants require display, material-set, and palette ids"
			)
		end
		if #variant.variantTags == 0 then
			issue(variant.variantId, "VariantTagRequired", "crafting variants require at least one presentation tag")
		end
		if not variant.presentationOnly or variant.gameplayModifiers ~= nil then
			issue(
				variant.variantId,
				"VariantGameplayModifierForbidden",
				"crafting visual variants may not alter gameplay"
			)
		end
	end

	for _, definition in definitions do
		local seenVariants = {}
		for _, variantId in definition.variantIds do
			if seenVariants[variantId] then
				issue(
					definition.presentationId,
					"DuplicateVariantReference",
					"crafting variant references must not repeat"
				)
			elseif not variantById[variantId] then
				issue(
					definition.presentationId,
					"UnknownVariantId",
					"crafting presentation references an unknown variant"
				)
			else
				seenVariants[variantId] = true
			end
		end
	end

	return issues
end

return table.freeze(Contracts)
