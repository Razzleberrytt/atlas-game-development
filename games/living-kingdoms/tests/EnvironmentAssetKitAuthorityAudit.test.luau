--!strict

local fs = require("@lune/fs")

local registrySource = fs.readFile("games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau")
local contractsSource = fs.readFile("games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "EnvironmentAssetKitAuthorityAudit assertion failed", 2)
	end
end

for _, forbidden in {
	"RemoteEvent",
	"RemoteFunction",
	"TeleportService",
	"DataStoreService",
	"HttpService",
	"ProximityPrompt",
	"BindToClose",
	"FireServer",
	"FireClient",
} do
	check(string.find(registrySource, forbidden, 1, true) == nil, "registry contains forbidden runtime surface: " .. forbidden)
	check(string.find(contractsSource, forbidden, 1, true) == nil, "contracts contain forbidden runtime surface: " .. forbidden)
end

check(string.find(contractsSource, "GameplayAuthorityForbidden", 1, true) ~= nil)
check(string.find(registrySource, "presentationOnly = true", 1, true) ~= nil)
