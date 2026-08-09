--!strict

--[[
	BA-022 canonical crafting recipe contracts and deterministic eligibility resolver.

	This module is pure, dormant architecture. Item, station, and unlock references
	remain opaque IDs until BA-025 cross-domain validation. It does not consume
	items, grant outputs, persist state, bind networking, or activate crafting UI.
]]

local Contracts = {}

Contracts.RuntimeConsumptionActive = false
Contracts.MutationIntentAllowed = false

Contracts.DenialReasonIds = table.freeze({
	RuntimeDisabled = "RuntimeDisabled",
	StationRequired = "StationRequired",
	UnlockRequired = "UnlockRequired",
	MissingIngredient = "MissingIngredient",
})

export type CraftingItemReference = {
	ItemRefId: string,
	Quantity: number,
}

export type CraftingRecipeDefinition = {
	RecipeId: string,
	Version: string,
	IngredientRefs: { CraftingItemReference },
	OutputRefs: { CraftingItemReference },
	RequiredStationRefId: string?,
	RequiredUnlockId: string?,
	RuntimeEnabled: boolean,
}

export type CraftingEligibilityContext = {
	ItemQuantitiesByRefId: { [string]: number },
	UnlockedIds: { [string]: boolean },
	StationRefId: string?,
}

export type CraftingEligibilityResult = {
	Eligible: boolean,
	ReasonId: string?,
	MissingItemRefId: string?,
	RequiredQuantity: number?,
	AvailableQuantity: number?,
}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 1 and (value :: number) % 1 == 0
end

local function isNonNegativeInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

local function isDenseArray(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count += 1
	end
	return #value == count
end

local function validateItemReference(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local reference = value :: { [any]: any }
	return hasOnlyKeys(reference, {
		ItemRefId = true,
		Quantity = true,
	}) and isNonEmptyBoundedString(reference.ItemRefId, 128) and isPositiveInteger(reference.Quantity)
end

local function validateItemReferenceList(value: unknown): boolean
	if type(value) ~= "table" or not isDenseArray(value :: { [any]: any }) or #value < 1 then
		return false
	end
	local seen = {}
	for _, reference in value :: { any } do
		if not validateItemReference(reference) or seen[reference.ItemRefId] then
			return false
		end
		seen[reference.ItemRefId] = true
	end
	return true
end

function Contracts.validateRecipeDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			RecipeId = true,
			Version = true,
			IngredientRefs = true,
			OutputRefs = true,
			RequiredStationRefId = true,
			RequiredUnlockId = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(definition.RecipeId, 96) or not isNonEmptyBoundedString(definition.Version, 24) then
		return false
	end
	if not validateItemReferenceList(definition.IngredientRefs) or not validateItemReferenceList(definition.OutputRefs) then
		return false
	end
	if definition.RequiredStationRefId ~= nil and not isNonEmptyBoundedString(definition.RequiredStationRefId, 128) then
		return false
	end
	if definition.RequiredUnlockId ~= nil and not isNonEmptyBoundedString(definition.RequiredUnlockId, 128) then
		return false
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

function Contracts.validateRecipeSet(definitions: unknown): boolean
	if type(definitions) ~= "table" or not isDenseArray(definitions :: { [any]: any }) then
		return false
	end
	local seenRecipeIds = {}
	for _, definition in definitions :: { any } do
		if not Contracts.validateRecipeDefinition(definition) or seenRecipeIds[definition.RecipeId] then
			return false
		end
		seenRecipeIds[definition.RecipeId] = true
	end
	return true
end

local function normalizedQuantity(value: unknown): number
	if isNonNegativeInteger(value) then
		return value :: number
	end
	return 0
end

function Contracts.evaluateEligibility(
	definition: CraftingRecipeDefinition,
	context: CraftingEligibilityContext
): CraftingEligibilityResult
	if not definition.RuntimeEnabled then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.RuntimeDisabled,
			MissingItemRefId = nil,
			RequiredQuantity = nil,
			AvailableQuantity = nil,
		})
	end
	if definition.RequiredStationRefId ~= nil and context.StationRefId ~= definition.RequiredStationRefId then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.StationRequired,
			MissingItemRefId = nil,
			RequiredQuantity = nil,
			AvailableQuantity = nil,
		})
	end
	if definition.RequiredUnlockId ~= nil and context.UnlockedIds[definition.RequiredUnlockId] ~= true then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.UnlockRequired,
			MissingItemRefId = nil,
			RequiredQuantity = nil,
			AvailableQuantity = nil,
		})
	end
	for _, ingredient in definition.IngredientRefs do
		local availableQuantity = normalizedQuantity(context.ItemQuantitiesByRefId[ingredient.ItemRefId])
		if availableQuantity < ingredient.Quantity then
			return table.freeze({
				Eligible = false,
				ReasonId = Contracts.DenialReasonIds.MissingIngredient,
				MissingItemRefId = ingredient.ItemRefId,
				RequiredQuantity = ingredient.Quantity,
				AvailableQuantity = availableQuantity,
			})
		end
	end
	return table.freeze({
		Eligible = true,
		ReasonId = nil,
		MissingItemRefId = nil,
		RequiredQuantity = nil,
		AvailableQuantity = nil,
	})
end

assert(Contracts.RuntimeConsumptionActive == false, "BA-022 must remain dormant")
assert(Contracts.MutationIntentAllowed == false, "BA-022 cannot authorize item mutation")

return table.freeze(Contracts)
