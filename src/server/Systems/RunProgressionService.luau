--!strict

--[[
	HROI-0105 server-owned squad Field XP and run upgrades. One bounded heartbeat
	scan observes existing server-authored enemy death state and awards shared XP
	exactly once. Level thresholds create three server-generated upgrade choices;
	the first valid squad selection applies one bounded run-only modifier.

	Clients may submit only one offered upgrade ID. They cannot submit kills, XP,
	levels, stacks, modifier values, reward amounts, or combat outcomes. Applied
	combat modifiers are published as server-owned attributes on the progression
	network and reset whenever this service starts or stops.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)
local RunProgressionResolver = require(ReplicatedStorage.Shared.Progression.RunProgressionResolver)
local RunUpgradeResolver = require(ReplicatedStorage.Shared.Progression.RunUpgradeResolver)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local RunBuildService = require(script.Parent.RunBuildService)
local RelicRewardSourceConfig = require(ReplicatedStorage.Shared.Config.RelicRewardSourceConfig)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)

local RewardSourceIds = RunRpgContracts.RewardSourceIds

local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local EliteBonusFieldXpAttribute = EnemyPresentationContracts.AttributeNames.EliteBonusFieldXp
local EliteAffixIdAttribute = EnemyPresentationContracts.AttributeNames.EliteAffixId
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead

local ENEMY_FOLDER_NAME = "EnemyEntities"

export type PublicUpgradeChoice = {
	id: string,
	name: string,
	description: string,
	statPreview: string,
	stacks: number,
	maximumStacks: number,
}

export type PublicActiveUpgrade = {
	id: string,
	name: string,
	stacks: number,
}

export type PublicRunStats = {
	damageBonusPercent: number,
	fireRateBonusPercent: number,
	ammoConservationPercent: number,
	damageReductionPercent: number,
	reloadSpeedBonusPercent: number,
	xpBonusPercent: number,
}

export type SafeRunProgressionSnapshot = {
	version: string,
	revision: number,
	level: number,
	xp: number,
	xpForNextLevel: number,
	totalXp: number,
	squadKills: number,
	lastGainAmount: number,
	lastGainSequence: number,
	levelsGainedLastAward: number,
	pendingChoices: { PublicUpgradeChoice },
	activeUpgrades: { PublicActiveUpgrade },
	runStats: PublicRunStats,
	unclaimedUpgradeChoices: number,
	selectionSequence: number,
	lastSelectedUpgradeId: string,
	lastSelectedUpgradeName: string,
	lastSelectedUpgradeStack: number,
}

local RunProgressionService = {}

local started = false
local revision = 0
local level = 1
local xp = 0
local totalXp = 0
local squadKills = 0
local eliteKillsSinceReward = 0
local lastGainAmount = 0
local lastGainSequence = 0
local levelsGainedLastAward = 0
local accumulatedSeconds = 0
local initialScanComplete = false
local unclaimedUpgradeChoices = 0
local offerSequence = 0
local selectionSequence = 0
local lastSelectedUpgradeId = ""
local lastSelectedUpgradeName = ""
local lastSelectedUpgradeStack = 0
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local choiceConnection: RBXScriptConnection? = nil
local trackedLifeStates: { [Model]: string } = {}
local pendingChoiceIds: { string } = {}
local lastUpgradeRequestTimestamps: { [Player]: number } = {}
local processedFieldIntelRewardIds: { [string]: boolean } = {}
local fieldIntelRewardOrder: { string } = {}
local MAX_PROCESSED_FIELD_INTEL_REWARDS = 64

local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local chooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent

local function readUpgradeStacks(): RunUpgradeResolver.UpgradeStacks
	return RunBuildService.readSquadUpgradeStacks()
end

local function roundedPercent(value: number): number
	return math.floor(value * 100 + 0.5)
end

local function bonusPercent(multiplier: number): number
	return roundedPercent(math.max(0, multiplier - 1))
