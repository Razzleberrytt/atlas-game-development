--!strict

-- Read-only expedition debrief. It listens to the sanitized expedition snapshot,
-- renders terminal outcome facts, and sends no request back to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)

local Controller = {}
local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("ExpeditionNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent

local started = false
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local headline: TextLabel? = nil
local summary: TextLabel? = nil
local details: TextLabel? = nil

local VALID_OUTCOMES = {
	Completed = true,
	Failed = true,
	Abandoned = true,
}

local function validSnapshot(payload: any): boolean
	return type(payload) == "table"
		and type(payload.RunId) == "string"
		and type(payload.PhaseId) == "string"
		and type(payload.OutcomeId) == "string"
		and type(payload.PartySize) == "number"
		and type(payload.SecretDiscovered) == "boolean"
end

local function createGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("LK_ExpeditionResult")
	if existing then existing:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "LK_ExpeditionResult"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 22
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	InterfaceTheme.backdrop(screen)
	local panel = InterfaceTheme.panel(screen, "ResultPanel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(620, 330)
	InterfaceTheme.padding(panel, InterfaceTheme.Spacing.XLarge)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, InterfaceTheme.Spacing.Large)
	layout.Parent = panel

	headline = InterfaceTheme.label(panel, {
		name = "Headline",
		role = "Display",
		size = InterfaceTheme.TextSize.Display,
		color = InterfaceTheme.Palette.Accent,
	})
	headline.Size = UDim2.new(1, 0, 0, 50)

	summary = InterfaceTheme.label(panel, {
		name = "Summary",
		role = "Heading",
		size = InterfaceTheme.TextSize.Title,
	})
	summary.Size = UDim2.new(1, 0, 0, 64)

	details = InterfaceTheme.label(panel, {
		name = "Details",
		role = "Body",
		size = InterfaceTheme.TextSize.Subtitle,
		color = InterfaceTheme.Palette.TextMuted,
	})
	details.Size = UDim2.new(1, 0, 0, 120)
end

local function applySnapshot(snapshot: any)
	if gui == nil or headline == nil or summary == nil or details == nil then return end
	if not VALID_OUTCOMES[snapshot.OutcomeId] then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	if snapshot.OutcomeId == "Completed" then
		headline.Text = "EXPEDITION COMPLETE"
		summary.Text = "The Keeper has fallen and the descent is secure."
	elseif snapshot.OutcomeId == "Failed" then
		headline.Text = "EXPEDITION FAILED"
		summary.Text = "The squad could not complete the descent."
	else
		headline.Text = "EXPEDITION ABANDONED"
		summary.Text = "The run ended before the objective was completed."
	end

	local secretText = if snapshot.SecretDiscovered then "Secret reliquary discovered" else "Secret reliquary not found"
	details.Text = string.format(
		"Party size: %d\n%s\nRun: %s\n\nReturn to preparation to begin another seeded expedition.",
		snapshot.PartySize,
		secretText,
		snapshot.RunId
	)
end

function Controller.start()
	if started then return end
	started = true
	createGui()
	connection = stateRemote.OnClientEvent:Connect(function(payload)
		if payload == nil then
			if gui then gui.Enabled = false end
			return
		end
		if validSnapshot(payload) then applySnapshot(payload) end
	end)
end

function Controller.stop()
	if not started then return end
	started = false
	if connection then connection:Disconnect(); connection = nil end
	if gui then gui:Destroy(); gui = nil end
end

return Controller
