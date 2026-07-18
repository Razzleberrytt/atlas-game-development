--!strict

--[[
	Server-authoritative horde/progression vertical slice. This service composes
	the existing EnemyDirectorService, OperativeLifeService, and combat runtime.
	It never accepts client-authored XP, health, ammunition, enemy, damage, loot,
	or threat values. The only client request is selection of one server-offered
	upgrade ID.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local HordeConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local LifeAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local EnemyLifeStateIds = EnemyPresentationContracts.LifeStateIds
local SpawnSourceIds = EnemyContracts.EnemySpawnSourceIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local LOOT_FOLDER_NAME = "HordeLoot"

local Service = {}

local started = false
local startTimestamp = 0
local spawnSequence = 0
local lootSequence = 0
local revision = 0
local accumulatedSeconds = 0
local publishAccumulatedSeconds = 0
local nextHordeServerTimestamp = 0
local enemyFolder: Folder? = nil
local lootFolder: Folder? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local enemyAddedConnection: RBXScriptConnection? = nil
local enemyRemovedConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local choiceConnection: RBXScriptConnection? = nil
local lifeConnection: { Disconnect: (self: any) -> () }? = nil

local network = ReplicatedStorage:WaitForChild("HordeNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local choiceRemote = network:WaitForChild("ChooseUpgrade") :: RemoteEvent

local roleOrder = {
	HordeConfig.Roles.Basic,
	HordeConfig.Roles.Runner,
	HordeConfig.Roles.Crawler,
	HordeConfig.Roles.Screamer,
	HordeConfig.Roles.Bloater,
	HordeConfig.Roles.Brute,
}

local roleById: { [string]: any } = {}
local totalRoleWeight = 0
for _, role in roleOrder do
	roleById[role.Id] = role
	totalRoleWeight += role.Weight
end

local upgradeById: { [string]: any } = {}
for _, upgrade in HordeConfig.Upgrades do
	upgradeById[upgrade.Id] = upgrade
end

local lootKinds = {
	HordeConfig.Loot.Kinds.Ammo,
	HordeConfig.Loot.Kinds.Medical,
	HordeConfig.Loot.Kinds.Surge,
	HordeConfig.Loot.Kinds.Weapon,
}

local totalLootWeight = 0
for _, kind in lootKinds do
	totalLootWeight += kind.Weight
end

type PlayerState = {
	level: number,
	xp: number,
	kills: number,
	streak: number,
	lastKillServerTimestamp: number,
	pendingChoices: { string },
	unclaimedUpgrades: number,
	upgradeStacks: { [string]: number },
	weaponTier: number,
	recoveryCharges: number,
	surgeUntilServerTimestamp: number,
	lastEventText: string,
	lastEventKind: string,
	lastEventSequence: number,
	lastChoiceServerTimestamp: number,
}

type EnemyRecord = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	roleId: string,
	lifeStateId: string,
	lastHitSequence: number,
	nextSpecialServerTimestamp: number,
	deathHandled: boolean,
}

type LootRecord = {
	part: BasePart,
	kindId: string,
	amount: number,
	expiresAtServerTimestamp: number,
	connection: RBXScriptConnection,
	claimed: boolean,
}

local playerStates: { [Player]: PlayerState } = {}
local enemyRecords: { [Model]: EnemyRecord } = {}
local forcedRoleByEntityId: { [string]: string } = {}
local lootRecords: { [BasePart]: LootRecord } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function finiteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function stableHash(text: string): number
	local hash = 17
	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index) * index) % 2147483647
	end
	return hash
end

local function colorFromTuple(tuple): Color3
	return Color3.fromRGB(tuple[1], tuple[2], tuple[3])
end

local function xpForLevel(level: number): number
	return math.max(1, math.floor(HordeConfig.Progression.BaseXpToLevel * (HordeConfig.Progression.XpGrowthPerLevel ^ (level - 1))))
end

local function createPlayerState(): PlayerState
	return {
		level = 1,
		xp = 0,
		kills = 0,
		streak = 0,
		lastKillServerTimestamp = -math.huge,
		pendingChoices = {},
		unclaimedUpgrades = 0,
		upgradeStacks = {},
		weaponTier = 0,
		recoveryCharges = 0,
		surgeUntilServerTimestamp = 0,
		lastEventText = "SURVIVE. REGROUP. EXTRACT.",
		lastEventKind = "System",
		lastEventSequence = 1,
		lastChoiceServerTimestamp = -math.huge,
	}
