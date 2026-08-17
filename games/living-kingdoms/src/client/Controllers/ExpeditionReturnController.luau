--!strict

-- Terminal-only return control. A return request is a server-owned party vote;
-- this controller presents the sanitized consensus snapshot and never decides
-- whether the expedition may stop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder or child the server has not created yet fails
	this one controller instead of stalling the whole client bootstrap. The
	bootstrap requires controllers in a deliberate order with no isolation, so
	an unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20

local Controller = {}
local player = Players.LocalPlayer
local resultNetwork = ReplicatedStorage:WaitForChild("ExpeditionResultNetwork", NETWORK_WAIT_SECONDS)
assert(resultNetwork ~= nil, "ExpeditionResultNetwork did not become available before the client bootstrap timeout")
local resultState = resultNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(resultState ~= nil, "ExpeditionResultNetwork.State did not become available before the client bootstrap timeout")
local resultRead = resultNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?
assert(
	resultRead ~= nil,
	"ExpeditionResultNetwork.ReadState did not become available before the client bootstrap timeout"
)
local lobbyNetwork = ReplicatedStorage:WaitForChild("ExpeditionLobbyNetwork", NETWORK_WAIT_SECONDS)
assert(lobbyNetwork ~= nil, "ExpeditionLobbyNetwork did not become available before the client bootstrap timeout")
local lobbyRequest = lobbyNetwork:WaitForChild("Request", NETWORK_WAIT_SECONDS) :: RemoteFunction?
assert(
	lobbyRequest ~= nil,
	"ExpeditionLobbyNetwork.Request did not become available before the client bootstrap timeout"
)
local lobbyState = lobbyNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(lobbyState ~= nil, "ExpeditionLobbyNetwork.State did not become available before the client bootstrap timeout")

local started = false
local resultConnection: RBXScriptConnection? = nil
local lobbyConnection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local button: TextButton? = nil
local requestInFlight = false
local terminalVisible = false
local votedForReturn = false

local function applyDecision(snapshot: any)
	if gui == nil or button == nil or not terminalVisible then
		return
	end
	local decision = if type(snapshot) == "table" then snapshot.TerminalDecision else nil
	if type(decision) ~= "table" then
		if not requestInFlight then
			button.Active = true
			button.Text = "RETURN TO LOBBY"
		end
		return
	end
	local ownVote = if type(decision.VotesByPlayerId) == "table" then decision.VotesByPlayerId[player.UserId] else nil
	votedForReturn = ownVote == "ReturnToPreparation"
	if votedForReturn and decision.ResolvedDecisionId == "Undecided" then
		button.Active = false
		button.Text =
			string.format("WAITING FOR SQUAD  %d/%d", decision.ReturnVotes or 0, decision.ParticipantCount or 0)
	elseif not requestInFlight then
		button.Active = true
		button.Text = "RETURN TO LOBBY"
	end
end

local function createGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "LK_ExpeditionReturn"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 23
	screen.Enabled = false
	local playerGui = player:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?
	assert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")
	screen.Parent = playerGui
	gui = screen

	local returnButton = Instance.new("TextButton")
	returnButton.AnchorPoint = Vector2.new(0.5, 1)
	returnButton.Position = UDim2.new(0.5, 0, 1, -54)
	returnButton.Size = UDim2.fromOffset(270, 48)
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
		if requestInFlight or votedForReturn then
			return
		end
		requestInFlight = true
		returnButton.Active = false
		returnButton.Text = "CASTING RETURN VOTE..."
		local ok, result = pcall(function()
			return lobbyRequest:InvokeServer("ReturnToLobby")
		end)
		requestInFlight = false
		if ok and type(result) == "table" and result.Accepted == true then
			if result.ReasonId == "AwaitingPartyReturn" then
				votedForReturn = true
				applyDecision(result.Snapshot)
			else
				screen.Enabled = false
			end
		else
			returnButton.Active = true
			returnButton.Text = "RETURN TO LOBBY"
		end
	end)
end

local function receive(summary: any)
	if gui == nil or button == nil then
		return
	end
	terminalVisible = type(summary) == "table"
		and (summary.OutcomeId == "Completed" or summary.OutcomeId == "Failed" or summary.OutcomeId == "Abandoned")
	gui.Enabled = terminalVisible
	if terminalVisible and not votedForReturn then
		button.Active = true
		button.Text = "RETURN TO LOBBY"
	elseif not terminalVisible then
		votedForReturn = false
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createGui()
	resultConnection = resultState.OnClientEvent:Connect(receive)
	lobbyConnection = lobbyState.OnClientEvent:Connect(applyDecision)
	local ok, initial = pcall(function()
		return resultRead:InvokeServer()
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
	if resultConnection then
		resultConnection:Disconnect()
		resultConnection = nil
	end
	if lobbyConnection then
		lobbyConnection:Disconnect()
		lobbyConnection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	button = nil
	terminalVisible = false
	votedForReturn = false
	requestInFlight = false
end

return Controller
