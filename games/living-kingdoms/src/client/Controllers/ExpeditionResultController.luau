--!strict

-- Read-only expedition debrief. It renders only the server-finalized summary and
-- equipment disclosures. It sends no request that can mutate rewards or results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local PANEL_WIDTH = 680
local PANEL_HEIGHT = 430
local PANEL_VIEWPORT_MARGIN = 24

local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)
local ResponsivePanelScale = require(script.Parent.Parent.Presentation.ResponsivePanelScale)

local Controller = {}
local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("ExpeditionResultNetwork", NETWORK_WAIT_SECONDS)
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local readState = network:WaitForChild("ReadState") :: RemoteFunction

local started = false
local connection: RBXScriptConnection? = nil
local scaleConnection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local headline: TextLabel? = nil
local summary: TextLabel? = nil
local rewardsLabel: TextLabel? = nil
local details: TextLabel? = nil

local VALID_OUTCOMES = {
	Completed = true,
	Failed = true,
	Abandoned = true,
}
local VALID_REWARD_DISPOSITIONS = {
	Banked = true,
	Forfeited = true,
}

local VALID_SLOTS = { Primary = true, Secondary = true, Armor = true, Relic = true }
local VALID_RARITIES = { Common = true, Uncommon = true, Rare = true }
local VALID_SOURCES = { Elite = true, Boss = true }

local function validReward(reward: any): boolean
	return type(reward) == "table"
		and type(reward.DisplayName) == "string"
		and #reward.DisplayName > 0
		and VALID_SLOTS[reward.Slot] == true
		and VALID_RARITIES[reward.Rarity] == true
		and VALID_SOURCES[reward.SourceId] == true
		and type(reward.Power) == "number"
		and reward.Power % 1 == 0
		and reward.Power >= 1
end

local function validSnapshot(payload: any): boolean
	if
		type(payload) ~= "table"
		or type(payload.RunId) ~= "string"
		or VALID_OUTCOMES[payload.OutcomeId] ~= true
		or VALID_REWARD_DISPOSITIONS[payload.RewardDispositionId] ~= true
		or type(payload.DurationSeconds) ~= "number"
		or payload.DurationSeconds < 0
		or type(payload.PartySize) ~= "number"
		or type(payload.SecretDiscovered) ~= "boolean"
		or type(payload.Rewards) ~= "table"
	then
		return false
	end
	for _, reward in payload.Rewards do
		if not validReward(reward) then
			return false
		end
	end
	return true
end

local function createGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("LK_ExpeditionResult")
	if existing then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "LK_ExpeditionResult"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 22
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	local backdrop = InterfaceTheme.backdrop(screen)
	local panel = InterfaceTheme.panel(screen, "ResultPanel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	InterfaceTheme.padding(panel, InterfaceTheme.Spacing.XLarge)

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "ResponsiveScale"
	panelScale.Parent = panel
	local function updatePanelScale()
		local viewport = backdrop.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		panelScale.Scale = ResponsivePanelScale.calculate(
			viewport.X,
			viewport.Y,
			PANEL_WIDTH,
			PANEL_HEIGHT,
			PANEL_VIEWPORT_MARGIN
		)
	end
	updatePanelScale()
	scaleConnection = backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePanelScale)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, InterfaceTheme.Spacing.Medium)
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
	summary.Size = UDim2.new(1, 0, 0, 58)

	rewardsLabel = InterfaceTheme.label(panel, {
		name = "Rewards",
		role = "Body",
		size = InterfaceTheme.TextSize.Subtitle,
	})
	rewardsLabel.Size = UDim2.new(1, 0, 0, 120)

	details = InterfaceTheme.label(panel, {
		name = "Details",
		role = "Body",
		size = InterfaceTheme.TextSize.Subtitle,
		color = InterfaceTheme.Palette.TextMuted,
	})
	details.Size = UDim2.new(1, 0, 0, 100)
end

local function formatDuration(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function formatRewards(rewards: { any }, rewardDispositionId: string): string
	if #rewards == 0 then
		if rewardDispositionId == "Forfeited" then
			return "RUN LOOT FORFEITED\nNo equipment was carried out of the failed run."
		end
		return "REWARDS\nNo equipment rewards were secured."
	end
	local lines = {
		if rewardDispositionId == "Forfeited" then "EQUIPMENT FORFEITED" else "EQUIPMENT SECURED",
	}
	for _, reward in rewards do
		table.insert(
			lines,
			string.format(
				"%s — %s %s  •  %s  •  Power %d",
				reward.SourceId,
				reward.Rarity,
				reward.DisplayName,
				reward.Slot,
				reward.Power
			)
		)
	end
	if rewardDispositionId == "Forfeited" then
		table.insert(lines, "These run rewards were not added to your durable inventory.")
	end
	return table.concat(lines, "\n")
end

local function applySnapshot(snapshot: any)
	if gui == nil or headline == nil or summary == nil or rewardsLabel == nil or details == nil then
		return
	end

	gui.Enabled = true
	if snapshot.OutcomeId == "Completed" then
		headline.Text = "EXPEDITION COMPLETE"
		summary.Text = "The Keeper has fallen and the descent is secure."
	elseif snapshot.OutcomeId == "Failed" then
		headline.Text = "EXPEDITION FAILED"
		summary.Text = "The squad could not complete the descent. Unbanked run equipment was lost."
	else
		headline.Text = "EXPEDITION ABANDONED"
		summary.Text = "The run ended before the objective was completed. Unbanked run equipment was lost."
	end

	rewardsLabel.Text = formatRewards(snapshot.Rewards, snapshot.RewardDispositionId)
	local secretText = if snapshot.SecretDiscovered then "Secret reliquary discovered" else "Secret reliquary not found"
	details.Text = string.format(
		"Duration: %s  •  Party: %d\n%s\nRun: %s\n\nReturn to preparation to begin another seeded expedition.",
		formatDuration(snapshot.DurationSeconds),
		snapshot.PartySize,
		secretText,
		snapshot.RunId
	)
end

local function receive(payload: any)
	if payload == nil then
		if gui then
			gui.Enabled = false
		end
		return
	end
	if validSnapshot(payload) then
		applySnapshot(payload)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createGui()
	connection = stateRemote.OnClientEvent:Connect(receive)
	local ok, initial = pcall(function()
		return readState:InvokeServer()
	end)
	if ok then
		receive(initial)
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
