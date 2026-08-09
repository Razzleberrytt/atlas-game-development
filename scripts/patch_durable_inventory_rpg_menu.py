from pathlib import Path

PATH = Path("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")
source = PATH.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global source
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, found {count}")
    source = source.replace(old, new, 1)


replace_once(
    '''local survivalNetwork = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local survivalStateRemote = survivalNetwork:WaitForChild("State") :: RemoteEvent
''',
    '''local survivalNetwork = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local inventoryNetwork = ReplicatedStorage:WaitForChild("InventoryNetwork")
local survivalStateRemote = survivalNetwork:WaitForChild("State") :: RemoteEvent
''',
    "inventory network declaration",
)
replace_once(
    '''local progressionStateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local progressionChooseUpgrade = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent
''',
    '''local progressionStateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local progressionChooseUpgrade = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent
local inventoryStateRemote = inventoryNetwork:WaitForChild("State") :: RemoteEvent
local inventoryReadOwn = inventoryNetwork:WaitForChild("ReadOwnInventory") :: RemoteFunction
local inventoryEquipOwnedItem = inventoryNetwork:WaitForChild("EquipOwnedItem") :: RemoteFunction
''',
    "inventory remote declarations",
)
replace_once(
    '''local latestSurvival: any = nil
local latestProgression: any = nil
''',
    '''local latestSurvival: any = nil
local latestProgression: any = nil
local latestDurableInventory: any = nil
''',
    "durable state declaration",
)
replace_once(
    '''local function rebuildViewport()
''',
    '''local function durableEquippedItem(slotId: string): any
\tif type(latestDurableInventory) ~= "table" or type(latestDurableInventory.Items) ~= "table" then
\t\treturn nil
\tend
\tfor _, item in latestDurableInventory.Items do
\t\tif type(item) == "table" and item.Slot == slotId and item.Equipped == true then
\t\t\treturn item
\t\tend
\tend
\treturn nil
end

local function durableItemLabel(item: any): string
\tif type(item) ~= "table" then
\t\treturn "Empty"
\tend
\tlocal name = if type(item.DisplayName) == "string" then item.DisplayName else "Gear"
\tlocal power = tonumber(item.Power)
\treturn if power ~= nil then string.format("%s  P%d", name, power) else name
end

local function rebuildViewport()
''',
    "durable equipment helpers",
)
old_rebuild_equipment = '''local function rebuildEquipment()
\tlocal panel = characterPanel
\tif panel == nil then
\t\treturn
\tend
\tlocal equipment = panel:FindFirstChild("EquipmentSlots")
\tif equipment == nil or not equipment:IsA("Frame") then
\t\treturn
\tend
\tclearGenerated(equipment)
\tlocal weaponId = player:GetAttribute("LK_EquippedWeaponId")
\tlocal isSidearm = weaponId == FirearmConfig.ServicePistol.WeaponId
\tequipmentSlot(equipment, "Head", "Empty", UDim2.fromOffset(8, 20))
\tequipmentSlot(equipment, "Chest", "Empty", UDim2.fromOffset(8, 94))
\tequipmentSlot(equipment, "Primary", if isSidearm then "Empty" else equippedWeaponName(), UDim2.new(1, -140, 0, 20))
\tequipmentSlot(equipment, "Sidearm", if isSidearm then equippedWeaponName() else "Empty", UDim2.new(1, -140, 0, 94))
\tequipmentSlot(equipment, "Melee", "Empty", UDim2.fromOffset(8, 168))
\tequipmentSlot(equipment, "Relic", "Empty", UDim2.new(1, -140, 0, 168))
end
'''
new_rebuild_equipment = '''local function rebuildEquipment()
\tlocal panel = characterPanel
\tif panel == nil then
\t\treturn
\tend
\tlocal equipment = panel:FindFirstChild("EquipmentSlots")
\tif equipment == nil or not equipment:IsA("Frame") then
\t\treturn
\tend
\tclearGenerated(equipment)
\tlocal weaponId = player:GetAttribute("LK_EquippedWeaponId")
\tlocal isSidearm = weaponId == FirearmConfig.ServicePistol.WeaponId
\tlocal primary = durableEquippedItem("Primary")
\tlocal secondary = durableEquippedItem("Secondary")
\tlocal armor = durableEquippedItem("Armor")
\tlocal relic = durableEquippedItem("Relic")
\tlocal primaryValue = if primary ~= nil
\t\tthen durableItemLabel(primary)
\t\telse if isSidearm then "Empty" else equippedWeaponName()
\tlocal secondaryValue = if secondary ~= nil
\t\tthen durableItemLabel(secondary)
\t\telse if isSidearm then equippedWeaponName() else "Empty"
\tequipmentSlot(equipment, "Head", "Empty", UDim2.fromOffset(8, 20))
\tequipmentSlot(equipment, "Chest", durableItemLabel(armor), UDim2.fromOffset(8, 94))
\tequipmentSlot(equipment, "Primary", primaryValue, UDim2.new(1, -140, 0, 20))
\tequipmentSlot(equipment, "Sidearm", secondaryValue, UDim2.new(1, -140, 0, 94))
\tequipmentSlot(equipment, "Melee", "Empty", UDim2.fromOffset(8, 168))
\tequipmentSlot(equipment, "Relic", durableItemLabel(relic), UDim2.new(1, -140, 0, 168))
end
'''
replace_once(old_rebuild_equipment, new_rebuild_equipment, "equipment rebuild")
replace_once(
    '''local function rebuildInventory()
''',
    '''local function durableInventorySlot(parent: Instance, order: number, item: any)
\tlocal slot = Instance.new("TextButton")
\tslot.Name = "Durable_" .. tostring(item.InstanceId)
\tslot.Size = UDim2.fromOffset(112, 104)
\tslot.BackgroundColor3 = COLORS.slot
\tslot.BorderSizePixel = 0
\tslot.LayoutOrder = order
\tslot.AutoButtonColor = item.Equipped ~= true
\tslot.Active = item.Equipped ~= true
\tslot.Text = ""
\tslot.Parent = parent
\tlocal border = if item.Rarity == "Rare"
\t\tthen Color3.fromRGB(94, 142, 255)
\t\telse if item.Rarity == "Uncommon" then COLORS.gold else Color3.fromRGB(111, 151, 112)
\tdecorate(slot, border)
\tlocal iconText = if item.Slot == "Primary" or item.Slot == "Secondary"
\t\tthen "⌁"
\t\telse if item.Slot == "Armor" then "▣" else "✦"
\tlocal itemIcon = label(slot, iconText, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 31), 23)
\titemIcon.TextXAlignment = Enum.TextXAlignment.Center
\titemIcon.TextColor3 = border
\tlocal itemName = label(slot, tostring(item.DisplayName), UDim2.fromOffset(6, 35), UDim2.new(1, -12, 0, 30), 10)
\titemName.TextXAlignment = Enum.TextXAlignment.Center
\titemName.TextWrapped = true
\tlocal meta = label(
\t\tslot,
\t\tstring.format("%s • P%d", tostring(item.Rarity), tonumber(item.Power) or 0),
\t\tUDim2.fromOffset(6, 65),
\t\tUDim2.new(1, -12, 0, 16),
\t\t9
\t)
\tmeta.TextXAlignment = Enum.TextXAlignment.Center
\tmeta.TextColor3 = COLORS.muted
\tlocal status = label(
\t\tslot,
\t\tif item.Equipped == true then "EQUIPPED" else "EQUIP",
\t\tUDim2.fromOffset(6, 82),
\t\tUDim2.new(1, -12, 0, 16),
\t\t10
\t)
\tstatus.TextXAlignment = Enum.TextXAlignment.Center
\tstatus.TextColor3 = if item.Equipped == true then COLORS.green else COLORS.gold
\tif item.Equipped ~= true and type(item.InstanceId) == "string" then
\t\tlocal instanceId = item.InstanceId
\t\tslot.Activated:Connect(function()
\t\t\tslot.Active = false
\t\t\ttask.spawn(function()
\t\t\t\tlocal ok, outcome = pcall(function()
\t\t\t\t\treturn inventoryEquipOwnedItem:InvokeServer(instanceId)
\t\t\t\tend)
\t\t\t\tif not ok or type(outcome) ~= "table" or outcome.Accepted ~= true then
\t\t\t\t\tslot.Active = true
\t\t\t\tend
\t\t\tend)
\t\tend)
\tend
end

local function rebuildInventory()
''',
    "durable inventory slot",
)
replace_once(
    '''\tif inventoryTitle ~= nil then
\t\tinventoryTitle.Text = string.format("BACKPACK   %d / %d   //   24-SLOT FIELD PACK", packUsed, packCapacity)
\tend
\tlocal order = 0
''',
    '''\tlocal durableItems = if type(latestDurableInventory) == "table" and type(latestDurableInventory.Items) == "table"
\t\tthen latestDurableInventory.Items
\t\telse {}
\tif inventoryTitle ~= nil then
\t\tinventoryTitle.Text = string.format("DURABLE GEAR   %d   //   FIELD PACK   %d / %d", #durableItems, packUsed, packCapacity)
\tend
\tlocal order = 0
\tfor _, item in durableItems do
\t\tif type(item) == "table" and type(item.InstanceId) == "string" then
\t\t\torder += 1
\t\t\tdurableInventorySlot(grid, order, item)
\t\tend
\tend
''',
    "durable inventory population",
)
replace_once(
    '''\t\tinventorySlot(grid, order, "⌁", weaponName, 1, "Rare")
\tend
\tfor index = order + 1, 24 do
''',
    '''\t\tinventorySlot(grid, order, "⌁", "RUN: " .. weaponName, 1, "Rare")
\tend
\tfor index = order + 1, 24 do
''',
    "run weapon label",
)
replace_once(
    '''\tgrid.CanvasSize = UDim2.fromOffset(0, math.ceil(24 / 5) * 116)
end
''',
    '''\tgrid.CanvasSize = UDim2.fromOffset(0, math.ceil(math.max(24, order) / 5) * 116)
end
''',
    "inventory canvas",
)
replace_once(
    '''\ttable.insert(
\t\tconnections,
\t\tprogressionStateRemote.OnClientEvent:Connect(function(snapshot)
''',
    '''\ttable.insert(
\t\tconnections,
\t\tinventoryStateRemote.OnClientEvent:Connect(function(result)
\t\t\tif type(result) == "table" and result.Accepted == true and type(result.Snapshot) == "table" then
\t\t\t\tlatestDurableInventory = result.Snapshot
\t\t\t\trebuildEquipment()
\t\t\t\trebuildInventory()
\t\t\tend
\t\tend)
\t)
\ttable.insert(
\t\tconnections,
\t\tprogressionStateRemote.OnClientEvent:Connect(function(snapshot)
''',
    "durable state connection",
)
replace_once(
    '''\tlocal survivalOk, survivalSnapshot = pcall(function()
''',
    '''\tlocal inventoryOk, inventoryResult = pcall(function()
\t\treturn inventoryReadOwn:InvokeServer()
\tend)
\tif
\t\tinventoryOk
\t\tand type(inventoryResult) == "table"
\t\tand inventoryResult.Accepted == true
\t\tand type(inventoryResult.Snapshot) == "table"
\tthen
\t\tlatestDurableInventory = inventoryResult.Snapshot
\tend
\tlocal survivalOk, survivalSnapshot = pcall(function()
''',
    "initial durable inventory read",
)
replace_once(
    '''\tlatestSurvival = nil
\tlatestProgression = nil
end
''',
    '''\tlatestSurvival = nil
\tlatestProgression = nil
\tlatestDurableInventory = nil
end
''',
    "durable teardown",
)

PATH.write_text(source)
print("Applied durable inventory RPG menu patch")
