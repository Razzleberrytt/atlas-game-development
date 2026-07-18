--!strict

--[[
	Regression audit for the horde vertical slice single source of truth. It locks
	the ownership split established by the stabilization pass:

	  * RunProgressionService is the only owner of Field XP, levels, upgrade
	    offers, upgrade selection, and combat modifiers.
	  * EnemyLootService is the only owner of ammunition loot.
	  * HordeExperienceService owns only spawning, pressure, enemy roles and
	    behaviour, threat, a non-rewarding massacre streak, and the event feed.
	  * HordeHUDController is the only combat HUD and routes upgrade selection
	    exclusively through ProgressionNetwork.ChooseUpgrade.
]]

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local project = fs.readFile("games/living-kingdoms/default.project.json")
local enemyConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")
local hordeConfig = fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local effects = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeEffectsController.luau")
local weapon = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local life = fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeLifeController.luau")
local mission = fs.readFile("games/living-kingdoms/src/client/Controllers/MissionController.luau")

-- The horde network carries only presentation state. Upgrade selection lives on
-- ProgressionNetwork (created in code), so no ChooseUpgrade remote may exist in
-- the static project tree at all.
assertThat(contains(project, '"HordeNetwork"'), "project mapping is missing the horde network")
assertThat(contains(project, '"State"'), "project mapping is missing the horde state remote")
assertThat(not contains(project, "ChooseUpgrade"), "the only upgrade remote must be the runtime ProgressionNetwork one")

for _, required in
	{
		"MaximumConcurrentPerOperative = 24",
		"AbsoluteMaximumConcurrent = 96",
		"EvaluationIntervalSeconds = 0.1",
		"MaximumLineOfSightRaycastsPerEvaluation = 8",
	}
do
	assertThat(contains(enemyConfig, required), "horde enemy bounds are missing " .. required)
end

for _, required in
	{
		"WarmupSeconds = 12",
		"BaseSpawnIntervalSeconds = 10",
		"MinimumSpawnIntervalSeconds = 4",
		"BaseSpawnCount = 3",
		"MaximumSpawnCount = 10",
		'Id = "horde.role.screamer"',
		'Id = "horde.role.bloater"',
		'Id = "horde.role.brute"',
	}
do
	assertThat(contains(hordeConfig, required), "horde configuration is missing " .. required)
end

-- The horde config must no longer describe progression rewards it does not own.
for _, forbidden in
	{
		"Upgrades = table.freeze",
		"Loot = table.freeze",
		"UpgradeChoicesPerLevel",
		"MaximumWorldDrops",
	}
do
	assertThat(not contains(hordeConfig, forbidden), "horde config must not own progression rewards: " .. forbidden)
end

-- HordeExperienceService keeps spawning, roles, behaviour, threat, and events.
for _, required in
	{
		"EnemyDirectorService.spawnEnemy",
		"OperativeLifeService.applyAuthoritativeDamage",
		"stateRemote:FireClient",
		"threatValue",
		"spawnHorde",
		"HordeConfig.Pressure.MaximumSpawnCount",
		"HordeConfig.Roles.Screamer.Id",
		"HordeConfig.Roles.Bloater.Id",
		"HordeConfig.Roles.Brute.Id",
	}
do
	assertThat(contains(runtime, required), "server horde runtime is missing " .. required)
end

-- HordeExperienceService must own no progression, upgrade, loot, heal, ammo, or
-- overcharge authority. These tokens encode the duplicate systems that were
-- consolidated into RunProgressionService and EnemyLootService.
for _, forbidden in
	{
		"Humanoid:TakeDamage",
		"clientDamage",
		"clientXp",
		"clientHealth",
		"clientEnemy",
		"ChooseUpgrade",
		"choiceRemote",
		"pendingChoices",
		"generateChoices",
		"applyUpgrade",
		"upgradeStacks",
		"spawnLoot",
		"HordeLoot",
		"grantAmmunition",
		"healPlayer",
		"weaponTier",
		"recoveryCharges",
		"require(script.Parent.RunProgressionService)",
		"RunProgressionService.read",
		"commitReviveCombatState",
		"commitAcceptedTransition",
	}
do
	assertThat(not contains(runtime, forbidden), "server horde runtime must not own progression rewards: " .. forbidden)
end

assertThat(contains(serverBootstrap, "HordeExperienceService.start()"), "server bootstrap must start the horde runtime")

-- HordeHUDController is the single combat HUD.
for _, required in
	{
		"HordeHUDController.start()",
		"CriticalConditionController.start()",
		"ConfirmedHitMarkerController.start()",
	}
do
	assertThat(
		contains(clientBootstrap, required),
		"client bootstrap is missing composed presentation owner " .. required
	)
end
assertThat(
	not contains(clientBootstrap, "RunProgressionHUDController.start()"),
	"the standalone progression HUD must not run alongside the unified combat HUD"
)

-- The unified HUD renders progression from ProgressionNetwork and submits one
-- offered upgrade ID only through ProgressionNetwork.ChooseUpgrade.
for _, required in
	{
		"progressionChooseUpgradeRemote:FireServer(upgradeId)",
		"progressionReadStateRemote:InvokeServer()",
		"progressionStateRemote.OnClientEvent",
		"pendingChoices",
		"LK_P3_CurrentHealth",
		"LK_HUD_LoadedRounds",
		"LK_HUD_Objective",
		"HOSTILES",
		"MASSACRE",
	}
do
	assertThat(contains(hud, required), "unified HUD is missing " .. required)
end

for _, forbidden in
	{
		'network:WaitForChild("ChooseUpgrade")',
		"choiceRemote",
		"DamageResolver",
		"applyAuthoritativeDamage",
		"commitHealthState",
		"TakeDamage",
		"loadedRounds -=",
		"currentHealth = currentHealth -",
	}
do
	assertThat(not contains(hud, forbidden), "HUD must not own gameplay or a second upgrade remote: " .. forbidden)
end

for _, required in
	{
		"payload.didApplyDamage ~= true",
		"model:GetAttribute(lifeAttribute)",
		"Debris:AddItem",
		"addShake(0.035, 0.06)",
		"createBloodPool",
		"createKillText",
	}
do
	assertThat(contains(effects, required), "horde reward effects are missing " .. required)
end
for _, forbidden in
	{
		"ParticleEmitter",
		"impactWorldPosition",
		"FireServer",
		"DamageResolver",
		"commitHealthState",
		"applyAuthoritativeDamage",
		"TakeDamage",
	}
do
	assertThat(not contains(effects, forbidden), "horde effects must defer impact authority: " .. forbidden)
end

assertThat(not contains(weapon, "TemporaryCombatPresentation"), "old temporary combat overlay must be removed")
assertThat(not contains(life, "TemporaryP3Validation"), "old temporary life overlay must be removed")
assertThat(not contains(mission, "TemporaryMissionUI"), "old temporary mission overlay must be removed")

print("Horde vertical slice single-source-of-truth ownership, bounds, and unified HUD audit passed")
