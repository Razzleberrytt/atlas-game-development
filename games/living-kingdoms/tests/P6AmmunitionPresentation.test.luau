--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "P6 ammunition presentation audit failed", 2)
	end
end

local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local cache = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")

check(string.find(contracts, "AmmunitionState", 1, true) ~= nil)
check(string.find(contracts, "AmmunitionCollected", 1, true) ~= nil)
check(string.find(runtime, "publishAmmunitionState", 1, true) ~= nil)
check(string.find(runtime, "presentationRemote:FireClient", 1, true) ~= nil)
check(string.find(cache, "result.grantedRounds", 1, true) ~= nil)
check(string.find(cache, "commitReviveCombatState", 1, true) ~= nil)
check(string.find(controller, "presentAmmunitionPayload", 1, true) ~= nil)
check(string.find(controller, "FireServer", 1, true) ~= nil)
check(string.find(controller, "reserveRounds =", 1, true) == nil, "client must not assign authoritative reserve rounds")
check(string.find(controller, "loadedRounds =", 1, true) == nil, "client must not assign authoritative loaded rounds")

print("P6 ammunition presentation source audit passed")
