--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "P6 cache depletion presentation audit failed", 2)
	end
end

local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/AmmunitionCachePresentationContracts.luau")
local cache = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")

check(string.find(contracts, "AmmunitionCacheConsumed", 1, true) ~= nil)
check(string.find(cache, "CachePresentationContracts.MessageKindIds.Consumed", 1, true) ~= nil)
check(string.find(controller, "CachePresentationContracts.MessageKindIds.Consumed", 1, true) ~= nil)
check(string.find(cache, "if processed[definition.cacheId] then", 1, true) ~= nil)
check(string.find(controller, "prompt.Enabled = false", 1, true) ~= nil)
check(string.find(controller, "ConsumedCacheHighlight", 1, true) ~= nil)
check(string.find(controller, 'SUPPLY_CACHE_ID_ATTRIBUTE = "SupplyCacheId"', 1, true) ~= nil)
check(string.find(controller, "processedByPlayer", 1, true) == nil, "client must not duplicate collection history")
check(string.find(cache, 'Instance.new("RemoteEvent")', 1, true) == nil, "cache feedback must reuse the existing remote")
check(string.find(controller, 'SetAttribute("SupplyCacheId"', 1, true) == nil, "client must not author cache identity")

local combatCommitIndex = string.find(cache, "not OperativeCombatRuntimeService.commitReviveCombatState", 1, true)
local historyCommitIndex = string.find(cache, "processedByPlayer[player] = table.clone", 1, true)
local feedbackIndex = string.find(cache, "CachePresentationContracts.MessageKindIds.Consumed", 1, true)
check(combatCommitIndex ~= nil and historyCommitIndex ~= nil and feedbackIndex ~= nil)
check(combatCommitIndex < historyCommitIndex, "collection history advanced before combat commit")
check(historyCommitIndex < feedbackIndex, "depletion feedback escaped before collection history commit")

print("P6 cache depletion presentation source audit passed")
