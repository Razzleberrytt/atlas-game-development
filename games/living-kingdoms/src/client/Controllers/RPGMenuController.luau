--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActiveInputDeviceFamily = require(script.Parent.Parent.State.ActiveInputDeviceFamily)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local InputActionMapConfig = require(ReplicatedStorage.Shared.Config.InputActionMapConfig)
local InputDeviceFamilyResolver = require(ReplicatedStorage.Shared.Input.InputDeviceFamilyResolver)
local MovementLimits = require(ReplicatedStorage.Shared.Config.MovementLimits)
local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)
local EquipmentRewardConfig = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)
local EquipmentComparisonResolver = require(ReplicatedStorage.Shared.Equipment.EquipmentComparisonResolver)
local EquipmentBuildChoicePresentation = require(ReplicatedStorage.Shared.Equipment.EquipmentBuildChoicePresentation)

local Controller = {}
local player = Players.LocalPlayer
local survivalNetwork = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local inventoryNetwork = ReplicatedStorage:WaitForChild("InventoryNetwork")
local survivalStateRemote = survivalNetwork:WaitForChild("State") :: RemoteEvent
local survivalReadState = survivalNetwork:WaitForChild("ReadState") :: RemoteFunction
local progressionStateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local progressionChooseUpgrade = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent
local inventoryStateRemote = inventoryNetwork:WaitForChild("State") :: RemoteEvent
local inventoryReadOwn = inventoryNetwork:WaitForChild("ReadOwnInventory") :: RemoteFunction
local inventoryEquipOwnedItem = inventoryNetwork:WaitForChild("EquipOwnedItem") :: RemoteFunction

local started = false
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui? = nil
local modal: Frame? = nil
local characterPanel: Frame? = nil
local inventoryPanel: Frame? = nil
local skillsPanel: ScrollingFrame? = nil
local viewport: ViewportFrame? = nil
local statsList: Frame? = nil
local inventoryGrid: ScrollingFrame? = nil
local inventoryTitle: TextLabel? = nil
local characterLauncherButton: TextButton? = nil
local inventoryLauncherButton: TextButton? = nil
local characterTab: TextButton? = nil
local inventoryTab: TextButton? = nil
local skillsTab: TextButton? = nil
local selectedTab = "Character"
local latestSurvival: any = nil
local latestProgression: any = nil
local latestDurableInventory: any = nil

local EQUIPMENT_DEFINITIONS_BY_ID = {}
for _, definition in EquipmentRewardConfig.Definitions do
	EQUIPMENT_DEFINITIONS_BY_ID[definition.Id] = definition
end

local COLORS = table.freeze({
	background = Color3.fromRGB(9, 12, 14),
	panel = Color3.fromRGB(18, 23, 25),
	slot = Color3.fromRGB(28, 34, 35),
	gold = Color3.fromRGB(224, 177, 83),
	text = Color3.fromRGB(239, 237, 224),
	muted = Color3.fromRGB(154, 164, 159),
	green = Color3.fromRGB(105, 214, 139),
})

-- Delegated to the single active-device owner. The previous local test mapped any
-- unrecognised input type to "not keyboard", so the engine's non-device `Focus`
-- event (fired whenever the window regains focus) silently dropped the C / I
-- shortcut hints for keyboard players.
local function usesKeyboardShortcutLabels(): boolean
	return ActiveInputDeviceFamily.get() == InputDeviceFamilyResolver.DeviceFamilyIds.KeyboardPointer
end

local function keyboardShortcut(actionId: string): string
	local definition = InputActionMapConfig.get(actionId)
	if definition == nil then
		return ""
	end
	return definition.KeyboardKeyCodeNames[1] or ""
end

