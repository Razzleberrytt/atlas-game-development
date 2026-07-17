--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "P6 cache depletion presentation audit failed", 2)
	end
end

local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/AmmunitionCachePresentationContracts.luau")
local cache = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")
local controller =
	fs.readFile("games/living-kingdoms/src/client/Controllers/AmmunitionCachePresentationController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

check(string.find(contracts, 'Consumed = "AmmunitionCacheConsumed"', 1, true) ~= nil)
check(string.find(contracts, 'kindId: "AmmunitionCacheConsumed"', 1, true) ~= nil)
check(string.find(cache, "AmmunitionCachePresentationContracts", 1, true) ~= nil)
check(string.find(cache, "processed[definition.cacheId]", 1, true) ~= nil)
check(string.find(cache, "presentationRemote:FireClient(player", 1, true) ~= nil)
check(string.find(cache, "FireAllClients", 1, true) == nil, "cache depletion must remain per-player")
check(string.find(cache, 'Instance.new("RemoteEvent")', 1, true) == nil, "must reuse CombatPresentation")
check(string.find(cache, "prompt.Enabled", 1, true) == nil, "server must not globally disable shared prompts")

local commitPosition = string.find(cache, "commitReviveCombatState", 1, true)
local historyPosition = string.find(cache, "processedByPlayer[player] = table.clone", 1, true)
local disclosurePosition = string.find(cache, "presentationRemote:FireClient", 1, true)
check(commitPosition ~= nil and historyPosition ~= nil and disclosurePosition ~= nil)
check(commitPosition < historyPosition, "collection history must update only after the generation-checked commit")
check(historyPosition < disclosurePosition, "depletion feedback must follow committed collection history")

local duplicateGuardPosition = string.find(cache, "processed[definition.cacheId]", 1, true)
local combatReadPosition = string.find(cache, "readReviveCombatState", 1, true)
check(duplicateGuardPosition ~= nil and combatReadPosition ~= nil and duplicateGuardPosition < combatReadPosition)

check(string.find(controller, 'WaitForChild("CombatPresentation")', 1, true) ~= nil)
check(string.find(controller, "Contracts.MessageKindIds.Consumed", 1, true) ~= nil)
check(string.find(controller, 'GetAttribute(SUPPLY_CACHE_ID_ATTRIBUTE)', 1, true) ~= nil)
check(string.find(controller, "prompt.Enabled = false", 1, true) ~= nil)
check(string.find(controller, "ConsumedCacheHighlight", 1, true) ~= nil)
check(string.find(controller, "Enum.Material.SmoothPlastic", 1, true) ~= nil)
check(string.find(controller, "cachePart.Transparency = 0.35", 1, true) ~= nil)
check(string.find(controller, "FireServer", 1, true) == nil, "presentation controller must not send authority input")
check(string.find(controller, "Heartbeat", 1, true) == nil)
check(string.find(controller, "RenderStepped", 1, true) == nil)
check(string.find(controller, "task.", 1, true) == nil)
check(string.find(controller, "while ", 1, true) == nil)

check(string.find(bootstrap, "AmmunitionCachePresentationController", 1, true) ~= nil)
check(string.find(bootstrap, "AmmunitionCachePresentationController.start()", 1, true) ~= nil)

print("P6 cache depletion presentation source audit passed")
