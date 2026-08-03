--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local MovementLimits = require(ReplicatedStorage.Shared.Config.MovementLimits)

local Controller = {}
local player = Players.LocalPlayer
local survivalNetwork = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local survivalStateRemote = survivalNetwork:WaitForChild("State") :: RemoteEvent
local survivalReadState = survivalNetwork:WaitForChild("ReadState") :: RemoteFunction
local progressionStateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction

local started = false
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui? = nil
local modal: Frame? = nil
local characterPanel: Frame? = nil
local inventoryPanel: Frame? = nil
local viewport: ViewportFrame? = nil
local statsList: Frame? = nil
local inventoryGrid: ScrollingFrame? = nil
local inventoryTitle: TextLabel? = nil
local characterTab: TextButton? = nil
local inventoryTab: TextButton? = nil
local selectedTab = "Character"
local latestSurvival: any = nil
local latestProgression: any = nil

local COLORS = table.freeze({
	background = Color3.fromRGB(9, 12, 14),
	panel = Color3.fromRGB(18, 23, 25),
	slot = Color3.fromRGB(28, 34, 35),
	gold = Color3.fromRGB(224, 177, 83),
	text = Color3.fromRGB(239, 237, 224),
	muted = Color3.fromRGB(154, 164, 159),
	green = Color3.fromRGB(105, 214, 139),
})

local function decorate(target: GuiObject, color: Color3?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = target
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.gold
	stroke.Transparency = 0.35
	stroke.Parent = target
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local created = Instance.new("TextLabel")
	created.BackgroundTransparency = 1
	created.Position = position
	created.Size = size
	created.Font = Enum.Font.GothamBold
	created.Text = text
	created.TextColor3 = COLORS.text
	created.TextSize = textSize
	created.TextXAlignment = Enum.TextXAlignment.Left
	created.Parent = parent
	return created
end

local function clearGenerated(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function equippedWeaponName(): string
	local weaponId = player:GetAttribute("LK_EquippedWeaponId")
	if type(weaponId) ~= "string" then
		return "Empty"
	end
	local definition = FirearmConfig.get(weaponId)
	return if definition ~= nil then definition.DisplayName else weaponId
end

local function rebuildViewport()
	local frame = viewport
	local character = player.Character
	if frame == nil or character == nil then
		return
	end
	for _, child in frame:GetChildren() do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = frame
	local oldArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = oldArchivable
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Tool") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	clone:PivotTo(CFrame.new(0, 0, 0))
	clone.Parent = world
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.65, 8.2), Vector3.new(0, 2.55, 0))
	camera.FieldOfView = 32
	camera.Parent = frame
	frame.CurrentCamera = camera
end

local function equipmentSlot(parent: Instance, name: string, value: string, position: UDim2)
	local slot = Instance.new("TextButton")
	slot.Name = name .. "Slot"
	slot.Position = position
	slot.Size = UDim2.fromOffset(132, 58)
	slot.BackgroundColor3 = COLORS.slot
	slot.BorderSizePixel = 0
	slot.AutoButtonColor = true
	slot.Font = Enum.Font.GothamBold
	slot.Text = string.format("%s\n%s", string.upper(name), value)
	slot.TextColor3 = if value == "Empty" then COLORS.muted else COLORS.text
	slot.TextSize = 11
	slot.TextWrapped = true
	slot.Parent = parent
	decorate(slot, if value == "Empty" then Color3.fromRGB(79, 87, 84) else COLORS.gold)
	slot.Activated:Connect(function()
		if inventoryPanel ~= nil and characterPanel ~= nil then
			characterPanel.Visible = false
			inventoryPanel.Visible = true
		end
	end)
end

