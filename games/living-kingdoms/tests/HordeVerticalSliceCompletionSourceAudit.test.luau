--!strict

--[[
	Completion-level source audit for the high-ROI horde/run-reward vertical slice.
	The deeper subsystem fixtures own individual mechanics; this test locks the
	cross-system composition that makes the loop pressure -> progress -> choice ->
	recovery -> consequence while preserving server authority.
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

local horde = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local progressionConfig = fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local recoveryLoot = fs.readFile("games/living-kingdoms/src/server/Systems/RecoveryLootService.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local rewardDisposition =
	fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionRewardDispositionResolver.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")

-- Pressure and escalation remain delegated through the canonical enemy owner,
-- with the recovery deadline consumed by the scheduled horde lane.
for _, required in
	{
		"EnemyDirectorService.spawnEnemy",
		"HordeConfig.Roles.Screamer.Id",
		"HordeConfig.Roles.Bloater.Id",
		"HordeConfig.Roles.Brute.Id",
		"EnemyDirectorService.readPressureState()",
		"recoveryWindowEndServerTimestamp",
	}
do
	assertThat(contains(horde, required), "horde pressure/recovery composition is missing " .. required)
end

-- Confirmed deaths advance bounded server-owned run progression. Every level
-- offer is exactly three choices, and clients can select only from the IDs the
-- server generated and then committed through the run-build owner.
for _, required in
	{
		"FieldXpPerConfirmedEnemyDeath = 20",
		"BaseXpToLevel = 80",
		"UpgradeChoiceCount = 3",
	}
do
	assertThat(contains(progressionConfig, required), "run progression pacing is missing " .. required)
end
for _, required in
	{
		"awardConfirmedEnemyDeath(model)",
		"RunUpgradeResolver.generateChoices(upgradeStacks, offerSequence, squadKills, squadWeaponIds)",
		"RunUpgradeResolver.applyChoice(readUpgradeStacks(), pendingChoiceIds, selectedUpgradeId)",
		"RunBuildService.commitSquadUpgradeStacks(",
		"choiceConnection = chooseUpgradeRemote.OnServerEvent:Connect(onChooseUpgrade)",
	}
do
	assertThat(contains(progression, required), "server-owned progression/choice seam is missing " .. required)
end

-- Immediate recovery value is created from confirmed server-observed deaths.
-- Collection revalidates proximity and commits ammo, healing, or Field XP only
-- through their existing authoritative owners.
for _, required in
	{
		"local resolution = LootDropResolver.resolve({",
		"initialScanComplete",
		"lifeState == DeadLifeStateId",
		"hitSequence > 0",
		"horizontalDistance(position, entry.worldPosition) > LootDropConfig.PickupMaximumDistanceStuds",
		"OperativeCombatRuntimeService.commitReviveCombatState(",
		"OperativeLifeService.applyAuthoritativeHealing(",
		"RunProgressionService.awardFieldIntel(",
		"ProximityPromptService.PromptTriggered:Connect(function(prompt, player)",
	}
do
	assertThat(contains(recoveryLoot, required), "server-owned recovery-loot seam is missing " .. required)
end

-- The authored objective remains a server-sampled purpose for the combat loop;
-- no parallel objective state machine is introduced by the horde slice.
for _, required in
	{
		"ObjectiveChainResolver",
		"SquadFailureService",
		"activeObjectiveId",
		"extractionUnlocked",
	}
do
	assertThat(contains(mission, required), "mission-purpose seam is missing " .. required)
end

-- Run rewards have a real terminal consequence: completed runs bank value while
-- failure or abandonment forfeits it. In-progress rewards cannot be persisted.
for _, required in
	{
		"OutcomeIds.Completed",
		"RewardDispositionIds.Banked",
		"OutcomeIds.Failed",
		"OutcomeIds.Abandoned",
		"RewardDispositionIds.Forfeited",
		"return Resolver.resolve(outcomeId) == RewardDispositionIds.Banked",
	}
do
	assertThat(contains(rewardDisposition, required), "run reward disposition is missing " .. required)
end

-- The unified HUD exposes the loop's critical state and sends only an offered
-- upgrade ID. Consequential XP/reward/heal/spawn mutations stay off the client.
for _, required in
	{
		"progressionChooseUpgradeRemote:FireServer(upgradeId)",
		"pendingChoices",
		"snapshot.runStats",
		"LK_P3_CurrentHealth",
		"LK_HUD_LoadedRounds",
		"LK_HUD_Objective",
		"HOSTILES",
	}
do
	assertThat(contains(hud, required), "combat HUD completion surface is missing " .. required)
end
for _, forbidden in
	{
		"EnemyDirectorService.spawnEnemy",
		"RunProgressionService.awardFieldIntel",
		"OperativeLifeService.applyAuthoritativeHealing",
		"commitSquadUpgradeStacks",
	}
do
	assertThat(not contains(hud, forbidden), "combat HUD must not own consequential gameplay: " .. forbidden)
end

print("Horde/run-reward vertical slice completion composition and authority audit passed")
