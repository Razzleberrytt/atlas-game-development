--!strict

--[[
	HROI-0106 server-owned immediate loot runtime. One bounded heartbeat observes
	confirmed enemy deaths and expires temporary drops. One global
	ProximityPromptService connection handles collection. Clients provide only the
	Player attached by Roblox to a triggered prompt; drop identity, kind, position,
	distance, eligibility, reward values, mutation, claim state, and cleanup are
	all validated and committed on the server.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AmmunitionContracts = require(ReplicatedStorage.Shared.Combat.AmmunitionScarcityContracts)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local LootDropConfig = require(ReplicatedStorage.Shared.Config.LootDropConfig)
local LootDropContracts = require(ReplicatedStorage.Shared.Loot.LootDropContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local AmmunitionSupplyResolver = require(script.Parent.Parent.Domain.AmmunitionSupplyResolver)
local LootDropResolver = require(script.Parent.LootDropResolver)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local RunProgressionService = require(script.Parent.RunProgressionService)

type LootKindId = LootDropContracts.LootKindId

local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead
local AttributeNames = LootDropContracts.AttributeNames
local KindIds = LootDropContracts.LootKindIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local LOOT_FOLDER_NAME = "LootDrops"

local PRESENTATION = table.freeze({
	[KindIds.AmmunitionBundle] = table.freeze({
		displayName = "AMMUNITION",
		promptText = "+8 ROUNDS",
		color = Color3.fromRGB(232, 159, 48),
		material = Enum.Material.Neon,
	}),
	[KindIds.FieldDressing] = table.freeze({
		displayName = "FIELD DRESSING",
		promptText = "+30 HEALTH",
		color = Color3.fromRGB(198, 49, 57),
		material = Enum.Material.Neon,
	}),
	[KindIds.FieldIntel] = table.freeze({
		displayName = "FIELD INTEL",
		promptText = "+40 FIELD XP",
		color = Color3.fromRGB(58, 194, 205),
		material = Enum.Material.Neon,
	}),
})

type DropEntry = {
	dropId: string,
	kindId: LootKindId,
	part: BasePart,
	prompt: ProximityPrompt,
	worldPosition: Vector3,
	expiresAtServerTimestamp: number,
	claimed: boolean,
}

local LootDropService = {}

local started = false
local accumulatedSeconds = 0
local initialScanComplete = false
local heartbeatConnection: RBXScriptConnection? = nil
local promptTriggeredConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local lootFolder: Folder? = nil
local trackedLifeStates: { [Model]: string } = {}
local processedEnemyEntityIds: { [string]: boolean } = {}
local entriesByDropId: { [string]: DropEntry } = {}
local dropIdByPrompt: { [ProximityPrompt]: string } = {}
local collectingPlayers: { [Player]: boolean } = {}

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function operativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function activeDropCount(): number
	local count = 0
	for _ in entriesByDropId do
		count += 1
	end
	return count
end

local function destroyEntry(entry: DropEntry)
	entriesByDropId[entry.dropId] = nil
	dropIdByPrompt[entry.prompt] = nil
	if entry.part.Parent ~= nil then
		entry.part:Destroy()
	end
end

local function createDropPart(
	dropId: string,
	kindId: LootKindId,
	worldPosition: Vector3,
	spawnedAtServerTimestamp: number,
	expiresAtServerTimestamp: number
): (BasePart, ProximityPrompt)
	local presentation = PRESENTATION[kindId]
	assert(presentation ~= nil, "every loot kind requires server-authored presentation")
	local parent = lootFolder
	assert(parent ~= nil, "loot folder must exist before spawning drops")

	local part = Instance.new("Part")
	part.Name = dropId
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(
		LootDropConfig.Presentation.PartSizeStuds,
		LootDropConfig.Presentation.PartSizeStuds,
		LootDropConfig.Presentation.PartSizeStuds
	)
	part.Position = worldPosition
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Material = presentation.material
	part.Color = presentation.color
	part.CastShadow = false
	part:SetAttribute(AttributeNames.DropId, dropId)
	part:SetAttribute(AttributeNames.KindId, kindId)
	part:SetAttribute(AttributeNames.Available, true)
	part:SetAttribute(AttributeNames.SpawnedAtServerTimestamp, spawnedAtServerTimestamp)
	part:SetAttribute(AttributeNames.ExpiresAtServerTimestamp, expiresAtServerTimestamp)
	part.Parent = parent

	local highlight = Instance.new("Highlight")
	highlight.Name = "LootHighlight"
	highlight.Adornee = part
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = presentation.color
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = Color3.fromRGB(245, 245, 235)
	highlight.OutlineTransparency = 0.15
	highlight.Parent = part

	local light = Instance.new("PointLight")
	light.Name = "LootLight"
	light.Color = presentation.color
	light.Brightness = 1.8
	light.Range = LootDropConfig.Presentation.LightRangeStuds
	light.Shadows = false
	light.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LootLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(190, 48)
	billboard.StudsOffset = Vector3.new(0, 1.55, 0)
	billboard.MaxDistance = LootDropConfig.Presentation.BillboardMaxDistanceStuds
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = Color3.fromRGB(12, 15, 16)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = presentation.displayName .. "\n" .. presentation.promptText
	label.TextColor3 = Color3.fromRGB(245, 246, 238)
	label.TextStrokeColor3 = Color3.fromRGB(7, 8, 9)
	label.TextStrokeTransparency = 0.45
	label.TextSize = 15
	label.TextWrapped = true
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectLootPrompt"
	prompt.ActionText = "Collect"
	prompt.ObjectText = presentation.displayName
	prompt.HoldDuration = LootDropConfig.PromptHoldDurationSeconds
	prompt.MaxActivationDistance = LootDropConfig.PickupMaximumDistanceStuds
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part

	return part, prompt
end

local function spawnDrop(enemyModel: Model, serverTimestamp: number)
	local entityId = enemyModel:GetAttribute("CombatEntityId")
	if type(entityId) ~= "string" or entityId == "" or processedEnemyEntityIds[entityId] then
		return
	end
	processedEnemyEntityIds[entityId] = true
	local root = enemyModel:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local position = root.Position
	local resolution = LootDropResolver.resolve({
		enemyEntityId = entityId,
		worldPosition = { x = position.X, y = position.Y, z = position.Z },
		activeDropCount = activeDropCount(),
		serverTimestamp = serverTimestamp,
	})
	if
		not resolution.didDrop
		or resolution.dropId == nil
		or resolution.kindId == nil
		or resolution.worldPosition == nil
		or resolution.expiresAtServerTimestamp == nil
	then
		return
	end
	local worldPosition =
		Vector3.new(resolution.worldPosition.x, resolution.worldPosition.y, resolution.worldPosition.z)
	local part, prompt = createDropPart(
		resolution.dropId,
		resolution.kindId,
		worldPosition,
		serverTimestamp,
		resolution.expiresAtServerTimestamp
	)
	local entry: DropEntry = {
		dropId = resolution.dropId,
		kindId = resolution.kindId,
		part = part,
		prompt = prompt,
		worldPosition = worldPosition,
		expiresAtServerTimestamp = resolution.expiresAtServerTimestamp,
		claimed = false,
	}
	entriesByDropId[entry.dropId] = entry
	dropIdByPrompt[prompt] = entry.dropId
end

local function collectAmmunition(player: Player, entry: DropEntry): boolean
	local read = OperativeCombatRuntimeService.readReviveCombatState(player)
	if read == nil then
		return false
	end
	local combatState = read.combatState
	local ammunition = combatState.weaponState.ammunition
	local resolution = AmmunitionSupplyResolver.collect({
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
		maximumReserveRounds = FirearmConfig.BasicFirearm.MaximumReserveRounds,
		processedSupplyIds = {},
	}, {
		supplyId = entry.dropId,
		sourceId = AmmunitionContracts.SupplySourceIds.EnemyDrop,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		availableRounds = LootDropConfig.Rewards.AmmunitionRounds,
	})
	if not resolution.didCollect then
		return false
	end
	combatState.weaponState.ammunition.reserveRounds = resolution.stateAfter.reserveRounds
	return OperativeCombatRuntimeService.commitReviveCombatState(
		player,
		read.generation,
		combatState,
		resolution.grantedRounds
	)
end

local function collectHealing(player: Player, entry: DropEntry, serverTimestamp: number): boolean
	local read = OperativeLifeService.read(player)
	if read == nil then
		return false
	end
	local snapshot = read.snapshot
	local result = OperativeLifeService.applyAuthoritativeHealing(snapshot.operativeEntityId, read.revision, {
		healingEventId = "healing:" .. entry.dropId,
		sourceEntityId = entry.dropId,
		targetEntityId = snapshot.operativeEntityId,
		healingAmount = LootDropConfig.Rewards.HealingAmount,
		serverTimestamp = serverTimestamp,
	})
	return result.didCommit
end

local function collectIntel(entry: DropEntry): boolean
	return RunProgressionService.awardFieldIntel(entry.dropId, LootDropConfig.Rewards.FieldIntelXp)
end

local function tryCollect(player: Player, prompt: ProximityPrompt)
	if not started or collectingPlayers[player] or not OperativeLifeService.isCombatAllowed(player) then
		return
	end
	local dropId = dropIdByPrompt[prompt]
	local entry = if dropId == nil then nil else entriesByDropId[dropId]
	if entry == nil or entry.claimed or entry.prompt ~= prompt or entry.part.Parent == nil then
		return
	end
	local position = operativePosition(player)
	if
		position == nil
		or horizontalDistance(position, entry.worldPosition) > LootDropConfig.PickupMaximumDistanceStuds
	then
		return
	end
	collectingPlayers[player] = true
	local serverTimestamp = Workspace:GetServerTimeNow()
	local didCollect = if entry.kindId == KindIds.AmmunitionBundle
		then collectAmmunition(player, entry)
		elseif entry.kindId == KindIds.FieldDressing then collectHealing(player, entry, serverTimestamp)
		elseif entry.kindId == KindIds.FieldIntel then collectIntel(entry)
		else false
	collectingPlayers[player] = nil
	if not didCollect or entriesByDropId[entry.dropId] ~= entry or entry.claimed then
		return
	end
	entry.claimed = true
	entry.part:SetAttribute(AttributeNames.Available, false)
	entry.prompt.Enabled = false
	destroyEntry(entry)
end

local function scanEnemyDeaths(serverTimestamp: number)
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil or not folder:IsA("Folder") then
		return
	end
	local seen: { [Model]: boolean } = {}
	local inspectedCount = 0
	for _, child in folder:GetChildren() do
		if inspectedCount >= LootDropConfig.MaximumTrackedEnemyModels then
			break
		end
		if not child:IsA("Model") or child:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId then
			continue
		end
		inspectedCount += 1
		local model = child :: Model
		seen[model] = true
		local lifeState = model:GetAttribute(LifeStateAttribute)
		if type(lifeState) ~= "string" then
			continue
		end
		local previous = trackedLifeStates[model]
		if previous == nil then
			trackedLifeStates[model] = lifeState
			local hitSequence = model:GetAttribute(HitSequenceAttribute)
			if
				initialScanComplete
				and lifeState == DeadLifeStateId
				and type(hitSequence) == "number"
				and hitSequence > 0
			then
				spawnDrop(model, serverTimestamp)
			end
		elseif previous ~= DeadLifeStateId and lifeState == DeadLifeStateId then
			trackedLifeStates[model] = lifeState
			spawnDrop(model, serverTimestamp)
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

local function expireDrops(serverTimestamp: number)
	local expired: { DropEntry } = {}
	for _, entry in entriesByDropId do
		if serverTimestamp >= entry.expiresAtServerTimestamp then
			table.insert(expired, entry)
		end
	end
	for _, entry in expired do
		destroyEntry(entry)
	end
end

function LootDropService.readActiveDropCount(): number
	return activeDropCount()
end

function LootDropService.start()
	if started then
		return
	end
	started = true
	accumulatedSeconds = 0
	initialScanComplete = false
	table.clear(trackedLifeStates)
	table.clear(processedEnemyEntityIds)
	table.clear(entriesByDropId)
	table.clear(dropIdByPrompt)
	table.clear(collectingPlayers)
	local existing = Workspace:FindFirstChild(LOOT_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = LOOT_FOLDER_NAME
	folder.Parent = Workspace
	lootFolder = folder
	scanEnemyDeaths(Workspace:GetServerTimeNow())
	promptTriggeredConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "CollectLootPrompt" then
			tryCollect(player, prompt)
		end
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		collectingPlayers[player] = nil
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < LootDropConfig.EnemyScanIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		local serverTimestamp = Workspace:GetServerTimeNow()
		scanEnemyDeaths(serverTimestamp)
		expireDrops(serverTimestamp)
	end)
end

function LootDropService.stop()
	if not started then
		return
	end
	started = false
	for _, connection in { heartbeatConnection, promptTriggeredConnection, playerRemovingConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	promptTriggeredConnection = nil
	playerRemovingConnection = nil
	local currentEntries: { DropEntry } = {}
	for _, entry in entriesByDropId do
		table.insert(currentEntries, entry)
	end
	for _, entry in currentEntries do
		destroyEntry(entry)
	end
	table.clear(trackedLifeStates)
	table.clear(processedEnemyEntityIds)
	table.clear(dropIdByPrompt)
	table.clear(collectingPlayers)
	if lootFolder ~= nil then
		lootFolder:Destroy()
		lootFolder = nil
	end
	accumulatedSeconds = 0
	initialScanComplete = false
end

return table.freeze(LootDropService)
