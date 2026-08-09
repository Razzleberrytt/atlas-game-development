--!strict

--[[
	P10-0105 deterministic match cleanup and replay.

	This is the one owner of the terminal stop/start sequence. It holds no gameplay
	state of its own: it executes `MatchResultConfig.CleanupStopOrder` and
	`ReplayStartOrder` against each system's existing lifecycle, so cleanup order
	lives in shared configuration rather than in a hand-written sequence here. Both
	orders are asserted to cover every declared cleanup owner exactly once, so no
	owner can be skipped or torn down twice.

	Replay is a clean restart of the same authored operation, never a resume. The
	mission director mints a fresh per-run `operationId` on each start, so a
	replayed operation is a distinct result with no stale timers, connections,
	revisions, cache history, class resources, enemies, boss state, contribution
	records, or terminal result.

	It owns exactly one timer and one subscription, and it accepts no client
	request — replay is server-driven, so a resolved server restarts without
	developer intervention.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchResultConfig = require(ReplicatedStorage.Shared.Config.MatchResultConfig)
local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)
local AmmunitionCacheService = require(script.Parent.AmmunitionCacheService)
local ClassService = require(script.Parent.ClassService)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local MatchResultService = require(script.Parent.MatchResultService)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local OperativeReviveSessionService = require(script.Parent.OperativeReviveSessionService)
local SquadFailureService = require(script.Parent.SquadFailureService)

type OperationReplayStateId = MatchResultContracts.OperationReplayStateId
type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

local CleanupOwnerIds = MatchResultContracts.CleanupOwnerIds
local ReplayStateIds = MatchResultContracts.OperationReplayStateIds

local OperationLifecycleService = {}

-- Each declared cleanup owner mapped to the lifecycle it already exposes. The
-- objective runtime is owned by the mission director, so it releases its own
-- state at its documented place and the director tears the rest down last.
local stopByOwnerId: { [string]: () -> () } = {
	[CleanupOwnerIds.EnemyDirector] = function()
		EnemyDirectorService.stop()
	end,
	[CleanupOwnerIds.Objectives] = function()
		MissionDirectorService.resetObjectiveRuntime()
	end,
	[CleanupOwnerIds.AmmunitionCaches] = function()
		AmmunitionCacheService.stop()
	end,
	[CleanupOwnerIds.Classes] = function()
		ClassService.stop()
	end,
	[CleanupOwnerIds.ReviveSessions] = function()
		OperativeReviveSessionService.stop()
	end,
	-- OperativeLifeService owns application-scoped player and subscriber
	-- bindings. Replay resets its operation state during the start sequence
	-- instead of stopping it and orphaning long-lived consumers.
	[CleanupOwnerIds.OperativeLife] = function() end,
	[CleanupOwnerIds.SquadFailure] = function()
		SquadFailureService.stop()
	end,
	[CleanupOwnerIds.ContributionRecord] = function()
		MatchResultService.stop()
	end,
	[CleanupOwnerIds.MissionDirector] = function()
		MissionDirectorService.stop()
	end,
}

local startByOwnerId: { [string]: () -> () } = {
	[CleanupOwnerIds.EnemyDirector] = function()
		EnemyDirectorService.start()
	end,
	-- The objective runtime comes back with the mission director that owns it.
	[CleanupOwnerIds.Objectives] = function() end,
	[CleanupOwnerIds.AmmunitionCaches] = function()
		AmmunitionCacheService.start()
	end,
	[CleanupOwnerIds.Classes] = function()
		ClassService.start()
	end,
	[CleanupOwnerIds.ReviveSessions] = function()
		OperativeReviveSessionService.start()
	end,
	[CleanupOwnerIds.OperativeLife] = function()
		OperativeLifeService.resetForReplay()
	end,
	[CleanupOwnerIds.SquadFailure] = function()
		SquadFailureService.start()
	end,
	[CleanupOwnerIds.ContributionRecord] = function()
		MatchResultService.start()
	end,
	[CleanupOwnerIds.MissionDirector] = function()
		MissionDirectorService.start()
	end,
}

local started = false
local replayStateId: OperationReplayStateId = ReplayStateIds.InProgress
local replayGeneration = 0
local replayThread: thread? = nil
local terminalConnection: ListenerConnection? = nil
local completedReplayCount = 0

local function cancelScheduledReplay()
	replayGeneration += 1
	if replayThread ~= nil then
		pcall(task.cancel, replayThread)
		replayThread = nil
	end
end

--[[
	Runs the documented stop order, then the documented start order. Every step is
	isolated: one owner erroring cannot strand the rest half-torn-down, because the
	sequence is configuration-driven and each call is protected.
]]
local function performReplay()
	for _, ownerId in MatchResultConfig.CleanupStopOrder do
		local stopOwner = stopByOwnerId[ownerId]
		if stopOwner ~= nil then
			pcall(stopOwner)
		end
	end
	for _, ownerId in MatchResultConfig.ReplayStartOrder do
		local startOwner = startByOwnerId[ownerId]
		if startOwner ~= nil then
			pcall(startOwner)
		end
	end
	completedReplayCount += 1
	replayStateId = ReplayStateIds.InProgress
end

local function onResolved()
	if not started or replayStateId ~= ReplayStateIds.InProgress then
		return
	end
	replayStateId = ReplayStateIds.Resolved
	cancelScheduledReplay()
	local generation = replayGeneration
	replayThread = task.delay(MatchResultConfig.ReplayDebriefSeconds, function()
		if not started or generation ~= replayGeneration then
			return
		end
		replayThread = nil
		replayStateId = ReplayStateIds.Replayable
		performReplay()
	end)
end

-- Server-only immediate replay, for validation and for a future operator control.
-- It is never reachable from a client.
function OperationLifecycleService.replayNow(): boolean
	if not started then
		return false
	end
	cancelScheduledReplay()
	replayStateId = ReplayStateIds.Replayable
	performReplay()
	return true
end

function OperationLifecycleService.readReplayStateId(): OperationReplayStateId
	return replayStateId
end

function OperationLifecycleService.readCompletedReplayCount(): number
	return completedReplayCount
end

function OperationLifecycleService.start()
	if started then
		return
	end
	started = true
	replayStateId = ReplayStateIds.InProgress
	completedReplayCount = 0
	terminalConnection = MissionDirectorService.subscribeResolved(onResolved)
end

function OperationLifecycleService.stop()
	if not started then
		return
	end
	started = false
	cancelScheduledReplay()
	if terminalConnection ~= nil then
		terminalConnection:Disconnect()
		terminalConnection = nil
	end
	replayStateId = ReplayStateIds.InProgress
	completedReplayCount = 0
end

return table.freeze(OperationLifecycleService)