end

local function reductionPercent(multiplier: number): number
	return roundedPercent(math.max(0, 1 - multiplier))
end

local function choiceStatPreview(definition: any, stacks: RunUpgradeResolver.UpgradeStacks): string
	local stacksAfter = table.clone(stacks)
	stacksAfter[definition.Id] = (stacksAfter[definition.Id] or 0) + 1
	local before = RunUpgradeResolver.deriveCombatModifiers(stacks)
	local after = RunUpgradeResolver.deriveCombatModifiers(stacksAfter)
	if definition.DamageMultiplierPerStack ~= nil then
		return string.format(
			"FIREARM DAMAGE  %d%% → %d%%",
			roundedPercent(before.damageMultiplier),
			roundedPercent(after.damageMultiplier)
		)
	elseif definition.CadenceReductionPerStack ~= nil then
		return string.format(
			"SHOT DELAY  %d%% → %d%%",
			roundedPercent(before.cadenceMultiplier),
			roundedPercent(after.cadenceMultiplier)
		)
	elseif definition.AmmoConservationChancePerStack ~= nil then
		return string.format(
			"AMMO SAVED  %d%% → %d%%",
			roundedPercent(before.ammoConservationChance),
			roundedPercent(after.ammoConservationChance)
		)
	elseif definition.CullDamageMultiplierPerStack ~= nil then
		return string.format(
			"EXECUTE DAMAGE  %d%% → %d%%",
			roundedPercent(before.cullDamageMultiplier),
			roundedPercent(after.cullDamageMultiplier)
		)
	elseif definition.IncomingDamageReductionPerStack ~= nil then
		return string.format(
			"DAMAGE REDUCTION  %d%% → %d%%",
			reductionPercent(before.incomingDamageMultiplier),
			reductionPercent(after.incomingDamageMultiplier)
		)
	elseif definition.XpGainMultiplierPerStack ~= nil then
		return string.format(
			"FIELD XP  %d%% → %d%%",
			roundedPercent(before.xpGainMultiplier),
			roundedPercent(after.xpGainMultiplier)
		)
	elseif definition.ReloadDurationReductionPerStack ~= nil then
		return string.format(
			"RELOAD TIME  %d%% → %d%%",
			roundedPercent(before.reloadDurationMultiplier),
			roundedPercent(after.reloadDurationMultiplier)
		)
	elseif definition.PatternDamageMultiplierPerStack ~= nil then
		return string.format(
			"CLEAVE / PIERCE  %d%% → %d%%",
			roundedPercent(before.patternDamageMultiplier),
			roundedPercent(after.patternDamageMultiplier)
		)
	elseif definition.SpecialEnemyDamageMultiplierPerStack ~= nil then
		return string.format(
			"SPECIAL DAMAGE  %d%% → %d%%",
			roundedPercent(before.specialEnemyDamageMultiplier),
			roundedPercent(after.specialEnemyDamageMultiplier)
		)
	elseif definition.MagazineCapacityMultiplierPerStack ~= nil then
		return string.format(
			"MAGAZINE SIZE  %d%% → %d%%",
			roundedPercent(before.magazineCapacityMultiplier),
			roundedPercent(after.magazineCapacityMultiplier)
		)
	elseif definition.LootPickupRadiusBonusStudsPerStack ~= nil then
		return string.format(
			"PICKUP REACH  +%.1f → +%.1f STUDS",
			before.lootPickupRadiusBonusStuds,
			after.lootPickupRadiusBonusStuds
		)
	elseif definition.LastMagazineDamageMultiplierPerStack ~= nil then
		return string.format(
			"LOW-AMMO DAMAGE  %d%% → %d%%",
			roundedPercent(before.lastMagazineDamageMultiplier),
			roundedPercent(after.lastMagazineDamageMultiplier)
		)
	end
	return "RUN POWER INCREASE"
end

