--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.SurvivalLootConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local Service = {}
local network = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local collectItemRemote = network:WaitForChild("CollectItem") :: RemoteEvent
local readState = network:WaitForChild("ReadState") :: RemoteFunction

type PendingLoot = {
	itemId: string,
	kindId: string,
	displayName: string,
	quantity: number,
	rarityId: string,
	chestId: string,
	worldPosition: Vector3,
	weaponId: string?,
}

type PlayerState = {
	wood: number,
	openedChests: number,
	foundWeapon: boolean,
	pendingLoot: { [string]: PendingLoot },
	revision: number,
}

local states: { [Player]: PlayerState } = {}
local started = false
local campfireFuel = Config.Campfire.StartingFuel
local worldFolder: Folder? = nil
local fireLight: PointLight? = nil
local fireCore: BasePart? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local collectItemConnection: RBXScriptConnection? = nil
local accumulated = 0
local reachedStableFire = false
local reachedMaximumFire = false

local CHEST_POSITIONS = table.freeze({
	Vector3.new(-243, 2, -220),
	Vector3.new(-175, 2, -168),
	Vector3.new(-118, 2, 33),
	Vector3.new(-64, 2, 72),
	Vector3.new(18, 2, 20),
	Vector3.new(92, 2, -88),
	Vector3.new(172, 2, -156),
	Vector3.new(205, 2, 82),
	Vector3.new(145, 2, 188),
	Vector3.new(-190, 2, 150),
	Vector3.new(-330, 2, 110),
	Vector3.new(350, 2, -40),
	Vector3.new(410, 2, 260),
	Vector3.new(-420, 2, -250),
})

local WOOD_POSITIONS = table.freeze({
	Vector3.new(-246, 2, -208),
	Vector3.new(-205, 2, -228),
	Vector3.new(-174, 2, -214),
	Vector3.new(-138, 2, -177),
	Vector3.new(-112, 2, -42),
	Vector3.new(-78, 2, 58),
	Vector3.new(-24, 2, 12),
	Vector3.new(40, 2, -30),
	Vector3.new(96, 2, -126),
	Vector3.new(164, 2, -194),
	Vector3.new(228, 2, 44),
	Vector3.new(190, 2, 116),
	Vector3.new(92, 2, 180),
	Vector3.new(-118, 2, 174),
	Vector3.new(-260, 2, 82),
	Vector3.new(-350, 2, -96),
})

local function playerState(player: Player): PlayerState
	local state = states[player]
	if state == nil then
		state = { wood = 0, openedChests = 0, foundWeapon = false, pendingLoot = {}, revision = 1 }
		states[player] = state
	end
	return state
end

local function snapshot(player: Player, eventText: string?): any
	local state = playerState(player)
	local pendingLoot = {}
	for _, item in state.pendingLoot do
		table.insert(
			pendingLoot,
			table.freeze({
				itemId = item.itemId,
				kindId = item.kindId,
				displayName = item.displayName,
				quantity = item.quantity,
				rarityId = item.rarityId,
				chestId = item.chestId,
			})
		)
	end
	table.sort(pendingLoot, function(left, right)
		return left.itemId < right.itemId
	end)
	return table.freeze({
		revision = state.revision,
		inventoryCapacity = Config.InventoryCapacity,
		inventoryUsed = state.wood,
		wood = state.wood,
		openedChests = state.openedChests,
		foundWeapon = state.foundWeapon,
		pendingLoot = table.freeze(pendingLoot),
		inventoryItems = table.freeze({
			table.freeze({ itemId = "resource.wood", kindId = "wood", displayName = "Firewood", quantity = state.wood }),
		}),
		campfireFuel = campfireFuel,
		campfireMaximumFuel = Config.Campfire.MaximumFuel,
		eventText = eventText,
	})
end

local function hasPendingWeapon(state: PlayerState): boolean
	for _, item in state.pendingLoot do
		if item.kindId == "weapon" then
			return true
		end
	end
	return false
end

local function stageLoot(state: PlayerState, item: PendingLoot)
	state.pendingLoot[item.itemId] = item
end

local publish: (player: Player, eventText: string?) -> ()
local isNear: (player: Player, position: Vector3, maximumDistance: number) -> boolean

