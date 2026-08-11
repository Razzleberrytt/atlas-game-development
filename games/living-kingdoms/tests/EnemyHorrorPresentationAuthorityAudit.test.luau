--!strict

local fs = require("@lune/fs")

local registrySource = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyHorrorPresentationRegistry.luau")
local contractsSource = fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyHorrorPresentationContracts.luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "EnemyHorrorPresentationAuthorityAudit assertion failed", 2)
	end
end

for _, forbidden in {
	"MaximumHealth",
	"AttackDamage",
	"PursuitSpeedStudsPerSecond",
	"SpawnCount",
	"Reward",
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"FireClient",
} do
	check(string.find(registrySource, forbidden, 1, true) == nil, "enemy presentation contains gameplay/runtime surface: " .. forbidden)
end

check(string.find(contractsSource, "GameplayAuthorityForbidden", 1, true) ~= nil)
check(string.find(contractsSource, "SkinGameplayModifierForbidden", 1, true) ~= nil)
check(string.find(registrySource, "horde.role.crawler", 1, true) ~= nil)
check(string.find(registrySource, "four-point-ground-contact", 1, true) ~= nil)
