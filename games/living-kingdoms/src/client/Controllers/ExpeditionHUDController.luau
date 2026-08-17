--!strict

-- Read-only expedition HUD. The client validates presentation fields, renders
-- phase/objective/progress, and sends no gameplay or completion request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local PANEL_MAX_WIDTH = 520
local PANEL_HEIGHT = 132
local PANEL_HORIZONTAL_MARGIN = 16

local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)

local Controller = {}
local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("ExpeditionNetwork", NETWORK_WAIT_SECONDS)
assert(network ~= nil, "ExpeditionNetwork did not become available before the client bootstrap timeout")
local stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS)
assert(stateRemote ~= nil, "ExpeditionNetwork.State did not become available before the client bootstrap timeout")
local readState = network:WaitForChild("ReadState", NETWORK_WAIT_SECONDS)
assert(readState ~= nil, "ExpeditionNetwork.ReadState did not become available before the client bootstrap timeout")

local started = false
local connection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local phaseLabel: TextLabel? = nil
local objectiveLabel: TextLabel? = nil
local progressLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil

local PHASE_DISPLAY: { [string]: string } = {
	Preparation = "PREPARATION",
	Approach = "THE APPROACH",
	Dungeon = "THE DESCENT",
	Elite = "WARDEN",
	Boss = "KEEPER",
	Rewards = "REWARDS",
	Results = "RESULTS",
}

local function validSnapshot(value: any): boolean
	return type(value) == "table"
		and type(value.RunId) == "string"
		and type(value.PhaseId) == "string"
		and type(value.PhaseIndex) == "number"
		and value.PhaseIndex % 1 == 0
		and type(value.PhaseCount) == "number"
		and value.PhaseCount % 1 == 0
		and value.PhaseIndex >= 1
		and value.PhaseIndex <= value.PhaseCount
		and type(value.OutcomeId) == "string"
		and type(value.PartySize) == "number"
		and value.PartySize % 1 == 0
		and type(value.SecretDiscovered) == "boolean"
		and type(value.ObjectiveText) == "string"
end

local function createGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	local existing = playerGui:FindFirstChild("LK_ExpeditionHUD")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LK_ExpeditionHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = playerGui
	screenGui = gui

	local panel = InterfaceTheme.panel(gui, "ExpeditionPanel")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.025)
	panel.Size = UDim2.new(1, -PANEL_HORIZONTAL_MARGIN * 2, 0, PANEL_HEIGHT)
	InterfaceTheme.padding(panel, InterfaceTheme.Spacing.Medium)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(PANEL_MAX_WIDTH, PANEL_HEIGHT)
	sizeConstraint.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, InterfaceTheme.Spacing.XSmall)
	layout.Parent = panel

	phaseLabel = InterfaceTheme.label(panel, {
		name = "Phase",
		role = "Heading",
		size = InterfaceTheme.TextSize.Title,
		color = InterfaceTheme.Palette.Accent,
		xAlign = Enum.TextXAlignment.Center,
	})
	phaseLabel.Size = UDim2.new(1, 0, 0, 26)
	phaseLabel.LayoutOrder = 1

	objectiveLabel = InterfaceTheme.label(panel, {
		name = "Objective",
		role = "Body",
		size = InterfaceTheme.TextSize.Subtitle,
		xAlign = Enum.TextXAlignment.Center,
	})
	objectiveLabel.Size = UDim2.new(1, 0, 0, 42)
	objectiveLabel.LayoutOrder = 2

	progressLabel = InterfaceTheme.label(panel, {
		name = "Progress",
		role = "Body",
		size = InterfaceTheme.TextSize.Caption,
		color = InterfaceTheme.Palette.TextMuted,
		xAlign = Enum.TextXAlignment.Center,
	})
	progressLabel.Size = UDim2.new(1, 0, 0, 20)
	progressLabel.LayoutOrder = 3

	detailLabel = InterfaceTheme.label(panel, {
		name = "Details",
		role = "Body",
		size = InterfaceTheme.TextSize.Caption,
		color = InterfaceTheme.Palette.TextMuted,
		xAlign = Enum.TextXAlignment.Center,
	})
	detailLabel.Size = UDim2.new(1, 0, 0, 18)
	detailLabel.LayoutOrder = 4
end

local function hide()
	if screenGui ~= nil then
		screenGui.Enabled = false
	end
end

local function render(payload: any)
	if payload == nil then
		hide()
		return
	end
	if not validSnapshot(payload) then
		return
	end
	if screenGui == nil then
		createGui()
	end
	local phase = PHASE_DISPLAY[payload.PhaseId] or string.upper(payload.PhaseId)
	phaseLabel.Text = phase
	objectiveLabel.Text = payload.ObjectiveText
	progressLabel.Text =
		string.format("PHASE %d OF %d  •  %s", payload.PhaseIndex, payload.PhaseCount, payload.OutcomeId)
	detailLabel.Text = string.format(
		"PARTY %d  •  SECRET %s",
		payload.PartySize,
		if payload.SecretDiscovered then "DISCOVERED" else "UNDISCOVERED"
	)
	screenGui.Enabled = true
end

function Controller.start()
	if started then
		return
	end
	started = true
	createGui()
	connection = stateRemote.OnClientEvent:Connect(render)
	local ok, snapshot = pcall(function()
		return readState:InvokeServer()
	end)
	if ok then
		render(snapshot)
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
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	phaseLabel = nil
	objectiveLabel = nil
	progressLabel = nil
	detailLabel = nil
end

return table.freeze(Controller)