end

local function alivePlayerPosition(player: Player): Vector3?
	if not OperativeLifeService.isAlive(player) then
		return nil
	end
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function copySnapshot(snapshot): any
	return {
		operativeEntityId = snapshot.operativeEntityId,
		lifeStateId = snapshot.lifeStateId,
		healthState = {
			currentHealth = snapshot.healthState.currentHealth,
			maximumHealth = snapshot.healthState.maximumHealth,
		},
		incapacitationState = if snapshot.incapacitationState == nil
			then nil
			else {
				startedAtServerTimestamp = snapshot.incapacitationState.startedAtServerTimestamp,
				bleedOutDeadlineServerTimestamp = snapshot.incapacitationState.bleedOutDeadlineServerTimestamp,
			},
		soloRecoveryState = {
			isEligible = snapshot.soloRecoveryState.isEligible,
			recoveriesUsed = snapshot.soloRecoveryState.recoveriesUsed,
			recoveryStartedAtServerTimestamp = snapshot.soloRecoveryState.recoveryStartedAtServerTimestamp,
			recoveryCompletionServerTimestamp = snapshot.soloRecoveryState.recoveryCompletionServerTimestamp,
		},
		processedDamageEventIds = table.clone(snapshot.processedDamageEventIds),
	}
end

local function healPlayer(player: Player, amount: number, eventText: string): boolean
	local read = OperativeLifeService.read(player)
	if read == nil or read.snapshot.lifeStateId ~= "Alive" or amount <= 0 then
		return false
	end
	local before = read.snapshot
	local after = copySnapshot(before)
	local healed = math.min(after.healthState.maximumHealth, after.healthState.currentHealth + amount)
	if healed <= after.healthState.currentHealth then
		return false
	end
	after.healthState.currentHealth = healed
	local timestamp = now()
	local result = OperativeLifeService.commitAcceptedTransition(player, read.revision, {
		didTransition = true,
		snapshotAfter = after,
		lifeStateIdBefore = before.lifeStateId,
		lifeStateIdAfter = after.lifeStateId,
		transitionServerTimestamp = timestamp,
	})
	if result.didCommit then
		local state = playerStates[player]
		if state ~= nil then
			state.lastEventText = eventText
			state.lastEventKind = "Heal"
			state.lastEventSequence += 1
		end
		return true
	end
	return false
end

local function grantAmmunition(player: Player, rounds: number): number
	if rounds <= 0 then
		return 0
	end
	local read = OperativeCombatRuntimeService.readReviveCombatState(player)
	if read == nil then
		return 0
	end
	local combatState = read.combatState
	local ammunition = combatState.weaponState.ammunition
	local before = ammunition.reserveRounds
	ammunition.reserveRounds = math.min(FirearmConfig.BasicFirearm.MaximumReserveRounds, before + rounds)
	local granted = ammunition.reserveRounds - before
	if granted <= 0 then
		return 0
	end
	if not OperativeCombatRuntimeService.commitReviveCombatState(player, read.generation, combatState, granted) then
		return 0
	end
	return granted
end

local function threatValue(serverTimestamp: number): number
	local elapsedMinutes = math.max(0, serverTimestamp - startTimestamp) / 60
	local totalKills = 0
	for _, state in playerStates do
		totalKills = math.max(totalKills, state.kills)
	end
	return math.clamp(
		elapsedMinutes * HordeConfig.Pressure.ThreatPerMinute
			+ EnemyDirectorService.readActiveEnemyCount() * HordeConfig.Pressure.ThreatPerLivingEnemy
			+ totalKills * HordeConfig.Pressure.ThreatPerKill,
		0,
		HordeConfig.Pressure.ThreatMaximum
	)
end

local function threatLabel(value: number): string
	if value >= 85 then
		return "CATASTROPHIC"
	elseif value >= 65 then
		return "OVERRUN"
	elseif value >= 45 then
		return "SEVERE"
	elseif value >= 25 then
		return "RISING"
	end
	return "HUNTING"
end

local function publicUpgradeChoices(state: PlayerState): { any }
	local result = {}
	for _, upgradeId in state.pendingChoices do
		local definition = upgradeById[upgradeId]
		if definition ~= nil then
			table.insert(result, {
				id = definition.Id,
				name = definition.Name,
				description = definition.Description,
				stacks = state.upgradeStacks[definition.Id] or 0,
				maximumStacks = definition.MaximumStacks,
			})
		end
	end
	return result
