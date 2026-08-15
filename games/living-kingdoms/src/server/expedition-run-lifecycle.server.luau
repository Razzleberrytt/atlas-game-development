--!strict

-- Server-only orchestration glue for expedition run records. The live runtime
-- owns placed geometry/phase advancement; this owner mirrors those authoritative
-- facts into isolated run records, handles participant connectivity, and closes
-- teardown gaps without creating a client mutation surface.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EquipmentContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)

local Systems = script.Parent.Systems
local EnemyDirectorService = require(Systems.EnemyDirectorService)
local ExpeditionLiveRuntimeService = require(Systems.ExpeditionLiveRuntimeService)
local ExpeditionRunRosterService = require(Systems.ExpeditionRunRosterService)
local ExpeditionRunStateService = require(Systems.ExpeditionRunStateService)

local STEP_INTERVAL_SECONDS = 0.25
local accumulatedSeconds = 0
local observedRunId: string? = nil

local function nowUnix(): number
	return Workspace:GetServerTimeNow()
end

local function roleForRoom(roomPlan: any, roomId: string?): string?
	if roomId == nil or type(roomPlan) ~= "table" or type(roomPlan.Nodes) ~= "table" then
		return nil
	end
	for _, node in roomPlan.Nodes do
		if node.RoomId == roomId then
			return if type(node.Role) == "string" then node.Role else node.RoleId
		end
	end
	return nil
end

local function resetEnemyDirector()
	-- EnemyDirector owns enemy entities. Its public stop/start lifecycle clears
	-- the stable enemy folder and internal entries, then remounts the same folder
	-- contract for the next run without Agent 5 reaching into combat internals.
	EnemyDirectorService.stop()
	EnemyDirectorService.start()
end

local function archiveAndRelease(runId: string, reasonId: string?)
	local current = ExpeditionRunStateService.read(runId)
	if current ~= nil and current.LifecycleState ~= "Completed" and current.LifecycleState ~= "Failed" then
		ExpeditionRunStateService.fail(runId, reasonId or "RunStoppedBeforeCompletion", nowUnix(), "Abandoned")
	end
	ExpeditionRunStateService.completeCleanup(runId, nowUnix())
	ExpeditionRunRosterService.clear(runId)
end

local function ensureTracked(snapshot: any): any?
	local existing = ExpeditionRunStateService.read(snapshot.RunId)
	if existing ~= nil then
		return existing
	end
	local created = ExpeditionRunStateService.create({
		RunId = snapshot.RunId,
		Seed = snapshot.Seed,
		PartySize = snapshot.PartySize,
		StartedAtUnix = snapshot.StartedAtUnix,
		RoomPlan = ExpeditionLiveRuntimeService.readRoomPlan(),
	})
	if created.Accepted ~= true then
		warn("[ExpeditionRunLifecycle] failed to track run:", created.ReasonId)
		return nil
	end
	return created.Snapshot
end

local function synchronizeParticipantRoster(runId: string)
	local roster = ExpeditionRunRosterService.read(runId)
	if roster == nil then
		return
	end
	local bound = ExpeditionRunStateService.bindParticipants(runId, roster.ParticipantUserIds)
	if bound.Accepted ~= true and bound.ReasonId ~= "ParticipantsAlreadyBound" then
		warn("[ExpeditionRunLifecycle] participant binding rejected:", bound.ReasonId)
		return
	end
	for _, userId in roster.ParticipantUserIds do
		if Players:GetPlayerByUserId(userId) ~= nil then
			ExpeditionRunStateService.setParticipantConnected(runId, userId, true)
		else
			ExpeditionRunStateService.setParticipantConnected(runId, userId, false)
		end
	end
end