local function collectPendingLoot(player: Player, itemId: unknown)
	if type(itemId) ~= "string" or #itemId > 96 then
		return
	end
	local state = playerState(player)
	local item = state.pendingLoot[itemId]
	if item == nil or not isNear(player, item.worldPosition, Config.ChestInteractionDistanceStuds + 2) then
		return
	end

	local eventText: string
	if item.kindId == "wood" then
		local room = Config.InventoryCapacity - state.wood
		if room <= 0 then
			publish(player, "BACKPACK FULL — make room before taking the firewood")
			return
		end
		local collected = math.min(room, item.quantity)
		state.wood += collected
		item.quantity -= collected
		eventText = string.format("FIREWOOD ADDED  +%d", collected)
		if item.quantity <= 0 then
			state.pendingLoot[itemId] = nil
		end
	elseif item.kindId == "ammunition" then
		local granted = OperativeCombatRuntimeService.grantFoundAmmunition(player, item.quantity)
		if granted <= 0 then
			publish(player, "AMMUNITION FULL — leave it in the chest for now")
			return
		end
		item.quantity -= granted
		eventText = string.format("PISTOL AMMO ADDED  +%d", granted)
		if item.quantity <= 0 then
			state.pendingLoot[itemId] = nil
		end
	elseif item.kindId == "weapon" and item.weaponId ~= nil then
		if not OperativeCombatRuntimeService.equipFoundWeapon(player, item.weaponId) then
			publish(player, "WEAPON CANNOT BE EQUIPPED RIGHT NOW")
			return
		end
		state.foundWeapon = true
		state.pendingLoot[itemId] = nil
		eventText = item.displayName .. " EQUIPPED"
	else
		return
	end
	state.revision += 1
	publish(player, eventText)
end

publish = function(player: Player, eventText: string?)
	stateRemote:FireClient(player, snapshot(player, eventText))
end

local function publishAll(eventText: string?)
	for _, player in Players:GetPlayers() do
		publish(player, eventText)
	end
end

isNear = function(player: Player, position: Vector3, maximumDistance: number): boolean
	if not OperativeLifeService.isCombatAllowed(player) then
		return false
	end
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - position).Magnitude <= maximumDistance
end

local function updateFirePresentation()
	local fraction = campfireFuel / Config.Campfire.MaximumFuel
	if fireLight ~= nil then
		fireLight.Brightness = 1.2 + fraction * 4.8
		fireLight.Range = 14 + fraction * Config.Campfire.SafeLightRangeStuds
		fireLight.Enabled = campfireFuel > 0
	end
	if fireCore ~= nil then
		fireCore.Size = Vector3.new(1.6 + fraction, 2.4 + fraction * 3.5, 1.6 + fraction)
		fireCore.Transparency = if campfireFuel > 0 then 0.08 else 0.78
	end
end

