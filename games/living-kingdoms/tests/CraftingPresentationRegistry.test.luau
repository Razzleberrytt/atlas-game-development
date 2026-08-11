--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "CraftingPresentationRegistry assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadModule(
	"games/living-kingdoms/src/shared/Visual/CraftingPresentationContracts.luau",
	"CraftingPresentationContracts"
)
local registry = loadModule(
	"games/living-kingdoms/src/shared/Config/CraftingPresentationRegistry.luau",
	"CraftingPresentationRegistry"
)

local knownCanonicalRefs = {
	["station.hub.crafting"] = true,
}

check(registry.Version == "CRAFTING-PRESENTATION-v1")
check(#registry.Definitions == 5)
check(#registry.Variants == 3)
check(#contracts.validate(registry.Definitions, registry.Variants, knownCanonicalRefs) == 0)

local hubSource = fs.readFile("games/living-kingdoms/src/shared/Config/HubInteractionConfig.luau")
local foundStation = false
for _, definition in registry.Definitions do
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
	check(string.sub(definition.modelPath, 1, 9) == "Crafting/")
	if definition.canonicalRefId == "station.hub.crafting" then
		foundStation = true
		check(definition.kind == "Workstation")
		check(string.find(hubSource, definition.canonicalRefId, 1, true) ~= nil)
	end
end
check(foundStation, "canonical crafting station requires a planned presentation")

local authorityClaim = table.clone(registry.Definitions[1])
authorityClaim.gameplayAuthorityOwnerId = "FakeCraftingService"
local authorityIssues = contracts.validate({ authorityClaim }, registry.Variants, knownCanonicalRefs)
local foundAuthorityIssue = false
for _, issue in authorityIssues do
	if issue.code == "GameplayAuthorityForbidden" then
		foundAuthorityIssue = true
	end
end
check(foundAuthorityIssue)

local modifierVariant = table.clone(registry.Variants[1])
modifierVariant.gameplayModifiers = { outputQuantity = 2 }
local variantIssues = contracts.validate(registry.Definitions, {
	modifierVariant,
	registry.Variants[2],
	registry.Variants[3],
}, knownCanonicalRefs)
local foundVariantAuthorityIssue = false
for _, issue in variantIssues do
	if issue.code == "VariantGameplayModifierForbidden" then
		foundVariantAuthorityIssue = true
	end
end
check(foundVariantAuthorityIssue)

local fakeBoundItem = table.clone(registry.Definitions[2])
fakeBoundItem.canonicalRefId = "item.not-authored"
local unknownRefIssues = contracts.validate({ fakeBoundItem }, registry.Variants, knownCanonicalRefs)
local foundUnknownRef = false
for _, issue in unknownRefIssues do
	if issue.code == "UnknownCanonicalRef" then
		foundUnknownRef = true
	end
end
check(foundUnknownRef, "un-authored item ids must not be promoted as canonical bindings")