local function publicRunStats(): PublicRunStats
	local modifiers = RunUpgradeResolver.deriveCombatModifiers(readUpgradeStacks())
	return table.freeze({
		damageBonusPercent = bonusPercent(modifiers.damageMultiplier),
		fireRateBonusPercent = bonusPercent(1 / modifiers.cadenceMultiplier),
		ammoConservationPercent = roundedPercent(modifiers.ammoConservationChance),
		damageReductionPercent = reductionPercent(modifiers.incomingDamageMultiplier),
		reloadSpeedBonusPercent = bonusPercent(1 / modifiers.reloadDurationMultiplier),
		xpBonusPercent = bonusPercent(modifiers.xpGainMultiplier),
	})
end

local function publicPendingChoices(): { PublicUpgradeChoice }
	local result = {}
	local upgradeStacks = readUpgradeStacks()
	for _, upgradeId in pendingChoiceIds do
		local definition = RunUpgradeResolver.readDefinition(upgradeId)
		if definition ~= nil then
			table.insert(result, {
				id = definition.Id,
				name = definition.Name,
				description = definition.Description,
				statPreview = choiceStatPreview(definition, upgradeStacks),
				stacks = upgradeStacks[definition.Id] or 0,
				maximumStacks = definition.MaximumStacks,
			})
		end
	end
	return result
end

local function publicActiveUpgrades(): { PublicActiveUpgrade }
	local result = {}
	local upgradeStacks = readUpgradeStacks()
	for _, definition in RunProgressionConfig.UpgradeDefinitions do
		local stacks = upgradeStacks[definition.Id] or 0
		if stacks > 0 then
			table.insert(result, {
				id = definition.Id,
				name = definition.Name,
				stacks = stacks,
			})
		end
	end
	return result
end

local function safeSnapshot(): SafeRunProgressionSnapshot
	return table.freeze({
		version = RunProgressionConfig.Version,
		revision = revision,
		level = level,
		xp = xp,
		xpForNextLevel = RunProgressionResolver.xpRequiredForLevel(level),
		totalXp = totalXp,
		squadKills = squadKills,
		lastGainAmount = lastGainAmount,
		lastGainSequence = lastGainSequence,
		levelsGainedLastAward = levelsGainedLastAward,
		pendingChoices = publicPendingChoices(),
		activeUpgrades = publicActiveUpgrades(),
		runStats = publicRunStats(),
		unclaimedUpgradeChoices = unclaimedUpgradeChoices,
		selectionSequence = selectionSequence,
		lastSelectedUpgradeId = lastSelectedUpgradeId,
		lastSelectedUpgradeName = lastSelectedUpgradeName,
		lastSelectedUpgradeStack = lastSelectedUpgradeStack,
	}) :: SafeRunProgressionSnapshot
end

local function syncCombatModifierAttributes()
	local upgradeStacks = readUpgradeStacks()
	local modifiers = RunUpgradeResolver.deriveCombatModifiers(upgradeStacks)
	progressionNetwork:SetAttribute("RunDamageMultiplier", modifiers.damageMultiplier)
	progressionNetwork:SetAttribute("RunCadenceMultiplier", modifiers.cadenceMultiplier)
	progressionNetwork:SetAttribute("RunAmmoConservationChance", modifiers.ammoConservationChance)
	progressionNetwork:SetAttribute("RunCullDamageMultiplier", modifiers.cullDamageMultiplier)
	progressionNetwork:SetAttribute("RunCullHealthThreshold", modifiers.cullHealthThreshold)
	progressionNetwork:SetAttribute("RunIncomingDamageMultiplier", modifiers.incomingDamageMultiplier)
	progressionNetwork:SetAttribute("RunReloadDurationMultiplier", modifiers.reloadDurationMultiplier)
	progressionNetwork:SetAttribute("RunPatternDamageMultiplier", modifiers.patternDamageMultiplier)
	progressionNetwork:SetAttribute("RunSpecialEnemyDamageMultiplier", modifiers.specialEnemyDamageMultiplier)
	progressionNetwork:SetAttribute("RunMagazineCapacityMultiplier", modifiers.magazineCapacityMultiplier)
	progressionNetwork:SetAttribute("RunLootPickupRadiusBonusStuds", modifiers.lootPickupRadiusBonusStuds)
	progressionNetwork:SetAttribute("RunLastMagazineDamageMultiplier", modifiers.lastMagazineDamageMultiplier)
	progressionNetwork:SetAttribute("RunLastMagazineReserveFraction", modifiers.lastMagazineReserveFraction)
