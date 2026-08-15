--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local basePath = "games/living-kingdoms/src/server/Systems/"
local presentation = fs.readFile(basePath .. "ModularRewardContainerPresentation.luau")
local survivalLoot = fs.readFile(basePath .. "SurvivalLootService.luau")
local catalog = fs.readFile("games/living-kingdoms/src/shared/Config/ModularAssetProductionCatalog.luau")

assert(contains(catalog, 'id = "reward.chest.common"'))
assert(contains(presentation, 'COMMON_REWARD_ASSET_ID = "reward.chest.common"'))
assert(contains(presentation, "ModularAssetResolver.GetGeneratedRoot"))
assert(contains(presentation, "ModularAssetResolver.CloneByAssetId"))
assert(contains(presentation, 'findBasePart(model, "Root")'))
assert(contains(presentation, 'findBasePart(model, "Lid")'))
assert(contains(presentation, 'VisualStatus", MODULAR_STATUS'))
assert(contains(presentation, 'VisualStatus", FALLBACK_STATUS'))

-- Generated geometry stays purely visual. Invisible proxies preserve the old
-- character collision, touch, and ray-query footprint plus lid opening motion.
assert(contains(presentation, "part.CanCollide = false"))
assert(contains(presentation, "part.CanTouch = false"))
assert(contains(presentation, "part.CanQuery = false"))
assert(contains(presentation, "proxy.CanCollide = true"))
assert(contains(presentation, "proxy.CanTouch = true"))
assert(contains(presentation, "proxy.CanQuery = true"))
assert(contains(presentation, '"ChestCollisionBase"'))
assert(contains(presentation, '"ChestCollisionLid"'))
assert(contains(presentation, '"ChestCollisionBand"'))
assert(contains(presentation, "collisionLid.CFrame = collisionClosedCFrame * openOffset"))
assert(contains(presentation, 'base.Name = "ChestBase"'))
assert(contains(presentation, 'lid.Name = "ChestLid"'))
assert(contains(presentation, 'band.Name = "MetalBand"'))

-- SurvivalLootService remains the gameplay owner; only construction and the
-- lid-open presentation are delegated.
assert(contains(survivalLoot, "require(script.Parent.ModularRewardContainerPresentation)"))
assert(contains(survivalLoot, "ModularRewardContainerPresentation.createSupplyChest(parent, index, position)"))
assert(contains(survivalLoot, "presentation.Open()"))
assert(not contains(survivalLoot, 'base.Name = "ChestBase"'))
assert(not contains(survivalLoot, 'lid.Name = "ChestLid"'))
assert(not contains(survivalLoot, 'band.Name = "MetalBand"'))

-- Reward/collection authority contracts must stay in the live service.
for _, authorityToken in
	{
		"Config.ChestWoodMinimum",
		"Config.AmmoRoundsMinimum",
		"Config.ChestWeaponChancePercent",
		"Config.GuaranteedWeaponByOpenedChest",
		"OperativeCombatRuntimeService.grantFoundAmmunition",
		"OperativeCombatRuntimeService.equipFoundWeapon",
		"stageLoot(state",
		"collectChestLoot(player, chestId, position)",
		"lootOwner ~= player",
	}
do
	assert(contains(survivalLoot, authorityToken), "survival loot authority contract missing " .. authorityToken)
end

for _, prohibited in
	{
		"ChestWeaponChancePercent",
		"GuaranteedWeaponByOpenedChest",
		"grantFoundAmmunition",
		"equipFoundWeapon",
		"stageLoot",
		"RemoteEvent",
		"FireClient",
		"FireServer",
	}
do
	assert(
		not contains(presentation, prohibited),
		"reward-container presentation gained gameplay authority token " .. prohibited
	)
end

print(
	"ModularRewardContainerPresentationSourceAudit: modular shell, fallback, collision/query, and authority boundaries passed"
)
