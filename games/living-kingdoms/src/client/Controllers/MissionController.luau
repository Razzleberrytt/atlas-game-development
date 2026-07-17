--!strict

--[[
	Temporary P5-0103 mission presentation. Renders only the server-disclosed
	safe mission snapshot: current objective, extraction availability, the
	holdout countdown, placeholder radio transmissions, and the final outcome.
	The client sends nothing through this controller and no displayed value is
	ever echoed back as authority.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)

type SafeMissionSnapshot = MissionContracts.SafeMissionSnapshot

type Controller = { start: () -> (), stop: () -> () }

local RADIO_VISIBLE_SECONDS = 6

local Controller: Controller = {} :: Controller
local localPlayer = Players.LocalPlayer
local stateRemote = ReplicatedStorage:WaitForChild("MissionNetwork"):WaitForChild("State") :: RemoteEvent

local started = false
local connections: { RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local objectiveLabel: TextLabel? = nil
local radioLabel: TextLabel? = nil
local countdownLabel: TextLabel? = nil
local outcomeLabel: TextLabel? = nil
local latestSnapshot: SafeMissionSnapshot? = nil
local displayedRadioTimestamp: number? = nil

local function createLabel(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.Size = size
	label.BackgroundColor3 = Color3.fromRGB(18, 21, 24)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 238, 235)
	label.TextSize = textSize
	label.TextWrapped = true
	label.Visible = false
	label.Parent = parent
	return label
end

local function updatePresentation()
	local snapshot = latestSnapshot
	local objective = objectiveLabel
	local radio = radioLabel
	local outcome = outcomeLabel
	if snapshot == nil or objective == nil or radio == nil or outcome == nil then
		return
	end
	local extraction = if snapshot.extractionUnlocked and snapshot.phaseId ~= "Resolved"
		then "  |  EXTRACTION AVAILABLE"
		else ""
	objective.Text = "OBJECTIVE: " .. snapshot.objectiveText .. extraction
	objective.Visible = true
	local transmission = snapshot.radio
	if transmission ~= nil and transmission.serverTimestamp ~= displayedRadioTimestamp then
		displayedRadioTimestamp = transmission.serverTimestamp
		radio.Text = "RADIO: " .. transmission.text
		radio.Visible = true
	end
	if snapshot.phaseId == "Resolved" and snapshot.outcomeId ~= nil then
		outcome.Text = if snapshot.outcomeId == "Success" then "MISSION SUCCESS" else "MISSION FAILURE"
		outcome.TextColor3 = if snapshot.outcomeId == "Success"
			then Color3.fromRGB(126, 214, 129)
			else Color3.fromRGB(224, 96, 78)
		outcome.Visible = true
	else
		outcome.Visible = false
	end
end

local function updateCountdown()
	local snapshot = latestSnapshot
	local countdown = countdownLabel
	local radio = radioLabel
	if countdown == nil then
		return
	end
	local deadline = if snapshot == nil then nil else snapshot.holdoutDeadlineServerTimestamp
	if snapshot ~= nil and snapshot.phaseId == "Holdout" and deadline ~= nil then
		local remaining = math.max(0, deadline - Workspace:GetServerTimeNow())
		countdown.Text = string.format("EXTRACTION IN %d:%04.1f", remaining // 60, remaining % 60)
		countdown.Visible = true
	else
		countdown.Visible = false
	end
	local displayed = displayedRadioTimestamp
	if radio ~= nil and radio.Visible and displayed ~= nil then
		if Workspace:GetServerTimeNow() - displayed > RADIO_VISIBLE_SECONDS then
			radio.Visible = false
		end
	end
end

local function onSnapshot(payload: unknown)
	if not MissionContracts.validateSafeMissionSnapshot(payload) then
		return
	end
	local snapshot = payload :: SafeMissionSnapshot
	local previous = latestSnapshot
	if previous ~= nil and snapshot.revision <= previous.revision then
		return
	end
	latestSnapshot = snapshot
	updatePresentation()
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TemporaryMissionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	objectiveLabel = createLabel(gui, "Objective", UDim2.new(0.5, 0, 0, 52), UDim2.fromOffset(640, 26), 16)
	radioLabel = createLabel(gui, "Radio", UDim2.new(0.5, 0, 0, 84), UDim2.fromOffset(640, 24), 15)
	countdownLabel = createLabel(gui, "Countdown", UDim2.new(0.5, 0, 0, 114), UDim2.fromOffset(320, 30), 20)
	local outcome = createLabel(gui, "Outcome", UDim2.fromScale(0.5, 0.4), UDim2.fromOffset(640, 64), 44)
	outcome.Font = Enum.Font.GothamBold
	outcome.BackgroundTransparency = 0.15
	outcomeLabel = outcome
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	table.insert(connections, stateRemote.OnClientEvent:Connect(onSnapshot))
	table.insert(connections, RunService.Heartbeat:Connect(updateCountdown))
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
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	objectiveLabel = nil
	radioLabel = nil
	countdownLabel = nil
	outcomeLabel = nil
	latestSnapshot = nil
	displayedRadioTimestamp = nil
end

return Controller