local function rebuildEquipment()
	local panel = characterPanel
	if panel == nil then
		return
	end
	local equipment = panel:FindFirstChild("EquipmentSlots")
	if equipment == nil or not equipment:IsA("Frame") then
		return
	end
	clearGenerated(equipment)
	local weaponId = player:GetAttribute("LK_EquippedWeaponId")
	local isSidearm = weaponId == FirearmConfig.ServicePistol.WeaponId
	equipmentSlot(equipment, "Head", "Empty", UDim2.fromOffset(8, 20))
	equipmentSlot(equipment, "Chest", "Empty", UDim2.fromOffset(8, 94))
	equipmentSlot(equipment, "Primary", if isSidearm then "Empty" else equippedWeaponName(), UDim2.new(1, -140, 0, 20))
	equipmentSlot(equipment, "Sidearm", if isSidearm then equippedWeaponName() else "Empty", UDim2.new(1, -140, 0, 94))
	equipmentSlot(equipment, "Melee", "Empty", UDim2.fromOffset(8, 168))
	equipmentSlot(equipment, "Relic", "Empty", UDim2.new(1, -140, 0, 168))
end

local function statRow(parent: Instance, order: number, name: string, value: string, color: Color3?)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 29)
	row.BackgroundColor3 = if order % 2 == 0 then Color3.fromRGB(22, 28, 29) else Color3.fromRGB(17, 22, 23)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent
	local key = label(row, name, UDim2.fromOffset(9, 0), UDim2.new(0.62, -9, 1, 0), 11)
	key.TextColor3 = COLORS.muted
	local amount = label(row, value, UDim2.fromScale(0.62, 0), UDim2.new(0.38, -9, 1, 0), 12)
	amount.TextColor3 = color or COLORS.text
	amount.TextXAlignment = Enum.TextXAlignment.Right
end

local function rebuildStats()
	local list = statsList
	if list == nil then
		return
	end
	clearGenerated(list)
	local runStats = if type(latestProgression) == "table" and type(latestProgression.runStats) == "table"
		then latestProgression.runStats
		else {}
	local health = tonumber(player:GetAttribute("LK_P3_CurrentHealth")) or 100
	local maximumHealth = tonumber(player:GetAttribute("LK_P3_MaximumHealth")) or 100
	statRow(
		list,
		1,
		"LEVEL",
		tostring(if type(latestProgression) == "table" then latestProgression.level or 1 else 1),
		COLORS.gold
	)
	statRow(list, 2, "HEALTH", string.format("%d / %d", health, maximumHealth), COLORS.green)
	statRow(list, 3, "DAMAGE", "+" .. tostring(tonumber(runStats.damageBonusPercent) or 0) .. "%")
	statRow(list, 4, "FIRE RATE", "+" .. tostring(tonumber(runStats.fireRateBonusPercent) or 0) .. "%")
	statRow(list, 5, "DAMAGE REDUCTION", tostring(tonumber(runStats.damageReductionPercent) or 0) .. "%")
	statRow(list, 6, "RELOAD SPEED", "+" .. tostring(tonumber(runStats.reloadSpeedBonusPercent) or 0) .. "%")
	statRow(list, 7, "AMMO SAVING", tostring(tonumber(runStats.ammoConservationPercent) or 0) .. "%")
	statRow(list, 8, "XP BONUS", "+" .. tostring(tonumber(runStats.xpBonusPercent) or 0) .. "%")
	statRow(
		list,
		9,
		"WALK / SPRINT",
		string.format("%d / %d", MovementLimits.WalkingSpeed, MovementLimits.SprintingSpeed)
	)
	statRow(
		list,
		10,
		"SQUAD KILLS",
		tostring(if type(latestProgression) == "table" then latestProgression.squadKills or 0 else 0)
	)
end

