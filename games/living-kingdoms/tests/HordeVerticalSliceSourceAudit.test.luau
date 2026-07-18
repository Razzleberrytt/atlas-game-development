--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
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

for _, required in {
	'"HordeNetwork"',
	'"State"',
	'"ChooseUpgrade"',
} do
	assertThat(string.find(project, required, 1, true) ~= nil, "project mapping is missing " .. required)
end

for _, required in {
	"MaximumConcurrentPerOperative = 24",
	"AbsoluteMaximumConcurrent = 96",
	"EvaluationIntervalSeconds = 0.1",
	"MaximumLineOfSightRaycastsPerEvaluation = 8",
} do
	assertThat(string.find(enemyConfig, required, 1, true) ~= nil, "horde enemy bounds are missing " .. required)
end

for _, required in {
	"BaseSpawnIntervalSeconds = 7",
	"MinimumSpawnIntervalSeconds = 2.4",
	"MaximumSpawnCount = 16",
	"UpgradeChoicesPerLevel = 3",
	"MaximumWorldDrops = 32",
	'Id = "horde.role.screamer"',
	'Id = "horde.role.bloater"',
	'Id = "horde.role.brute"',
} do
	assertThat(string.find(hordeConfig, required, 1, true) ~= nil, "horde configuration is missing " .. required)
end

for _, required in {
	"EnemyDirectorService.spawnEnemy",
	"RunProgressionService.readSafeSnapshot",
	"EnemyDirectorService.commitHealthState",
	"OperativeLifeService.applyAuthoritativeDamage",
	"OperativeLifeService.commitAcceptedTransition",
	"OperativeCombatRuntimeService.commitReviveCombatState",
	"choiceRemote.OnServerEvent:Connect(onChoice)",
	"table.find(state.pendingChoices, upgradeId)",
	"HordeConfig.Loot.MaximumWorldDrops",
	"HordeConfig.Pressure.MaximumSpawnCount",
} do
	assertThat(string.find(runtime, required, 1, true) ~= nil, "server horde runtime is missing " .. required)
end

for _, forbidden in {
	"Humanoid:TakeDamage",
	"OnClientEvent:Connect(function(player",
	"clientDamage",
	"clientXp",
	"clientHealth",
	"clientEnemy",
	"local function addXp",
} do
	assertThat(not string.find(runtime, forbidden, 1, true), "server horde runtime contains forbidden pattern " .. forbidden)
end

assertThat(
	string.find(serverBootstrap, "HordeExperienceService.start()", 1, true) ~= nil,
	"server bootstrap must start the horde runtime"
)
for _, required in {
	"EnemyImpactPresentationController.start()",
	"HordeEffectsController.start()",
	"HordeHUDController.start()",
} do
	assertThat(
		string.find(clientBootstrap, required, 1, true) ~= nil,
		"client bootstrap is missing composed presentation owner " .. required
	)
end

for _, required in {
	"choiceRemote:FireServer(upgradeId)",
	"pendingChoices",
	"LK_P3_CurrentHealth",
	"LK_HUD_LoadedRounds",
	"LK_HUD_Objective",
	"HOSTILES",
	"MASSACRE",
} do
	assertThat(string.find(hud, required, 1, true) ~= nil, "unified HUD is missing " .. required)
end

for _, forbidden in {
	"DamageResolver",
	"applyAuthoritativeDamage",
	"commitHealthState",
	"TakeDamage",
	"loadedRounds -=",
	"currentHealth = currentHealth -",
} do
	assertThat(not string.find(hud, forbidden, 1, true), "HUD must not own gameplay through " .. forbidden)
end

for _, required in {
	"payload.didApplyDamage ~= true",
	"model:GetAttribute(lifeAttribute)",
	"Debris:AddItem",
	"addShake(0.035, 0.06)",
	"createBloodPool",
	"createKillText",
} do
	assertThat(string.find(effects, required, 1, true) ~= nil, "horde reward effects are missing " .. required)
end
for _, forbidden in {
	"ParticleEmitter",
	"impactWorldPosition",
	"FireServer",
	"DamageResolver",
	"commitHealthState",
	"applyAuthoritativeDamage",
	"TakeDamage",
} do
	assertThat(not string.find(effects, forbidden, 1, true), "horde effects must defer impact authority: " .. forbidden)
end

assertThat(
	not string.find(weapon, "TemporaryCombatPresentation", 1, true),
	"old temporary combat overlay must be removed"
)
assertThat(not string.find(life, "TemporaryP3Validation", 1, true), "old temporary life overlay must be removed")
assertThat(not string.find(mission, "TemporaryMissionUI", 1, true), "old temporary mission overlay must be removed")

print("Horde vertical slice authority, bounds, and composed presentation audit passed")
