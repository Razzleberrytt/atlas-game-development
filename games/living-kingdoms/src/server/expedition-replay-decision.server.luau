--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems = ServerScriptService:WaitForChild("Systems")
local ExpeditionLiveRuntimeService = require(Systems.ExpeditionLiveRuntimeService)
local ExpeditionPartyDecisionService = require(Systems.ExpeditionPartyDecisionService)

local resultNetwork = ReplicatedStorage:WaitForChild("ExpeditionResultNetwork")
local resultReadState = resultNetwork:WaitForChild("ReadState") :: RemoteFunction

local request = Instance.new("RemoteFunction")
request.Name = "DecisionRequest"
request.Parent = resultNetwork

local state = Instance.new("RemoteEvent")
state.Name = "DecisionState"
state.Parent = resultNetwork

local decisionService: any = nil
local activeRunId: string? = nil
local activeSummary: any = nil
local resolvedRunId: string? = nil

local function captureParticipants(partySize: number): { number }
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local ids = {}
	for index = 1, math.min(partySize, #players) do
		table.insert(ids, players[index].UserId)
	end
	return ids
end

local function ensureDecisionService(summary: any)
	if activeRunId == summary.RunId and decisionService ~= nil then
		return
	end
	if decisionService ~= nil then
		decisionService:destroy()
	end
	activeRunId = summary.RunId
	activeSummary = summary
	resolvedRunId = nil
	decisionService = ExpeditionPartyDecisionService.new(captureParticipants(summary.PartySize))
end

local function safeSnapshot(snapshot: any): any
	if snapshot == nil then
		return nil
	end
	return table.freeze({
		ParticipantCount = snapshot.ParticipantCount,
		VoteCount = snapshot.VoteCount,
		ReplayVotes = snapshot.ReplayVotes,
		ReturnVotes = snapshot.ReturnVotes,
		ResolvedDecisionId = snapshot.ResolvedDecisionId,
	})
end

local function resolveIfReady(summary: any, snapshot: any)
	if snapshot == nil or snapshot.ResolvedDecisionId == "Undecided" or resolvedRunId == summary.RunId then
		return
	end
	resolvedRunId = summary.RunId
	ExpeditionLiveRuntimeService.stopExpedition("PartyDecision")
	if snapshot.ResolvedDecisionId == "Replay" then
		local launch = ExpeditionLiveRuntimeService.startExpedition({ PartySize = snapshot.ParticipantCount })
		if launch.Accepted ~= true then
			warn("[ExpeditionReplayDecision] replay rejected:", launch.ReasonId)
		end
	end
end

request.OnServerInvoke = function(player: Player, decisionId: any): any
	local summary = resultReadState.OnServerInvoke(player)
	if type(summary) ~= "table" then
		return table.freeze({ Accepted = false, ReasonId = "ResultUnavailable", Snapshot = nil })
	end
	ensureDecisionService(summary)
	local result = decisionService:cast(player.UserId, decisionId)
	local safe = safeSnapshot(result.Snapshot)
	state:FireAllClients(safe)
	if result.Accepted then
		resolveIfReady(summary, result.Snapshot)
	end
	return table.freeze({ Accepted = result.Accepted, ReasonId = result.ReasonId, Snapshot = safe })
end

Players.PlayerRemoving:Connect(function(player)
	if decisionService == nil or activeSummary == nil then
		return
	end
	local removal = decisionService:removeParticipant(player.UserId)
	if not removal.Accepted then
		return
	end
	local safe = safeSnapshot(removal.Snapshot)
	state:FireAllClients(safe)
	if removal.ReasonId == "PartyEmpty" then
		ExpeditionLiveRuntimeService.stopExpedition("PartyDisconnected")
		resolvedRunId = activeSummary.RunId
		return
	end
	resolveIfReady(activeSummary, removal.Snapshot)
end)

game:BindToClose(function()
	if decisionService ~= nil then
		decisionService:destroy()
	end
end)