local function inventorySlot(
	parent: Instance,
	order: number,
	icon: string,
	name: string,
	quantity: number,
	rarity: string
)
	local slot = Instance.new("TextButton")
	slot.Size = UDim2.fromOffset(112, 104)
	slot.BackgroundColor3 = COLORS.slot
	slot.BorderSizePixel = 0
	slot.LayoutOrder = order
	slot.AutoButtonColor = true
	slot.Text = ""
	slot.Parent = parent
	decorate(slot, if rarity == "Rare" then Color3.fromRGB(94, 142, 255) else Color3.fromRGB(111, 151, 112))
	local itemIcon = label(slot, icon, UDim2.fromOffset(8, 5), UDim2.new(1, -16, 0, 42), 27)
	itemIcon.TextXAlignment = Enum.TextXAlignment.Center
	itemIcon.TextColor3 = COLORS.gold
	local itemName = label(slot, name, UDim2.fromOffset(6, 49), UDim2.new(1, -12, 0, 29), 10)
	itemName.TextXAlignment = Enum.TextXAlignment.Center
	itemName.TextWrapped = true
	local count = label(slot, "×" .. tostring(quantity), UDim2.fromOffset(6, 80), UDim2.new(1, -12, 0, 18), 12)
	count.TextXAlignment = Enum.TextXAlignment.Right
end

local function rebuildInventory()
	local grid = inventoryGrid
	if grid == nil then
		return
	end
	clearGenerated(grid)
	local packUsed = if type(latestSurvival) == "table" then tonumber(latestSurvival.inventoryUsed) or 0 else 0
	local packCapacity = if type(latestSurvival) == "table"
		then tonumber(latestSurvival.inventoryCapacity) or 30
		else 30
	if inventoryTitle ~= nil then
		inventoryTitle.Text = string.format("BACKPACK   %d / %d   //   24-SLOT FIELD PACK", packUsed, packCapacity)
	end
	local order = 0
	if type(latestSurvival) == "table" and type(latestSurvival.inventoryItems) == "table" then
		for _, item in latestSurvival.inventoryItems do
			if type(item) == "table" and (tonumber(item.quantity) or 0) > 0 then
				order += 1
				inventorySlot(
					grid,
					order,
					if item.kindId == "wood" then "▰" else "◆",
					tostring(item.displayName),
					tonumber(item.quantity) or 0,
					"Common"
				)
			end
		end
	end
	local weaponName = equippedWeaponName()
	if weaponName ~= "Empty" then
		order += 1
		inventorySlot(grid, order, "⌁", weaponName, 1, "Rare")
	end
	for index = order + 1, 24 do
		local empty = Instance.new("Frame")
		empty.Name = "EmptySlot" .. tostring(index)
		empty.Size = UDim2.fromOffset(112, 104)
		empty.BackgroundColor3 = Color3.fromRGB(15, 19, 20)
		empty.BackgroundTransparency = 0.18
		empty.BorderSizePixel = 0
		empty.LayoutOrder = index
		empty.Parent = grid
		decorate(empty, Color3.fromRGB(54, 63, 61))
	end
	grid.CanvasSize = UDim2.fromOffset(0, math.ceil(24 / 5) * 116)
end

local function selectTab(tabName: string)
	if characterPanel == nil or inventoryPanel == nil then
		return
	end
	selectedTab = tabName
	characterPanel.Visible = tabName == "Character"
	inventoryPanel.Visible = tabName == "Inventory"
	if characterTab ~= nil then
		characterTab.BackgroundColor3 = if tabName == "Character" then COLORS.gold else COLORS.slot
		characterTab.TextColor3 = if tabName == "Character" then COLORS.background else COLORS.text
	end
	if inventoryTab ~= nil then
		inventoryTab.BackgroundColor3 = if tabName == "Inventory" then COLORS.gold else COLORS.slot
		inventoryTab.TextColor3 = if tabName == "Inventory" then COLORS.background else COLORS.text
	end
	if tabName == "Character" then
		rebuildViewport()
		rebuildEquipment()
		rebuildStats()
	else
		rebuildInventory()
	end
end

local function setOpen(open: boolean, tabName: string?)
	if modal == nil then
		return
	end
	modal.Visible = open
	UserInputService.MouseIconEnabled = open
	if open then
		selectTab(tabName or "Character")
	end
end

local function toggleTab(tabName: string)
	if modal ~= nil and modal.Visible and selectedTab == tabName then
		setOpen(false)
	else
		setOpen(true, tabName)
	end
