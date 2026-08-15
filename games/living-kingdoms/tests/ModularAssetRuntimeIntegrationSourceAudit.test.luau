--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local enemyService = fs.readFile("games/living-kingdoms/src/server/Systems/ModularEnemyAssetPresentationService.luau")
local enemyBootstrap = fs.readFile("games/living-kingdoms/src/server/modular-enemy-assets.server.luau")
local worldDressing = fs.readFile("games/living-kingdoms/src/server/ModularWorldDressing.server.luau")

assert(contains(enemyService, "ModularAssetFactory.BuildEnemyVariant"))
assert(contains(enemyService, '"Armor", "ModularArmor"'))
assert(contains(enemyService, '"Accessory", "ModularAccessory"'))
assert(contains(enemyService, 'VISIBLE_MELEE_WEAPON_ID = "enemy.weapon.blade"'))
assert(contains(enemyService, '"PreserveGameplayReadability"'))
assert(contains(enemyService, '"BodyPartId"'))
assert(contains(enemyService, '"HeadPartId"'))
assert(contains(enemyService, '"Modular" .. attributeName'))
assert(contains(enemyBootstrap, 'PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"'))
assert(contains(enemyBootstrap, "ModularEnemyAssetPresentationService.apply"))

assert(contains(worldDressing, "ModularAssetResolver.CloneByAssetId"))
assert(contains(worldDressing, "ModularAssetCatalog.Props.Categories"))
assert(contains(worldDressing, "MAX_PROP_COUNT = 10"))
assert(contains(worldDressing, "EnvironmentCompositionPlanner.Plan()"))
assert(contains(worldDressing, "descendant.CanCollide = false"))
assert(contains(worldDressing, "descendant.CanQuery = false"))

for _, prohibited in
	{
		"TakeDamage",
		"Humanoid.Health",
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"RewardCoins",
		"DamagePerHit",
	}
do
	assert(
		not contains(enemyService, prohibited),
		"modular enemy presentation gained gameplay authority token " .. prohibited
	)
	assert(
		not contains(worldDressing, prohibited),
		"modular world dressing gained gameplay authority token " .. prohibited
	)
end

print(
	"ModularAssetRuntimeIntegrationSourceAudit: canonical assets are live with presentation-only authority boundaries"
)
