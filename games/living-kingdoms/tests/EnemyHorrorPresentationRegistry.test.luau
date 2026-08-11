--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "EnemyHorrorPresentationRegistry assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadModule(
	"games/living-kingdoms/src/shared/Visual/EnemyHorrorPresentationContracts.luau",
	"EnemyHorrorPresentationContracts"
)
local registry = loadModule(
	"games/living-kingdoms/src/shared/Config/EnemyHorrorPresentationRegistry.luau",
	"EnemyHorrorPresentationRegistry"
)

local knownArchetypeIds = {
	["enemy.exclusion_walker"] = true,
	["enemy.blight_spitter"] = true,
	["boss.progenitor"] = true,
}
local knownRoleIds = {
	["horde.role.infected"] = true,
	["horde.role.runner"] = true,
	["horde.role.crawler"] = true,
	["horde.role.screamer"] = true,
	["horde.role.bloater"] = true,
	["horde.role.brute"] = true,
}

check(registry.Version == "ENEMY-HORROR-PRESENTATION-v1")
check(#registry.Definitions == 6)
check(#registry.Skins == 3)
check(#contracts.validate(registry.Definitions, registry.Skins, knownArchetypeIds, knownRoleIds) == 0)

local enemySource = fs.readFile("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau")
local hordeSource = fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau")
for _, definition in registry.Definitions do
	check(string.find(enemySource, definition.archetypeId, 1, true) ~= nil)
	check(string.find(hordeSource, definition.roleId, 1, true) ~= nil)
	check(definition.status == "PlannedCustomModel")
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
end

local crawler
for _, definition in registry.Definitions do
	if definition.roleId == "horde.role.crawler" then
		crawler = definition
		break
	end
end
check(crawler ~= nil, "Crawler requires an explicit custom-model identity")
check(crawler.silhouetteClass == "LowPredator")
check(crawler.locomotionClass == "Crawl")
check(#crawler.horrorTags >= 4, "Crawler requires a stronger-than-baseline horror identity")
check(#crawler.attackTellTags >= 2, "Crawler must remain readable despite horror treatment")

local authorityClaim = table.clone(registry.Definitions[1])
authorityClaim.gameplayAuthorityOwnerId = "FakeEnemyAIService"
local authorityIssues = contracts.validate({ authorityClaim }, registry.Skins, knownArchetypeIds, knownRoleIds)
local foundAuthorityIssue = false
for _, issue in authorityIssues do
	if issue.code == "GameplayAuthorityForbidden" then
		foundAuthorityIssue = true
	end
end
check(foundAuthorityIssue)

local modifierSkin = table.clone(registry.Skins[1])
modifierSkin.gameplayModifiers = { health = 2 }
local skinIssues = contracts.validate(registry.Definitions, { modifierSkin, registry.Skins[2], registry.Skins[3] }, knownArchetypeIds, knownRoleIds)
local foundSkinModifierIssue = false
for _, issue in skinIssues do
	if issue.code == "SkinGameplayModifierForbidden" then
		foundSkinModifierIssue = true
	end
end
check(foundSkinModifierIssue)
