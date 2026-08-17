--!strict

-- Minimal expedition lobby UI. The client can request only its own membership and
-- ready state; the server validates every request and exclusively decides launch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local PANEL_WIDTH = 390
local PANEL_HEIGHT = 330
local PANEL_VIEWPORT_MARGIN = 24

local ResponsivePanelScale = require(script.Parent.Parent.Presentation.ResponsivePanelScale)

local Controller = {}
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("ExpeditionLobbyNetwork", NETWORK_WAIT_SECONDS)
assert(network ~= nil, "ExpeditionLobbyNetwork did not become available before the client bootstrap timeout")
local request = network:WaitForChild("Request", NETWORK_WAIT_SECONDS) :: RemoteFunction?
assert(request ~= nil, "ExpeditionLobbyNetwork.Request did not become available before the client bootstrap timeout")
local stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(stateRemote ~= nil, "ExpeditionLobbyNetwork.State did not become available before the client bootstrap timeout")
local readState = network:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?
assert(
	readState ~= nil,
	"ExpeditionLobbyNetwork.ReadState did not become available before the client bootstrap timeout"
)

local started = false
local connection: RBXScriptConnection? = nil
local scaleConnection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local membersLabel: TextLabel? = nil
local actionButton: TextButton? = nil
local leaveButton: TextButton? = nil
local currentSnapshot: any = nil
local requestInFlight = false

local function validSnapshot(value: any): boolean
	return type(value) == "table"
		and type(value.Members) == "table"
		and type(value.MemberCount) == "number"
		and type(value.MinimumPlayers) == "number"
		and type(value.MaximumPlayers) == "number"
		and type(value.AllReady) == "boolean"
		and type(value.LaunchPending) == "boolean"
end

local function localMember(snapshot: any): any
	for _, member in snapshot.Members do
		if member.PlayerId == player.UserId then
			return member
		end
	end
	return nil
end

local function createLabel(parent: Instance, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.Gotham
	label.TextSize = textSize
	label.TextColor3 = Color3.fromRGB(235, 240, 245)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = parent
	return label
end

local function createButton(parent: Instance, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(180, 42)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(44, 74, 96)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local function createGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "LK_ExpeditionLobby"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 18
	local playerGui = player:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	screen.Parent = playerGui
	gui = screen

	local viewportProbe = Instance.new("Frame")
	viewportProbe.Name = "ViewportProbe"
	viewportProbe.Size = UDim2.fromScale(1, 1)
	viewportProbe.BackgroundTransparency = 1
	viewportProbe.BorderSizePixel = 0
	viewportProbe.Parent = screen

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, PANEL_VIEWPORT_MARGIN, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.BackgroundColor3 = Color3.fromRGB(18, 25, 32)
	panel.BackgroundTransparency = 0.08
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "ResponsiveScale"
	panelScale.Parent = panel
	local function updatePanelScale()
		local viewport = viewportProbe.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		panelScale.Scale =
			ResponsivePanelScale.calculate(viewport.X, viewport.Y, PANEL_WIDTH, PANEL_HEIGHT, PANEL_VIEWPORT_MARGIN)
	end
	updatePanelScale()
	scaleConnection = viewportProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePanelScale)

	local title = createLabel(panel, UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 14), 22)
	title.Font = Enum.Font.GothamBold
	title.Text = "EXPEDITION LOBBY"

	statusLabel = createLabel(panel, UDim2.new(1, -32, 0, 48), UDim2.fromOffset(16, 58), 15)
	membersLabel = createLabel(panel, UDim2.new(1, -32, 0, 145), UDim2.fromOffset(16, 108), 15)
	actionButton = createButton(panel, "JOIN", UDim2.new(0, 16, 1, -58))
	leaveButton = createButton(panel, "LEAVE", UDim2.new(1, -196, 1, -58))

	actionButton.Activated:Connect(function()
		if requestInFlight or currentSnapshot == nil then
			return
		end
		requestInFlight = true
		local member = localMember(currentSnapshot)
		local ok, result = pcall(function()
			if member == nil then
				return request:InvokeServer("Join")
			end
			return request:InvokeServer("SetReady", { Ready = not member.Ready })
		end)
		requestInFlight = false
		if ok and type(result) == "table" and validSnapshot(result.Snapshot) then
			currentSnapshot = result.Snapshot
		end
	end)

	leaveButton.Activated:Connect(function()
		if requestInFlight then
			return
		end
		requestInFlight = true
		pcall(function()
			request:InvokeServer("Leave")
		end)
		requestInFlight = false
	end)
end

local function render(snapshot: any)
	currentSnapshot = snapshot
	if gui == nil or statusLabel == nil or membersLabel == nil or actionButton == nil or leaveButton == nil then
		return
	end
	local member = localMember(snapshot)
	statusLabel.Text = string.format(
		"Party %d/%d  •  Minimum %d",
		snapshot.MemberCount,
		snapshot.MaximumPlayers,
		snapshot.MinimumPlayers
	)
	if snapshot.LaunchPending then
		statusLabel.Text ..= "\nLaunching expedition..."
	elseif snapshot.AllReady then
		statusLabel.Text ..= "\nAll operatives ready"
	else
		statusLabel.Text ..= "\nWaiting for ready operatives"
	end

	local lines = {}
	for _, entry in snapshot.Members do
		table.insert(
			lines,
			string.format("%s  —  %s", entry.DisplayName, if entry.Ready then "READY" else "NOT READY")
		)
	end
	if #lines == 0 then
		table.insert(lines, "No operatives have joined.")
	end
	membersLabel.Text = table.concat(lines, "\n")

	actionButton.Text = if member == nil then "JOIN" elseif member.Ready then "UNREADY" else "READY"
	actionButton.Active = not snapshot.LaunchPending
	leaveButton.Visible = member ~= nil
	leaveButton.Active = member ~= nil and not snapshot.LaunchPending
end

function Controller.start()
	if started then
		return
	end
	started = true
	createGui()
	connection = stateRemote.OnClientEvent:Connect(function(snapshot)
		if validSnapshot(snapshot) then
			render(snapshot)
		end
	end)
	local ok, snapshot = pcall(function()
		return readState:InvokeServer()
	end)
	if ok and validSnapshot(snapshot) then
		render(snapshot)
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if scaleConnection then
		scaleConnection:Disconnect()
		scaleConnection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return Controller