end

local function publishAll()
	revision += 1
	stateRemote:FireAllClients(safeSnapshot())
end

local function generatePendingChoices()
	if #pendingChoiceIds > 0 or unclaimedUpgradeChoices <= 0 then
		return
	end
	local upgradeStacks = readUpgradeStacks()
	local squadWeaponIds = {}
	local seenWeaponIds = {}
	for _, player in Players:GetPlayers() do
		local weaponId = player:GetAttribute("LK_EquippedWeaponId")
		if type(weaponId) ~= "string" or not FirearmConfig.isKnownWeaponId(weaponId) then
			weaponId = FirearmConfig.BasicFirearm.WeaponId
		end
		if not seenWeaponIds[weaponId] then
			seenWeaponIds[weaponId] = true
			table.insert(squadWeaponIds, weaponId)
		end
	end
	offerSequence += 1
	local generated = RunUpgradeResolver.generateChoices(upgradeStacks, offerSequence, squadKills, squadWeaponIds)
	table.clear(pendingChoiceIds)
	for _, upgradeId in generated do
		table.insert(pendingChoiceIds, upgradeId)
	end
	if #pendingChoiceIds == 0 then
		unclaimedUpgradeChoices = 0
	end
end

local function applyFieldXpAward(amount: number, countAsKill: boolean): boolean
	local resolution = RunProgressionResolver.applyAward(level, xp, amount)
	if not resolution.didApply then
		return false
	end
	level = resolution.levelAfter
	xp = resolution.xpAfter
	totalXp += amount
	if countAsKill then
		squadKills += 1
	end
	lastGainAmount = amount
	lastGainSequence += 1
	levelsGainedLastAward = resolution.levelsGained
	if resolution.levelsGained > 0 then
		unclaimedUpgradeChoices += resolution.levelsGained
		generatePendingChoices()
	end
	publishAll()
	return true
end

--[[
	RPG-0110: confirmed enemy deaths are the live relic-reward source this owner
	already observes. An elite death opens a choice immediately; ordinary deaths
	accumulate toward a squad-kill milestone so a run with unlucky elite spawns
	still reaches relics. Reward IDs derive from the enemy's own server identity
	and the milestone index, so the existing replay history rejects duplicates.
]]
local function offerRelicRewardsForDeath(model: Model)
	local eliteAffixId = model:GetAttribute(EliteAffixIdAttribute)
	if type(eliteAffixId) == "string" and eliteAffixId ~= "" then
		eliteKillsSinceReward += 1
		if eliteKillsSinceReward >= RelicRewardSourceConfig.EliteKillsPerReward then
			eliteKillsSinceReward = 0
			local entityId = model:GetAttribute("CombatEntityId")
			local eventId = if type(entityId) == "string" and entityId ~= ""
				then "elite:" .. entityId
				else "elite:" .. tostring(squadKills)
			RunBuildService.offerRelicRewardToParticipants(eventId, RewardSourceIds.EliteKill)
		end
	end
	if squadKills > 0 and squadKills % RelicRewardSourceConfig.HordeKillsPerReward == 0 then
		local milestoneIndex = squadKills // RelicRewardSourceConfig.HordeKillsPerReward
		RunBuildService.offerRelicRewardToParticipants("horde:" .. tostring(milestoneIndex), RewardSourceIds.HordeClear)
	end