local function observeLiveRun()
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil then
		if observedRunId ~= nil then
			archiveAndRelease(observedRunId, "RunStopped")
			observedRunId = nil
			resetEnemyDirector()
		end
		return
	end

	if observedRunId ~= nil and observedRunId ~= snapshot.RunId then
		-- A replacement run is already live, so never reset the director here: that
		-- would erase the new run's enemies. Only archive the stale metadata.
		archiveAndRelease(observedRunId, "RunReplaced")
	end
	observedRunId = snapshot.RunId
	if ensureTracked(snapshot) == nil then
		return
	end
	synchronizeParticipantRoster(snapshot.RunId)

	local roomPlan = ExpeditionLiveRuntimeService.readRoomPlan()
	local composition = ExpeditionLiveRuntimeService.readRunVariationComposition(snapshot.RunId, os.clock())
	local compositionReadable = type(composition) == "table" and composition.RunId == snapshot.RunId
	local roomId = if compositionReadable then composition.CurrentRoomId else nil
	local encounterPhaseId = if compositionReadable then composition.CurrentEncounterPhaseId else snapshot.PhaseId
	local roomRoleId = roleForRoom(roomPlan, roomId)
	if roomRoleId == nil and (snapshot.PhaseId == "Elite" or snapshot.PhaseId == "Boss") then
		roomRoleId = snapshot.PhaseId
	end
	local encounterActive = snapshot.OutcomeId == "InProgress"
		and (
			snapshot.PhaseId == "Approach"
			or snapshot.PhaseId == "Elite"
			or snapshot.PhaseId == "Boss"
			or (roomId ~= nil and roomRoleId ~= "Traversal")
		)
	local encounterKey = if encounterActive
		then table.concat({ tostring(encounterPhaseId), tostring(roomId or roomRoleId or "phase") }, ":")
		else nil

	if type(snapshot.PhaseIndex) == "number" and snapshot.PhaseIndex > 4 then
		ExpeditionRunStateService.recordRewardOutcome(snapshot.RunId, EquipmentContracts.SourceIds.Elite)
	end
	if type(snapshot.PhaseIndex) == "number" and snapshot.PhaseIndex > 5 then
		ExpeditionRunStateService.recordRewardOutcome(snapshot.RunId, EquipmentContracts.SourceIds.Boss)
	end

	local synchronized = ExpeditionRunStateService.sync(snapshot.RunId, {
		Snapshot = snapshot,
		CurrentRoomId = roomId,
		CurrentRoomRoleId = roomRoleId,
		EncounterKey = encounterKey,
		EncounterActive = encounterActive,
		CompletedRoomCount = if compositionReadable then composition.CompletedRoomCount else nil,
		EncounteredRoomCount = if compositionReadable then composition.EncounteredRoomCount else nil,
		TotalRoomCount = if compositionReadable then composition.TotalRoomCount else nil,
		ObservedAtUnix = nowUnix(),
	})
	if synchronized.Accepted ~= true then
		warn("[ExpeditionRunLifecycle] run synchronization rejected:", synchronized.ReasonId)
	end
end

local function activeParticipantDeparture(userId: number)
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil then
		return
	end
	local roster = ExpeditionRunRosterService.read(snapshot.RunId)
	if roster == nil then
		return
	end
	local isParticipant = false
	for _, participantUserId in roster.ParticipantUserIds do
		if participantUserId == userId then
			isParticipant = true
			break
		end
	end
	if not isParticipant then
		return
	end

	ensureTracked(snapshot)
	ExpeditionRunStateService.bindParticipants(snapshot.RunId, roster.ParticipantUserIds)
	local departure = ExpeditionRunStateService.setParticipantConnected(snapshot.RunId, userId, false)
	if departure.Accepted ~= true or departure.AllParticipantsDisconnected ~= true then
		return
	end

	ExpeditionRunStateService.fail(snapshot.RunId, "AllParticipantsLeft", nowUnix(), "Abandoned")
	local stopped = ExpeditionLiveRuntimeService.stopExpedition("AllParticipantsLeft")
	if stopped.Accepted == true then
		archiveAndRelease(snapshot.RunId, "AllParticipantsLeft")
		observedRunId = nil
		resetEnemyDirector()
	end
end

local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
	if type(deltaTime) ~= "number" or deltaTime <= 0 then
		return
	end
	accumulatedSeconds += deltaTime
	if accumulatedSeconds < STEP_INTERVAL_SECONDS then
		return
	end
	accumulatedSeconds = accumulatedSeconds % STEP_INTERVAL_SECONDS
	observeLiveRun()
end)

local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil then
		return
	end
	local roster = ExpeditionRunRosterService.read(snapshot.RunId)
	if roster == nil then
		return
	end
	for _, participantUserId in roster.ParticipantUserIds do
		if participantUserId == player.UserId then
			ExpeditionRunStateService.setParticipantConnected(snapshot.RunId, player.UserId, true)
			return
		end
	end
end)

local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
	activeParticipantDeparture(player.UserId)
end)

game:BindToClose(function()
	heartbeatConnection:Disconnect()
	playerAddedConnection:Disconnect()
	playerRemovingConnection:Disconnect()
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot ~= nil then
		ExpeditionRunStateService.fail(snapshot.RunId, "ServerClosing", nowUnix(), "Abandoned")
		archiveAndRelease(snapshot.RunId, "ServerClosing")
	end
end)

print("[Living Kingdoms] Expedition run lifecycle mounted")