local function updateLauncherLabels()
	local showShortcut = usesKeyboardShortcutLabels()
	local characterButton = characterLauncherButton
	if characterButton ~= nil then
		local shortcut = keyboardShortcut("OpenCharacter")
		characterButton.Text = if showShortcut and shortcut ~= "" then shortcut .. "   CHARACTER" else "CHARACTER"
	end
	local inventoryButton = inventoryLauncherButton
	if inventoryButton ~= nil then
		local shortcut = keyboardShortcut("OpenInventory")
		inventoryButton.Text = if showShortcut and shortcut ~= "" then shortcut .. "   INVENTORY" else "INVENTORY"
	end
end

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

local function durableEquippedItem(slotId: string): any
	if type(latestDurableInventory) ~= "table" or type(latestDurableInventory.Items) ~= "table" then
		return nil
	end
	for _, item in latestDurableInventory.Items do
		if type(item) == "table" and item.Slot == slotId and item.Equipped == true then
			return item
		end
	end
	return nil
end

local function durableItemLabel(item: any): string
	if type(item) ~= "table" then
		return "Empty"
	end
	local name = if type(item.DisplayName) == "string" then item.DisplayName else "Gear"
	local power = tonumber(item.Power)
	return if power ~= nil then string.format("%s  P%d", name, power) else name
end

local function lookupEquipmentDefinition(definitionId: string): any
	return EQUIPMENT_DEFINITIONS_BY_ID[definitionId]
end

local function durableBuildChoice(item: any): (string, string)
	local rawAffixes = EquipmentBuildChoicePresentation.formatAffixes(item.Affixes)
	if type(item) ~= "table" or type(item.Slot) ~= "string" then
		return "", rawAffixes
	end
	local incumbent = durableEquippedItem(item.Slot)
	local result = EquipmentComparisonResolver.compare(item, incumbent, lookupEquipmentDefinition)
	if type(result) ~= "table" or result.Accepted ~= true or type(result.Comparison) ~= "table" then
		return "", rawAffixes
	end
	local comparison = result.Comparison
	local verdict = EquipmentBuildChoicePresentation.formatVerdict(comparison)
	if item.Equipped == true or incumbent == nil then
		return verdict, rawAffixes
	end
	local affixFacts = EquipmentBuildChoicePresentation.formatAffixDeltas(comparison.AffixDeltas)
	return verdict, if affixFacts == "NO AFFIX CHANGE" then rawAffixes else affixFacts
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
	local primary = durableEquippedItem("Primary")
	local secondary = durableEquippedItem("Secondary")
	local armor = durableEquippedItem("Armor")
	local relic = durableEquippedItem("Relic")
	local primaryValue = if primary ~= nil
		then durableItemLabel(primary)
		else if isSidearm then "Empty" else equippedWeaponName()
	local secondaryValue = if secondary ~= nil
		then durableItemLabel(secondary)
		else if isSidearm then equippedWeaponName() else "Empty"
	equipmentSlot(equipment, "Head", "Empty", UDim2.fromOffset(8, 20))
	equipmentSlot(equipment, "Chest", durableItemLabel(armor), UDim2.fromOffset(8, 94))
	equipmentSlot(equipment, "Primary", primaryValue, UDim2.new(1, -140, 0, 20))
	equipmentSlot(equipment, "Sidearm", secondaryValue, UDim2.new(1, -140, 0, 94))
	equipmentSlot(equipment, "Melee", "Empty", UDim2.fromOffset(8, 168))
	equipmentSlot(equipment, "Relic", durableItemLabel(relic), UDim2.new(1, -140, 0, 168))
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