end

local function topButton(parent: Instance, text: string, xOffset: number, tabName: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = tabName .. "Button"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, xOffset, 1, -18)
	button.Size = UDim2.fromOffset(126, 42)
	button.BackgroundColor3 = COLORS.panel
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = COLORS.text
	button.TextSize = 12
	button.Parent = parent
	decorate(button)
	button.Activated:Connect(function()
		setOpen(true, tabName)
	end)
	return button
end

local function createPresentation()
	local created = Instance.new("ScreenGui")
	created.Name = "RPGMenu"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.DisplayOrder = 70
	topButton(created, "C   CHARACTER", -148, "Character")
	topButton(created, "I   INVENTORY", -12, "Inventory")

	local shade = Instance.new("Frame")
	shade.Name = "Modal"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(2, 4, 5)
	shade.BackgroundTransparency = 0.18
	shade.BorderSizePixel = 0
	shade.Visible = false
	shade.Parent = created
	modal = shade
	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.88, 0.84)
	window.BackgroundColor3 = COLORS.background
	window.BorderSizePixel = 0
	window.Parent = shade
	decorate(window)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(660, 430)
	constraint.MaxSize = Vector2.new(1060, 680)
	constraint.Parent = window
	label(window, "SURVIVOR RECORD", UDim2.fromOffset(20, 10), UDim2.fromOffset(260, 42), 20).TextColor3 = COLORS.gold
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 11)
	close.Size = UDim2.fromOffset(42, 36)
	close.BackgroundColor3 = Color3.fromRGB(69, 30, 31)
	close.Font = Enum.Font.GothamBlack
	close.Text = "×"
	close.TextColor3 = COLORS.text
	close.TextSize = 22
	close.Parent = window
	decorate(close, Color3.fromRGB(176, 76, 70))
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local charTab = topButton(window, "CHARACTER", -174, "Character")
	charTab.AnchorPoint = Vector2.new(0, 0)
	charTab.Position = UDim2.fromOffset(286, 11)
	charTab.Size = UDim2.fromOffset(138, 36)
	local invTab = topButton(window, "INVENTORY", -12, "Inventory")
	invTab.AnchorPoint = Vector2.new(0, 0)
	invTab.Position = UDim2.fromOffset(432, 11)
	invTab.Size = UDim2.fromOffset(138, 36)
	characterTab = charTab
	inventoryTab = invTab

	local charPanel = Instance.new("Frame")
	charPanel.Name = "CharacterPanel"
	charPanel.Position = UDim2.fromOffset(14, 58)
	charPanel.Size = UDim2.new(1, -28, 1, -72)
	charPanel.BackgroundTransparency = 1
	charPanel.Parent = window
	characterPanel = charPanel
	local equipment = Instance.new("Frame")
	equipment.Name = "EquipmentSlots"
	equipment.Size = UDim2.new(0.67, -8, 1, 0)
	equipment.BackgroundTransparency = 1
	equipment.Parent = charPanel
	local view = Instance.new("ViewportFrame")
	view.Name = "CharacterBody"
	view.AnchorPoint = Vector2.new(0.5, 0)
	view.Position = UDim2.new(0.5, 0, 0, 5)
	view.Size = UDim2.new(0.46, 0, 1, -10)
	view.BackgroundColor3 = Color3.fromRGB(12, 17, 19)
	view.BackgroundTransparency = 0.08
	view.Ambient = Color3.fromRGB(155, 159, 148)
	view.LightColor = Color3.fromRGB(255, 221, 163)
	view.LightDirection = Vector3.new(-1, -0.5, -1)
	view.Parent = equipment
	decorate(view, Color3.fromRGB(96, 110, 104))
	viewport = view
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.AnchorPoint = Vector2.new(1, 0)
	stats.Position = UDim2.fromScale(1, 0)
	stats.Size = UDim2.new(0.33, -8, 1, 0)
	stats.BackgroundColor3 = COLORS.panel
	stats.BorderSizePixel = 0
	stats.Parent = charPanel
	decorate(stats)
	label(stats, "SURVIVOR STATS", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 30), 15).TextColor3 = COLORS.gold
	local list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(10, 44)
	list.Size = UDim2.new(1, -20, 1, -54)
	list.BackgroundTransparency = 1
	list.Parent = stats
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = list
	statsList = list

	local invPanel = Instance.new("Frame")
	invPanel.Name = "InventoryPanel"
	invPanel.Position = UDim2.fromOffset(14, 58)
	invPanel.Size = UDim2.new(1, -28, 1, -72)
	invPanel.BackgroundTransparency = 1
	invPanel.Visible = false
	invPanel.Parent = window
	inventoryPanel = invPanel
	local packUsed = if type(latestSurvival) == "table" then latestSurvival.inventoryUsed or 0 else 0
	local packCapacity = if type(latestSurvival) == "table" then latestSurvival.inventoryCapacity or 30 else 30
	local title = label(
		invPanel,
		string.format("BACKPACK   %d / %d   //   24-SLOT FIELD PACK", packUsed, packCapacity),
		UDim2.fromOffset(4, 0),
		UDim2.new(1, -8, 0, 34),
		13
	)
	title.TextColor3 = COLORS.gold
	inventoryTitle = title
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "InventoryGrid"
	grid.Position = UDim2.fromOffset(2, 40)
	grid.Size = UDim2.new(1, -4, 1, -42)
	grid.BackgroundColor3 = COLORS.panel
	grid.BackgroundTransparency = 0.08
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = COLORS.gold
	grid.Parent = invPanel
	decorate(grid)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(112, 104)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.Parent = grid
	inventoryGrid = grid

	created.Parent = player:WaitForChild("PlayerGui")
	gui = created
	selectTab("Character")
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.KeyCode == Enum.KeyCode.C then
				toggleTab("Character")
			elseif input.KeyCode == Enum.KeyCode.I then
				toggleTab("Inventory")
			elseif input.KeyCode == Enum.KeyCode.Escape and modal ~= nil and modal.Visible then
				setOpen(false)
			end
		end)
	)
	table.insert(
		connections,
		survivalStateRemote.OnClientEvent:Connect(function(snapshot)
			latestSurvival = snapshot
			if inventoryPanel ~= nil and inventoryPanel.Visible then
				rebuildInventory()
			end
		end)
	)
	table.insert(
		connections,
		progressionStateRemote.OnClientEvent:Connect(function(snapshot)
			latestProgression = snapshot
			if characterPanel ~= nil and characterPanel.Visible then
				rebuildStats()
			end
		end)
	)
	table.insert(
		connections,
		player.CharacterAdded:Connect(function()
			task.delay(1, rebuildViewport)
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("LK_EquippedWeaponId"):Connect(rebuildEquipment))
	table.insert(connections, player:GetAttributeChangedSignal("LK_P3_CurrentHealth"):Connect(rebuildStats))
	table.insert(connections, player:GetAttributeChangedSignal("LK_P3_MaximumHealth"):Connect(rebuildStats))
	local survivalOk, survivalSnapshot = pcall(function()
		return survivalReadState:InvokeServer()
	end)
	if survivalOk then
		latestSurvival = survivalSnapshot
	end
	local progressionOk, progressionSnapshot = pcall(function()
		return progressionReadState:InvokeServer()
	end)
	if progressionOk then
		latestProgression = progressionSnapshot
	end
	rebuildEquipment()
	rebuildStats()
	rebuildInventory()
end

function Controller.stop()
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if gui ~= nil then
		gui:Destroy()
	end
	gui = nil
	modal = nil
	characterPanel = nil
	inventoryPanel = nil
	viewport = nil
	statsList = nil
	inventoryGrid = nil
	inventoryTitle = nil
	characterTab = nil
	inventoryTab = nil
	selectedTab = "Character"
	latestSurvival = nil
	latestProgression = nil
end

return table.freeze(Controller)