end

local function awardConfirmedEnemyDeath(model: Model)
	local upgradeStacks = readUpgradeStacks()
	local xpGainMultiplier = RunUpgradeResolver.deriveCombatModifiers(upgradeStacks).xpGainMultiplier
	local eliteBonus = model:GetAttribute(EliteBonusFieldXpAttribute)
	if type(eliteBonus) ~= "number" or eliteBonus ~= eliteBonus or eliteBonus < 0 or eliteBonus > 100 then
		eliteBonus = 0
	end
	local base = RunProgressionConfig.FieldXpPerConfirmedEnemyDeath + math.floor(eliteBonus)
	local corruptionMultiplier = ReplicatedStorage.HordeNetwork:GetAttribute("NightCorruptionXpMultiplier")
	if type(corruptionMultiplier) ~= "number" then
		corruptionMultiplier = 1
	end
	local boosted = math.max(base, math.floor(base * xpGainMultiplier * math.clamp(corruptionMultiplier, 1, 1.5) + 0.5))
	if applyFieldXpAward(boosted, true) then
		offerRelicRewardsForDeath(model)
	end
end

local function isTrackedEnemy(model: Model): boolean
	return model:GetAttribute("EnemyArchetypeId") == EnemyConfig.Walker.ArchetypeId
end

local function readLifeState(model: Model): string?
	local value = model:GetAttribute(LifeStateAttribute)
	return if type(value) == "string" then value else nil
end

local function hasConfirmedHit(model: Model): boolean
	local value = model:GetAttribute(HitSequenceAttribute)
	return type(value) == "number" and value > 0 and value == value
end

local function scanEnemyDeaths()
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil or not folder:IsA("Folder") then
		return
	end

	local seen: { [Model]: boolean } = {}
	local inspectedCount = 0
	for _, child in folder:GetChildren() do
		if inspectedCount >= RunProgressionConfig.MaximumTrackedEnemyModels then
			break
		end
		if not child:IsA("Model") or not isTrackedEnemy(child) then
			continue
		end
		inspectedCount += 1
		local model = child :: Model
		seen[model] = true
		local lifeState = readLifeState(model)
		if lifeState == nil then
			continue
		end
		local previousLifeState = trackedLifeStates[model]
		if previousLifeState == nil then
			trackedLifeStates[model] = lifeState
			if initialScanComplete and lifeState == DeadLifeStateId and hasConfirmedHit(model) then
				awardConfirmedEnemyDeath(model)
			end
		elseif previousLifeState ~= DeadLifeStateId and lifeState == DeadLifeStateId then
			trackedLifeStates[model] = lifeState
			awardConfirmedEnemyDeath(model)
		else
			trackedLifeStates[model] = lifeState
		end
	end

	local staleModels: { Model } = {}
	for model in trackedLifeStates do
		if seen[model] ~= true then
			table.insert(staleModels, model)
		end
	end
	for _, model in staleModels do
		trackedLifeStates[model] = nil
	end
	initialScanComplete = true
end

