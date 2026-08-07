--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local collectItemRemote = network:WaitForChild("CollectItem") :: RemoteEvent
local readState = network:WaitForChild("ReadState") :: RemoteFunction

local started = false
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local fireLabel: TextLabel? = nil
local packLabel: TextLabel? = nil
local goalLabel: TextLabel? = nil
local eventLabel: TextLabel? = nil
local lootPanel: Frame? = nil
local lootList: Frame? = nil
local backpackSlots: Frame? = nil
local lastRevision = -1
local eventGeneration = 0

local RARITY_COLORS = table.freeze({
	Common = Color3.fromRGB(176, 183, 177),
	Uncommon = Color3.fromRGB(98, 211, 132),
	Rare = Color3.fromRGB(109, 151, 255),
})

local ITEM_ICONS = table.freeze({
	wood = "▰",
	ammunition = "●",
	weapon = "⌁",
})

local function clearGenerated(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function addCornerAndStroke(target: GuiObject, color: Color3, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = target
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.28
	stroke.Thickness = 1
	stroke.Parent = target
end

local function renderLootCards(items: unknown)
	if lootList == nil or lootPanel == nil then
		return
	end
	clearGenerated(lootList)
	local count = 0
	if type(items) == "table" then
		for _, value in items :: any do
			if type(value) == "table" and type(value.itemId) == "string" then
				count += 1
				local item = value :: any
				local rarityColor = RARITY_COLORS[item.rarityId] or RARITY_COLORS.Common
				local card = Instance.new("TextButton")
				card.Name = "LootCard" .. tostring(count)
				card.Size = UDim2.new(1, 0, 0, 68)
				card.BackgroundColor3 = Color3.fromRGB(20, 25, 27)
				card.AutoButtonColor = true
				card.Text = ""
				card.LayoutOrder = count
				card.Parent = lootList
				addCornerAndStroke(card, rarityColor, 7)

				local icon = Instance.new("TextLabel")
				icon.Name = "ItemIcon"
				icon.Position = UDim2.fromOffset(8, 8)
				icon.Size = UDim2.fromOffset(50, 50)
				icon.BackgroundColor3 = rarityColor
				icon.BackgroundTransparency = 0.76
				icon.Font = Enum.Font.GothamBlack
				icon.Text = ITEM_ICONS[item.kindId] or "◆"
				icon.TextColor3 = rarityColor
				icon.TextSize = 27
				icon.Parent = card
				local iconCorner = Instance.new("UICorner")
				iconCorner.CornerRadius = UDim.new(0, 6)
				iconCorner.Parent = icon

				local name = Instance.new("TextLabel")
				name.Position = UDim2.fromOffset(68, 8)
				name.Size = UDim2.new(1, -138, 0, 25)
				name.BackgroundTransparency = 1
				name.Font = Enum.Font.GothamBold
				name.Text = tostring(item.displayName or "Unknown Item")
				name.TextColor3 = Color3.fromRGB(238, 237, 226)
				name.TextSize = 14
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.TextTruncate = Enum.TextTruncate.AtEnd
				name.Parent = card

				local detail = Instance.new("TextLabel")
				detail.Position = UDim2.fromOffset(68, 34)
				detail.Size = UDim2.new(1, -138, 0, 20)
				detail.BackgroundTransparency = 1
				detail.Font = Enum.Font.GothamMedium
				detail.Text =
					string.format("%s   ×%d", string.upper(tostring(item.rarityId or "Common")), item.quantity or 1)
				detail.TextColor3 = rarityColor
				detail.TextSize = 11
				detail.TextXAlignment = Enum.TextXAlignment.Left
				detail.Parent = card

				local take = Instance.new("TextLabel")
				take.AnchorPoint = Vector2.new(1, 0.5)
				take.Position = UDim2.new(1, -10, 0.5, 0)
				take.Size = UDim2.fromOffset(58, 30)
				take.BackgroundColor3 = rarityColor
				take.BackgroundTransparency = 0.12
				take.Font = Enum.Font.GothamBlack
				take.Text = "TAKE"
				take.TextColor3 = Color3.fromRGB(12, 15, 16)
				take.TextSize = 11
				take.Parent = card
				local takeCorner = Instance.new("UICorner")
				takeCorner.CornerRadius = UDim.new(0, 5)
				takeCorner.Parent = take

				card.Activated:Connect(function()
					card.Active = false
					card.BackgroundTransparency = 0.45
					collectItemRemote:FireServer(item.itemId)
				end)
			end
		end
	end
	lootPanel.Visible = count > 0
	lootPanel.Size = UDim2.fromOffset(326, 50 + count * 76)
end

local function makeInventorySlot(
	parent: Instance,
	layoutOrder: number,
	iconText: string,
	titleText: string,
	countText: string
)
	local slot = Instance.new("Frame")
	slot.Size = UDim2.fromOffset(82, 58)
	slot.BackgroundColor3 = Color3.fromRGB(18, 22, 24)
	slot.LayoutOrder = layoutOrder
	slot.Parent = parent
	addCornerAndStroke(slot, Color3.fromRGB(118, 104, 75), 6)
	local icon = Instance.new("TextLabel")
	icon.Position = UDim2.fromOffset(5, 5)
	icon.Size = UDim2.fromOffset(29, 29)
	icon.BackgroundColor3 = Color3.fromRGB(76, 65, 47)
	icon.BackgroundTransparency = 0.38
	icon.Font = Enum.Font.GothamBlack
	icon.Text = iconText
	icon.TextColor3 = Color3.fromRGB(231, 194, 123)
	icon.TextSize = 17
	icon.Parent = slot
	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(38, 5)
	name.Size = UDim2.new(1, -42, 0, 28)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = titleText
	name.TextColor3 = Color3.fromRGB(216, 215, 205)
	name.TextSize = 9
	name.TextWrapped = true
	name.Parent = slot
	local count = Instance.new("TextLabel")
	count.Position = UDim2.fromOffset(6, 36)
	count.Size = UDim2.new(1, -12, 0, 17)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBlack
	count.Text = countText
	count.TextColor3 = Color3.fromRGB(244, 231, 193)
	count.TextSize = 11
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = slot
end

local function renderBackpack(state: any)
	if backpackSlots == nil then
		return
	end
	clearGenerated(backpackSlots)
	makeInventorySlot(backpackSlots, 1, "▰", "FIREWOOD", "×" .. tostring(state.wood or 0))
	makeInventorySlot(backpackSlots, 2, "●", "AMMO", "WEAPON RESERVE")
	makeInventorySlot(backpackSlots, 3, "†", "MELEE", "EMPTY SLOT")
end

local function render(payload: unknown)
	if type(payload) ~= "table" or type((payload :: any).revision) ~= "number" then
		return
	end
	local state = payload :: any
	if state.revision < lastRevision then
		return
	end
	lastRevision = state.revision
	if fireLabel ~= nil then
		fireLabel.Text = string.format("HOME FIRE   %d / %d", state.campfireFuel or 0, state.campfireMaximumFuel or 100)
		fireLabel.TextColor3 = if (state.campfireFuel or 0) <= 20
			then Color3.fromRGB(255, 92, 63)
			else Color3.fromRGB(255, 184, 83)
	end
	if packLabel ~= nil then
		packLabel.Text = string.format(
			"PACK   %d / %d     WOOD   %d     CHESTS   %d",
			state.inventoryUsed or 0,
			state.inventoryCapacity or 30,
			state.wood or 0,
			state.openedChests or 0
		)
	end
	if goalLabel ~= nil then
		if (state.openedChests or 0) == 0 then
			goalLabel.Text = "NEXT  //  SEARCH THE NEAREST SUPPLY CHEST"
		elseif not state.foundWeapon and (state.openedChests or 0) < 3 then
			goalLabel.Text = "NEXT  //  KEEP SEARCHING — A WEAPON IS CLOSE"
		elseif (state.wood or 0) > 0 and (state.campfireFuel or 0) < 75 then
			goalLabel.Text = "NEXT  //  RETURN HOME AND STABILIZE THE FIRE"
		else
			goalLabel.Text = "NEXT  //  LOOT, HUNT, AND KEEP THE FIRE ALIVE"
		end
	end
	if eventLabel ~= nil and type(state.eventText) == "string" and state.eventText ~= "" then
		eventGeneration += 1
		local generation = eventGeneration
		eventLabel.Text = state.eventText
		eventLabel.Visible = true
		task.delay(3.5, function()
			if started and generation == eventGeneration and eventLabel ~= nil then
				eventLabel.Visible = false
			end
		end)
	end
	renderLootCards(state.pendingLoot)
	renderBackpack(state)
end

local function makeLabel(parent: Instance, name: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(236, 235, 226)
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function Controller.start()
	if started then
		return
	end
	started = true
	local created = Instance.new("ScreenGui")
	created.Name = "SurvivalHUD"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.DisplayOrder = 51
	local panel = Instance.new("Frame")
	panel.Name = "SurvivalPanel"
	panel.Position = UDim2.fromOffset(16, 126)
	panel.Size = UDim2.fromOffset(270, 92)
	panel.BackgroundColor3 = Color3.fromRGB(13, 16, 18)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = created
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(151, 116, 66)
	stroke.Transparency = 0.3
	stroke.Parent = panel
	fireLabel = makeLabel(panel, "Fire", 5, 28, 16)
	packLabel = makeLabel(panel, "Pack", 34, 24, 11)
	goalLabel = makeLabel(panel, "Goal", 58, 29, 11)
	goalLabel.TextWrapped = true
	goalLabel.TextColor3 = Color3.fromRGB(255, 202, 105)
	eventLabel = makeLabel(created, "LootEvent", 226, 34, 16)
	eventLabel.Position = UDim2.fromOffset(16, 226)
	eventLabel.Size = UDim2.fromOffset(270, 42)
	eventLabel.TextWrapped = true
	eventLabel.TextColor3 = Color3.fromRGB(255, 202, 105)
	eventLabel.Visible = false

	local createdLootPanel = Instance.new("Frame")
	createdLootPanel.Name = "ChestLootPanel"
	createdLootPanel.AnchorPoint = Vector2.new(1, 0.5)
	createdLootPanel.Position = UDim2.new(1, -20, 0.5, 0)
	createdLootPanel.Size = UDim2.fromOffset(326, 278)
	createdLootPanel.BackgroundColor3 = Color3.fromRGB(10, 13, 15)
	createdLootPanel.BackgroundTransparency = 0.05
	createdLootPanel.BorderSizePixel = 0
	createdLootPanel.Visible = false
	createdLootPanel.Parent = created
	addCornerAndStroke(createdLootPanel, Color3.fromRGB(170, 130, 67), 9)
	local lootTitle = makeLabel(createdLootPanel, "LootTitle", 8, 30, 15)
	lootTitle.Text = "CHEST LOOT   //   TAP TO TAKE"
	lootTitle.TextColor3 = Color3.fromRGB(240, 199, 112)
	local createdLootList = Instance.new("Frame")
	createdLootList.Name = "LootList"
	createdLootList.Position = UDim2.fromOffset(10, 43)
	createdLootList.Size = UDim2.new(1, -20, 1, -51)
	createdLootList.BackgroundTransparency = 1
	createdLootList.Parent = createdLootPanel
	local lootLayout = Instance.new("UIListLayout")
	lootLayout.Padding = UDim.new(0, 8)
	lootLayout.Parent = createdLootList
	lootPanel = createdLootPanel
	lootList = createdLootList

	local backpack = Instance.new("Frame")
	backpack.Name = "BackpackBar"
	backpack.AnchorPoint = Vector2.new(0.5, 1)
	backpack.Position = UDim2.new(0.5, 0, 1, -18)
	backpack.Size = UDim2.fromOffset(290, 88)
	backpack.BackgroundColor3 = Color3.fromRGB(11, 14, 16)
	backpack.BackgroundTransparency = 0.1
	backpack.BorderSizePixel = 0
	backpack.Parent = created
	addCornerAndStroke(backpack, Color3.fromRGB(116, 94, 57), 8)
	local backpackTitle = makeLabel(backpack, "BackpackTitle", 2, 22, 10)
	backpackTitle.Text = "BACKPACK   //   RPG INVENTORY"
	backpackTitle.TextColor3 = Color3.fromRGB(185, 163, 113)
	local createdSlots = Instance.new("Frame")
	createdSlots.Name = "Slots"
	createdSlots.Position = UDim2.fromOffset(10, 25)
	createdSlots.Size = UDim2.new(1, -20, 0, 58)
	createdSlots.BackgroundTransparency = 1
	createdSlots.Parent = backpack
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.Padding = UDim.new(0, 7)
	slotLayout.Parent = createdSlots
	backpackSlots = createdSlots
	created.Parent = player:WaitForChild("PlayerGui")
	gui = created
	connection = stateRemote.OnClientEvent:Connect(render)
	local ok, payload = pcall(function()
		return readState:InvokeServer()
	end)
	if ok then
		render(payload)
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	if gui ~= nil then
		gui:Destroy()
		gui = nil
	end
	fireLabel = nil
	packLabel = nil
	goalLabel = nil
	eventLabel = nil
	lootPanel = nil
	lootList = nil
	backpackSlots = nil
	lastRevision = -1
end

return table.freeze(Controller)
