--!strict

local fs = require("@lune/fs")

local registrySource = fs.readFile("games/living-kingdoms/src/shared/Config/CraftingPresentationRegistry.luau")
local contractsSource = fs.readFile("games/living-kingdoms/src/shared/Visual/CraftingPresentationContracts.luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "CraftingPresentationAuthorityAudit assertion failed", 2)
	end
end

for _, forbidden in
	{
		"IngredientRefs",
		"OutputRefs",
		"Quantity",
		"evaluateEligibility",
		"DataStoreService",
		"RemoteEvent",
		"RemoteFunction",
		"FireServer",
		"FireClient",
		"InvokeServer",
	}
do
	check(
		string.find(registrySource, forbidden, 1, true) == nil,
		"crafting presentation registry contains gameplay/runtime surface: " .. forbidden
	)
end

check(string.find(contractsSource, "GameplayAuthorityForbidden", 1, true) ~= nil)
check(string.find(contractsSource, "VariantGameplayModifierForbidden", 1, true) ~= nil)
check(string.find(registrySource, "station.hub.crafting", 1, true) ~= nil)
