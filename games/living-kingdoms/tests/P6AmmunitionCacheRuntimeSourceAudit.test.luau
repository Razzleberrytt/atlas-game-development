--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P6 ammunition cache source audit failed", 2)
	end
end

local service = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/AmmunitionCacheConfig.luau")

assert(service:find("ProximityPrompt", 1, true) ~= nil, "cache runtime must use server-observed proximity prompts")
assert(service:find("OperativeLifeService.isCombatAllowed", 1, true) ~= nil, "collection must require combat-eligible life state")
assert(service:find("horizontalDistance", 1, true) ~= nil, "collection must revalidate distance on the server")
assert(service:find("AmmunitionSupplyResolver.collect", 1, true) ~= nil, "collection must use the pure scarcity resolver")
assert(service:find("readReviveCombatState", 1, true) ~= nil, "collection must read through the combat owner")
assert(service:find("commitReviveCombatState", 1, true) ~= nil, "collection must commit through the combat owner")
assert(service:find("RemoteEvent", 1, true) == nil, "cache runtime must not add a client remote")
assert(service:find("RemoteFunction", 1, true) == nil, "cache runtime must not add a client function")
assert(service:find("Heartbeat", 1, true) == nil, "cache runtime must not add a scheduler")
assert(service:find("task%.", 1) == nil, "cache runtime must not add task loops or timers")
assert(bootstrap:find("AmmunitionCacheService.start()", 1, true) ~= nil, "production bootstrap must start the cache runtime")
assert(config:find("MaximumDistanceStuds", 1, true) ~= nil, "cache interaction distance must be configured")
assert(config:find("HoldDurationSeconds", 1, true) ~= nil, "cache hold duration must be configured")

print("P6 ammunition cache runtime source audit passed")