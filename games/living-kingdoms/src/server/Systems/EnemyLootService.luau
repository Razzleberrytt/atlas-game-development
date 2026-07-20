--!strict

--[[
	HROI-0106 server-owned enemy ammunition loot. One bounded Heartbeat pass
	observes confirmed enemy deaths, animates at most sixteen replicated pickups,
	checks nearby living operatives, commits ammunition through the existing P6
	supply resolver and combat runtime, and removes expired or collected drops.

	There is no client collection request, touch event, ProximityPrompt, per-drop
	connection, delayed task, permanent inventory, or account reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AmmunitionScarcityContracts = require(ReplicatedStorage.Shared.Combat.AmmunitionScarcityContracts)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyLootConfig = require(ReplicatedStorage.Shared.Config.EnemyLootConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end
local EnemyLootResolver = require(ReplicatedStorage.Shared.Loot.EnemyLootResolver)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local AmmunitionSupplyResolver = require(script.Parent.Parent.Domain.AmmunitionSupplyResolver)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead
local EnemyLootSourceId = AmmunitionScarcityContracts.SupplySourceIds.EnemyLoot
local ENEMY_FOLDER_NAME = "EnemyEntities"
local LOOT_FOLDER_NAME = "EnemyLootDrops"

type DropRecord = {
	dropId: string,
	part: BasePart,
	basePosition: Vector3,
	createdAtServerTimestamp: number,
	expiresAtServerTimestamp: number,
	rounds: number,
	rarityId: string,
	phaseOffset: number,
}

local EnemyLootService = {}

local started = false
local accumulatedSeconds = 0
local deathSequence = 0
local activeDropCount = 0
local initialScanComplete = false
local lootFolder: Folder? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local trackedLifeStates: { [Model]: string } = {}
local dropsById: { [string]: DropRecord } = {}
local processedSupplyIdsByPlayer: { [Player]: { [string]: boolean } } = {}

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

local function processedSetFor(player: Player): { [string]: boolean }
	local existing = processedSupplyIdsByPlayer[player]
	if existing ~= nil then
		return existing
	end
	local created = {}
	processedSupplyIdsByPlayer[player] = created
	return created
end

local function createLabel(part: BasePart, displayName: string, rounds: number, rarityId: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LootLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 52)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.65, 0)
	billboard.MaxDistance = 75
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s\n+%d ROUNDS", displayName, rounds)
	label.TextColor3 = if rarityId == "Rare" then Color3.fromRGB(125, 226, 255) else Color3.fromRGB(255, 210, 91)
	label.TextStrokeColor3 = Color3.fromRGB(8, 10, 11)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = billboard
end

local function createDropPart(
	dropId: string,
	lootKindId: string,
	displayName: string,
	rounds: number,
	rarityId: string,
	position: Vector3,
	parent: Folder
): BasePart
	local part = Instance.new("Part")
	part.Name = dropId
	part.Size = if rarityId == "Rare" then Vector3.new(2.4, 1.1, 1.7) else Vector3.new(1.45, 0.55, 0.55)
	part.Shape = if rarityId == "Rare" then Enum.PartType.Block else Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = if rarityId == "Rare" then Color3.fromRGB(50, 176, 220) else Color3.fromRGB(226, 158, 42)
	part.Transparency = 0.04
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position)
	part:SetAttribute("EnemyLootId", dropId)
	part:SetAttribute("LootKindId", lootKindId)
	part:SetAttribute("LootRarityId", rarityId)
	part:SetAttribute("AvailableRounds", rounds)
	part.Parent = parent

	local light = Instance.new("PointLight")
	light.Name = "LootGlow"
	light.Color = part.Color
	light.Brightness = if rarityId == "Rare" then 2.4 else 1.5
	light.Range = if rarityId == "Rare" then 13 else 9
	light.Shadows = false
	light.Parent = part

	createLabel(part, displayName, rounds, rarityId)
	return part
end

local function destroyDrop(dropId: string)
	local record = dropsById[dropId]
	if record == nil then
		return
	end
	dropsById[dropId] = nil
	activeDropCount = math.max(0, activeDropCount - 1)
	if record.part.Parent ~= nil then
		record.part:Destroy()
	end
end

local function spawnDrop(enemyModel: Model, worldPosition: Vector3, serverTimestamp: number)
	deathSequence += 1
	local entityId = enemyModel:GetAttribute("CombatEntityId")
	if type(entityId) ~= "string" or entityId == "" then
		entityId = enemyModel.Name
	end
	local resolution = EnemyLootResolver.resolveDrop(entityId, deathSequence, activeDropCount)
	if not resolution.didDrop then
		return
	end
	local dropId = resolution.dropId
	local lootKindId = resolution.lootKindId
	local displayName = resolution.displayName
	local rarityId = resolution.rarityId
	local folder = lootFolder
	if
		dropId == nil
		or lootKindId == nil
		or displayName == nil
		or rarityId == nil
		or folder == nil
		or resolution.rounds <= 0
		or resolution.lifetimeSeconds <= 0
	then
		return
	end

	local part = createDropPart(dropId, lootKindId, displayName, resolution.rounds, rarityId, worldPosition, folder)
	dropsById[dropId] = {
		dropId = dropId,
		part = part,
		basePosition = worldPosition,
		createdAtServerTimestamp = serverTimestamp,
		expiresAtServerTimestamp = serverTimestamp + resolution.lifetimeSeconds,
		rounds = resolution.rounds,
		rarityId = rarityId,
		phaseOffset = (deathSequence % 8) * 0.65,
	}
	activeDropCount += 1
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

local function deathPosition(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end
	return model:GetPivot().Position
end

local function observeConfirmedDeaths(serverTimestamp: number)
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil or not folder:IsA("Folder") then
		return
	end

	local seen: { [Model]: boolean } = {}
	local inspectedCount = 0
	for _, child in folder:GetChildren() do
		if inspectedCount >= EnemyLootConfig.MaximumTrackedEnemyModels then
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
				spawnDrop(model, deathPosition(model), serverTimestamp)
			end
		elseif previousLifeState ~= DeadLifeStateId and lifeState == DeadLifeStateId then
			trackedLifeStates[model] = lifeState
			spawnDrop(model, deathPosition(model), serverTimestamp)
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

local function sortedPlayers(): { Player }
	local players = Players:GetPlayers()
	table.sort(players, function(left, right)
		return left.UserId < right.UserId
	end)
	return players
end

local function pickupRadiusStuds(): number
	local network = ReplicatedStorage:FindFirstChild("ProgressionNetwork")
	if network == nil then
		return EnemyLootConfig.PickupRadiusStuds
	end
	local bonus = network:GetAttribute("RunLootPickupRadiusBonusStuds")
	if type(bonus) ~= "number" or bonus ~= bonus or bonus < 0 or bonus > 4.5 then
		return EnemyLootConfig.PickupRadiusStuds
	end
	return math.min(10, EnemyLootConfig.PickupRadiusStuds + bonus)
end

local function nearestEligibleCollector(record: DropRecord): Player?
	local nearest: Player? = nil
	local nearestDistance = math.huge
	local pickupRadius = pickupRadiusStuds()
	for _, player in sortedPlayers() do
		if not OperativeLifeService.isCombatAllowed(player) then
			continue
		end
		local position = operativePosition(player)
		if position == nil then
			continue
		end
		local verticalDistance = math.abs(position.Y - record.basePosition.Y)
		local distance = horizontalDistance(position, record.basePosition)
		if
			verticalDistance <= EnemyLootConfig.MaximumVerticalPickupDistanceStuds
			and distance <= pickupRadius
			and distance < nearestDistance
		then
			nearest = player
			nearestDistance = distance
		end
	end
	return nearest
end

local function tryCollect(player: Player, record: DropRecord): boolean
	local read = OperativeCombatRuntimeService.readReviveCombatState(player)
	if read == nil then
		return false
	end
	local combatState = read.combatState
	local weaponState = combatState.weaponState
	local ammunition = weaponState.ammunition
	local processed = processedSetFor(player)
	local result = AmmunitionSupplyResolver.collect({
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
		maximumReserveRounds = (resolveWeaponDefinition(ammunition.weaponId) or FirearmConfig.BasicFirearm).MaximumReserveRounds,
		processedSupplyIds = processed,
	}, {
		supplyId = record.dropId,
		sourceId = EnemyLootSourceId,
		weaponId = ammunition.weaponId,
		availableRounds = record.rounds,
	})
	if not result.didCollect then
		return false
	end
	combatState.weaponState.ammunition.reserveRounds = result.stateAfter.reserveRounds
	if
		not OperativeCombatRuntimeService.commitReviveCombatState(
			player,
			read.generation,
			combatState,
			result.grantedRounds
		)
	then
		return false
	end
	processedSupplyIdsByPlayer[player] = table.clone(result.stateAfter.processedSupplyIds)
	return true
end

local function evaluateDrops(serverTimestamp: number)
	local toDestroy: { string } = {}
	for dropId, record in dropsById do
		if record.part.Parent == nil or serverTimestamp >= record.expiresAtServerTimestamp then
			table.insert(toDestroy, dropId)
			continue
		end
		local age = math.max(0, serverTimestamp - record.createdAtServerTimestamp)
		local bob = math.sin(age * EnemyLootConfig.BobRadiansPerSecond + record.phaseOffset)
			* EnemyLootConfig.BobAmplitudeStuds
		local spin = age * EnemyLootConfig.SpinRadiansPerSecond
		local orientation = if record.rarityId == "Rare"
			then CFrame.Angles(0, spin, 0)
			else CFrame.Angles(0, spin, math.rad(90))
		record.part.CFrame = CFrame.new(record.basePosition + Vector3.new(0, EnemyLootConfig.HoverHeightStuds + bob, 0))
			* orientation

		local collector = nearestEligibleCollector(record)
		if collector ~= nil and tryCollect(collector, record) then
			table.insert(toDestroy, dropId)
		end
	end
	for _, dropId in toDestroy do
		destroyDrop(dropId)
	end
end

function EnemyLootService.readActiveDropCount(): number
	return activeDropCount
end

function EnemyLootService.evaluateAt(serverTimestamp: number)
	if not started or type(serverTimestamp) ~= "number" or serverTimestamp ~= serverTimestamp then
		return
	end
	observeConfirmedDeaths(serverTimestamp)
	evaluateDrops(serverTimestamp)
end

function EnemyLootService.start()
	if started then
		return
	end
	started = true
	accumulatedSeconds = 0
	deathSequence = 0
	activeDropCount = 0
	initialScanComplete = false
	table.clear(trackedLifeStates)
	table.clear(dropsById)
	table.clear(processedSupplyIdsByPlayer)

	local existing = Workspace:FindFirstChild(LOOT_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = LOOT_FOLDER_NAME
	folder.Parent = Workspace
	lootFolder = folder

	observeConfirmedDeaths(Workspace:GetServerTimeNow())
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		processedSupplyIdsByPlayer[player] = nil
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < EnemyLootConfig.EvaluationIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		EnemyLootService.evaluateAt(Workspace:GetServerTimeNow())
	end)
end

function EnemyLootService.stop()
	if not started then
		return
	end
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	local dropIds = {}
	for dropId in dropsById do
		table.insert(dropIds, dropId)
	end
	for _, dropId in dropIds do
		destroyDrop(dropId)
	end
	table.clear(trackedLifeStates)
	table.clear(processedSupplyIdsByPlayer)
	accumulatedSeconds = 0
	deathSequence = 0
	activeDropCount = 0
	initialScanComplete = false
	local folder = lootFolder
	if folder ~= nil then
		folder:Destroy()
		lootFolder = nil
	end
end

return table.freeze(EnemyLootService)
