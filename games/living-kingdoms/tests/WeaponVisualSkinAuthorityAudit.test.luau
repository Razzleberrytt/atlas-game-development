--!strict

local fs = require("@lune/fs")

local registrySource = fs.readFile("games/living-kingdoms/src/shared/Config/WeaponVisualSkinRegistry.luau")
local contractsSource = fs.readFile("games/living-kingdoms/src/shared/Visual/WeaponVisualSkinContracts.luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "WeaponVisualSkinAuthorityAudit assertion failed", 2)
	end
end

for _, forbidden in {
	"DamagePerHit",
	"CadenceSeconds",
	"MagazineCapacity",
	"ReloadDurationSeconds",
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"FireClient",
	"DataStoreService",
} do
	check(string.find(registrySource, forbidden, 1, true) == nil, "weapon visual registry contains gameplay/runtime surface: " .. forbidden)
end

check(string.find(contractsSource, "GameplayAuthorityForbidden", 1, true) ~= nil)
check(string.find(contractsSource, "SkinGameplayModifierForbidden", 1, true) ~= nil)
check(string.find(registrySource, "PlannedCustomModel", 1, true) ~= nil)