end

local function publishPlayer(player: Player, serverTimestamp: number)
	local state = playerStates[player]
	if state == nil then
		return
	end
	local value = threatValue(serverTimestamp)
	stateRemote:FireClient(player, {
		revision = revision,
		level = state.level,
		xp = state.xp,
		xpForNextLevel = xpForLevel(state.level),
		kills = state.kills,
		streak = state.streak,
		streakMultiplier = math.min(
			HordeConfig.Progression.MaximumStreakMultiplier,
			1 + state.streak * HordeConfig.Progression.StreakMultiplierStep
		),
		threat = value,
		threatLabel = threatLabel(value),
		activeEnemies = EnemyDirectorService.readActiveEnemyCount(),
		pendingChoices = publicUpgradeChoices(state),
		weaponTier = state.weaponTier,
		recoveryCharges = state.recoveryCharges,
		surgeUntilServerTimestamp = state.surgeUntilServerTimestamp,
		lastEventText = state.lastEventText,
		lastEventKind = state.lastEventKind,
		lastEventSequence = state.lastEventSequence,
		serverTimestamp = serverTimestamp,
	})
end

local function publishAll(serverTimestamp: number)
	revision += 1
	for player in playerStates do
		publishPlayer(player, serverTimestamp)
	end
end

local function setEvent(player: Player, text: string, kind: string)
	local state = playerStates[player]
	if state == nil then
		return
	end
	state.lastEventText = text
	state.lastEventKind = kind
	state.lastEventSequence += 1
	revision += 1
	publishPlayer(player, now())
end

