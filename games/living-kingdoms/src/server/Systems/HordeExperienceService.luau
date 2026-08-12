--!strict

--[[
	Server-authoritative horde pressure runtime for the vertical slice. This
	service owns only horde spawning and pressure, enemy role assignment and
	behaviour, threat tracking, a non-rewarding massacre-streak display, and the
	horde event feed.

	It deliberately owns no progression: Field XP, levels, upgrades, loot,
	healing, ammunition, and weapon overcharge belong to RunProgressionService
	and EnemyLootService. This service never grants a reward, never mutates
	operative health or ammunition except through authoritative enemy behaviour
	(the Bloater death burst), and accepts no client request of any kind.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local HordeConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local HordeSpecialTelegraphConfig = require(ReplicatedStorage.Shared.Config.HordeSpecialTelegraphConfig)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local HordeRolePresentationService = require(script.Parent.HordeRolePresentationService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local RelicModifierService = require(script.Parent.RelicModifierService)

local LifeAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local EnemyLifeStateIds = EnemyPresentationContracts.LifeStateIds
local SpawnSourceIds = EnemyContracts.EnemySpawnSourceIds
local SpecialAttributeNames = HordeSpecialTelegraphConfig.AttributeNames
local SpecialKindIds = HordeSpecialTelegraphConfig.KindIds
local SpecialStateIds = HordeSpecialTelegraphConfig.StateIds

local ENEMY_FOLDER_NAME = "EnemyEntities"

local Service = {}

local started = false
-- Set once by Service.armPressure() when the player deliberately launches an
-- expedition from the Forward Operations Hub. Never reset by start()/stop() so
-- an already-armed server keeps its existing replay-restart behavior; only the
-- very first safe-arrival window is gated.
local pressureArmed = false
local startTimestamp = 0
local spawnSequence = 0
local revision = 0
local accumulatedSeconds = 0
local publishAccumulatedSeconds = 0
local nextHordeServerTimestamp = 0
local heartbeatConnection: RBXScriptConnection? = nil
local enemyAddedConnection: RBXScriptConnection? = nil
local enemyRemovedConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local network = ReplicatedStorage:WaitForChild("HordeNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent

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

type PlayerState = {
	kills: number,
	streak: number,
	lastKillServerTimestamp: number,
	lastEventText: string,
	lastEventKind: string,
	lastEventSequence: number,
}

type EnemyRecord = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	roleId: string,
	lifeStateId: string,
	lastHitSequence: number,
	nextSpecialServerTimestamp: number,
	specialSequence: number,
	pendingSpecialKindId: string?,
	pendingSpecialCommitServerTimestamp: number?,
	deathHandled: boolean,
}

local playerStates: { [Player]: PlayerState } = {}
local enemyRecords: { [Model]: EnemyRecord } = {}
local forcedRoleByEntityId: { [string]: string } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
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

local function createPlayerState(): PlayerState
	return {
		kills = 0,
		streak = 0,
		lastKillServerTimestamp = -math.huge,
		lastEventText = "SURVIVE. REGROUP. EXTRACT.",
		lastEventKind = "System",
		lastEventSequence = 1,
	}
end

--[[
	This service owns the authoritative kill-chain window. Grave Momentum (RPG-0108)
	extends it per operative through the bounded shared relic modifier, so the
	window is read here rather than assumed constant.
]]
local function streakWindowSeconds(player: Player): number
	return HordeConfig.Streak.KillStreakWindowSeconds + RelicModifierService.read(player).killChainExtensionSeconds
end

local function alivePlayerPosition(player: Player): Vector3?
	if not OperativeLifeService.isAlive(player) then
		return nil
	end
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function threatValue(serverTimestamp: number): number
	local elapsedMinutes = math.max(0, serverTimestamp - startTimestamp) / 60
	local totalKills = 0
	for _, state in playerStates do
		totalKills = math.max(totalKills, state.kills)
	end
	local corruptionBonus = network:GetAttribute("NightCorruptionThreatBonus")
	if type(corruptionBonus) ~= "number" then
		corruptionBonus = 0
	end
	return math.clamp(
		elapsedMinutes * HordeConfig.Pressure.ThreatPerMinute
			+ EnemyDirectorService.readActiveEnemyCount() * HordeConfig.Pressure.ThreatPerLivingEnemy
			+ totalKills * HordeConfig.Pressure.ThreatPerKill
			+ corruptionBonus,
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

local function publishPlayer(player: Player, serverTimestamp: number)
	local state = playerStates[player]
	if state == nil then
		return
	end
	local value = threatValue(serverTimestamp)
	stateRemote:FireClient(player, {
		revision = revision,
		kills = state.kills,
		streak = state.streak,
		streakExpiresServerTimestamp = if state.streak >= 2
			then state.lastKillServerTimestamp + streakWindowSeconds(player)
			else 0,
		threat = value,
		threatLabel = threatLabel(value),
		corruptionTier = network:GetAttribute("NightCorruptionTier") or 0,
		corruptionIntensity = network:GetAttribute("NightCorruptionIntensity") or 0,
		corruptionSequence = network:GetAttribute("NightCorruptionSequence") or 0,
		dayNumber = network:GetAttribute("NightDayNumber") or 1,
		isNight = network:GetAttribute("NightIsActive") == true,
		activeEnemies = EnemyDirectorService.readActiveEnemyCount(),
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

local function enemyEntityId(model: Model): string?
	local value = model:GetAttribute("CombatEntityId")
	return if type(value) == "string" and value ~= "" then value else nil
end

local function assignRole(model: Model): any
	local entityId = enemyEntityId(model) or model.Name
	local forced = forcedRoleByEntityId[entityId]
	forcedRoleByEntityId[entityId] = nil
	return if forced ~= nil
		then roleById[forced] or HordeConfig.Roles.Basic
		else chooseWeightedRole(stableHash(entityId))
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
	record.model:SetAttribute(SpecialAttributeNames.KindId, nil)
	record.model:SetAttribute(SpecialAttributeNames.Sequence, 0)
	record.model:SetAttribute(SpecialAttributeNames.StateId, SpecialStateIds.Idle)
	record.model:SetAttribute(SpecialAttributeNames.CommitServerTimestamp, 0)
	HordeRolePresentationService.applyRolePresentation(record.model)
	local highlight = record.model:FindFirstChild("HordeRoleHighlight")
	if highlight == nil then
		local created = Instance.new("Highlight")
		created.Name = "HordeRoleHighlight"
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		-- Keep role identity in silhouettes, materials, names, and effects. A
		-- persistent full-model highlight exposes invisible collision parts and
		-- makes the horde look like editor wireframes in first person.
		created.FillTransparency = 1
		created.OutlineTransparency = 1
		created.Adornee = record.model
		created.Parent = record.model
		highlight = created
	end
	if highlight:IsA("Highlight") then
		highlight.FillColor = colorFromTuple(role.HighlightFill)
		highlight.OutlineColor = colorFromTuple(role.HighlightOutline)
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
		specialSequence = 0,
		pendingSpecialKindId = nil,
		pendingSpecialCommitServerTimestamp = nil,
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
		isHordePulse = true,
		hordeRoleId = role.Id,
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

local function beginSpecialTelegraph(record: EnemyRecord, kindId: string, serverTimestamp: number): boolean
	if record.pendingSpecialKindId ~= nil then
		return false
	end
	local definition = HordeSpecialTelegraphConfig.get(kindId)
	if definition == nil then
		return false
	end
	record.specialSequence += 1
	record.pendingSpecialKindId = kindId
	record.pendingSpecialCommitServerTimestamp = serverTimestamp + definition.WindupSeconds
	record.model:SetAttribute(SpecialAttributeNames.KindId, kindId)
	record.model:SetAttribute(SpecialAttributeNames.CommitServerTimestamp, record.pendingSpecialCommitServerTimestamp)
	record.model:SetAttribute(SpecialAttributeNames.StateId, SpecialStateIds.Windup)
	record.model:SetAttribute(SpecialAttributeNames.Sequence, record.specialSequence)
	return true
end

local function interruptPendingSpecial(record: EnemyRecord)
	record.pendingSpecialKindId = nil
	record.pendingSpecialCommitServerTimestamp = nil
	record.model:SetAttribute(SpecialAttributeNames.CommitServerTimestamp, 0)
	record.model:SetAttribute(SpecialAttributeNames.StateId, SpecialStateIds.Interrupted)
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
				damageEventId = string.format(
					"horde-bloater:%s:%d",
					enemyEntityId(record.model) or "unknown",
					math.floor(serverTimestamp * 1000)
				),
				sourceEntityId = enemyEntityId(record.model) or "horde.bloater",
				targetEntityId = read.operativeEntityId,
				damageAmount = damage,
				serverTimestamp = serverTimestamp,
			})
		end
	end
end

local function commitPendingSpecial(record: EnemyRecord, role, serverTimestamp: number): boolean
	local kindId = record.pendingSpecialKindId
	local commitServerTimestamp = record.pendingSpecialCommitServerTimestamp
	if kindId == nil or commitServerTimestamp == nil or serverTimestamp < commitServerTimestamp then
		return false
	end
	record.pendingSpecialKindId = nil
	record.pendingSpecialCommitServerTimestamp = nil
	record.model:SetAttribute(SpecialAttributeNames.StateId, SpecialStateIds.Committed)

	if kindId == SpecialKindIds.ScreamerReinforcement then
		if record.lifeStateId == EnemyLifeStateIds.Dead then
			return false
		end
		record.model:SetAttribute("HordeScreamSequence", serverTimestamp)
		spawnReinforcements(record.root.Position, role.ReinforcementCount, "scream")
		record.nextSpecialServerTimestamp = serverTimestamp + role.SpecialIntervalSeconds
	elseif kindId == SpecialKindIds.BloaterDeathBurst then
		damagePlayersInBurst(record, role, serverTimestamp)
		record.model:SetAttribute("HordeDeathBurstSequence", serverTimestamp)
	elseif kindId == SpecialKindIds.BruteSecondPhase then
		spawnRoleAt(HordeConfig.Roles.Brute.Id, record.root.Position, "brute-phase2")
	else
		return false
	end
	return true
end

local function handleEnemyDeath(record: EnemyRecord, serverTimestamp: number)
	if record.deathHandled then
		return
	end
	record.deathHandled = true
	local role = roleById[record.roleId] or HordeConfig.Roles.Basic
	if record.pendingSpecialKindId == SpecialKindIds.ScreamerReinforcement then
		interruptPendingSpecial(record)
	end
	for player, state in playerStates do
		if serverTimestamp - state.lastKillServerTimestamp <= streakWindowSeconds(player) then
			state.streak += 1
		else
			state.streak = 1
		end
		state.lastKillServerTimestamp = serverTimestamp
		state.kills += 1
	end
	if role.Id == HordeConfig.Roles.Bloater.Id then
		beginSpecialTelegraph(record, SpecialKindIds.BloaterDeathBurst, serverTimestamp)
	elseif role.Id == HordeConfig.Roles.Brute.Id then
		local entityId = enemyEntityId(record.model) or ""
		if not string.find(entityId, "phase2", 1, true) then
			beginSpecialTelegraph(record, SpecialKindIds.BruteSecondPhase, serverTimestamp)
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
	commitPendingSpecial(record, role, serverTimestamp)
	if record.lifeStateId == EnemyLifeStateIds.Dead then
		return
	end
	local eliteMovementMultiplier =
		record.model:GetAttribute(EnemyPresentationContracts.AttributeNames.EffectiveMovementSpeedMultiplier)
	if type(eliteMovementMultiplier) ~= "number" or eliteMovementMultiplier ~= eliteMovementMultiplier then
		eliteMovementMultiplier = 1
	end
	local corruptionSpeedMultiplier = network:GetAttribute("NightCorruptionEnemySpeedMultiplier")
	if type(corruptionSpeedMultiplier) ~= "number" then
		corruptionSpeedMultiplier = 1
	end
	record.humanoid.WalkSpeed = role.SpeedFloor
		* math.clamp(eliteMovementMultiplier, 1, 1.35)
		* math.clamp(corruptionSpeedMultiplier, 1, 1.3)
	local hitSequence = record.model:GetAttribute(HitSequenceAttribute)
	if type(hitSequence) == "number" and hitSequence > record.lastHitSequence then
		record.lastHitSequence = hitSequence
	end
	if
		role.Id == HordeConfig.Roles.Screamer.Id
		and record.pendingSpecialKindId == nil
		and serverTimestamp >= record.nextSpecialServerTimestamp
	then
		beginSpecialTelegraph(record, SpecialKindIds.ScreamerReinforcement, serverTimestamp)
	end
end

local function currentSpawnInterval(serverTimestamp: number): number
	local value = threatValue(serverTimestamp)
	local fraction = value / HordeConfig.Pressure.ThreatMaximum
	return HordeConfig.Pressure.BaseSpawnIntervalSeconds
		- fraction
			* (HordeConfig.Pressure.BaseSpawnIntervalSeconds - HordeConfig.Pressure.MinimumSpawnIntervalSeconds)
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
		spawnRoleAt(
			role.Id,
			anchor + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
			"night-corruption"
		)
	end
	for player in playerStates do
		setEvent(player, "THE NIGHT DEEPENS — " .. tostring(count) .. " HUNTERS EMERGE", "Threat")
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
	if not pressureArmed then
		return
	end
	for _, record in enemyRecords do
		processEnemy(record, serverTimestamp)
	end
	local pressureState = EnemyDirectorService.readPressureState()
	local recoveryWindowEndServerTimestamp = pressureState.recoveryWindowEndServerTimestamp
	if recoveryWindowEndServerTimestamp ~= nil and recoveryWindowEndServerTimestamp > serverTimestamp then
		nextHordeServerTimestamp = math.max(nextHordeServerTimestamp, recoveryWindowEndServerTimestamp)
	end
	if serverTimestamp >= nextHordeServerTimestamp then
		spawnHorde(serverTimestamp)
		nextHordeServerTimestamp = serverTimestamp + currentSpawnInterval(serverTimestamp)
	end
	for player, state in playerStates do
		if serverTimestamp - state.lastKillServerTimestamp > streakWindowSeconds(player) then
			state.streak = 0
		end
	end
end

-- Releases horde spawn pressure once the player has deliberately launched an
-- expedition. Safe to call before or after start(); evaluate() itself is the
-- only gated behavior, so ordering between the two calls does not matter.
function Service.armPressure()
	pressureArmed = true
end

function Service.start()
	if started then
		return
	end
	started = true
	startTimestamp = now()
	nextHordeServerTimestamp = startTimestamp + HordeConfig.Pressure.WarmupSeconds
	local foundEnemyFolder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if foundEnemyFolder == nil then
		foundEnemyFolder = Workspace:WaitForChild(ENEMY_FOLDER_NAME)
	end
	assert(foundEnemyFolder:IsA("Folder"), "EnemyEntities must be a Folder")
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
	for _, connection in
		{
			heartbeatConnection,
			enemyAddedConnection,
			enemyRemovedConnection,
			playerAddedConnection,
			playerRemovingConnection,
		}
	do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	enemyAddedConnection = nil
	enemyRemovedConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	table.clear(enemyRecords)
	table.clear(forcedRoleByEntityId)
	table.clear(playerStates)
	accumulatedSeconds = 0
	publishAccumulatedSeconds = 0
	spawnSequence = 0
	revision = 0
end

return Service