local function onChooseUpgrade(player: Player, selectedUpgradeId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(selectedUpgradeId) ~= "string" or #pendingChoiceIds == 0 then
		return
	end
	local serverTimestamp = Workspace:GetServerTimeNow()
	local previousRequestTimestamp = lastUpgradeRequestTimestamps[player] or -math.huge
	if serverTimestamp - previousRequestTimestamp < RunProgressionConfig.UpgradeRequestCooldownSeconds then
		return
	end
	lastUpgradeRequestTimestamps[player] = serverTimestamp

	local resolution = RunUpgradeResolver.applyChoice(readUpgradeStacks(), pendingChoiceIds, selectedUpgradeId)
	if not resolution.didApply or resolution.upgradeId == nil then
		return
	end
	local definition = RunUpgradeResolver.readDefinition(resolution.upgradeId)
	if definition == nil then
		return
	end
	local didCommit = RunBuildService.commitSquadUpgradeStacks(
		RunBuildService.readOperationGeneration(),
		string.format("field-upgrade:%d:%d", offerSequence, selectionSequence + 1),
		resolution.stacksAfter
	)
	if not didCommit then
		return
	end

	unclaimedUpgradeChoices = math.max(0, unclaimedUpgradeChoices - 1)
	selectionSequence += 1
	lastSelectedUpgradeId = definition.Id
	lastSelectedUpgradeName = definition.Name
	lastSelectedUpgradeStack = resolution.stackAfter
	table.clear(pendingChoiceIds)
	generatePendingChoices()
	syncCombatModifierAttributes()
	publishAll()
end

function RunProgressionService.awardFieldIntel(rewardId: string, amount: number): boolean
	if
		not started
		or type(rewardId) ~= "string"
		or rewardId == ""
		or #rewardId > 240
		or processedFieldIntelRewardIds[rewardId]
		or type(amount) ~= "number"
		or amount ~= amount
		or amount % 1 ~= 0
		or amount <= 0
		or amount > 100
	then
		return false
	end
	processedFieldIntelRewardIds[rewardId] = true
	table.insert(fieldIntelRewardOrder, rewardId)
	if #fieldIntelRewardOrder > MAX_PROCESSED_FIELD_INTEL_REWARDS then
		local expired = table.remove(fieldIntelRewardOrder, 1)
		if expired ~= nil then
			processedFieldIntelRewardIds[expired] = nil
		end
	end
	return applyFieldXpAward(amount, false)
end

function RunProgressionService.readSafeSnapshot(): SafeRunProgressionSnapshot
	return safeSnapshot()
end

function RunProgressionService.readCombatModifiers(): RunUpgradeResolver.CombatModifiers
	return RunUpgradeResolver.deriveCombatModifiers(readUpgradeStacks())
end

function RunProgressionService.start()
	if started then
		return
	end
	started = true
	revision = 0
	level = 1
	xp = 0
	totalXp = 0
	squadKills = 0
	eliteKillsSinceReward = 0
	lastGainAmount = 0
	lastGainSequence = 0
	levelsGainedLastAward = 0
	accumulatedSeconds = 0
	initialScanComplete = false
	unclaimedUpgradeChoices = 0
	offerSequence = 0
	selectionSequence = 0
	lastSelectedUpgradeId = ""
	lastSelectedUpgradeName = ""
	lastSelectedUpgradeStack = 0
	table.clear(trackedLifeStates)
	table.clear(pendingChoiceIds)
	table.clear(lastUpgradeRequestTimestamps)
	table.clear(processedFieldIntelRewardIds)
	table.clear(fieldIntelRewardOrder)
	syncCombatModifierAttributes()

	readStateRemote.OnServerInvoke = function(_player: Player)
		return safeSnapshot()
	end
	choiceConnection = chooseUpgradeRemote.OnServerEvent:Connect(onChooseUpgrade)
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		stateRemote:FireClient(player, safeSnapshot())
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		lastUpgradeRequestTimestamps[player] = nil
	end)
	scanEnemyDeaths()
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < RunProgressionConfig.EnemyScanIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		scanEnemyDeaths()
	end)
end

function RunProgressionService.stop()
	if not started then
		return
	end
	started = false
	for _, connection in { heartbeatConnection, playerAddedConnection, playerRemovingConnection, choiceConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	choiceConnection = nil
	readStateRemote.OnServerInvoke = nil
	table.clear(trackedLifeStates)
	table.clear(pendingChoiceIds)
	table.clear(lastUpgradeRequestTimestamps)
	table.clear(processedFieldIntelRewardIds)
	table.clear(fieldIntelRewardOrder)
	syncCombatModifierAttributes()
	accumulatedSeconds = 0
	initialScanComplete = false
end

return table.freeze(RunProgressionService)
