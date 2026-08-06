--!strict

-- Server-authoritative expedition lobby bridge. Clients may request join, leave,
-- or ready changes for themselves only. Launch decisions remain owned by the
-- lobby domain and are forwarded to the live expedition runtime exactly once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems = ServerScriptService:WaitForChild("Systems")
local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)
local ExpeditionLobbyService = require(Systems.ExpeditionLobbyService)
local ExpeditionLiveRuntimeService = require(Systems.ExpeditionLiveRuntimeService)

local existing = ReplicatedStorage:FindFirstChild("ExpeditionLobbyNetwork")
if existing ~= nil then
	existing:Destroy()
end

local network = Instance.new("Folder")
network.Name = "ExpeditionLobbyNetwork"
network.Parent = ReplicatedStorage

local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = network

local state = Instance.new("RemoteEvent")
state.Name = "State"
state.Parent = network

local readState = Instance.new("RemoteFunction")
readState.Name = "ReadState"
readState.Parent = network

local definition = ExpeditionConfig.Definitions.FirstExpedition
local lobby = ExpeditionLobbyService.new(definition.MinimumPlayers, definition.MaximumPlayers)
local launchInFlight = false

local function sanitizedSnapshot(): any
	local snapshot = lobby:readSnapshot()
	if snapshot == nil then return nil end
	local members = {}
	for _, member in snapshot.Members do
		local player = Players:GetPlayerByUserId(member.PlayerId)
		table.insert(members, table.freeze({
			PlayerId = member.PlayerId,
			DisplayName = if player then player.DisplayName else ("Player " .. tostring(member.PlayerId)),
			Ready = member.Ready,
		}))
	end
	return table.freeze({
		Members = table.freeze(members),
		MemberCount = snapshot.MemberCount,
		MinimumPlayers = snapshot.MinimumPlayers,
		MaximumPlayers = snapshot.MaximumPlayers,
		AllReady = snapshot.AllReady,
		LaunchPending = snapshot.LaunchPending,
	})
end

local function broadcast()
	state:FireAllClients(sanitizedSnapshot())
end

local function attemptLaunch()
	if launchInFlight then return end
	local snapshot = lobby:readSnapshot()
	if snapshot == nil or not snapshot.LaunchPending then return end
	launchInFlight = true

	local consumed = lobby:consumeLaunch()
	if consumed.Accepted ~= true then
		launchInFlight = false
		broadcast()
		return
	end

	local launch = ExpeditionLiveRuntimeService.startExpedition({
		PartySize = consumed.Snapshot.MemberCount,
	})
	if launch.Accepted ~= true then
		warn("[ExpeditionLobby] launch rejected:", launch.ReasonId)
		for _, member in consumed.Snapshot.Members do
			lobby:setReady(member.PlayerId, false)
		end
	end
	launchInFlight = false
	broadcast()
end

local function response(result: any): any
	return table.freeze({
		Accepted = result.Accepted == true,
		ReasonId = result.ReasonId,
		Snapshot = sanitizedSnapshot(),
	})
end

request.OnServerInvoke = function(player: Player, action: any, payload: any): any
	if type(action) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidAction", Snapshot = sanitizedSnapshot() })
	end

	local result
	if action == "Join" then
		result = lobby:join(player.UserId)
	elseif action == "Leave" then
		result = lobby:leave(player.UserId)
	elseif action == "SetReady" then
		local ready = if type(payload) == "table" then payload.Ready else nil
		result = lobby:setReady(player.UserId, ready)
	else
		return table.freeze({ Accepted = false, ReasonId = "UnknownAction", Snapshot = sanitizedSnapshot() })
	end

	broadcast()
	attemptLaunch()
	return response(result)
end

readState.OnServerInvoke = function(_player: Player): any
	return sanitizedSnapshot()
end

Players.PlayerRemoving:Connect(function(player)
	lobby:leave(player.UserId)
	broadcast()
end)

game:BindToClose(function()
	lobby:destroy()
end)

print("[Living Kingdoms] Expedition lobby mounted")