local function durableInventorySlot(parent: Instance, order: number, item: any)
	local slot = Instance.new("TextButton")
	slot.Name = "Durable_" .. tostring(item.InstanceId)
	slot.Size = UDim2.fromOffset(112, 104)
	slot.BackgroundColor3 = COLORS.slot
	slot.BorderSizePixel = 0
	slot.LayoutOrder = order
	slot.AutoButtonColor = item.Equipped ~= true
	slot.Active = item.Equipped ~= true
	slot.Text = ""
	slot.Parent = parent
	local border = if item.Rarity == "Rare"
		then Color3.fromRGB(94, 142, 255)
		else if item.Rarity == "Uncommon" then COLORS.gold else Color3.fromRGB(111, 151, 112)
	decorate(slot, border)
	local iconText = if item.Slot == "Primary" or item.Slot == "Secondary"
		then "⌁"
		else if item.Slot == "Armor" then "▣" else "✦"
	local itemIcon = label(slot, iconText, UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 27), 21)
	itemIcon.TextXAlignment = Enum.TextXAlignment.Center
	itemIcon.TextColor3 = border
	local itemName = label(slot, tostring(item.DisplayName), UDim2.fromOffset(6, 28), UDim2.new(1, -12, 0, 27), 10)
	itemName.TextXAlignment = Enum.TextXAlignment.Center
	itemName.TextWrapped = true
	local verdictText, affixText = durableBuildChoice(item)
	local metaText = string.format("%s • P%d", tostring(item.Rarity), tonumber(item.Power) or 0)
	if verdictText ~= "" then
		metaText ..= " • " .. verdictText
	end
	local meta = label(slot, metaText, UDim2.fromOffset(6, 55), UDim2.new(1, -12, 0, 14), 8)
	meta.TextXAlignment = Enum.TextXAlignment.Center
	meta.TextColor3 = COLORS.muted
	local affixes = label(slot, affixText, UDim2.fromOffset(5, 68), UDim2.new(1, -10, 0, 21), 8)
	affixes.TextXAlignment = Enum.TextXAlignment.Center
	affixes.TextWrapped = true
	affixes.TextColor3 = if item.Equipped == true then COLORS.muted else COLORS.text
	local status = label(
		slot,
		if item.Equipped == true then "EQUIPPED" else "EQUIP",
		UDim2.fromOffset(6, 89),
		UDim2.new(1, -12, 0, 13),
		9
	)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextColor3 = if item.Equipped == true then COLORS.green else COLORS.gold
	if item.Equipped ~= true and type(item.InstanceId) == "string" then
		local instanceId = item.InstanceId
		slot.Activated:Connect(function()
			slot.Active = false
			task.spawn(function()
				local ok, outcome = pcall(function()
					return inventoryEquipOwnedItem:InvokeServer(instanceId)
				end)
				if not ok or type(outcome) ~= "table" or outcome.Accepted ~= true then
					slot.Active = true
				end
			end)
		end)
	end
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
	local durableItems = if type(latestDurableInventory) == "table"
			and type(latestDurableInventory.Items) == "table"
		then latestDurableInventory.Items
		else {}
	if inventoryTitle ~= nil then
		inventoryTitle.Text =
			string.format("DURABLE GEAR   %d   //   FIELD PACK   %d / %d", #durableItems, packUsed, packCapacity)
	end
	local order = 0
	for _, item in durableItems do
		if type(item) == "table" and type(item.InstanceId) == "string" then
			order += 1
			durableInventorySlot(grid, order, item)
		end
	end
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
		inventorySlot(grid, order, "⌁", "RUN: " .. weaponName, 1, "Rare")
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
	grid.CanvasSize = UDim2.fromOffset(0, math.ceil(math.max(24, order) / 5) * 116)
end

local function upgradeStacks(): { [string]: number }
	local stacks: { [string]: number } = {}
	if type(latestProgression) ~= "table" or type(latestProgression.activeUpgrades) ~= "table" then
		return stacks
	end
	for _, upgrade in latestProgression.activeUpgrades do
		if type(upgrade) == "table" and type(upgrade.id) == "string" then
			stacks[upgrade.id] = tonumber(upgrade.stacks) or 0
		end
	end
	return stacks
end

local function pendingUpgradeIds(): { [string]: boolean }
	local pending: { [string]: boolean } = {}
	if type(latestProgression) ~= "table" or type(latestProgression.pendingChoices) ~= "table" then
		return pending
	end
	for _, choice in latestProgression.pendingChoices do
		if type(choice) == "table" and type(choice.id) == "string" then
			pending[choice.id] = true
		end
	end
	return pending
end

local function prerequisitesMet(definition: any, stacks: { [string]: number }): boolean
	for _, prerequisiteId in definition.PrerequisiteIds do
		if (stacks[prerequisiteId] or 0) < 1 then
			return false
		end
	end
	return true
end

local function prerequisiteName(definition: any): string
	local prerequisiteId = definition.PrerequisiteIds[1]
	if prerequisiteId == nil then
		return ""
	end
	for _, candidate in RunProgressionConfig.UpgradeDefinitions do
		if candidate.Id == prerequisiteId then
			return candidate.Name
		end
	end
	return tostring(prerequisiteId)
end

local TREE_COLORS = table.freeze({
	Predator = Color3.fromRGB(194, 67, 62),
	Gunslinger = Color3.fromRGB(221, 166, 62),
	Survivor = Color3.fromRGB(75, 159, 125),
})

local function skillNode(
	parent: Instance,
	definition: any,
	stacks: { [string]: number },
	pending: { [string]: boolean },
	treeColor: Color3
)
	local currentRank = stacks[definition.Id] or 0
	local isOffered = pending[definition.Id] == true
	local isUnlocked = prerequisitesMet(definition, stacks)
	local isMaxed = currentRank >= definition.MaximumStacks
	local node = Instance.new("TextButton")
	node.Name = definition.Id
	node.Position = UDim2.fromOffset(8, 50 + (definition.Tier - 1) * 105)
	node.Size = UDim2.new(1, -16, 0, 88)
	node.BackgroundColor3 = if isOffered
		then Color3.fromRGB(55, 45, 25)
		elseif currentRank > 0 then Color3.fromRGB(25, 52, 39)
		elseif isUnlocked then Color3.fromRGB(27, 33, 37)
		else Color3.fromRGB(15, 18, 19)
	node.BackgroundTransparency = if isUnlocked or currentRank > 0 then 0 else 0.25
	node.BorderSizePixel = 0
	node.AutoButtonColor = isOffered
	node.Active = isOffered
	node.Text = ""
	node.Parent = parent
	decorate(node, if isOffered then COLORS.gold elseif currentRank > 0 then COLORS.green else treeColor)

	local icon = label(node, definition.Icon, UDim2.fromOffset(7, 8), UDim2.fromOffset(47, 47), 28)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextColor3 = if isOffered then COLORS.gold elseif currentRank > 0 then COLORS.green else treeColor
	local name = label(node, definition.Name, UDim2.fromOffset(58, 7), UDim2.new(1, -66, 0, 22), 12)
	name.TextColor3 = if isUnlocked or currentRank > 0 then COLORS.text else Color3.fromRGB(91, 98, 96)
	local rank = label(
		node,
		string.format("RANK %d / %d", currentRank, definition.MaximumStacks),
		UDim2.fromOffset(6, 60),
		UDim2.fromOffset(50, 18),
		8
	)
	rank.TextXAlignment = Enum.TextXAlignment.Center
	rank.TextColor3 = if isMaxed then COLORS.green elseif isOffered then COLORS.gold else COLORS.muted
	local description = label(node, definition.Description, UDim2.fromOffset(58, 30), UDim2.new(1, -66, 0, 34), 10)
	description.TextWrapped = true
	description.TextColor3 = if isUnlocked or currentRank > 0 then COLORS.muted else Color3.fromRGB(72, 78, 76)
	local statusText = if isMaxed
		then "MASTERED"
		elseif isOffered then "AVAILABLE — CHOOSE"
		elseif not isUnlocked then "REQUIRES " .. prerequisiteName(definition)
		elseif currentRank > 0 then "OWNED — AWAIT NEXT POINT"
		else "UNLOCKED — AWAIT NEXT POINT"
	local status = label(node, statusText, UDim2.fromOffset(58, 67), UDim2.new(1, -66, 0, 16), 9)
	status.TextColor3 = if isOffered
		then COLORS.gold
		elseif isMaxed then COLORS.green
		elseif isUnlocked then treeColor
		else Color3.fromRGB(83, 88, 87)
	if isOffered then
		node.Activated:Connect(function()
			node.Active = false
			progressionChooseUpgrade:FireServer(definition.Id)
		end)
	end
end

local function rebuildSkillTree()
	local panel = skillsPanel
	if panel == nil then
		return
	end
	clearGenerated(panel)
	local level = if type(latestProgression) == "table" then tonumber(latestProgression.level) or 1 else 1
	local unclaimed = if type(latestProgression) == "table"
		then tonumber(latestProgression.unclaimedUpgradeChoices) or 0
		else 0
	local heading = label(
		panel,
		string.format(
			"FIELD SKILLS   //   LEVEL %d   //   %s",
			level,
			if unclaimed > 0 then "CHOOSE A GLOWING NODE" else "NEXT POINT EARNED WITH FIELD XP"
		),
		UDim2.fromOffset(4, 0),
		UDim2.new(1, -8, 0, 32),
		13
	)
	heading.TextColor3 = if unclaimed > 0 then COLORS.gold else COLORS.muted
	local stacks = upgradeStacks()
	local pending = pendingUpgradeIds()
	for treeIndex, tree in RunProgressionConfig.SkillTrees do
		local treeColor = TREE_COLORS[tree.Id] or COLORS.gold
		local column = Instance.new("Frame")
		column.Name = tree.Id .. "Tree"
		column.Position = UDim2.new((treeIndex - 1) / 3, if treeIndex == 1 then 0 else 6, 0, 36)
		column.Size = UDim2.new(1 / 3, -8, 0, 480)
		column.BackgroundColor3 = COLORS.panel
		column.BorderSizePixel = 0
		column.Parent = panel
		decorate(column, treeColor)
		local treeName = label(column, tree.Name, UDim2.fromOffset(10, 5), UDim2.new(1, -20, 0, 21), 14)
		treeName.TextXAlignment = Enum.TextXAlignment.Center
		treeName.TextColor3 = treeColor
		local treeDescription = label(column, tree.Description, UDim2.fromOffset(10, 25), UDim2.new(1, -20, 0, 20), 9)
		treeDescription.TextXAlignment = Enum.TextXAlignment.Center
		treeDescription.TextColor3 = COLORS.muted
		for tier = 1, 3 do
			local connector = Instance.new("Frame")
			connector.Name = "Connector" .. tostring(tier)
			connector.AnchorPoint = Vector2.new(0.5, 0)
			connector.Position = UDim2.new(0.5, 0, 0, 134 + (tier - 1) * 105)
			connector.Size = UDim2.fromOffset(4, 18)
			connector.BackgroundColor3 = treeColor
			connector.BackgroundTransparency = 0.35
			connector.BorderSizePixel = 0
			connector.Parent = column
		end
		for _, definition in RunProgressionConfig.UpgradeDefinitions do
			if definition.TreeId == tree.Id then
				skillNode(column, definition, stacks, pending, treeColor)
			end
		end
	end
end

local function selectTab(tabName: string)
	if characterPanel == nil or inventoryPanel == nil or skillsPanel == nil then
		return
	end
	selectedTab = tabName
	characterPanel.Visible = tabName == "Character"
	inventoryPanel.Visible = tabName == "Inventory"
	skillsPanel.Visible = tabName == "Skills"
	if characterTab ~= nil then
		characterTab.BackgroundColor3 = if tabName == "Character" then COLORS.gold else COLORS.slot
		characterTab.TextColor3 = if tabName == "Character" then COLORS.background else COLORS.text
	end
	if inventoryTab ~= nil then
		inventoryTab.BackgroundColor3 = if tabName == "Inventory" then COLORS.gold else COLORS.slot
		inventoryTab.TextColor3 = if tabName == "Inventory" then COLORS.background else COLORS.text
	end
	if skillsTab ~= nil then
		skillsTab.BackgroundColor3 = if tabName == "Skills" then COLORS.gold else COLORS.slot
		skillsTab.TextColor3 = if tabName == "Skills" then COLORS.background else COLORS.text
	end
	if tabName == "Character" then
		rebuildViewport()
		rebuildEquipment()
		rebuildStats()
	elseif tabName == "Inventory" then
		rebuildInventory()
	else
		rebuildSkillTree()
	end
end

local function setOpen(open: boolean, tabName: string?)
	if modal == nil then
		return
	end
	if open and not modal.Visible and player:GetAttribute("LK_InputModalOpen") == true then
		return
	end
	modal.Visible = open
	UserInputService.MouseIconEnabled = open
	player:SetAttribute("LK_InputModalOpen", if open then true else nil)
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
	characterLauncherButton = topButton(created, "CHARACTER", -148, "Character")
	inventoryLauncherButton = topButton(created, "INVENTORY", -12, "Inventory")
	updateLauncherLabels()

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
	charTab.Position = UDim2.fromOffset(275, 11)
	charTab.Size = UDim2.fromOffset(125, 36)
	local invTab = topButton(window, "INVENTORY", -12, "Inventory")
	invTab.AnchorPoint = Vector2.new(0, 0)
	invTab.Position = UDim2.fromOffset(407, 11)
	invTab.Size = UDim2.fromOffset(125, 36)
	characterTab = charTab
	inventoryTab = invTab
	skillsTab = nil

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

	local skillPanel = Instance.new("ScrollingFrame")
	skillPanel.Name = "SkillsPanel"
	skillPanel.Position = UDim2.fromOffset(14, 58)
	skillPanel.Size = UDim2.new(1, -28, 1, -72)
	skillPanel.BackgroundTransparency = 1
	skillPanel.BorderSizePixel = 0
	skillPanel.ScrollBarThickness = 6
	skillPanel.ScrollBarImageColor3 = COLORS.gold
	skillPanel.CanvasSize = UDim2.fromOffset(0, 525)
	skillPanel.Visible = false
	skillPanel.Parent = window
	skillsPanel = skillPanel

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
	table.insert(connections, ActiveInputDeviceFamily.onChanged(updateLauncherLabels))
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
		inventoryStateRemote.OnClientEvent:Connect(function(result)
			if type(result) == "table" and result.Accepted == true and type(result.Snapshot) == "table" then
				latestDurableInventory = result.Snapshot
				rebuildEquipment()
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
			elseif skillsPanel ~= nil and skillsPanel.Visible then
				rebuildSkillTree()
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
	local inventoryOk, inventoryResult = pcall(function()
		return inventoryReadOwn:InvokeServer()
	end)
	if
		inventoryOk
		and type(inventoryResult) == "table"
		and inventoryResult.Accepted == true
		and type(inventoryResult.Snapshot) == "table"
	then
		latestDurableInventory = inventoryResult.Snapshot
	end
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
	rebuildSkillTree()
end

function Controller.stop()
	started = false
	player:SetAttribute("LK_InputModalOpen", nil)
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
	skillsPanel = nil
	viewport = nil
	statsList = nil
	inventoryGrid = nil
	inventoryTitle = nil
	characterLauncherButton = nil
	inventoryLauncherButton = nil
	characterTab = nil
	inventoryTab = nil
	skillsTab = nil
	selectedTab = "Character"
	latestSurvival = nil
	latestProgression = nil
	latestDurableInventory = nil
end

return table.freeze(Controller)
