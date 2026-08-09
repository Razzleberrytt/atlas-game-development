--!strict

-- Client-only presentation router for the forward operations hub. The hub owns
-- no gameplay mutation: it merely reveals existing class/loadout/lobby UIs.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local player = Players.LocalPlayer

local UI_BY_ACTION = table.freeze({
	OpenClass = "TemporaryClassSelectionUI",
	OpenWeapon = "WeaponLoadoutSelectionUI",
	OpenExpedition = "LK_ExpeditionLobby",
})

local started = false
local runActive = false
local connections: { RBXScriptConnection } = {}
local closeAffordanceGui: ScreenGui? = nil
local closeAffordanceButton: TextButton? = nil

local function playerGui(): PlayerGui
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

local function setHubUiEnabled(guiName: string, enabled: boolean): boolean
	local candidate = playerGui():FindFirstChild(guiName)
	if candidate ~= nil and candidate:IsA("ScreenGui") then
		candidate.Enabled = enabled
		return true
	end
	return false
end

local function setCloseAffordanceVisible(visible: boolean)
	local button = closeAffordanceButton
	if button ~= nil then
		button.Visible = visible
	end
end

local function closeHubUi()
	for _, guiName in UI_BY_ACTION do
		setHubUiEnabled(guiName, false)
	end
	setCloseAffordanceVisible(false)
end

local function createCloseAffordance()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HubCloseAffordance"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 95

	local button = Instance.new("TextButton")
	button.Name = "Close"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -18, 0, 18)
	button.Size = UDim2.fromOffset(126, 42)
	button.BackgroundColor3 = Color3.fromRGB(38, 42, 45)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Active = true
	button.Selectable = true
	button.Font = Enum.Font.GothamBold
	button.Text = "CLOSE"
	button.TextColor3 = Color3.fromRGB(244, 244, 238)
	button.TextSize = 14
	button.Visible = false
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(190, 163, 102)
	stroke.Transparency = 0.25
	stroke.Parent = button

	table.insert(connections, button.Activated:Connect(closeHubUi))
	gui.Parent = playerGui()
	closeAffordanceGui = gui
	closeAffordanceButton = button
end

local function applyExpeditionState(snapshot: any)
	runActive = type(snapshot) == "table" and snapshot.OutcomeId == "InProgress"
	if runActive then
		closeHubUi()
	end
end

local function openAction(actionId: string)
	if runActive then
		return
	end
	local guiName = UI_BY_ACTION[actionId]
	if guiName == nil then
		return
	end
	closeHubUi()
	if setHubUiEnabled(guiName, true) then
		setCloseAffordanceVisible(true)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createCloseAffordance()
	closeHubUi()

	local expeditionNetwork = ReplicatedStorage:WaitForChild("ExpeditionNetwork")
	local expeditionState = expeditionNetwork:WaitForChild("State") :: RemoteEvent
	local expeditionReadState = expeditionNetwork:WaitForChild("ReadState") :: RemoteFunction
	table.insert(connections, expeditionState.OnClientEvent:Connect(applyExpeditionState))
	local stateOk, snapshot = pcall(function()
		return expeditionReadState:InvokeServer()
	end)
	if stateOk then
		applyExpeditionState(snapshot)
	end

	table.insert(
		connections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt)
			local parent = prompt.Parent
			if parent == nil or not parent:IsA("BasePart") then
				return
			end
			if parent:GetAttribute("LK_PresentationOnly") ~= true then
				return
			end
			local actionId = parent:GetAttribute("LK_HubAction")
			if type(actionId) ~= "string" then
				return
			end
			openAction(actionId)
		end)
	)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	closeHubUi()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if closeAffordanceGui ~= nil then
		closeAffordanceGui:Destroy()
		closeAffordanceGui = nil
	end
	closeAffordanceButton = nil
	runActive = false
end

return table.freeze(Controller)
