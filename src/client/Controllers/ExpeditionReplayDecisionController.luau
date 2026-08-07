--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)

local Controller = {}
local started = false
local gui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local resultConnection: RBXScriptConnection? = nil
local decisionConnection: RBXScriptConnection? = nil

local function createButton(parent: Instance, text: string, position: UDim2, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(220, 46)
	button.Position = position
	button.Text = text
	button.TextSize = 18
	button.AutoButtonColor = true
	button.Parent = parent
	button.Activated:Connect(callback)
	return button
end

function Controller.start()
	if started then
		return
	end
	started = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local network = ReplicatedStorage:WaitForChild("ExpeditionResultNetwork")
	local resultState = network:WaitForChild("State") :: RemoteEvent
	local decisionRequest = network:WaitForChild("DecisionRequest") :: RemoteFunction
	local decisionState = network:WaitForChild("DecisionState") :: RemoteEvent

	local screen = Instance.new("ScreenGui")
	screen.Name = "LK_ExpeditionReplayDecision"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 24
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	local panel = InterfaceTheme.panel(screen, "DecisionPanel")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 0.95)
	panel.Size = UDim2.fromOffset(500, 115)

	statusLabel =
		InterfaceTheme.label(panel, { name = "Status", role = "Body", size = InterfaceTheme.TextSize.Subtitle })
	statusLabel.Size = UDim2.new(1, -20, 0, 35)
	statusLabel.Position = UDim2.fromOffset(10, 8)
	statusLabel.Text = "Choose the party's next move."

	createButton(panel, "REPLAY", UDim2.fromOffset(20, 56), function()
		local ok, response = pcall(function()
			return decisionRequest:InvokeServer("Replay")
		end)
		if ok and statusLabel then
			statusLabel.Text = response.Accepted and "Replay vote recorded." or response.ReasonId
		end
	end)
	createButton(panel, "RETURN", UDim2.fromOffset(260, 56), function()
		local ok, response = pcall(function()
			return decisionRequest:InvokeServer("ReturnToPreparation")
		end)
		if ok and statusLabel then
			statusLabel.Text = response.Accepted and "Return vote recorded." or response.ReasonId
		end
	end)

	resultConnection = resultState.OnClientEvent:Connect(function(summary)
		screen.Enabled = type(summary) == "table" and summary.OutcomeId ~= "InProgress"
	end)
	decisionConnection = decisionState.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" or statusLabel == nil then
			return
		end
		if snapshot.ResolvedDecisionId == "Undecided" then
			statusLabel.Text = string.format(
				"Votes: %d/%d  •  Replay %d  •  Return %d",
				snapshot.VoteCount,
				snapshot.ParticipantCount,
				snapshot.ReplayVotes,
				snapshot.ReturnVotes
			)
		else
			statusLabel.Text = snapshot.ResolvedDecisionId == "Replay" and "Party replaying…"
				or "Returning to preparation…"
			screen.Enabled = false
		end
	end)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if resultConnection then
		resultConnection:Disconnect()
		resultConnection = nil
	end
	if decisionConnection then
		decisionConnection:Disconnect()
		decisionConnection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return Controller