local function generateChoices(player: Player, state: PlayerState)
	table.clear(state.pendingChoices)
	local candidates = {}
	for _, definition in HordeConfig.Upgrades do
		if (state.upgradeStacks[definition.Id] or 0) < definition.MaximumStacks then
			table.insert(candidates, definition.Id)
		end
	end
	if #candidates == 0 then
		state.unclaimedUpgrades = 0
		return
	end
	local offset = (player.UserId + state.level * 7 + state.unclaimedUpgrades * 13) % #candidates
	local count = math.min(HordeConfig.Progression.UpgradeChoicesPerLevel, #candidates)
	for index = 1, count do
		local candidateIndex = ((offset + index - 1) % #candidates) + 1
		table.insert(state.pendingChoices, candidates[candidateIndex])
	end
end

local function addXp(player: Player, baseAmount: number, isSpecial: boolean)
	local state = playerStates[player]
	if state == nil or baseAmount <= 0 then
		return
	end
	local multiplier = math.min(
		HordeConfig.Progression.MaximumStreakMultiplier,
		1 + state.streak * HordeConfig.Progression.StreakMultiplierStep
	)
	if now() < state.surgeUntilServerTimestamp then
		multiplier *= 1.35
	end
	if isSpecial then
		multiplier *= 1 + (state.upgradeStacks["upgrade.executioner"] or 0) * 0.25
	end
	state.xp += math.max(1, math.floor(baseAmount * multiplier))
	while state.level < HordeConfig.Progression.MaximumLevel and state.xp >= xpForLevel(state.level) do
		state.xp -= xpForLevel(state.level)
		state.level += 1
		state.unclaimedUpgrades += 1
		if #state.pendingChoices == 0 then
			generateChoices(player, state)
		end
		setEvent(player, "LEVEL " .. tostring(state.level) .. " — CHOOSE AN UPGRADE", "LevelUp")
	end
end

local function chooseWeightedRole(seed: number): any
	local roll = seed % totalRoleWeight
	local cursor = 0
	for _, role in roleOrder do
		cursor += role.Weight
		if roll < cursor then
			return role
		end
	end
	return HordeConfig.Roles.Basic
end

local function chooseWeightedLoot(seed: number): any
	local roll = seed % totalLootWeight
	local cursor = 0
	for _, kind in lootKinds do
		cursor += kind.Weight
		if roll < cursor then
			return kind
		end
	end
	return HordeConfig.Loot.Kinds.Ammo
end

local function enemyEntityId(model: Model): string?
	local value = model:GetAttribute("CombatEntityId")
	return if type(value) == "string" and value ~= "" then value else nil
end

local function assignRole(model: Model): any
	local entityId = enemyEntityId(model) or model.Name
	local forced = forcedRoleByEntityId[entityId]
	forcedRoleByEntityId[entityId] = nil
	return if forced ~= nil then roleById[forced] or HordeConfig.Roles.Basic else chooseWeightedRole(stableHash(entityId))
end

local function decorateEnemy(record: EnemyRecord)
	local role = roleById[record.roleId]
	if role == nil then
		return
	end
	record.model.Name = role.DisplayName
	record.model:SetAttribute("HordeRoleId", role.Id)
	record.model:SetAttribute("HordeRoleDisplayName", role.DisplayName)
	record.model:SetAttribute("HordeRewardXp", role.Xp)
	record.model:SetAttribute("HordeThreatValue", role.Threat)
	local highlight = record.model:FindFirstChild("HordeRoleHighlight")
	if highlight == nil then
		local created = Instance.new("Highlight")
		created.Name = "HordeRoleHighlight"
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.FillTransparency = 0.78
		created.OutlineTransparency = 0.2
		created.Adornee = record.model
		created.Parent = record.model
		highlight = created
	end
	if highlight:IsA("Highlight") then
		highlight.FillColor = colorFromTuple(role.HighlightFill)
		highlight.OutlineColor = colorFromTuple(role.HighlightOutline)
	end
	if role.Id == HordeConfig.Roles.Brute.Id then
		pcall(function()
			record.model:ScaleTo(1.35)
		end)
	elseif role.Id == HordeConfig.Roles.Crawler.Id then
		pcall(function()
			record.model:ScaleTo(0.72)
		end)
	elseif role.Id == HordeConfig.Roles.Runner.Id then
		pcall(function()
			record.model:ScaleTo(0.9)
		end)
	end
end

local function trackEnemy(instance: Instance)
	if not instance:IsA("Model") or enemyRecords[instance] ~= nil then
		return
	end
	local root = instance:FindFirstChild("HumanoidRootPart")
	local humanoid = instance:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return
	end
	local role = assignRole(instance)
	local lifeState = instance:GetAttribute(LifeAttribute)
	local hitSequence = instance:GetAttribute(HitSequenceAttribute)
	local record: EnemyRecord = {
		model = instance,
		root = root,
		humanoid = humanoid,
		roleId = role.Id,
		lifeStateId = if type(lifeState) == "string" then lifeState else EnemyLifeStateIds.Alive,
		lastHitSequence = if type(hitSequence) == "number" then hitSequence else 0,
		nextSpecialServerTimestamp = now() + (role.SpecialIntervalSeconds or math.huge),
		deathHandled = false,
	}
	enemyRecords[instance] = record
	decorateEnemy(record)
end

local function untrackEnemy(instance: Instance)
	if instance:IsA("Model") then
		enemyRecords[instance] = nil
	end
end

local function nextEntityId(prefix: string, serverTimestamp: number): string
	spawnSequence += 1
	return string.format("horde.%s:%d:%d", prefix, math.floor(serverTimestamp * 1000), spawnSequence)
end

local function spawnRoleAt(roleId: string, position: Vector3, prefix: string): boolean
	local role = roleById[roleId] or HordeConfig.Roles.Basic
	local serverTimestamp = now()
	local entityId = nextEntityId(prefix, serverTimestamp)
	forcedRoleByEntityId[entityId] = role.Id
	local halfExtent = WorldFoundationConfig.PlayableHalfExtentStuds - 4
	local result = EnemyDirectorService.spawnEnemy({
		entityId = entityId,
		archetypeId = EnemyContracts.EnemyArchetypeIds.ExclusionWalker,
		spawnSourceId = SpawnSourceIds.RoamingPressure,
		displayName = role.DisplayName,
		position = {
			x = math.clamp(position.X, -halfExtent, halfExtent),
			y = position.Y,
			z = math.clamp(position.Z, -halfExtent, halfExtent),
		},
	})
	if not result.didSpawn then
		forcedRoleByEntityId[entityId] = nil
	end
	return result.didSpawn
end

local function spawnReinforcements(origin: Vector3, count: number, prefix: string)
	for index = 1, count do
		local angle = (spawnSequence + index) * 2.399963
		local distance = 14 + (index % 4) * 4
		spawnRoleAt(
			if index % 4 == 0 then HordeConfig.Roles.Runner.Id else HordeConfig.Roles.Basic.Id,
			origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
			prefix
		)
	end
end

local function maximumWeaponTier(): number
	local result = 0
	for _, state in playerStates do
		result = math.max(result, state.weaponTier)
	end
	return result
end

local function applyOverchargeDamage(record: EnemyRecord, observedHitSequence: number, serverTimestamp: number)
	local weaponTier = maximumWeaponTier()
	if weaponTier <= 0 then
		return
	end
	local entityId = enemyEntityId(record.model)
	if entityId == nil then
		return
	end
	local read = EnemyDirectorService.readHealthState(entityId)
	if read == nil or not read.isAlive then
		return
	end
	local after = {
		entityId = read.healthState.entityId,
		currentHealth = math.max(0, read.healthState.currentHealth - weaponTier * 2),
		processedShotIds = table.clone(read.healthState.processedShotIds),
	}
	if after.currentHealth >= read.healthState.currentHealth then
		return
	end
	EnemyDirectorService.commitHealthState(entityId, read.revision, after, serverTimestamp)
	local updated = record.model:GetAttribute(HitSequenceAttribute)
	record.lastHitSequence = if type(updated) == "number" then updated else observedHitSequence
end

local function damagePlayersInBurst(record: EnemyRecord, role, serverTimestamp: number)
	local radius = role.DeathBurstRadiusStuds
	local damage = role.DeathBurstDamage
	if type(radius) ~= "number" or type(damage) ~= "number" then
		return
	end
	for _, read in OperativeLifeService.readAll() do
		if read.snapshot.lifeStateId ~= "Alive" then
			continue
		end
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		local position = if player == nil then nil else alivePlayerPosition(player)
		if position ~= nil and (position - record.root.Position).Magnitude <= radius then
			OperativeLifeService.applyAuthoritativeDamage(read.operativeEntityId, read.revision, {
				damageEventId = string.format("horde-bloater:%s:%d", enemyEntityId(record.model) or "unknown", math.floor(serverTimestamp * 1000)),
				sourceEntityId = enemyEntityId(record.model) or "horde.bloater",
				targetEntityId = read.operativeEntityId,
				damageAmount = damage,
				serverTimestamp = serverTimestamp,
			})
		end
	end
end

local function lootColor(kindId: string): Color3
	if kindId == HordeConfig.Loot.Kinds.Ammo.Id then
		return Color3.fromRGB(232, 179, 66)
	elseif kindId == HordeConfig.Loot.Kinds.Medical.Id then
		return Color3.fromRGB(96, 222, 130)
	elseif kindId == HordeConfig.Loot.Kinds.Surge.Id then
		return Color3.fromRGB(89, 174, 255)
	end
	return Color3.fromRGB(205, 91, 255)
end

local function worldLootCount(): number
	local count = 0
	for _ in lootRecords do
		count += 1
	end
	return count
end

local function collectLoot(player: Player, part: BasePart)
	local record = lootRecords[part]
	if record == nil or record.claimed or not OperativeLifeService.isCombatAllowed(player) then
		return
	end
	local playerPosition = alivePlayerPosition(player)
	if playerPosition == nil or (playerPosition - part.Position).Magnitude > HordeConfig.Loot.InteractionDistanceStuds + 2 then
		return
	end
	record.claimed = true
	local state = playerStates[player]
	if state == nil then
		return
	end
	if record.kindId == HordeConfig.Loot.Kinds.Ammo.Id then
		local granted = grantAmmunition(player, record.amount + state.weaponTier * 4)
		setEvent(player, "+" .. tostring(granted) .. " AMMUNITION", "Loot")
	elseif record.kindId == HordeConfig.Loot.Kinds.Medical.Id then
		local bonus = (state.upgradeStacks["upgrade.trauma_kit"] or 0) * 4
		healPlayer(player, record.amount + bonus, "TRAUMA GEL APPLIED")
	elseif record.kindId == HordeConfig.Loot.Kinds.Surge.Id then
		state.surgeUntilServerTimestamp = now() + HordeConfig.Loot.Kinds.Surge.DurationSeconds
		healPlayer(player, 8, "ADRENAL SURGE — XP AMPLIFIED")
	else
		state.weaponTier = math.min(8, state.weaponTier + record.amount)
		setEvent(player, "WEAPON OVERCHARGE TIER " .. tostring(state.weaponTier), "Weapon")
	end
	record.connection:Disconnect()
	lootRecords[part] = nil
	part:Destroy()
end

local function spawnLoot(position: Vector3, seed: number, ownerState: PlayerState)
	if worldLootCount() >= HordeConfig.Loot.MaximumWorldDrops then
		return
	end
	local chance = math.min(0.8, HordeConfig.Loot.BaseDropChance + (ownerState.upgradeStacks["upgrade.scavenger"] or 0) * 0.12)
	if (seed % 1000) / 1000 > chance then
		return
	end
	local folder = lootFolder
	if folder == nil then
		return
	end
	local kind = chooseWeightedLoot(seed // 7)
	lootSequence += 1
	local part = Instance.new("Part")
	part.Name = "HordeLoot_" .. tostring(lootSequence)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.7, 1.7, 1.7)
	part.Position = position + Vector3.new(0, 1.5, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = lootColor(kind.Id)
	part:SetAttribute("HordeLootKindId", kind.Id)
	part.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Collect"
	prompt.ActionText = "TAKE"
	prompt.ObjectText = kind.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HordeConfig.Loot.InteractionDistanceStuds
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	local connection = prompt.Triggered:Connect(function(player)
		collectLoot(player, part)
	end)
	lootRecords[part] = {
		part = part,
		kindId = kind.Id,
		amount = kind.Amount or 0,
		expiresAtServerTimestamp = now() + HordeConfig.Loot.LifetimeSeconds,
		connection = connection,
		claimed = false,
	}
end

local function handleEnemyDeath(record: EnemyRecord, serverTimestamp: number)
	if record.deathHandled then
		return
	end
	record.deathHandled = true
	local role = roleById[record.roleId] or HordeConfig.Roles.Basic
	local isSpecial = role.Id ~= HordeConfig.Roles.Basic.Id and role.Id ~= HordeConfig.Roles.Runner.Id
	local seed = stableHash(enemyEntityId(record.model) or record.model.Name)
	for player, state in playerStates do
		if serverTimestamp - state.lastKillServerTimestamp <= HordeConfig.Progression.KillStreakWindowSeconds then
			state.streak += 1
		else
			state.streak = 1
		end
		state.lastKillServerTimestamp = serverTimestamp
		state.kills += 1
		addXp(player, role.Xp, isSpecial)
		local bloodlustStacks = state.upgradeStacks["upgrade.bloodlust"] or 0
		if bloodlustStacks > 0 and state.kills % 8 == 0 then
			healPlayer(player, 6 * bloodlustStacks, "BLOODLUST RESTORED HEALTH")
		end
		local ammoStacks = state.upgradeStacks["upgrade.ammo_scrounger"] or 0
		if ammoStacks > 0 and state.kills % 10 == 0 then
			local granted = grantAmmunition(player, 8 + ammoStacks * 4)
			if granted > 0 then
				setEvent(player, "SCROUNGED +" .. tostring(granted) .. " AMMO", "Loot")
			end
		end
		spawnLoot(record.root.Position, seed + player.UserId, state)
	end
	if role.Id == HordeConfig.Roles.Bloater.Id then
		damagePlayersInBurst(record, role, serverTimestamp)
		record.model:SetAttribute("HordeDeathBurstSequence", serverTimestamp)
	elseif role.Id == HordeConfig.Roles.Brute.Id then
		local entityId = enemyEntityId(record.model) or ""
		if not string.find(entityId, "phase2", 1, true) then
			spawnRoleAt(HordeConfig.Roles.Brute.Id, record.root.Position, "brute-phase2")
		end
	end
end

local function processEnemy(record: EnemyRecord, serverTimestamp: number)
	if record.model.Parent == nil then
		return
	end
	local role = roleById[record.roleId] or HordeConfig.Roles.Basic
	local lifeState = record.model:GetAttribute(LifeAttribute)
	if type(lifeState) == "string" and lifeState ~= record.lifeStateId then
		record.lifeStateId = lifeState
		if lifeState == EnemyLifeStateIds.Dead then
			handleEnemyDeath(record, serverTimestamp)
		end
	end
	if record.lifeStateId == EnemyLifeStateIds.Dead then
		return
	end
	record.humanoid.WalkSpeed = role.SpeedFloor
	local hitSequence = record.model:GetAttribute(HitSequenceAttribute)
	if type(hitSequence) == "number" and hitSequence > record.lastHitSequence then
		record.lastHitSequence = hitSequence
		applyOverchargeDamage(record, hitSequence, serverTimestamp)
	end
	if role.Id == HordeConfig.Roles.Screamer.Id and serverTimestamp >= record.nextSpecialServerTimestamp then
		record.nextSpecialServerTimestamp = serverTimestamp + role.SpecialIntervalSeconds
		record.model:SetAttribute("HordeScreamSequence", serverTimestamp)
		spawnReinforcements(record.root.Position, role.ReinforcementCount, "scream")
	end
end

local function currentSpawnInterval(serverTimestamp: number): number
	local value = threatValue(serverTimestamp)
	local fraction = value / HordeConfig.Pressure.ThreatMaximum
	return HordeConfig.Pressure.BaseSpawnIntervalSeconds
		- fraction * (HordeConfig.Pressure.BaseSpawnIntervalSeconds - HordeConfig.Pressure.MinimumSpawnIntervalSeconds)
end

local function spawnHorde(serverTimestamp: number)
	local anchors = {}
	for player in playerStates do
		local position = alivePlayerPosition(player)
		if position ~= nil then
			table.insert(anchors, position)
		end
	end
	if #anchors == 0 then
		return
	end
	local value = threatValue(serverTimestamp)
	local count = math.clamp(
		HordeConfig.Pressure.BaseSpawnCount + math.floor(value / 12),
		HordeConfig.Pressure.BaseSpawnCount,
		HordeConfig.Pressure.MaximumSpawnCount
	)
	for index = 1, count do
		local anchor = anchors[((spawnSequence + index - 1) % #anchors) + 1]
		local seed = spawnSequence * 37 + index * 97 + math.floor(serverTimestamp)
		local angle = seed * 2.399963
		local fraction = (seed % 11) / 11
		local distance = HordeConfig.Pressure.SpawnRingMinimumStuds
			+ fraction * (HordeConfig.Pressure.SpawnRingMaximumStuds - HordeConfig.Pressure.SpawnRingMinimumStuds)
		local role = chooseWeightedRole(seed)
		spawnRoleAt(role.Id, anchor + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance), "wave")
	end
	for player in playerStates do
		setEvent(player, "HORDE INBOUND — " .. tostring(count) .. " CONTACTS", "Threat")
	end
end

local function cleanupExpiredLoot(serverTimestamp: number)
	local expired = {}
	for part, record in lootRecords do
		if part.Parent == nil or serverTimestamp >= record.expiresAtServerTimestamp then
			table.insert(expired, part)
		end
	end
	for _, part in expired do
		local record = lootRecords[part]
		if record ~= nil then
			record.connection:Disconnect()
			lootRecords[part] = nil
			if part.Parent ~= nil then
				part:Destroy()
			end
		end
	end
end

local function applyUpgrade(player: Player, state: PlayerState, upgradeId: string)
	local definition = upgradeById[upgradeId]
	if definition == nil then
		return
	end
	local stacks = state.upgradeStacks[upgradeId] or 0
	if stacks >= definition.MaximumStacks then
		return
	end
	state.upgradeStacks[upgradeId] = stacks + 1
	if upgradeId == "upgrade.trauma_kit" then
		healPlayer(player, 20, "TRAUMA KIT RESTORED HEALTH")
	elseif upgradeId == "upgrade.second_wind" then
		state.recoveryCharges += 1
	end
	setEvent(player, string.upper(definition.Name) .. " ACQUIRED", "Upgrade")
end

local function onChoice(player: Player, upgradeId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(upgradeId) ~= "string" then
		return
	end
	local state = playerStates[player]
	if state == nil or #state.pendingChoices == 0 or now() - state.lastChoiceServerTimestamp < 0.25 then
		return
	end
	if table.find(state.pendingChoices, upgradeId) == nil then
		return
	end
	state.lastChoiceServerTimestamp = now()
	applyUpgrade(player, state, upgradeId)
	state.unclaimedUpgrades = math.max(0, state.unclaimedUpgrades - 1)
	table.clear(state.pendingChoices)
	if state.unclaimedUpgrades > 0 then
		generateChoices(player, state)
	end
	revision += 1
	publishPlayer(player, now())
end

local function onLifeChanged(player: Player, snapshot, revisionBefore: number)
	local state = playerStates[player]
	if state == nil or snapshot.lifeStateId ~= "Incapacitated" or state.recoveryCharges <= 0 then
		return
	end
	state.recoveryCharges -= 1
	local after = copySnapshot(snapshot)
	after.lifeStateId = "Alive"
	after.healthState.currentHealth = math.max(35, math.floor(after.healthState.maximumHealth * 0.35))
	after.incapacitationState = nil
	after.soloRecoveryState.recoveryStartedAtServerTimestamp = nil
	after.soloRecoveryState.recoveryCompletionServerTimestamp = nil
	local timestamp = now()
	local result = OperativeLifeService.commitAcceptedTransition(player, revisionBefore, {
		didTransition = true,
		snapshotAfter = after,
		lifeStateIdBefore = "Incapacitated",
		lifeStateIdAfter = "Alive",
		transitionServerTimestamp = timestamp,
	})
	if result.didCommit then
		setEvent(player, "SECOND WIND — BACK ON YOUR FEET", "Recovery")
	else
		state.recoveryCharges += 1
	end
end

local function addPlayer(player: Player)
	playerStates[player] = createPlayerState()
	task.defer(function()
		if started and player.Parent == Players then
			publishPlayer(player, now())
		end
	end)
end

local function removePlayer(player: Player)
	playerStates[player] = nil
end

local function evaluate(serverTimestamp: number)
	for _, record in enemyRecords do
		processEnemy(record, serverTimestamp)
	end
	cleanupExpiredLoot(serverTimestamp)
	if serverTimestamp >= nextHordeServerTimestamp then
		spawnHorde(serverTimestamp)
		nextHordeServerTimestamp = serverTimestamp + currentSpawnInterval(serverTimestamp)
	end
	for _, state in playerStates do
		if serverTimestamp - state.lastKillServerTimestamp > HordeConfig.Progression.KillStreakWindowSeconds then
			state.streak = 0
		end
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	startTimestamp = now()
	nextHordeServerTimestamp = startTimestamp + HordeConfig.Pressure.WarmupSeconds
	local existingLoot = Workspace:FindFirstChild(LOOT_FOLDER_NAME)
	if existingLoot ~= nil then
		existingLoot:Destroy()
	end
	local createdLoot = Instance.new("Folder")
	createdLoot.Name = LOOT_FOLDER_NAME
	createdLoot.Parent = Workspace
	lootFolder = createdLoot
	local foundEnemyFolder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if foundEnemyFolder == nil then
		foundEnemyFolder = Workspace:WaitForChild(ENEMY_FOLDER_NAME)
	end
	assert(foundEnemyFolder:IsA("Folder"), "EnemyEntities must be a Folder")
	enemyFolder = foundEnemyFolder
	for _, child in foundEnemyFolder:GetChildren() do
		trackEnemy(child)
	end
	enemyAddedConnection = foundEnemyFolder.ChildAdded:Connect(trackEnemy)
	enemyRemovedConnection = foundEnemyFolder.ChildRemoved:Connect(untrackEnemy)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	choiceConnection = choiceRemote.OnServerEvent:Connect(onChoice)
	lifeConnection = OperativeLifeService.subscribe(onLifeChanged)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		publishAccumulatedSeconds += deltaTime
		if accumulatedSeconds >= HordeConfig.Pressure.EvaluationIntervalSeconds then
			accumulatedSeconds = 0
			evaluate(now())
		end
		if publishAccumulatedSeconds >= HordeConfig.Pressure.StatePublishIntervalSeconds then
			publishAccumulatedSeconds = 0
			publishAll(now())
		end
	end)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	for _, connection in {
		heartbeatConnection,
		enemyAddedConnection,
		enemyRemovedConnection,
		playerAddedConnection,
		playerRemovingConnection,
		choiceConnection,
	} do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	enemyAddedConnection = nil
	enemyRemovedConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	choiceConnection = nil
	if lifeConnection ~= nil then
		lifeConnection:Disconnect()
		lifeConnection = nil
	end
	for part, record in lootRecords do
		record.connection:Disconnect()
		if part.Parent ~= nil then
			part:Destroy()
		end
	end
	table.clear(lootRecords)
	table.clear(enemyRecords)
	table.clear(forcedRoleByEntityId)
	table.clear(playerStates)
	local folder = lootFolder
	if folder ~= nil then
		folder:Destroy()
		lootFolder = nil
	end
	enemyFolder = nil
	accumulatedSeconds = 0
	publishAccumulatedSeconds = 0
	spawnSequence = 0
	lootSequence = 0
	revision = 0
end

return Service
