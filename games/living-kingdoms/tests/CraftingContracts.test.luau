--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-022 crafting contract assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/Crafting/CraftingContracts.luau"
local source = fs.readFile(sourcePath)
local Contracts = luau.load(source, {
	debugName = "CraftingContracts",
	injectGlobals = true,
})()

local definition = table.freeze({
	RecipeId = "recipe.fixture.field-kit",
	Version = "1",
	IngredientRefs = table.freeze({
		table.freeze({ ItemRefId = "item.fixture.fabric", Quantity = 2 }),
		table.freeze({ ItemRefId = "item.fixture.scrap", Quantity = 3 }),
	}),
	OutputRefs = table.freeze({
		table.freeze({ ItemRefId = "item.fixture.field-kit", Quantity = 1 }),
	}),
	RequiredStationRefId = "station.fixture.crafting",
	RequiredUnlockId = "unlock.fixture.field-kit",
	RuntimeEnabled = false,
})

assert(Contracts.RuntimeConsumptionActive == false)
assert(Contracts.MutationIntentAllowed == false)
assert(Contracts.validateRecipeDefinition(definition) == true)
assert(Contracts.validateRecipeSet({ definition }) == true)

local disabled = Contracts.evaluateEligibility(definition, {
	ItemQuantitiesByRefId = {},
	UnlockedIds = {},
	StationRefId = nil,
})
assert(disabled.Eligible == false)
assert(disabled.ReasonId == Contracts.DenialReasonIds.RuntimeDisabled)

local enabled = table.clone(definition)
enabled.RuntimeEnabled = true

local wrongStation = Contracts.evaluateEligibility(enabled, {
	ItemQuantitiesByRefId = {
		["item.fixture.fabric"] = 10,
		["item.fixture.scrap"] = 10,
	},
	UnlockedIds = { ["unlock.fixture.field-kit"] = true },
	StationRefId = "station.fixture.other",
})
assert(wrongStation.Eligible == false)
assert(wrongStation.ReasonId == Contracts.DenialReasonIds.StationRequired)

local locked = Contracts.evaluateEligibility(enabled, {
	ItemQuantitiesByRefId = {
		["item.fixture.fabric"] = 10,
		["item.fixture.scrap"] = 10,
	},
	UnlockedIds = {},
	StationRefId = "station.fixture.crafting",
})
assert(locked.Eligible == false)
assert(locked.ReasonId == Contracts.DenialReasonIds.UnlockRequired)

local missingFirstIngredient = Contracts.evaluateEligibility(enabled, {
	ItemQuantitiesByRefId = {
		["item.fixture.fabric"] = 1,
		["item.fixture.scrap"] = 0,
	},
	UnlockedIds = { ["unlock.fixture.field-kit"] = true },
	StationRefId = "station.fixture.crafting",
})
assert(missingFirstIngredient.Eligible == false)
assert(missingFirstIngredient.ReasonId == Contracts.DenialReasonIds.MissingIngredient)
assert(missingFirstIngredient.MissingItemRefId == "item.fixture.fabric")
assert(missingFirstIngredient.RequiredQuantity == 2)
assert(missingFirstIngredient.AvailableQuantity == 1)

local missingSecondIngredient = Contracts.evaluateEligibility(enabled, {
	ItemQuantitiesByRefId = {
		["item.fixture.fabric"] = 2,
		["item.fixture.scrap"] = 2,
	},
	UnlockedIds = { ["unlock.fixture.field-kit"] = true },
	StationRefId = "station.fixture.crafting",
})
assert(missingSecondIngredient.Eligible == false)
assert(missingSecondIngredient.MissingItemRefId == "item.fixture.scrap")
assert(missingSecondIngredient.RequiredQuantity == 3)
assert(missingSecondIngredient.AvailableQuantity == 2)

local eligible = Contracts.evaluateEligibility(enabled, {
	ItemQuantitiesByRefId = {
		["item.fixture.fabric"] = 2,
		["item.fixture.scrap"] = 3,
	},
	UnlockedIds = { ["unlock.fixture.field-kit"] = true },
	StationRefId = "station.fixture.crafting",
})
assert(eligible.Eligible == true)
assert(eligible.ReasonId == nil)

local invalidQuantityContext = Contracts.evaluateEligibility(enabled, {
	ItemQuantitiesByRefId = {
		["item.fixture.fabric"] = -5,
		["item.fixture.scrap"] = 3,
	},
	UnlockedIds = { ["unlock.fixture.field-kit"] = true },
	StationRefId = "station.fixture.crafting",
})
assert(invalidQuantityContext.Eligible == false)
assert(invalidQuantityContext.MissingItemRefId == "item.fixture.fabric")
assert(invalidQuantityContext.AvailableQuantity == 0)

local duplicateIngredient = table.clone(definition)
duplicateIngredient.IngredientRefs = {
	definition.IngredientRefs[1],
	definition.IngredientRefs[1],
}
assert(Contracts.validateRecipeDefinition(duplicateIngredient) == false)

local duplicateOutput = table.clone(definition)
duplicateOutput.OutputRefs = {
	definition.OutputRefs[1],
	definition.OutputRefs[1],
}
assert(Contracts.validateRecipeDefinition(duplicateOutput) == false)

local zeroIngredient = table.clone(definition)
zeroIngredient.IngredientRefs = {
	{ ItemRefId = "item.fixture.fabric", Quantity = 0 },
}
assert(Contracts.validateRecipeDefinition(zeroIngredient) == false)

local noIngredients = table.clone(definition)
noIngredients.IngredientRefs = {}
assert(Contracts.validateRecipeDefinition(noIngredients) == false)

local noOutputs = table.clone(definition)
noOutputs.OutputRefs = {}
assert(Contracts.validateRecipeDefinition(noOutputs) == false)

local duplicateRecipeId = table.clone(definition)
assert(Contracts.validateRecipeSet({ definition, duplicateRecipeId }) == false)

local unknownField = table.clone(definition)
unknownField.ClientMayCraft = true
assert(Contracts.validateRecipeDefinition(unknownField) == false)

-- BA-022 must stay pure eligibility architecture with no runtime/mutation path.
assert(string.find(source, "Instance.new", 1, true) == nil)
assert(string.find(source, "GetService", 1, true) == nil)
assert(string.find(source, "FireServer", 1, true) == nil)
assert(string.find(source, "InvokeServer", 1, true) == nil)
assert(string.find(source, "DataStore", 1, true) == nil)
assert(string.find(source, "RemoteEvent", 1, true) == nil)
assert(string.find(source, "RemoteFunction", 1, true) == nil)

print("BA-022 CraftingContracts fixture passed")
