--!strict

-- Client presentation for server-owned insertion loadout choice. The only
-- mutation request contains one request ID and one configured weapon ID.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local WeaponLoadoutContracts = require(ReplicatedStorage.Shared.Weapons.WeaponLoadoutContracts)

local Controller = {}
local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("WeaponLoadoutNetwork")
local intentRemote = network:WaitForChild("SelectionIntent") :: RemoteEvent
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local readState = network:WaitForChild("ReadState") :: RemoteFunction

local started = false
local requestSequence = 0
local lastRevision = -1
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local buttons: { [string]: TextButton } = {}
local latestSnapshot: WeaponLoadoutContracts.SafeSnapshot? = nil

local function requestWeapon(weaponId: string)
	local snapshot = latestSnapshot
	if snapshot == nil or snapshot.selectionStateId ~= WeaponLoadoutContracts.SelectionStateIds.Open then
		return
	end
	requestSequence += 1
	intentRemote:FireServer({
		requestId = string.format("weapon-loadout:%d:%d", localPlayer.UserId, requestSequence),
		weaponId = weaponId,
	})
end

local function updatePresentation()
	local snapshot = latestSnapshot
	if snapshot == nil or panel == nil or statusLabel == nil then
		return
	end
	local selectedId = if snapshot.ownerAssignment == nil then nil else snapshot.ownerAssignment.weaponId
	local selected = FirearmConfig.get(selectedId)
	if snapshot.selectionStateId == WeaponLoadoutContracts.SelectionStateIds.Open then
		panel.Visible = true
		statusLabel.Text = "CHOOSE LOADOUT — applies when insertion locks\nCurrent: "
			.. (if selected == nil then "Unassigned" else selected.DisplayName)
		for weaponId, button in buttons do
			local definition = FirearmConfig.get(weaponId)
			if definition ~= nil then
				button.Visible = true
				button.Text = if weaponId == selectedId
					then "✓ " .. definition.ShortName .. " — SELECTED"
					else definition.ShortName .. "\n" .. definition.RoleDescription
			end
		end
	else
		statusLabel.Text = "LOADOUT LOCKED: " .. (if selected == nil then "Unknown" else selected.DisplayName)
		for _, button in buttons do
			button.Visible = false
		end
		panel.Size = UDim2.fromOffset(360, 92)
	end
end

local function onPayload(payload: unknown)
	if not WeaponLoadoutContracts.validateSafeSnapshot(payload) then
		return
	end
	local snapshot = payload :: WeaponLoadoutContracts.SafeSnapshot
	if snapshot.rosterRevision < lastRevision then
		return
	end
	lastRevision = snapshot.rosterRevision
	latestSnapshot = snapshot
	updatePresentation()
end

local function createPresentation()
	local createdGui = Instance.new("ScreenGui")
	createdGui.Name = "WeaponLoadoutSelectionUI"
	createdGui.ResetOnSpawn = false
	createdGui.DisplayOrder = 14

	local frame = Instance.new("Frame")
	frame.Name = "LoadoutPanel"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -18, 0.5, 0)
	frame.Size = UDim2.fromOffset(360, 382)
	frame.BackgroundColor3 = Color3.fromRGB(15, 18, 21)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = createdGui
	panel = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 28)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "WEAPON LOADOUT"
	title.TextColor3 = Color3.fromRGB(244, 239, 222)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(16, 40)
	status.Size = UDim2.new(1, -32, 0, 50)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.Text = "Loading server loadout…"
	status.TextColor3 = Color3.fromRGB(210, 214, 207)
	status.TextSize = 14
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = frame
	statusLabel = status

	for index, weaponId in FirearmConfig.SelectableWeaponIds do
		local definition = FirearmConfig.get(weaponId)
		assert(definition ~= nil, "selectable weapon requires definition")
		local button = Instance.new("TextButton")
		button.Name = "WeaponOption" .. tostring(index)
		button.Position = UDim2.fromOffset(16, 94 + (index - 1) * 56)
		button.Size = UDim2.new(1, -32, 0, 50)
		button.BackgroundColor3 = Color3.fromRGB(42, 49, 55)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.Text = definition.ShortName .. "\n" .. definition.RoleDescription
		button.TextColor3 = Color3.fromRGB(244, 246, 240)
		button.TextSize = 13
		button.TextWrapped = true
		button.Parent = frame
		button.Activated:Connect(function()
			requestWeapon(weaponId)
		end)
		buttons[weaponId] = button
	end

	createdGui.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = createdGui
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	connection = stateRemote.OnClientEvent:Connect(onPayload)
	local succeeded, snapshot = pcall(function()
		return readState:InvokeServer()
	end)
	if succeeded then
		onPayload(snapshot)
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
	panel = nil
	statusLabel = nil
	table.clear(buttons)
	latestSnapshot = nil
	lastRevision = -1
	requestSequence = 0
end

return table.freeze(Controller)
