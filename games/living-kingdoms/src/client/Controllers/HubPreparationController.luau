--!strict

-- Client-only presentation router for the forward operations hub. The hub owns
-- no gameplay mutation: it merely reveals existing class/loadout/lobby UIs.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

local function playerGui(): PlayerGui
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

local function setHubUiEnabled(guiName: string, enabled: boolean)
	local candidate = playerGui():FindFirstChild(guiName)
	if candidate ~= nil and candidate:IsA("ScreenGui") then
		candidate.Enabled = enabled
	end
end

local function closeHubUi()
	for _, guiName in UI_BY_ACTION do
		setHubUiEnabled(guiName, false)
	end
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
	setHubUiEnabled(guiName, true)
end

function Controller.start()
	if started then
		return
	end
	started = true
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

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
				closeHubUi()
			end
		end)
	)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	runActive = false
	closeHubUi()
end

return table.freeze(Controller)