local function addPrompt(part: BasePart, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = Config.ChestInteractionDistanceStuds
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function createCampfire(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "HomeCampfire"
	model:SetAttribute("HomeBase", true)
	model.Parent = parent
	local center = Vector3.new(-220, 2.2, -224)
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		local stone = Instance.new("Part")
		stone.Name = "FireRingStone"
		stone.Shape = Enum.PartType.Ball
		stone.Size = Vector3.new(2.2, 1.2, 1.8)
		stone.Position = center + Vector3.new(math.cos(angle) * 3.4, -1.1, math.sin(angle) * 3.4)
		stone.Color = Color3.fromRGB(63, 61, 57)
		stone.Material = Enum.Material.Slate
		stone.Anchored = true
		stone.Parent = model
	end
	for index = 1, 3 do
		local log = Instance.new("Part")
		log.Name = "BurningLog"
		log.Shape = Enum.PartType.Cylinder
		log.Size = Vector3.new(1.1, 6, 1.1)
		log.CFrame = CFrame.new(center - Vector3.new(0, 0.55, 0))
			* CFrame.Angles(0, 0, math.rad(90))
			* CFrame.Angles(math.rad(index * 60), 0, 0)
		log.Color = Color3.fromRGB(76, 43, 28)
		log.Material = Enum.Material.Wood
		log.Anchored = true
		log.Parent = model
	end
	local core = Instance.new("Part")
	core.Name = "FireCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(2.2, 5, 2.2)
	core.Position = center + Vector3.new(0, 1.1, 0)
	core.Color = Color3.fromRGB(255, 112, 28)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.Parent = model
	fireCore = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 158, 74)
	light.Shadows = true
	light.Parent = core
	fireLight = light
	local prompt = addPrompt(core, "Feed 1 Wood", "HOME FIRE")
	prompt.Triggered:Connect(function(player)
		if not isNear(player, center, Config.ChestInteractionDistanceStuds + 2) then
			return
		end
		local state = playerState(player)
		if state.wood <= 0 then
			publish(player, "You need wood to feed the fire.")
			return
		end
		if campfireFuel >= Config.Campfire.MaximumFuel then
			publish(player, "The home fire is already full.")
			return
		end
		state.wood -= 1
		state.revision += 1
		local previousFuel = campfireFuel
		campfireFuel = math.min(Config.Campfire.MaximumFuel, campfireFuel + Config.Campfire.FuelPerWood)
		updateFirePresentation()
		local reward = 0
		local eventText = player.DisplayName .. " fed the home fire."
		if
			not reachedStableFire
			and previousFuel < Config.Campfire.StableFuelThreshold
			and campfireFuel >= Config.Campfire.StableFuelThreshold
		then
			reachedStableFire = true
			reward = Config.Campfire.StableFuelAmmoReward
			eventText = "FIRE STABILIZED — the light answers with ammunition"
		end
		if not reachedMaximumFire and campfireFuel >= Config.Campfire.MaximumFuel then
			reachedMaximumFire = true
			reward = math.max(reward, Config.Campfire.MaximumFuelAmmoReward)
			eventText = "HOME FIRE BLAZING — prepare for the hunt"
		end
		if reward > 0 then
			OperativeCombatRuntimeService.grantFoundAmmunition(player, reward)
		end
		publishAll(eventText)
	end)
	updateFirePresentation()
end

local function createChest(parent: Instance, index: number, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "LootChest" .. index
	model.Parent = parent
	local base = Instance.new("Part")
	base.Name = "ChestBase"
	base.Size = Vector3.new(5, 2.4, 3.2)
	base.Position = position
	base.Color = Color3.fromRGB(73, 47, 28)
	base.Material = Enum.Material.WoodPlanks
	base.Anchored = true
	base.Parent = model
	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(5.2, 1.1, 3.4)
	lid.Position = position + Vector3.new(0, 1.7, 0)
	lid.Color = Color3.fromRGB(102, 67, 34)
	lid.Material = Enum.Material.WoodPlanks
	lid.Anchored = true
	lid.Parent = model
	local band = Instance.new("Part")
	band.Name = "MetalBand"
	band.Size = Vector3.new(0.55, 3.2, 3.45)
	band.Position = position + Vector3.new(0, 0.7, 0)
	band.Color = Color3.fromRGB(45, 48, 47)
	band.Material = Enum.Material.Metal
	band.Anchored = true
	band.Parent = model
	local highlight = Instance.new("Highlight")
	highlight.Name = "SupplyReadability"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 170, 62)
	highlight.FillTransparency = 0.88
	highlight.OutlineColor = Color3.fromRGB(255, 203, 103)
	highlight.OutlineTransparency = 0.18
	highlight.Parent = model
	local beacon = Instance.new("BillboardGui")
	beacon.Name = "SupplyBeacon"
	beacon.Adornee = lid
	beacon.Size = UDim2.fromOffset(92, 24)
	beacon.StudsOffset = Vector3.new(0, 3.5, 0)
	beacon.AlwaysOnTop = false
	beacon.MaxDistance = 90
	beacon.Parent = model
	local beaconLabel = Instance.new("TextLabel")
	beaconLabel.Size = UDim2.fromScale(1, 1)
	beaconLabel.BackgroundColor3 = Color3.fromRGB(12, 14, 16)
	beaconLabel.BackgroundTransparency = 0.3
	beaconLabel.BorderSizePixel = 0
	beaconLabel.Font = Enum.Font.GothamBold
	beaconLabel.Text = "◇  SUPPLY"
	beaconLabel.TextColor3 = Color3.fromRGB(255, 203, 103)
	beaconLabel.TextSize = 12
	beaconLabel.Parent = beacon
	local prompt = addPrompt(lid, "Open Chest", "SUPPLY CHEST")
	local opened = false
	prompt.Triggered:Connect(function(player)
		if opened or not isNear(player, position, Config.ChestInteractionDistanceStuds + 2) then
			return
		end
		opened = true
		prompt.Enabled = false
		highlight.Enabled = false
		beacon.Enabled = false
		lid.CFrame = lid.CFrame * CFrame.new(0, 1.1, 1) * CFrame.Angles(math.rad(-32), 0, 0)
		local state = playerState(player)
		state.openedChests += 1
		local woodAmount = Config.ChestWoodMinimum
			+ (index * 5 % (Config.ChestWoodMaximum - Config.ChestWoodMinimum + 1))
		local rounds = Config.AmmoRoundsMinimum
			+ (index * 3 % (Config.AmmoRoundsMaximum - Config.AmmoRoundsMinimum + 1))
		local roll = (index * 37 + player.UserId) % 100
		local shouldFindWeapon = not state.foundWeapon
			and not hasPendingWeapon(state)
			and (state.openedChests >= Config.GuaranteedWeaponByOpenedChest or roll < Config.ChestWeaponChancePercent)
		local chestId = "chest." .. tostring(index)
		stageLoot(state, {
			itemId = chestId .. ".wood",
			kindId = "wood",
			displayName = "Dry Firewood",
			quantity = woodAmount,
			rarityId = "Common",
			chestId = chestId,
			worldPosition = position,
			weaponId = nil,
		})
		stageLoot(state, {
			itemId = chestId .. ".ammunition",
			kindId = "ammunition",
			displayName = "Pistol Ammunition",
			quantity = rounds,
			rarityId = "Uncommon",
			chestId = chestId,
			worldPosition = position,
			weaponId = nil,
		})
		if shouldFindWeapon then
			local weapons = Config.DiscoverableWeaponIds
			local weaponId = weapons[(index % #weapons) + 1]
			stageLoot(state, {
				itemId = chestId .. ".weapon",
				kindId = "weapon",
				displayName = (FirearmConfig.get(weaponId) :: any).DisplayName,
				quantity = 1,
				rarityId = "Rare",
				chestId = chestId,
				worldPosition = position,
				weaponId = weaponId,
			})
		end
		state.revision += 1
		publish(player, "CHEST OPENED — tap each item to take it")
	end)
end

local function createWoodBundle(parent: Instance, index: number, position: Vector3)
	local bundle = Instance.new("Part")
	bundle.Name = "WoodBundle" .. index
	bundle.Shape = Enum.PartType.Cylinder
	bundle.Size = Vector3.new(1.6, 4.5, 1.6)
	bundle.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	bundle.Color = Color3.fromRGB(93, 61, 37)
	bundle.Material = Enum.Material.Wood
	bundle.Anchored = true
	bundle.Parent = parent
	local prompt = addPrompt(bundle, "Take Wood", "FIREWOOD")
	local collected = false
	prompt.Triggered:Connect(function(player)
		if collected or not isNear(player, position, Config.ChestInteractionDistanceStuds + 2) then
			return
		end
		local state = playerState(player)
		local room = Config.InventoryCapacity - state.wood
		if room <= 0 then
			publish(player, "Your 30-slot pack is full.")
			return
		end
		local amount = math.min(room, Config.WoodPerBundleMinimum + index % 3)
		state.wood += amount
		state.revision += 1
		collected = true
		bundle:Destroy()
		publish(player, string.format("Collected %d wood", amount))
	end)
end

function Service.start()
	if started then
		return
	end
	started = true
	campfireFuel = Config.Campfire.StartingFuel
	reachedStableFire = campfireFuel >= Config.Campfire.StableFuelThreshold
	reachedMaximumFire = campfireFuel >= Config.Campfire.MaximumFuel
	local existing = Workspace:FindFirstChild("SurvivalLoot")
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SurvivalLoot"
	folder.Parent = Workspace
	worldFolder = folder
	createCampfire(folder)
	for index, position in CHEST_POSITIONS do
		createChest(folder, index, position)
	end
	for index, position in WOOD_POSITIONS do
		createWoodBundle(folder, index, position)
	end
	readState.OnServerInvoke = function(player)
		return snapshot(player, nil)
	end
	collectItemConnection = collectItemRemote.OnServerEvent:Connect(collectPendingLoot)
	for _, player in Players:GetPlayers() do
		publish(player, "Find wood and keep the home fire alive.")
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulated += deltaTime
		if accumulated < Config.Campfire.BurnIntervalSeconds then
			return
		end
		accumulated = 0
		if campfireFuel > 0 then
			campfireFuel -= 1
			updateFirePresentation()
			if campfireFuel == 20 then
				publishAll("HOME FIRE DYING — bring wood back now")
			elseif campfireFuel == 0 then
				publishAll("THE HOME FIRE IS OUT — the dark owns the camp")
			else
				publishAll(nil)
			end
		end
	end)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if collectItemConnection ~= nil then
		collectItemConnection:Disconnect()
		collectItemConnection = nil
	end
	readState.OnServerInvoke = nil
	if worldFolder ~= nil then
		worldFolder:Destroy()
		worldFolder = nil
	end
	table.clear(states)
	accumulated = 0
end

return table.freeze(Service)
