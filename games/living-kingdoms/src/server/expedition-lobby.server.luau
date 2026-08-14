--!strict

-- Server-authoritative expedition lobby bridge. Clients may request join, leave,
-- ready changes, or a terminal return for themselves only. Launch and teardown
-- decisions remain server-owned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = script.Parent.Systems
local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)
local FirstDungeonContentConfig = require(ReplicatedStorage.Shared.Config.FirstDungeonContentConfig)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local DurableStartingLoadoutService = require(Systems.DurableStartingLoadoutService)
local ExpeditionLobbyService = require(Systems.ExpeditionLobbyService)
local ExpeditionLiveRuntimeService = require(Systems.ExpeditionLiveRuntimeService)
local ExpeditionRunRosterService = require(Systems.ExpeditionRunRosterService)
local OperationLifecycleService = require(Systems.OperationLifecycleService)
local MissionDirectorService = require(Systems.MissionDirectorService)
local HordeExperienceService = require(Systems.HordeExperienceService)

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
	if snapshot == nil then
		return nil
	end
	local members = {}
	for _, member in snapshot.Members do
		local player = Players:GetPlayerByUserId(member.PlayerId)
		table.insert(
			members,
			table.freeze({
				PlayerId = member.PlayerId,
				DisplayName = if player then player.DisplayName else ("Player " .. tostring(member.PlayerId)),
				Ready = member.Ready,
			})
		)
	end
	return table.freeze({
		Revision = snapshot.Revision,
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

local function isMember(playerId: number): boolean
	local snapshot = lobby:readSnapshot()
	if snapshot == nil then
		return false
	end
	for _, member in snapshot.Members do
		if member.PlayerId == playerId then
			return true
		end
	end
	return false
end

local function activeRunParticipant(playerId: number): boolean
	local expedition = ExpeditionLiveRuntimeService.readSnapshot()
	if expedition == nil then
		return false
	end
	local roster = ExpeditionRunRosterService.read(expedition.RunId)
	if roster == nil then
		return false
	end
	for _, participantUserId in roster.ParticipantUserIds do
		if participantUserId == playerId then
			return true
		end
	end
	return false
end

local function applyDurableStartingLoadouts(members: { any })
	for _, member in members do
		local player = Players:GetPlayerByUserId(member.PlayerId)
		if player == nil then
			continue
		end
		local result = DurableStartingLoadoutService.applyForPlayer(player)
		if result.Accepted ~= true and result.ReasonId ~= "NoEquippedDurableWeapon" then
			warn(
				string.format(
					"[ExpeditionLobby] durable starting loadout rejected for %d: %s",
					member.PlayerId,
					result.ReasonId
				)
			)
		end
	end
end

local function participantUserIds(members: { any }): { number }
	local userIds = {}
	for _, member in members do
		table.insert(userIds, member.PlayerId)
	end
	return userIds
end

local function attemptLaunch()
	if launchInFlight then
		return
	end
	local snapshot = lobby:readSnapshot()
	if snapshot == nil or not snapshot.LaunchPending then
		return
	end
	if ExpeditionLiveRuntimeService.readSnapshot() ~= nil then
		return
	end
	launchInFlight = true

	local consumed = lobby:consumeLaunch()
	if consumed.Accepted ~= true then
		launchInFlight = false
		broadcast()
		return
	end

	if not OperationLifecycleService.prepareForLaunch() then
		warn("[ExpeditionLobby] lifecycle preparation rejected")
		launchInFlight = false
		broadcast()
		return
	end

	applyDurableStartingLoadouts(consumed.Snapshot.Members)
	MissionDirectorService.armPressure()
	HordeExperienceService.armPressure()

	local launch = ExpeditionLiveRuntimeService.startExpedition({
		PartySize = consumed.Snapshot.MemberCount,
		Seed = FirstDungeonContentConfig.CanonicalSeed,
	})
	if launch.Accepted ~= true then
		warn("[ExpeditionLobby] launch rejected:", launch.ReasonId)
	else
		local runId = if launch.Snapshot ~= nil then launch.Snapshot.RunId else nil
		local roster = if type(runId) == "string"
			then ExpeditionRunRosterService.bind(runId, participantUserIds(consumed.Snapshot.Members))
			else nil
		if roster == nil or roster.Accepted ~= true then
			warn("[ExpeditionLobby] run roster binding rejected")
			ExpeditionLiveRuntimeService.stopExpedition("RosterBindingFailed")
		end
	end
	launchInFlight = false
	broadcast()
end

local function response(accepted: boolean, reasonId: string): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Snapshot = sanitizedSnapshot() })
end

local function returnToLobby(player: Player): any
	if not isMember(player.UserId) then
		return response(false, "PlayerNotJoined")
	end
	local expedition = ExpeditionLiveRuntimeService.readSnapshot()
	if expedition == nil then
		return response(false, "NoActiveExpedition")
	end
	if expedition.OutcomeId == ExpeditionContracts.OutcomeIds.InProgress then
		return response(false, "RunStillInProgress")
	end

	local stopped = ExpeditionLiveRuntimeService.stopExpedition("ReturnedToLobby")
	if stopped.Accepted ~= true then
		return response(false, stopped.ReasonId)
	end
	broadcast()
	return response(true, "ReturnedToLobby")
end

request.OnServerInvoke = function(player: Player, action: any, payload: any): any
	if type(action) ~= "string" then
		return response(false, "InvalidAction")
	end

	local activeExpedition = ExpeditionLiveRuntimeService.readSnapshot()
	local result
	if action == "Join" then
		if activeExpedition ~= nil and not activeRunParticipant(player.UserId) then
			return response(false, "LateJoinClosed")
		end
		result = lobby:join(player.UserId)
	elseif action == "Leave" then
		if activeExpedition ~= nil then
			return response(false, "ActiveExpeditionMembershipLocked")
		end
		result = lobby:leave(player.UserId)
	elseif action == "SetReady" then
		if activeExpedition ~= nil then
			return response(false, "ExpeditionActive")
		end
		local ready = if type(payload) == "table" then payload.Ready else nil
		result = lobby:setReady(player.UserId, ready)
	elseif action == "ReturnToLobby" then
		return returnToLobby(player)
	else
		return response(false, "UnknownAction")
	end

	broadcast()
	attemptLaunch()
	return response(result.Accepted == true, result.ReasonId)
end

readState.OnServerInvoke = function(_player: Player): any
	return sanitizedSnapshot()
end

Players.PlayerRemoving:Connect(function(player)
	-- Disconnect removes the presentation/lobby member so a returning run
	-- participant has a clean reconnect path. The immutable run roster is not
	-- mutated, preserving reward credit and active-run identity.
	lobby:leave(player.UserId)
	broadcast()
end)

game:BindToClose(function()
	lobby:destroy()
end)

print("[Living Kingdoms] Expedition lobby mounted")
