--!strict

-- Terminal-only return control. It cannot stop an active expedition: the server
-- validates lobby membership and terminal outcome before teardown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local player = Players.LocalPlayer
local resultNetwork = ReplicatedStorage:WaitForChild("ExpeditionResultNetwork")
local resultState = resultNetwork:WaitForChild("State") :: RemoteEvent
local resultRead = resultNetwork:WaitForChild("ReadState") :: RemoteFunction
local lobbyRequest = ReplicatedStorage:WaitForChild("ExpeditionLobbyNetwork"):WaitForChild("Request") :: RemoteFunction

local started = false
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local button: TextButton? = nil
local requestInFlight = false

local function createGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "LK_ExpeditionReturn"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 23
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen

	local returnButton = Instance.new("TextButton")
	returnButton.AnchorPoint = Vector2.new(0.5, 1)
	returnButton.Position = UDim2.new(0.5, 0, 1, -54)
	returnButton.Size = UDim2.fromOffset(250, 48)
	returnButton.BackgroundColor3 = Color3.fromRGB(44, 74, 96)
	returnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	returnButton.Font = Enum.Font.GothamBold
	returnButton.TextSize = 17
	returnButton.Text = "RETURN TO LOBBY"
	returnButton.Parent = screen
	button = returnButton

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = returnButton

	returnButton.Activated:Connect(function()
		if requestInFlight then return end
		requestInFlight = true
		returnButton.Active = false
		returnButton.Text = "RETURNING..."
		local ok, result = pcall(function()
			return lobbyRequest:InvokeServer("ReturnToLobby")
		end)
		requestInFlight = false
		if ok and type(result) == "table" and result.Accepted == true then
			screen.Enabled = false
		else
			returnButton.Active = true
			returnButton.Text = "RETURN TO LOBBY"
		end
	end)
end

local function receive(summary: any)
	if gui == nil or button == nil then return end
	local terminal = type(summary) == "table"
		and (summary.OutcomeId == "Completed" or summary.OutcomeId == "Failed" or summary.OutcomeId == "Abandoned")
	gui.Enabled = terminal
	if terminal then
		button.Active = true
		button.Text = "RETURN TO LOBBY"
	end
end

function Controller.start()
	if started then return end
	started = true
	createGui()
	connection = resultState.OnClientEvent:Connect(receive)
	local ok, initial = pcall(function() return resultRead:InvokeServer() end)
	if ok then receive(initial) end
end

function Controller.stop()
	if not started then return end
	started = false
	if connection then connection:Disconnect(); connection = nil end
	if gui then gui:Destroy(); gui = nil end
end

return Controller
